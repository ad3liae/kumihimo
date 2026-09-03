import Foundation
import simd

enum HiraGenjiSurfaceRegion: CaseIterable, Hashable, Sendable {
    case front
    case back
    case leftEdge
    case rightEdge
}

enum HiraGenjiThreadRole: Equatable, Sendable {
    /// Threads worked vertically on faces 1 and 3.
    case inner
    /// Threads worked horizontally on faces 2 and 4.
    case outer
}

struct HiraGenjiSurfacePatch: Equatable, Sendable {
    let region: HiraGenjiSurfaceRegion
    let threadRole: HiraGenjiThreadRole
    let threadPosition: Int
    let colorID: ThreadColorID
    let widthColumn: Int
    /// The two thread appearances that alternate along the braid in this lane.
    let stitchPhase: Int
    /// Region-local width and repeat-local length coordinates.
    let corners: [SIMD2<Float>]
}

struct HiraGenjiSurfacePattern: Equatable, Sendable {
    let patches: [HiraGenjiSurfacePatch]

    func patches(in region: HiraGenjiSurfaceRegion) -> [HiraGenjiSurfacePatch] {
        patches.filter { $0.region == region }
    }
}

enum HiraGenjiSurfacePatternGenerator {
    static let requiredThreadCount = 16
    static let broadFaceColumnCount = 6
    static let stitchPhaseCount = 2
    static let edgeColumnCount = 2
    static let patchCount = 32

    static func generate(assignments: [ThreadAssignment]) -> HiraGenjiSurfacePattern? {
        let expectedPositions = Set(1...requiredThreadCount)
        let suppliedPositions = Set(assignments.map(\.position))
        guard
            assignments.count == requiredThreadCount,
            suppliedPositions == expectedPositions,
            suppliedPositions.count == requiredThreadCount
        else {
            return nil
        }
        let colorsByPosition = Dictionary(
            uniqueKeysWithValues: assignments.map { ($0.position, $0.colorID) }
        )
        guard let threadPositionsByRegion = surfaceCorrespondence() else { return nil }
        let outerPositions = Set(HiraGenjiBoardState.initial.east + HiraGenjiBoardState.initial.west)

        var patches = [HiraGenjiSurfacePatch]()
        for region in HiraGenjiSurfaceRegion.allCases {
            guard let rows = threadPositionsByRegion[region] else { return nil }
            let columnCount = region == .front || region == .back
                ? broadFaceColumnCount
                : edgeColumnCount
            guard rows.count == stitchPhaseCount,
                  rows.allSatisfy({ $0.count == columnCount }) else {
                return nil
            }

            for (phase, positions) in rows.enumerated() {
                for (column, threadPosition) in positions.enumerated() {
                    guard let colorID = colorsByPosition[threadPosition] else { return nil }
                    let u0 = Float(column) / Float(columnCount)
                    let u1 = Float(column + 1) / Float(columnCount)
                    let middleOffsets = stitchBoundaryOffsets(
                        region: region,
                        columnCount: columnCount
                    )
                    let leftMiddle = 0.5 + middleOffsets[column]
                    let rightMiddle = 0.5 + middleOffsets[column + 1]
                    let leftV0: Float = phase == 0 ? 0 : leftMiddle
                    let leftV1: Float = phase == 0 ? leftMiddle : 1
                    let rightV0: Float = phase == 0 ? 0 : rightMiddle
                    let rightV1: Float = phase == 0 ? rightMiddle : 1
                    patches.append(HiraGenjiSurfacePatch(
                        region: region,
                        threadRole: outerPositions.contains(threadPosition) ? .outer : .inner,
                        threadPosition: threadPosition,
                        colorID: colorID,
                        widthColumn: column,
                        stitchPhase: phase,
                        corners: [
                            SIMD2<Float>(u0, leftV0),
                            SIMD2<Float>(u0, leftV1),
                            SIMD2<Float>(u1, rightV1),
                            SIMD2<Float>(u1, rightV0),
                        ]
                    ))
                }
            }
        }

        guard patches.count == patchCount else { return nil }
        return HiraGenjiSurfacePattern(patches: patches)
    }

    /// The six broad-face columns are physical lanes across the finished flat braid:
    /// an outer lane at either edge and four inner lanes between them. Each lane has
    /// two threads that alternate in the longitudinal direction. The movement order
    /// is deliberately not used as a left-to-right coordinate.
    ///
    /// The back uses the horizontal threads that remain at the face centers after
    /// the six worked moves and reverses the inner-lane viewpoint. Keeping it as a
    /// separate table preserves the documented front/back color-role reversal.
    private static func surfaceCorrespondence()
        -> [HiraGenjiSurfaceRegion: [[Int]]]? {
        guard let cycle = HiraGenjiSimulation.cycle(from: .initial),
              cycle.moveEvents.count == broadFaceColumnCount,
              cycle.moveEvents.allSatisfy({ $0.moves.count == stitchPhaseCount }) else {
            return nil
        }

        // Physical left-to-right lane order. The two horizontal crossing pairs
        // enclose the four vertical crossing pairs visible in the reference samples.
        let frontEventOrder = [0, 4, 2, 3, 5, 1]
        let front = (0..<stitchPhaseCount).map { phase in
            frontEventOrder.map { cycle.moveEvents[$0].moves[phase].threadPosition }
        }

        let initial = cycle.startState
        return [
            .front: front,
            .back: [
                [initial.east[2], initial.north[3], initial.north[2],
                 initial.south[2], initial.south[3], initial.west[2]],
                [initial.east[1], initial.north[0], initial.north[1],
                 initial.south[1], initial.south[0], initial.west[1]],
            ],
            .leftEdge: [
                [initial.west[0], initial.west[1]],
                [initial.west[3], initial.west[2]],
            ],
            .rightEdge: [
                [initial.east[0], initial.east[1]],
                [initial.east[3], initial.east[2]],
            ],
        ]
    }

    /// Produces the staggered join between the two thread appearances in one
    /// stitch. Adjacent columns alternate direction, while the repeat boundary is
    /// kept straight so independently instanced infinite-length tiles remain exact.
    private static func stitchBoundaryOffsets(
        region: HiraGenjiSurfaceRegion,
        columnCount: Int
    ) -> [Float] {
        let amplitude: Float = region == .front || region == .back ? 0.20 : 0.12
        return (0...columnCount).map { boundary in
            guard boundary > 0, boundary < columnCount else { return 0 }
            let sign: Float = boundary.isMultiple(of: 2) ? -1 : 1
            return region == .back ? -sign * amplitude : sign * amplitude
        }
    }
}
