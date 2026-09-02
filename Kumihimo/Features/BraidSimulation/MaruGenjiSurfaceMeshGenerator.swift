import Foundation
import simd

struct MaruGenjiSurfaceMeshData: Sendable {
    let positions: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let textureCoordinates: [SIMD2<Float>]
    let patchLocalCoordinates: [SIMD2<Float>]
    let boundaryDistances: [Float]
    let colorGroups: [ThreadColorID: [UInt32]]
    let boundaryColorGroups: [ThreadColorID: [UInt32]]
    let surfaceTrianglePatchIndices: [Int]
    let surfaceTriangleIsBoundary: [Bool]
    let surfaceVertexPatchIndices: [Int]
    let seamStartVertexIndices: [Int]
    let seamEndVertexIndices: [Int]

    var triangleCount: Int {
        (Array(colorGroups.values) + Array(boundaryColorGroups.values))
            .reduce(0) { $0 + $1.count / 3 }
    }

    var allTriangleIndices: [UInt32] {
        (Array(colorGroups.values) + Array(boundaryColorGroups.values)).flatMap { $0 }
    }
}

enum MaruGenjiSurfaceMeshGenerator {
    static let defaultRadius: Float = 0.48
    static let defaultLength: Float = 3.4
    static let defaultPatternRepeatCount = 4
    static let defaultCircumferentialSubdivisionsPerPatch = 4
    static let defaultLongitudinalSubdivisionsPerPatch = 24
    static let boundaryWidth: Float = 0.035
    static let boundaryDepthRatio: Float = 0.012
    static let fiberReliefRatio: Float = 0.006
    static let fiberCount = 8

    static func generate(
        pattern: MaruGenjiSurfacePattern,
        radius: Float = defaultRadius,
        length: Float = defaultLength,
        patternRepeatCount: Int = defaultPatternRepeatCount,
        circumferentialSubdivisionsPerPatch: Int = defaultCircumferentialSubdivisionsPerPatch,
        longitudinalSubdivisionsPerPatch: Int = defaultLongitudinalSubdivisionsPerPatch
    ) -> MaruGenjiSurfaceMeshData? {
        guard
            pattern.patches.count == MaruGenjiSurfacePatternGenerator.patchCount,
            radius.isFinite,
            radius > 0,
            length.isFinite,
            length > 0,
            patternRepeatCount > 0,
            circumferentialSubdivisionsPerPatch > 0,
            longitudinalSubdivisionsPerPatch >= fiberCount * 3,
            pattern.patches.allSatisfy(isValid)
        else {
            return nil
        }

        var builder = MeshBuilder()
        let localUSamples = subdivisionSamples(count: circumferentialSubdivisionsPerPatch)
        let localVSamples = subdivisionSamples(count: longitudinalSubdivisionsPerPatch)

        // Include the preceding repeat because the final chevron row crosses v == 1.
        // Each triangle is clipped to the requested braid length below.
        for repeatIndex in -1..<patternRepeatCount {
            for (patchIndex, patch) in pattern.patches.enumerated() {
                appendSurfacePatch(
                    patch,
                    patchIndex: patchIndex,
                    repeatIndex: repeatIndex,
                    repeatCount: patternRepeatCount,
                    radius: radius,
                    length: length,
                    localUSamples: localUSamples,
                    localVSamples: localVSamples,
                    builder: &builder
                )
            }
        }

        appendEndCap(
            at: -length / 2,
            outwardNormal: SIMD3<Float>(-1, 0, 0),
            edgeV: 0,
            pattern: pattern,
            radius: radius,
            segmentCount: 8 * circumferentialSubdivisionsPerPatch,
            builder: &builder
        )
        appendEndCap(
            at: length / 2,
            outwardNormal: SIMD3<Float>(1, 0, 0),
            edgeV: 1,
            pattern: pattern,
            radius: radius,
            segmentCount: 8 * circumferentialSubdivisionsPerPatch,
            builder: &builder
        )

        let seamStartVertexIndices = uniqueSeamIndices(
            builder.seamStartVertexIndices,
            positions: builder.positions
        )
        let seamEndVertexIndices = uniqueSeamIndices(
            builder.seamEndVertexIndices,
            positions: builder.positions
        )
        let allIndices = (Array(builder.colorGroups.values) + Array(builder.boundaryColorGroups.values))
            .flatMap { $0 }

        guard
            !builder.positions.isEmpty,
            builder.positions.count == builder.normals.count,
            builder.positions.count == builder.textureCoordinates.count,
            builder.positions.count == builder.patchLocalCoordinates.count,
            builder.positions.count == builder.boundaryDistances.count,
            builder.positions.count == builder.surfaceVertexPatchIndices.count,
            builder.surfaceTrianglePatchIndices.count == builder.surfaceTriangleIsBoundary.count,
            !builder.colorGroups.isEmpty,
            builder.colorGroups.values.allSatisfy({ !$0.isEmpty && $0.count.isMultiple(of: 3) }),
            builder.boundaryColorGroups.values.allSatisfy({ !$0.isEmpty && $0.count.isMultiple(of: 3) }),
            allIndices.allSatisfy({ Int($0) < builder.positions.count }),
            builder.positions.allSatisfy(isFinite),
            builder.normals.allSatisfy(isFinite),
            builder.normals.allSatisfy({ abs(simd_length($0) - 1) < 0.001 }),
            builder.textureCoordinates.allSatisfy(isFiniteUnitCoordinate),
            builder.patchLocalCoordinates.allSatisfy(isFiniteUnitCoordinate),
            builder.boundaryDistances.allSatisfy({ $0.isFinite && (0...0.5).contains($0) }),
            trianglesAreNondegenerate(indices: allIndices, positions: builder.positions)
        else {
            return nil
        }

        return MaruGenjiSurfaceMeshData(
            positions: builder.positions,
            normals: builder.normals,
            textureCoordinates: builder.textureCoordinates,
            patchLocalCoordinates: builder.patchLocalCoordinates,
            boundaryDistances: builder.boundaryDistances,
            colorGroups: builder.colorGroups,
            boundaryColorGroups: builder.boundaryColorGroups,
            surfaceTrianglePatchIndices: builder.surfaceTrianglePatchIndices,
            surfaceTriangleIsBoundary: builder.surfaceTriangleIsBoundary,
            surfaceVertexPatchIndices: builder.surfaceVertexPatchIndices,
            seamStartVertexIndices: seamStartVertexIndices,
            seamEndVertexIndices: seamEndVertexIndices
        )
    }

    private struct PatchVertex {
        let surfaceCoordinate: SIMD2<Float>
        let localCoordinate: SIMD2<Float>
    }

    private struct MeshBuilder {
        var positions = [SIMD3<Float>]()
        var normals = [SIMD3<Float>]()
        var textureCoordinates = [SIMD2<Float>]()
        var patchLocalCoordinates = [SIMD2<Float>]()
        var boundaryDistances = [Float]()
        var colorGroups = [ThreadColorID: [UInt32]]()
        var boundaryColorGroups = [ThreadColorID: [UInt32]]()
        var surfaceTrianglePatchIndices = [Int]()
        var surfaceTriangleIsBoundary = [Bool]()
        var surfaceVertexPatchIndices = [Int]()
        var seamStartVertexIndices = [Int]()
        var seamEndVertexIndices = [Int]()
    }

    private static func appendSurfacePatch(
        _ patch: MaruGenjiSurfacePatch,
        patchIndex: Int,
        repeatIndex: Int,
        repeatCount: Int,
        radius: Float,
        length: Float,
        localUSamples: [Float],
        localVSamples: [Float],
        builder: inout MeshBuilder
    ) {
        for vIndex in 0..<(localVSamples.count - 1) {
            for uIndex in 0..<(localUSamples.count - 1) {
                let u0 = localUSamples[uIndex]
                let u1 = localUSamples[uIndex + 1]
                let v0 = localVSamples[vIndex]
                let v1 = localVSamples[vIndex + 1]
                let lowerLeading = patchVertex(
                    patch: patch,
                    repeatIndex: repeatIndex,
                    local: SIMD2<Float>(u0, v0)
                )
                let lowerTrailing = patchVertex(
                    patch: patch,
                    repeatIndex: repeatIndex,
                    local: SIMD2<Float>(u1, v0)
                )
                let upperLeading = patchVertex(
                    patch: patch,
                    repeatIndex: repeatIndex,
                    local: SIMD2<Float>(u0, v1)
                )
                let upperTrailing = patchVertex(
                    patch: patch,
                    repeatIndex: repeatIndex,
                    local: SIMD2<Float>(u1, v1)
                )

                for triangle in [
                    [lowerLeading, lowerTrailing, upperLeading],
                    [lowerTrailing, upperTrailing, upperLeading],
                ] {
                    appendTriangulated(
                        polygon: clip(
                            polygon: triangle,
                            minimumV: 0,
                            maximumV: Float(repeatCount)
                        ),
                        patch: patch,
                        patchIndex: patchIndex,
                        repeatIndex: repeatIndex,
                        repeatCount: repeatCount,
                        radius: radius,
                        length: length,
                        builder: &builder
                    )
                }
            }
        }
    }

    private static func appendEndCap(
        at x: Float,
        outwardNormal: SIMD3<Float>,
        edgeV: Float,
        pattern: MaruGenjiSurfacePattern,
        radius: Float,
        segmentCount: Int,
        builder: inout MeshBuilder
    ) {
        for segment in 0..<segmentCount {
            let startU = Float(segment) / Float(segmentCount)
            let endU = Float(segment + 1) / Float(segmentCount)
            let middleU = (startU + endU) / 2
            guard let colorID = edgeColor(at: middleU, edgeV: edgeV, pattern: pattern) else {
                continue
            }

            let triangle = [
                SIMD3<Float>(x, 0, 0),
                SIMD3<Float>(x, radius * cos(2 * .pi * startU), radius * sin(2 * .pi * startU)),
                SIMD3<Float>(x, radius * cos(2 * .pi * endU), radius * sin(2 * .pi * endU)),
            ]
            let winding = outwardNormal.x < 0 ? [0, 2, 1] : [0, 1, 2]
            let firstIndex = UInt32(builder.positions.count)
            for position in triangle {
                builder.positions.append(position)
                builder.normals.append(outwardNormal)
                builder.textureCoordinates.append(
                    SIMD2<Float>(position.y / (2 * radius) + 0.5, position.z / (2 * radius) + 0.5)
                )
                builder.patchLocalCoordinates.append(SIMD2<Float>(repeating: 0.5))
                builder.boundaryDistances.append(0)
                builder.surfaceVertexPatchIndices.append(-1)
            }
            builder.colorGroups[colorID, default: []].append(contentsOf: winding.map {
                firstIndex + UInt32($0)
            })
        }
    }

    private static func appendTriangulated(
        polygon: [PatchVertex],
        patch: MaruGenjiSurfacePatch,
        patchIndex: Int,
        repeatIndex: Int,
        repeatCount: Int,
        radius: Float,
        length: Float,
        builder: inout MeshBuilder
    ) {
        guard polygon.count >= 3 else { return }
        for index in 1..<(polygon.count - 1) {
            let triangle = [polygon[0], polygon[index], polygon[index + 1]]
            let mapped = triangle.map {
                position(
                    surfaceCoordinate: $0.surfaceCoordinate,
                    localCoordinate: $0.localCoordinate,
                    repeatCount: repeatCount,
                    radius: radius,
                    length: length
                )
            }
            guard simd_length_squared(simd_cross(mapped[1] - mapped[0], mapped[2] - mapped[0]))
                    > 0.000_000_000_001 else { continue }

            let center = triangle.reduce(SIMD2<Float>.zero) {
                $0 + $1.localCoordinate
            } / 3
            let isBoundary = boundaryDistance(center) < boundaryWidth
            let firstIndex = UInt32(builder.positions.count)
            for (vertex, mappedPosition) in zip(triangle, mapped) {
                let vertexIndex = builder.positions.count
                let distance = boundaryDistance(vertex.localCoordinate)
                builder.positions.append(mappedPosition)
                builder.normals.append(
                    surfaceNormal(
                        patch: patch,
                        repeatIndex: repeatIndex,
                        repeatCount: repeatCount,
                        localCoordinate: vertex.localCoordinate,
                        radius: radius,
                        length: length
                    )
                )
                builder.textureCoordinates.append(vertex.localCoordinate)
                builder.patchLocalCoordinates.append(vertex.localCoordinate)
                builder.boundaryDistances.append(distance)
                builder.surfaceVertexPatchIndices.append(patchIndex)
                if approximatelyEqual(vertex.surfaceCoordinate.x, 0) {
                    builder.seamStartVertexIndices.append(vertexIndex)
                } else if approximatelyEqual(vertex.surfaceCoordinate.x, 1) {
                    builder.seamEndVertexIndices.append(vertexIndex)
                }
            }

            let indices = [firstIndex, firstIndex + 1, firstIndex + 2]
            if isBoundary {
                builder.boundaryColorGroups[patch.colorID, default: []].append(contentsOf: indices)
            } else {
                builder.colorGroups[patch.colorID, default: []].append(contentsOf: indices)
            }
            builder.surfaceTrianglePatchIndices.append(patchIndex)
            builder.surfaceTriangleIsBoundary.append(isBoundary)
        }
    }

    private static func patchVertex(
        patch: MaruGenjiSurfacePatch,
        repeatIndex: Int,
        local: SIMD2<Float>
    ) -> PatchVertex {
        PatchVertex(
            surfaceCoordinate: repeated(
                interpolate(corners: patch.corners, local: local),
                repeatIndex: repeatIndex
            ),
            localCoordinate: local
        )
    }

    private static func position(
        surfaceCoordinate: SIMD2<Float>,
        localCoordinate: SIMD2<Float>,
        repeatCount: Int,
        radius: Float,
        length: Float
    ) -> SIMD3<Float> {
        let normalizedV = surfaceCoordinate.y / Float(repeatCount)
        let endDistance = min(normalizedV, 1 - normalizedV)
        let endFade = smoothstep(0, 0.025, endDistance)
        let displacedRadius = radius + reliefOffset(
            localCoordinate: localCoordinate,
            radius: radius
        ) * endFade
        let angle: Float = approximatelyEqual(surfaceCoordinate.x, 1)
            ? 0
            : 2 * .pi * surfaceCoordinate.x
        return SIMD3<Float>(
            -length / 2 + length * normalizedV,
            displacedRadius * cos(angle),
            displacedRadius * sin(angle)
        )
    }

    private static func surfaceNormal(
        patch: MaruGenjiSurfacePatch,
        repeatIndex: Int,
        repeatCount: Int,
        localCoordinate: SIMD2<Float>,
        radius: Float,
        length: Float
    ) -> SIMD3<Float> {
        let surfaceCoordinate = repeated(
            interpolate(corners: patch.corners, local: localCoordinate),
            repeatIndex: repeatIndex
        )
        let radial = radialNormal(u: surfaceCoordinate.x)
        if boundaryDistance(localCoordinate) < 0.000_001 {
            return radial
        }

        let epsilon: Float = 0.001
        let lowerU = SIMD2<Float>(max(0, localCoordinate.x - epsilon), localCoordinate.y)
        let upperU = SIMD2<Float>(min(1, localCoordinate.x + epsilon), localCoordinate.y)
        let lowerV = SIMD2<Float>(localCoordinate.x, max(0, localCoordinate.y - epsilon))
        let upperV = SIMD2<Float>(localCoordinate.x, min(1, localCoordinate.y + epsilon))

        func mappedPosition(_ local: SIMD2<Float>) -> SIMD3<Float> {
            position(
                surfaceCoordinate: repeated(
                    interpolate(corners: patch.corners, local: local),
                    repeatIndex: repeatIndex
                ),
                localCoordinate: local,
                repeatCount: repeatCount,
                radius: radius,
                length: length
            )
        }

        let tangentU = mappedPosition(upperU) - mappedPosition(lowerU)
        let tangentV = mappedPosition(upperV) - mappedPosition(lowerV)
        var normal = simd_cross(tangentU, tangentV)
        guard simd_length_squared(normal) > 0.000_000_000_001 else { return radial }
        normal = simd_normalize(normal)
        return simd_dot(normal, radial) < 0 ? -normal : normal
    }

    private static func reliefOffset(
        localCoordinate: SIMD2<Float>,
        radius: Float
    ) -> Float {
        let blend = smoothstep(0, boundaryWidth, boundaryDistance(localCoordinate))
        let boundaryOffset = -radius * boundaryDepthRatio * (1 - blend)
        let fiberWave = cos(2 * .pi * Float(fiberCount) * localCoordinate.y)
        let fiberOffset = radius * fiberReliefRatio * fiberWave * blend
        return boundaryOffset + fiberOffset
    }

    private static func boundaryDistance(_ localCoordinate: SIMD2<Float>) -> Float {
        min(
            localCoordinate.x,
            1 - localCoordinate.x,
            localCoordinate.y,
            1 - localCoordinate.y
        )
    }

    private static func subdivisionSamples(count: Int) -> [Float] {
        var samples = (0...count).map { Float($0) / Float(count) }
        samples.append(contentsOf: [boundaryWidth, 1 - boundaryWidth])
        return samples.sorted().reduce(into: []) { result, value in
            if result.last.map({ !approximatelyEqual($0, value) }) ?? true {
                result.append(value)
            }
        }
    }

    private static func edgeColor(
        at u: Float,
        edgeV: Float,
        pattern: MaruGenjiSurfacePattern
    ) -> ThreadColorID? {
        let insetV: Float = edgeV == 0 ? 0.0001 : 0.9999
        for periodOffset in -1...1 {
            for patch in pattern.patches {
                let shifted = patch.corners.map {
                    SIMD2<Float>($0.x, $0.y + Float(periodOffset))
                }
                if contains(SIMD2<Float>(u, insetV), in: shifted) {
                    return patch.colorID
                }
            }
        }
        return nil
    }

    private static func repeated(
        _ point: SIMD2<Float>,
        repeatIndex: Int
    ) -> SIMD2<Float> {
        SIMD2<Float>(point.x, point.y + Float(repeatIndex))
    }

    private static func clip(
        polygon: [PatchVertex],
        minimumV: Float,
        maximumV: Float
    ) -> [PatchVertex] {
        let aboveMinimum = clip(polygon: polygon) { $0.surfaceCoordinate.y >= minimumV }
            intersection: { intersection($0, $1, atV: minimumV) }
        return clip(polygon: aboveMinimum) { $0.surfaceCoordinate.y <= maximumV }
            intersection: { intersection($0, $1, atV: maximumV) }
    }

    private static func clip(
        polygon: [PatchVertex],
        isInside: (PatchVertex) -> Bool,
        intersection: (PatchVertex, PatchVertex) -> PatchVertex
    ) -> [PatchVertex] {
        guard var previous = polygon.last else { return [] }
        var result = [PatchVertex]()
        var previousIsInside = isInside(previous)

        for current in polygon {
            let currentIsInside = isInside(current)
            if currentIsInside != previousIsInside {
                result.append(intersection(previous, current))
            }
            if currentIsInside {
                result.append(current)
            }
            previous = current
            previousIsInside = currentIsInside
        }
        return removingAdjacentDuplicates(from: result)
    }

    private static func intersection(
        _ first: PatchVertex,
        _ second: PatchVertex,
        atV boundaryV: Float
    ) -> PatchVertex {
        let progress = (boundaryV - first.surfaceCoordinate.y)
            / (second.surfaceCoordinate.y - first.surfaceCoordinate.y)
        return PatchVertex(
            surfaceCoordinate: simd_mix(
                first.surfaceCoordinate,
                second.surfaceCoordinate,
                SIMD2<Float>(repeating: progress)
            ),
            localCoordinate: simd_mix(
                first.localCoordinate,
                second.localCoordinate,
                SIMD2<Float>(repeating: progress)
            )
        )
    }

    private static func removingAdjacentDuplicates(
        from polygon: [PatchVertex]
    ) -> [PatchVertex] {
        var result = [PatchVertex]()
        for vertex in polygon where result.last.map({
            simd_distance($0.surfaceCoordinate, vertex.surfaceCoordinate) > 0.000_001
        }) ?? true {
            result.append(vertex)
        }
        if result.count > 1, let first = result.first, let last = result.last,
           simd_distance(first.surfaceCoordinate, last.surfaceCoordinate) <= 0.000_001 {
            result.removeLast()
        }
        return result
    }

    private static func contains(
        _ point: SIMD2<Float>,
        in polygon: [SIMD2<Float>]
    ) -> Bool {
        guard polygon.count >= 3 else { return false }
        var isInside = false
        var previous = polygon[polygon.count - 1]
        for current in polygon {
            let crossesRay = (current.y > point.y) != (previous.y > point.y)
            if crossesRay {
                let crossingX = (previous.x - current.x) * (point.y - current.y)
                    / (previous.y - current.y) + current.x
                if point.x < crossingX {
                    isInside.toggle()
                }
            }
            previous = current
        }
        return isInside
    }

    private static func interpolate(
        corners: [SIMD2<Float>],
        local: SIMD2<Float>
    ) -> SIMD2<Float> {
        let leading = simd_mix(corners[0], corners[1], SIMD2<Float>(repeating: local.y))
        let trailing = simd_mix(corners[3], corners[2], SIMD2<Float>(repeating: local.y))
        return simd_mix(leading, trailing, SIMD2<Float>(repeating: local.x))
    }

    private static func radialNormal(u: Float) -> SIMD3<Float> {
        let angle: Float = approximatelyEqual(u, 1) ? 0 : 2 * .pi * u
        return SIMD3<Float>(0, cos(angle), sin(angle))
    }

    private static func smoothstep(_ edge0: Float, _ edge1: Float, _ value: Float) -> Float {
        let progress = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return progress * progress * (3 - 2 * progress)
    }

    private static func isValid(_ patch: MaruGenjiSurfacePatch) -> Bool {
        patch.corners.count == 4 && patch.corners.allSatisfy { corner in
            corner.x.isFinite && corner.y.isFinite
                && (0...1).contains(corner.x)
                && (0...MaruGenjiSurfacePatternGenerator.maximumUnwrappedV).contains(corner.y)
        }
    }

    private static func trianglesAreNondegenerate(
        indices: [UInt32],
        positions: [SIMD3<Float>]
    ) -> Bool {
        guard indices.count.isMultiple(of: 3) else { return false }
        return stride(from: 0, to: indices.count, by: 3).allSatisfy { offset in
            let first = positions[Int(indices[offset])]
            let second = positions[Int(indices[offset + 1])]
            let third = positions[Int(indices[offset + 2])]
            return simd_length_squared(simd_cross(second - first, third - first))
                > 0.000_000_000_001
        }
    }

    private static func uniqueSeamIndices(
        _ indices: [Int],
        positions: [SIMD3<Float>]
    ) -> [Int] {
        indices.sorted { positions[$0].x < positions[$1].x }.reduce(into: []) { result, index in
            guard let previous = result.last else {
                result.append(index)
                return
            }
            if !approximatelyEqual(positions[previous].x, positions[index].x) {
                result.append(index)
            }
        }
    }

    private static func isFinite(_ vector: SIMD3<Float>) -> Bool {
        vector.x.isFinite && vector.y.isFinite && vector.z.isFinite
    }

    private static func isFiniteUnitCoordinate(_ vector: SIMD2<Float>) -> Bool {
        vector.x.isFinite && vector.y.isFinite
            && (0...1).contains(vector.x)
            && (0...1).contains(vector.y)
    }

    private static func approximatelyEqual(_ lhs: Float, _ rhs: Float) -> Bool {
        abs(lhs - rhs) < 0.000_001
    }
}
