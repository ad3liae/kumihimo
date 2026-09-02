import Foundation
import simd

struct MaruGenjiSurfaceMeshData: Sendable {
    let positions: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let colorGroups: [ThreadColorID: [UInt32]]
    let surfaceTrianglePatchIndices: [Int]
    let seamStartVertexIndices: [Int]
    let seamEndVertexIndices: [Int]

    var triangleCount: Int {
        colorGroups.values.reduce(0) { $0 + $1.count / 3 }
    }
}

enum MaruGenjiSurfaceMeshGenerator {
    static let defaultRadius: Float = 0.48
    static let defaultLength: Float = 3.4
    static let defaultPatternRepeatCount = 4
    static let defaultCircumferentialSubdivisionsPerPatch = 4

    static func generate(
        pattern: MaruGenjiSurfacePattern,
        radius: Float = defaultRadius,
        length: Float = defaultLength,
        patternRepeatCount: Int = defaultPatternRepeatCount,
        circumferentialSubdivisionsPerPatch: Int = defaultCircumferentialSubdivisionsPerPatch,
        longitudinalSubdivisionsPerPatch: Int = 1
    ) -> MaruGenjiSurfaceMeshData? {
        guard
            pattern.patches.count == MaruGenjiSurfacePatternGenerator.patchCount,
            radius.isFinite,
            radius > 0,
            length.isFinite,
            length > 0,
            patternRepeatCount > 0,
            circumferentialSubdivisionsPerPatch > 0,
            longitudinalSubdivisionsPerPatch > 0,
            pattern.patches.allSatisfy(isValid)
        else {
            return nil
        }

        var positions = [SIMD3<Float>]()
        var normals = [SIMD3<Float>]()
        var colorGroups = [ThreadColorID: [UInt32]]()
        var surfaceTrianglePatchIndices = [Int]()
        var seamStartVertexIndices = [Int]()
        var seamEndVertexIndices = [Int]()

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
                    uSubdivisions: circumferentialSubdivisionsPerPatch,
                    vSubdivisions: longitudinalSubdivisionsPerPatch,
                    positions: &positions,
                    normals: &normals,
                    colorGroups: &colorGroups,
                    surfaceTrianglePatchIndices: &surfaceTrianglePatchIndices,
                    seamStartVertexIndices: &seamStartVertexIndices,
                    seamEndVertexIndices: &seamEndVertexIndices
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
            positions: &positions,
            normals: &normals,
            colorGroups: &colorGroups
        )
        appendEndCap(
            at: length / 2,
            outwardNormal: SIMD3<Float>(1, 0, 0),
            edgeV: 1,
            pattern: pattern,
            radius: radius,
            segmentCount: 8 * circumferentialSubdivisionsPerPatch,
            positions: &positions,
            normals: &normals,
            colorGroups: &colorGroups
        )

        seamStartVertexIndices = uniqueSeamIndices(
            seamStartVertexIndices,
            positions: positions
        )
        seamEndVertexIndices = uniqueSeamIndices(
            seamEndVertexIndices,
            positions: positions
        )

        let allIndices = colorGroups.values.flatMap { $0 }
        guard
            !positions.isEmpty,
            positions.count == normals.count,
            !colorGroups.isEmpty,
            colorGroups.values.allSatisfy({ !$0.isEmpty && $0.count.isMultiple(of: 3) }),
            allIndices.allSatisfy({ Int($0) < positions.count }),
            positions.allSatisfy(isFinite),
            normals.allSatisfy(isFinite),
            normals.allSatisfy({ abs(simd_length($0) - 1) < 0.001 }),
            trianglesAreNondegenerate(indices: allIndices, positions: positions)
        else {
            return nil
        }

        return MaruGenjiSurfaceMeshData(
            positions: positions,
            normals: normals,
            colorGroups: colorGroups,
            surfaceTrianglePatchIndices: surfaceTrianglePatchIndices,
            seamStartVertexIndices: seamStartVertexIndices,
            seamEndVertexIndices: seamEndVertexIndices
        )
    }

    private static func appendSurfacePatch(
        _ patch: MaruGenjiSurfacePatch,
        patchIndex: Int,
        repeatIndex: Int,
        repeatCount: Int,
        radius: Float,
        length: Float,
        uSubdivisions: Int,
        vSubdivisions: Int,
        positions: inout [SIMD3<Float>],
        normals: inout [SIMD3<Float>],
        colorGroups: inout [ThreadColorID: [UInt32]],
        surfaceTrianglePatchIndices: inout [Int],
        seamStartVertexIndices: inout [Int],
        seamEndVertexIndices: inout [Int]
    ) {
        for vIndex in 0..<vSubdivisions {
            for uIndex in 0..<uSubdivisions {
                let u0 = Float(uIndex) / Float(uSubdivisions)
                let u1 = Float(uIndex + 1) / Float(uSubdivisions)
                let v0 = Float(vIndex) / Float(vSubdivisions)
                let v1 = Float(vIndex + 1) / Float(vSubdivisions)
                let lowerLeading = repeated(
                    interpolate(corners: patch.corners, u: u0, v: v0),
                    repeatIndex: repeatIndex
                )
                let lowerTrailing = repeated(
                    interpolate(corners: patch.corners, u: u1, v: v0),
                    repeatIndex: repeatIndex
                )
                let upperLeading = repeated(
                    interpolate(corners: patch.corners, u: u0, v: v1),
                    repeatIndex: repeatIndex
                )
                let upperTrailing = repeated(
                    interpolate(corners: patch.corners, u: u1, v: v1),
                    repeatIndex: repeatIndex
                )

                for triangle in [
                    [lowerLeading, lowerTrailing, upperLeading],
                    [lowerTrailing, upperTrailing, upperLeading],
                ] {
                    let clipped = clip(
                        polygon: triangle,
                        minimumV: 0,
                        maximumV: Float(repeatCount)
                    )
                    appendTriangulated(
                        polygon: clipped,
                        patchIndex: patchIndex,
                        colorID: patch.colorID,
                        repeatCount: repeatCount,
                        radius: radius,
                        length: length,
                        positions: &positions,
                        normals: &normals,
                        colorGroups: &colorGroups,
                        surfaceTrianglePatchIndices: &surfaceTrianglePatchIndices,
                        seamStartVertexIndices: &seamStartVertexIndices,
                        seamEndVertexIndices: &seamEndVertexIndices
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
        positions: inout [SIMD3<Float>],
        normals: inout [SIMD3<Float>],
        colorGroups: inout [ThreadColorID: [UInt32]]
    ) {
        for segment in 0..<segmentCount {
            let startU = Float(segment) / Float(segmentCount)
            let endU = Float(segment + 1) / Float(segmentCount)
            let middleU = (startU + endU) / 2
            guard let colorID = edgeColor(at: middleU, edgeV: edgeV, pattern: pattern) else {
                continue
            }

            let first = UInt32(positions.count)
            positions.append(SIMD3<Float>(x, 0, 0))
            positions.append(SIMD3<Float>(x, radius * cos(2 * .pi * startU), radius * sin(2 * .pi * startU)))
            positions.append(SIMD3<Float>(x, radius * cos(2 * .pi * endU), radius * sin(2 * .pi * endU)))
            normals.append(contentsOf: [outwardNormal, outwardNormal, outwardNormal])
            if outwardNormal.x < 0 {
                colorGroups[colorID, default: []].append(contentsOf: [first, first + 2, first + 1])
            } else {
                colorGroups[colorID, default: []].append(contentsOf: [first, first + 1, first + 2])
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
        polygon: [SIMD2<Float>],
        minimumV: Float,
        maximumV: Float
    ) -> [SIMD2<Float>] {
        let aboveMinimum = clip(polygon: polygon) { $0.y >= minimumV } intersection: { first, second in
            intersection(first, second, atV: minimumV)
        }
        return clip(polygon: aboveMinimum) { $0.y <= maximumV } intersection: { first, second in
            intersection(first, second, atV: maximumV)
        }
    }

    private static func clip(
        polygon: [SIMD2<Float>],
        isInside: (SIMD2<Float>) -> Bool,
        intersection: (SIMD2<Float>, SIMD2<Float>) -> SIMD2<Float>
    ) -> [SIMD2<Float>] {
        guard var previous = polygon.last else { return [] }
        var result = [SIMD2<Float>]()
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
        _ first: SIMD2<Float>,
        _ second: SIMD2<Float>,
        atV boundaryV: Float
    ) -> SIMD2<Float> {
        let progress = (boundaryV - first.y) / (second.y - first.y)
        return simd_mix(first, second, SIMD2<Float>(repeating: progress))
    }

    private static func removingAdjacentDuplicates(
        from polygon: [SIMD2<Float>]
    ) -> [SIMD2<Float>] {
        var result = [SIMD2<Float>]()
        for point in polygon where result.last.map({ simd_distance($0, point) > 0.000_001 }) ?? true {
            result.append(point)
        }
        if result.count > 1, let first = result.first, let last = result.last,
           simd_distance(first, last) <= 0.000_001 {
            result.removeLast()
        }
        return result
    }

    private static func appendTriangulated(
        polygon: [SIMD2<Float>],
        patchIndex: Int,
        colorID: ThreadColorID,
        repeatCount: Int,
        radius: Float,
        length: Float,
        positions: inout [SIMD3<Float>],
        normals: inout [SIMD3<Float>],
        colorGroups: inout [ThreadColorID: [UInt32]],
        surfaceTrianglePatchIndices: inout [Int],
        seamStartVertexIndices: inout [Int],
        seamEndVertexIndices: inout [Int]
    ) {
        guard polygon.count >= 3 else { return }
        for index in 1..<(polygon.count - 1) {
            let triangle = [polygon[0], polygon[index], polygon[index + 1]]
            let mapped = triangle.map { point in
                position(
                    u: point.x,
                    v: point.y / Float(repeatCount),
                    radius: radius,
                    length: length
                )
            }
            guard simd_length_squared(simd_cross(mapped[1] - mapped[0], mapped[2] - mapped[0]))
                    > 0.000_000_000_001 else { continue }

            let firstIndex = UInt32(positions.count)
            for (point, mappedPosition) in zip(triangle, mapped) {
                let vertexIndex = positions.count
                positions.append(mappedPosition)
                normals.append(radialNormal(u: point.x))
                if approximatelyEqual(point.x, 0) {
                    seamStartVertexIndices.append(vertexIndex)
                } else if approximatelyEqual(point.x, 1) {
                    seamEndVertexIndices.append(vertexIndex)
                }
            }
            colorGroups[colorID, default: []].append(contentsOf: [
                firstIndex, firstIndex + 1, firstIndex + 2,
            ])
            surfaceTrianglePatchIndices.append(patchIndex)
        }
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
        u: Float,
        v: Float
    ) -> SIMD2<Float> {
        let leading = simd_mix(corners[0], corners[1], SIMD2<Float>(repeating: v))
        let trailing = simd_mix(corners[3], corners[2], SIMD2<Float>(repeating: v))
        return simd_mix(leading, trailing, SIMD2<Float>(repeating: u))
    }

    private static func position(
        u: Float,
        v: Float,
        radius: Float,
        length: Float
    ) -> SIMD3<Float> {
        let angle: Float = approximatelyEqual(u, 1) ? 0 : 2 * .pi * u
        return SIMD3<Float>(
            -length / 2 + length * v,
            radius * cos(angle),
            radius * sin(angle)
        )
    }

    private static func radialNormal(u: Float) -> SIMD3<Float> {
        let angle: Float = approximatelyEqual(u, 1) ? 0 : 2 * .pi * u
        return SIMD3<Float>(0, cos(angle), sin(angle))
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

    private static func approximatelyEqual(_ lhs: Float, _ rhs: Float) -> Bool {
        abs(lhs - rhs) < 0.000_001
    }
}
