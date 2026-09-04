import Foundation
import simd

struct HiraGenjiSurfaceMeshData: Sendable {
    let positions: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let textureCoordinates: [SIMD2<Float>]
    let boundaryDistances: [Float]
    let colorGroups: [ThreadColorID: [UInt32]]
    let boundaryColorGroups: [ThreadColorID: [UInt32]]
    let surfaceVertexPatchIndices: [Int]
    let surfaceVertexRegions: [HiraGenjiSurfaceRegion]

    var allTriangleIndices: [UInt32] {
        (Array(colorGroups.values) + Array(boundaryColorGroups.values)).flatMap { $0 }
    }

    var triangleCount: Int { allTriangleIndices.count / 3 }
}

enum HiraGenjiSurfaceMeshGenerator {
    static let defaultHalfWidth: Float = 0.72
    static let defaultHalfThickness: Float = 0.12
    /// Hira-genji is flat, so its perimeter is not a circle and its own repeat
    /// aspect ratio has not been read from a reference yet. The tile therefore
    /// keeps the length it was tuned with instead of borrowing the round braid's
    /// derived length. Deriving it is a separate task.
    static let defaultLength: Float = 3.4
    /// Twelve repeats keep each of the two stitch phases close to one yarn width.
    /// The previous value of four enlarged a single stitch into a rigid-looking tile.
    static let defaultPatternRepeatCount = 12
    static let widthSubdivisionsPerPatch = 4
    static let longitudinalSubdivisionsPerPatch = 24
    static let boundaryWidth: Float = 0.035
    static let boundaryDepthRatio: Float = 0.012
    static let fiberReliefRatio: Float = 0.006
    static let fiberCount = 8
    static let superellipseExponent: Float = 5

    static var widthToThicknessRatio: Float {
        defaultHalfWidth / defaultHalfThickness
    }

    static func generate(
        pattern: HiraGenjiSurfacePattern,
        halfWidth: Float = defaultHalfWidth,
        halfThickness: Float = defaultHalfThickness,
        length: Float = defaultLength,
        patternRepeatCount: Int = defaultPatternRepeatCount
    ) -> HiraGenjiSurfaceMeshData? {
        guard
            pattern.patches.count == HiraGenjiSurfacePatternGenerator.patchCount,
            halfWidth.isFinite,
            halfThickness.isFinite,
            length.isFinite,
            halfWidth > 0,
            halfThickness > 0,
            halfWidth / halfThickness >= 4,
            halfWidth / halfThickness <= 8,
            length > 0,
            patternRepeatCount > 0,
            pattern.patches.allSatisfy(isValid)
        else {
            return nil
        }

        var builder = MeshBuilder()
        let uSamples = subdivisionSamples(count: widthSubdivisionsPerPatch)
        let vSamples = subdivisionSamples(count: longitudinalSubdivisionsPerPatch)
        for repeatIndex in 0..<patternRepeatCount {
            for (patchIndex, patch) in pattern.patches.enumerated() {
                append(
                    patch: patch,
                    patchIndex: patchIndex,
                    repeatIndex: repeatIndex,
                    repeatCount: patternRepeatCount,
                    halfWidth: halfWidth,
                    halfThickness: halfThickness,
                    length: length,
                    uSamples: uSamples,
                    vSamples: vSamples,
                    builder: &builder
                )
            }
        }

        let indices = (Array(builder.colorGroups.values)
            + Array(builder.boundaryColorGroups.values)).flatMap { $0 }
        guard
            !builder.positions.isEmpty,
            builder.positions.count == builder.normals.count,
            builder.positions.count == builder.textureCoordinates.count,
            builder.positions.count == builder.boundaryDistances.count,
            builder.positions.count == builder.surfaceVertexPatchIndices.count,
            builder.positions.count == builder.surfaceVertexRegions.count,
            indices.allSatisfy({ Int($0) < builder.positions.count }),
            builder.positions.allSatisfy(isFinite),
            builder.normals.allSatisfy(isFinite),
            builder.normals.allSatisfy({ abs(simd_length($0) - 1) < 0.001 }),
            trianglesAreNondegenerate(indices: indices, positions: builder.positions)
        else {
            return nil
        }

        return HiraGenjiSurfaceMeshData(
            positions: builder.positions,
            normals: builder.normals,
            textureCoordinates: builder.textureCoordinates,
            boundaryDistances: builder.boundaryDistances,
            colorGroups: builder.colorGroups,
            boundaryColorGroups: builder.boundaryColorGroups,
            surfaceVertexPatchIndices: builder.surfaceVertexPatchIndices,
            surfaceVertexRegions: builder.surfaceVertexRegions
        )
    }

    private struct MeshBuilder {
        var positions = [SIMD3<Float>]()
        var normals = [SIMD3<Float>]()
        var textureCoordinates = [SIMD2<Float>]()
        var boundaryDistances = [Float]()
        var colorGroups = [ThreadColorID: [UInt32]]()
        var boundaryColorGroups = [ThreadColorID: [UInt32]]()
        var surfaceVertexPatchIndices = [Int]()
        var surfaceVertexRegions = [HiraGenjiSurfaceRegion]()
    }

    private static func append(
        patch: HiraGenjiSurfacePatch,
        patchIndex: Int,
        repeatIndex: Int,
        repeatCount: Int,
        halfWidth: Float,
        halfThickness: Float,
        length: Float,
        uSamples: [Float],
        vSamples: [Float],
        builder: inout MeshBuilder
    ) {
        for vIndex in 0..<(vSamples.count - 1) {
            for uIndex in 0..<(uSamples.count - 1) {
                let locals = [
                    SIMD2<Float>(uSamples[uIndex], vSamples[vIndex]),
                    SIMD2<Float>(uSamples[uIndex + 1], vSamples[vIndex]),
                    SIMD2<Float>(uSamples[uIndex], vSamples[vIndex + 1]),
                    SIMD2<Float>(uSamples[uIndex + 1], vSamples[vIndex + 1]),
                ]
                for triangleLocals in [[locals[0], locals[1], locals[2]],
                                       [locals[1], locals[3], locals[2]]] {
                    let firstIndex = UInt32(builder.positions.count)
                    let center = triangleLocals.reduce(.zero, +) / 3
                    let isBoundary = boundaryDistance(center) < boundaryWidth
                    for local in triangleLocals {
                        let position = surfacePosition(
                            patch: patch,
                            localCoordinate: local,
                            repeatIndex: repeatIndex,
                            repeatCount: repeatCount,
                            halfWidth: halfWidth,
                            halfThickness: halfThickness,
                            length: length
                        )
                        let normal = surfaceNormal(
                            patch: patch,
                            localCoordinate: local,
                            repeatIndex: repeatIndex,
                            repeatCount: repeatCount,
                            halfWidth: halfWidth,
                            halfThickness: halfThickness,
                            length: length
                        ) ?? fallbackNormal(
                            patch: patch,
                            localCoordinate: local,
                            halfWidth: halfWidth,
                            halfThickness: halfThickness
                        )
                        builder.positions.append(position)
                        builder.normals.append(normal)
                        builder.textureCoordinates.append(local)
                        builder.boundaryDistances.append(boundaryDistance(local))
                        builder.surfaceVertexPatchIndices.append(patchIndex)
                        builder.surfaceVertexRegions.append(patch.region)
                    }
                    let indices = [firstIndex, firstIndex + 1, firstIndex + 2]
                    if isBoundary {
                        builder.boundaryColorGroups[patch.colorID, default: []]
                            .append(contentsOf: indices)
                    } else {
                        builder.colorGroups[patch.colorID, default: []]
                            .append(contentsOf: indices)
                    }
                }
            }
        }
    }

    private static func surfacePosition(
        patch: HiraGenjiSurfacePatch,
        localCoordinate: SIMD2<Float>,
        repeatIndex: Int,
        repeatCount: Int,
        halfWidth: Float,
        halfThickness: Float,
        length: Float
    ) -> SIMD3<Float> {
        let surface = interpolate(corners: patch.corners, local: localCoordinate)
        let longitudinal = (surface.y + Float(repeatIndex)) / Float(repeatCount)
        let base = crossSectionPoint(
            region: patch.region,
            regionU: surface.x,
            halfWidth: halfWidth,
            halfThickness: halfThickness
        )
        let outward = crossSectionNormal(
            point: base,
            halfWidth: halfWidth,
            halfThickness: halfThickness
        )
        let relief = reliefOffset(
            localCoordinate: localCoordinate,
            threadRole: patch.threadRole,
            scale: halfThickness
        )
        return SIMD3<Float>(
            -length / 2 + length * longitudinal,
            base.x + outward.x * relief,
            base.y + outward.y * relief
        )
    }

    /// The relief is geometry, so its gradient must also affect the normal. Using
    /// the flat cross-section normal hid the yarn crown and fibre grooves even
    /// though their vertices existed in the mesh.
    private static func surfaceNormal(
        patch: HiraGenjiSurfacePatch,
        localCoordinate: SIMD2<Float>,
        repeatIndex: Int,
        repeatCount: Int,
        halfWidth: Float,
        halfThickness: Float,
        length: Float
    ) -> SIMD3<Float>? {
        let epsilon: Float = 0.002
        // Patch joins are recessed yarn boundaries. Keep their normal aligned to
        // the braid surface so the first and last repeat share an exact lighting
        // seam; the relief gradient resumes immediately inside the stitch.
        guard localCoordinate.y > epsilon, localCoordinate.y < 1 - epsilon else {
            return nil
        }
        let lowerU = max(0, localCoordinate.x - epsilon)
        let upperU = min(1, localCoordinate.x + epsilon)
        let lowerV = max(0, localCoordinate.y - epsilon)
        let upperV = min(1, localCoordinate.y + epsilon)
        guard upperU > lowerU, upperV > lowerV else { return nil }

        func position(_ u: Float, _ v: Float) -> SIMD3<Float> {
            surfacePosition(
                patch: patch,
                localCoordinate: SIMD2<Float>(u, v),
                repeatIndex: repeatIndex,
                repeatCount: repeatCount,
                halfWidth: halfWidth,
                halfThickness: halfThickness,
                length: length
            )
        }

        let tangentU = position(upperU, localCoordinate.y)
            - position(lowerU, localCoordinate.y)
        let tangentV = position(localCoordinate.x, upperV)
            - position(localCoordinate.x, lowerV)
        let cross = simd_cross(tangentU, tangentV)
        guard simd_length_squared(cross) > 0.000_000_000_001 else { return nil }
        return simd_normalize(cross)
    }

    private static func fallbackNormal(
        patch: HiraGenjiSurfacePatch,
        localCoordinate: SIMD2<Float>,
        halfWidth: Float,
        halfThickness: Float
    ) -> SIMD3<Float> {
        let surface = interpolate(corners: patch.corners, local: localCoordinate)
        let base = crossSectionPoint(
            region: patch.region,
            regionU: surface.x,
            halfWidth: halfWidth,
            halfThickness: halfThickness
        )
        let outward = crossSectionNormal(
            point: base,
            halfWidth: halfWidth,
            halfThickness: halfThickness
        )
        return SIMD3<Float>(0, outward.x, outward.y)
    }

    private static func crossSectionPoint(
        region: HiraGenjiSurfaceRegion,
        regionU: Float,
        halfWidth: Float,
        halfThickness: Float
    ) -> SIMD2<Float> {
        let startAngle: Float
        switch region {
        case .rightEdge: startAngle = -.pi / 4
        case .front: startAngle = .pi / 4
        case .leftEdge: startAngle = 3 * .pi / 4
        case .back: startAngle = 5 * .pi / 4
        }
        let angle = startAngle + regionU * .pi / 2
        let cosine = cos(angle)
        let sine = sin(angle)
        let power = 2 / superellipseExponent
        return SIMD2<Float>(
            halfWidth * signedPower(cosine, power),
            halfThickness * signedPower(sine, power)
        )
    }

    private static func crossSectionNormal(
        point: SIMD2<Float>,
        halfWidth: Float,
        halfThickness: Float
    ) -> SIMD2<Float> {
        let y = signedPower(point.x, superellipseExponent - 1)
            / pow(halfWidth, superellipseExponent)
        let z = signedPower(point.y, superellipseExponent - 1)
            / pow(halfThickness, superellipseExponent)
        let normal = SIMD2<Float>(y, z)
        return simd_length_squared(normal) > 0 ? simd_normalize(normal) : SIMD2<Float>(0, 1)
    }

    private static func signedPower(_ value: Float, _ exponent: Float) -> Float {
        (value < 0 ? -1 : 1) * pow(abs(value), exponent)
    }

    private static func reliefOffset(
        localCoordinate: SIMD2<Float>,
        threadRole: HiraGenjiThreadRole,
        scale: Float
    ) -> Float {
        let blend = smoothstep(0, boundaryWidth, boundaryDistance(localCoordinate))
        let boundary = -scale * boundaryDepthRatio * (1 - blend)
        let diagonalCoordinate = threadRole == .outer
            ? localCoordinate.y + localCoordinate.x * 0.28
            : localCoordinate.y - localCoordinate.x * 0.28
        let fiber = scale * fiberReliefRatio
            * cos(2 * .pi * Float(fiberCount) * diagonalCoordinate) * blend
        let longitudinalCrown = sin(.pi * localCoordinate.y)
        let crown = scale * 0.10
            * sin(.pi * localCoordinate.x)
            * longitudinalCrown * longitudinalCrown
        return boundary + fiber + crown
    }

    private static func boundaryDistance(_ local: SIMD2<Float>) -> Float {
        min(local.x, 1 - local.x, local.y, 1 - local.y)
    }

    private static func subdivisionSamples(count: Int) -> [Float] {
        var samples = (0...count).map { Float($0) / Float(count) }
        samples.append(contentsOf: [boundaryWidth, 1 - boundaryWidth])
        return samples.sorted().reduce(into: []) { result, value in
            if result.last.map({ abs($0 - value) > 0.000_001 }) ?? true {
                result.append(value)
            }
        }
    }

    private static func interpolate(
        corners: [SIMD2<Float>],
        local: SIMD2<Float>
    ) -> SIMD2<Float> {
        let leading = simd_mix(corners[0], corners[1], SIMD2<Float>(repeating: local.y))
        let trailing = simd_mix(corners[3], corners[2], SIMD2<Float>(repeating: local.y))
        return simd_mix(leading, trailing, SIMD2<Float>(repeating: local.x))
    }

    private static func smoothstep(_ edge0: Float, _ edge1: Float, _ value: Float) -> Float {
        let progress = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return progress * progress * (3 - 2 * progress)
    }

    private static func isValid(_ patch: HiraGenjiSurfacePatch) -> Bool {
        patch.corners.count == 4 && patch.corners.allSatisfy {
            $0.x.isFinite && $0.y.isFinite
                && (0...1).contains($0.x)
                && (0...1).contains($0.y)
        }
    }

    private static func isFinite(_ vector: SIMD3<Float>) -> Bool {
        vector.x.isFinite && vector.y.isFinite && vector.z.isFinite
    }

    private static func trianglesAreNondegenerate(
        indices: [UInt32],
        positions: [SIMD3<Float>]
    ) -> Bool {
        indices.count.isMultiple(of: 3) && stride(from: 0, to: indices.count, by: 3).allSatisfy {
            let a = positions[Int(indices[$0])]
            let b = positions[Int(indices[$0 + 1])]
            let c = positions[Int(indices[$0 + 2])]
            return simd_length_squared(simd_cross(b - a, c - a)) > 0.000_000_000_001
        }
    }
}
