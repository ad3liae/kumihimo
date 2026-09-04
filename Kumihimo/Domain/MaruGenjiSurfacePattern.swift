import Foundation
import simd

struct MaruGenjiSurfacePatch: Equatable, Sendable {
    let threadPosition: Int
    let colorID: ThreadColorID
    /// Which side of a crossing this run of thread takes. See `layer(for:)`.
    let layer: BraidCrossingLayer
    /// Corners in clockwise order: leading/top, leading/bottom, trailing/bottom, trailing/top.
    /// `v` may extend into the next repeat so a chevron can cross the longitudinal seam.
    let corners: [SIMD2<Float>]
}

struct MaruGenjiSurfacePattern: Equatable, Sendable {
    let patches: [MaruGenjiSurfacePatch]
}

enum MaruGenjiSurfacePatternGenerator {
    static let requiredThreadCount = 16
    static let patchCount = 64
    static let maximumUnwrappedV: Float = 9 / 8

    static func generate(assignments: [ThreadAssignment]) -> MaruGenjiSurfacePattern? {
        let expectedPositions = Set(1...requiredThreadCount)
        let suppliedPositions = Set(assignments.map(\.position))
        guard
            assignments.count == requiredThreadCount,
            suppliedPositions.count == requiredThreadCount,
            suppliedPositions == expectedPositions
        else {
            return nil
        }

        let colorsByPosition = Dictionary(
            uniqueKeysWithValues: assignments.map { ($0.position, $0.colorID) }
        )
        let patches = sourceStrands.flatMap { strand -> [MaruGenjiSurfacePatch] in
            guard let colorID = colorsByPosition[strand.threadPosition] else { return [] }
            return strand.diamonds.compactMap { diamond in
                guard let layer = layer(for: diamond) else { return nil }
                return MaruGenjiSurfacePatch(
                    threadPosition: strand.threadPosition,
                    colorID: colorID,
                    layer: layer,
                    corners: normalizedCorners(for: diamond)
                )
            }
        }

        guard
            patches.count == patchCount,
            patches.allSatisfy({ patch in
                patch.corners.count == 4 && patch.corners.allSatisfy { corner in
                        corner.x.isFinite && corner.y.isFinite
                            && (0...1).contains(corner.x)
                            && (0...maximumUnwrappedV).contains(corner.y)
                }
            })
        else {
            return nil
        }
        return MaruGenjiSurfacePattern(patches: patches)
    }

    private struct SourceStrand {
        let threadPosition: Int
        let diamonds: [SourceDiamond]
    }

    private struct SourceDiamond {
        let x: Int
        let y: Int
        let risesTowardTrailingEdge: Bool
    }

    /// The 64-patch correspondence verified by the local Maru-genji comparison page.
    /// Coordinates are retained here as compact integer source data, then rectified below.
    private static let sourceStrands: [SourceStrand] = [
        strand(1, (100, 175, false), (100, 375, false), (250, 225, true), (250, 425, true)),
        strand(2, (100, 225, false), (100, 425, false), (250, 275, true), (250, 475, true)),
        strand(3, (200, 300, false), (200, 500, false), (350, 150, true), (350, 350, true)),
        strand(4, (200, 250, false), (200, 450, false), (350, 100, true), (350, 300, true)),
        strand(5, (150, 200, true), (150, 400, true), (400, 150, false), (400, 350, false)),
        strand(6, (150, 250, true), (150, 450, true), (400, 200, false), (400, 400, false)),
        strand(7, (100, 325, false), (100, 525, false), (250, 175, true), (250, 375, true)),
        strand(8, (100, 275, false), (100, 475, false), (250, 125, true), (250, 325, true)),
        strand(9, (50, 225, true), (50, 425, true), (300, 175, false), (300, 375, false)),
        strand(10, (50, 275, true), (50, 475, true), (300, 225, false), (300, 425, false)),
        strand(11, (150, 150, true), (150, 350, true), (400, 300, false), (400, 500, false)),
        strand(12, (150, 100, true), (150, 300, true), (400, 250, false), (400, 450, false)),
        strand(13, (200, 150, false), (200, 350, false), (350, 400, true), (350, 200, true)),
        strand(14, (200, 200, false), (200, 400, false), (350, 250, true), (350, 450, true)),
        strand(15, (50, 175, true), (50, 375, true), (300, 325, false), (300, 525, false)),
        strand(16, (50, 125, true), (50, 325, true), (300, 275, false), (300, 475, false)),
    ]

    /// Each pair of source columns is one observed face of the braid. Its vertical
    /// origin differs in the reference drawing, so rectify the four faces before
    /// wrapping them around the cylinder. The last chevron row intentionally reaches
    /// 9/8 and is clipped into the next repeat by the mesh generator.
    private static let faceTopByColumnX: [Int: Int] = [
        50: 125,
        100: 125,
        150: 100,
        200: 100,
        250: 125,
        300: 125,
        350: 100,
        400: 100,
    ]

    private static func strand(
        _ position: Int,
        _ diamonds: (Int, Int, Bool)...
    ) -> SourceStrand {
        SourceStrand(
            threadPosition: position,
            diamonds: diamonds.map(SourceDiamond.init)
        )
    }

    /// The 64 patches fill an exact 8x8 grid of surface cells: eight columns
    /// around the braid, eight chevron rows along one repeat. Neighbouring cells
    /// always differ by one in exactly one of the two indices, so a checkerboard
    /// on `column + row` puts opposite layers on both sides of every crossing and
    /// makes each thread alternate over and under along its length.
    private static func layer(for diamond: SourceDiamond) -> BraidCrossingLayer? {
        guard let faceTop = faceTopByColumnX[diamond.x] else { return nil }
        let columnIndex = (diamond.x - 50) / 50
        let centerY = diamond.risesTowardTrailingEdge ? diamond.y + 50 : diamond.y
        let rowIndex = (centerY - faceTop) / 50
        return (columnIndex + rowIndex).isMultiple(of: 2) ? .over : .under
    }

    private static func normalizedCorners(for diamond: SourceDiamond) -> [SIMD2<Float>] {
        guard let faceTop = faceTopByColumnX[diamond.x] else { return [] }
        let rawCorners: [(Int, Int)]
        if diamond.risesTowardTrailingEdge {
            rawCorners = [
                (diamond.x, diamond.y),
                (diamond.x, diamond.y + 50),
                (diamond.x + 50, diamond.y + 100),
                (diamond.x + 50, diamond.y + 50),
            ]
        } else {
            rawCorners = [
                (diamond.x, diamond.y),
                (diamond.x, diamond.y + 50),
                (diamond.x + 50, diamond.y),
                (diamond.x + 50, diamond.y - 50),
            ]
        }

        return rawCorners.map { x, y in
            return SIMD2<Float>(
                Float(x - 50) / 400,
                Float(y - faceTop) / 400
            )
        }
    }
}
