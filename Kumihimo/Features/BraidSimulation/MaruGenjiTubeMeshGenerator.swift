import Foundation
import simd

struct TubeMeshData: Equatable, Sendable {
    let positions: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let triangleIndices: [UInt32]
}

enum MaruGenjiTubeMeshGenerator {
    static func generate(
        points: [SIMD3<Float>],
        tubeRadius: Float = 0.052,
        sideCount: Int = 8
    ) -> TubeMeshData? {
        let minimumLength: Float = 0.000_001
        guard
            points.count >= 2,
            tubeRadius.isFinite,
            tubeRadius > 0,
            sideCount >= 3,
            points.allSatisfy(isFinite),
            zip(points, points.dropFirst()).allSatisfy({
                simd_length_squared($1 - $0) > minimumLength * minimumLength
            })
        else {
            return nil
        }

        var positions = [SIMD3<Float>]()
        var normals = [SIMD3<Float>]()
        positions.reserveCapacity(points.count * sideCount)
        normals.reserveCapacity(points.count * sideCount)

        let tangents = points.indices.map { tangent(at: $0, points: points) }
        var normalAxis = initialNormal(for: tangents[0])

        for pointIndex in points.indices {
            let tangent = tangents[pointIndex]
            if pointIndex != points.startIndex {
                normalAxis = transportedNormal(
                    previousNormal: normalAxis,
                    tangent: tangent
                )
            }
            let binormalAxis = simd_normalize(simd_cross(tangent, normalAxis))

            for side in 0..<sideCount {
                let angle = 2 * Float.pi * Float(side) / Float(sideCount)
                let radialNormal = simd_normalize(
                    normalAxis * cos(angle) + binormalAxis * sin(angle)
                )
                positions.append(points[pointIndex] + radialNormal * tubeRadius)
                normals.append(radialNormal)
            }
        }

        var triangleIndices = [UInt32]()
        triangleIndices.reserveCapacity((points.count - 1) * sideCount * 6)
        for ring in 0..<(points.count - 1) {
            for side in 0..<sideCount {
                let nextSide = (side + 1) % sideCount
                let current = UInt32(ring * sideCount + side)
                let currentNext = UInt32(ring * sideCount + nextSide)
                let following = UInt32((ring + 1) * sideCount + side)
                let followingNext = UInt32((ring + 1) * sideCount + nextSide)

                appendTriangle(
                    current,
                    following,
                    currentNext,
                    positions: positions,
                    to: &triangleIndices
                )
                appendTriangle(
                    currentNext,
                    following,
                    followingNext,
                    positions: positions,
                    to: &triangleIndices
                )
            }
        }

        guard
            !triangleIndices.isEmpty,
            positions.allSatisfy(isFinite),
            normals.allSatisfy(isFinite),
            triangleIndices.allSatisfy({ Int($0) < positions.count })
        else {
            return nil
        }

        return TubeMeshData(
            positions: positions,
            normals: normals,
            triangleIndices: triangleIndices
        )
    }

    private static func tangent(
        at index: Int,
        points: [SIMD3<Float>]
    ) -> SIMD3<Float> {
        let vector: SIMD3<Float>
        if index == points.startIndex {
            vector = points[points.index(after: index)] - points[index]
        } else if index == points.index(before: points.endIndex) {
            vector = points[index] - points[points.index(before: index)]
        } else {
            vector = points[points.index(after: index)] - points[points.index(before: index)]
        }

        let length = simd_length(vector)
        return length > .ulpOfOne ? vector / length : SIMD3<Float>(1, 0, 0)
    }

    private static func initialNormal(for tangent: SIMD3<Float>) -> SIMD3<Float> {
        let reference = fallbackAxis(for: tangent)
        return simd_normalize(reference - tangent * simd_dot(reference, tangent))
    }

    private static func transportedNormal(
        previousNormal: SIMD3<Float>,
        tangent: SIMD3<Float>
    ) -> SIMD3<Float> {
        let projected = previousNormal - tangent * simd_dot(previousNormal, tangent)
        let projectedLength = simd_length(projected)
        var normal = projectedLength > 0.000_001
            ? projected / projectedLength
            : initialNormal(for: tangent)

        if simd_dot(normal, previousNormal) < 0 {
            normal = -normal
        }
        return normal
    }

    private static func fallbackAxis(for tangent: SIMD3<Float>) -> SIMD3<Float> {
        let axes = [
            SIMD3<Float>(1, 0, 0),
            SIMD3<Float>(0, 1, 0),
            SIMD3<Float>(0, 0, 1),
        ]
        return axes.min { abs(simd_dot(tangent, $0)) < abs(simd_dot(tangent, $1)) }
            ?? SIMD3<Float>(0, 1, 0)
    }

    private static func appendTriangle(
        _ first: UInt32,
        _ second: UInt32,
        _ third: UInt32,
        positions: [SIMD3<Float>],
        to triangleIndices: inout [UInt32]
    ) {
        let a = positions[Int(first)]
        let b = positions[Int(second)]
        let c = positions[Int(third)]
        guard simd_length_squared(simd_cross(b - a, c - a)) > 0.000_000_000_001 else {
            return
        }
        triangleIndices.append(contentsOf: [first, second, third])
    }

    private static func isFinite(_ vector: SIMD3<Float>) -> Bool {
        vector.x.isFinite && vector.y.isFinite && vector.z.isFinite
    }
}
