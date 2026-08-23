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
        guard points.count >= 2, tubeRadius > 0, sideCount >= 3 else { return nil }

        var positions = [SIMD3<Float>]()
        var normals = [SIMD3<Float>]()
        positions.reserveCapacity(points.count * sideCount)
        normals.reserveCapacity(points.count * sideCount)

        for pointIndex in points.indices {
            let tangent = tangent(at: pointIndex, points: points)
            let reference = abs(simd_dot(tangent, SIMD3<Float>(0, 0, 1))) < 0.9
                ? SIMD3<Float>(0, 0, 1)
                : SIMD3<Float>(0, 1, 0)
            let normalAxis = simd_normalize(simd_cross(tangent, reference))
            let binormalAxis = simd_normalize(simd_cross(tangent, normalAxis))

            for side in 0..<sideCount {
                let angle = 2 * Float.pi * Float(side) / Float(sideCount)
                let radialNormal = normalAxis * cos(angle) + binormalAxis * sin(angle)
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

                triangleIndices.append(contentsOf: [
                    current, following, currentNext,
                    currentNext, following, followingNext,
                ])
            }
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
}
