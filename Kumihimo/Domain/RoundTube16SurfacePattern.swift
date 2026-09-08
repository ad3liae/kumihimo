import Foundation
import simd

struct RoundTube16SurfacePatch: Equatable, Sendable {
    let threadPosition: Int
    let colorID: ThreadColorID
    /// Which side of a crossing this run of thread takes. See `layer(for:)`.
    let layer: BraidCrossingLayer
    /// Corners in clockwise order: leading/top, leading/bottom, trailing/bottom, trailing/top.
    /// `v` may extend into the next repeat so a chevron can cross the longitudinal seam.
    let corners: [SIMD2<Float>]
}

struct RoundTube16SurfacePattern: Equatable, Sendable {
    let patches: [RoundTube16SurfacePatch]
    /// Length of one repeat along the braid divided by the length around it, both
    /// measured in the unwrapped drawing the patches come from. Wrapping the
    /// pattern onto a braid of any radius has to preserve this ratio, or the
    /// chevrons lean at an angle the drawing never had.
    let aspectRatio: Float

    init(
        patches: [RoundTube16SurfacePatch],
        aspectRatio: Float = RoundTube16SurfacePatternGenerator.patternAspectRatio
    ) {
        self.patches = patches
        self.aspectRatio = aspectRatio
    }
}

enum RoundTube16SurfacePatternGenerator {
    static let requiredThreadCount = 16
    static let patchCount = 64
    static let maximumUnwrappedV: Float = 9 / 8
    /// Length of one repeat along the braid divided by one turn around it.
    ///
    /// The unwrapped drawing is a square — eight columns of 400 source units around,
    /// 400 units along one repeat, see `normalizedCorners(for:)` — but the drawing is
    /// a correspondence table, not a scale drawing, so its own proportions do not
    /// say how far the finished braid advances in one repeat. Task 005F took the
    /// square at face value and drew the chevrons about a third coarser than the
    /// real braid.
    ///
    /// This value was found by rendering and comparing, not by calculation: the
    /// braid is cut to 4.5 times its own width, scaled to the same height as the
    /// same length of the photographed braid, and the chevrons counted in both. The
    /// density is inversely proportional to this ratio, and lowering it from 1.0
    /// takes the count from about 1.3 chevrons per braid width to about 2.0.
    ///
    /// The photograph is read two ways: counted by eye it shows about 1.8 chevrons
    /// per braid width, measured off the same normalised strip about 2.15. This
    /// ratio sits between them, within 9 per cent of either, so it holds whichever
    /// reading is right. See `.build/task005i-screenshots/`.
    static let patternAspectRatio: Float = 0.65

    /// Which thread the occupancy history puts in each cell of this drawing.
    ///
    /// **The threads are no longer transcribed.** They come from the move table by
    /// way of `BraidOccupancy`. What joins the two is a correspondence worked out
    /// here, not chosen: **each column of this drawing is matched to the column of
    /// the occupancy history whose run of threads it holds**, at the offset along
    /// the braid where the two run together. If a column matched none, or matched
    /// more than one, this returns `nil` rather than guessing.
    ///
    /// **The order the columns come out in is the transcription's, and that order is
    /// not reachable from the ring by rotating or mirroring it** — book A's own
    /// colourings cannot tell the two apart, and the question is open, awaiting the
    /// author's own braid (`docs/architecture.md`, 丸源氏の64升の表). So the
    /// correspondence is a permutation and not a rotation, and it says so.
    ///
    /// The **shape** of every cell still comes from the transcribed drawing below.
    /// Only which thread is in it is derived.
    static func threadByCell(
        stand: BraidStand, method: BraidMethod, crossSection: BraidCrossSection
    ) -> [[Int]: Int]? {
        guard
            let occupancy = BraidOccupancy.history(of: method, on: stand,
                                                   crossSection: crossSection, cycles: 4),
            let columns = occupancy.columns(.landing), columns.count == 8,
            let grid = occupancy.grid(atColumns: columns, rows: 4)
        else { return nil }

        // The drawing's own cells, recovered from the shape data below.
        var drawn = [[Int]: Int]()
        for strand in sourceStrands {
            for diamond in strand.diamonds {
                guard let cell = cell(for: diamond) else { return nil }
                drawn[[cell.column, cell.row]] = strand.threadPosition
            }
        }

        // **The drawing's rows are numbered from one**, and eight of them are the
        // four cycles drawn twice. Its own checkerboard of over and under is built
        // on that numbering, so it is left exactly as it is.
        var out = [[Int]: Int]()
        for column in 0..<8 {
            let wanted = (1...4).compactMap { drawn[[column, $0]] }
            guard wanted.count == 4 else { return nil }
            // **A run matches more than one column of the history, and that is the
            // braid's own symmetry**: sixteen threads in eight columns repeat every
            // four columns, two cycles along. Every match must therefore fill the
            // column the same way, and that is checked rather than assumed.
            var filled: [Int]?
            for other in 0..<8 {
                for shift in 0..<4 {
                    for upwards in [true, false] {
                        let run = (0..<4).map { step in
                            grid[((shift + (upwards ? step : -step)) % 4 + 4) % 4][other]
                        }
                        guard run == wanted else { continue }
                        let whole = (1...8).map { row -> Int in
                            let step = (row - 1) % 4
                            let at = ((shift + (upwards ? step : -step)) % 4 + 4) % 4
                            return grid[at][other]
                        }
                        if let filled, filled != whole { return nil }  // truly ambiguous
                        filled = whole
                    }
                }
            }
            guard let filled else { return nil }         // no way round: not this braid
            for row in 1...8 { out[[column, row]] = filled[row - 1] }
        }
        return out
    }

    static func generate(assignments: [ThreadAssignment]) -> RoundTube16SurfacePattern? {
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
        guard let threadByCell = threadByCell(
            stand: BraidMethodCatalog.stand16, method: BraidMethodCatalog.maruGenji16,
            crossSection: BraidMethodCatalog.maruGenji16CrossSection
        ) else { return nil }
        let patches = sourceStrands.flatMap { strand -> [RoundTube16SurfacePatch] in
            strand.diamonds.compactMap { diamond in
                guard
                    let layer = layer(for: diamond),
                    let cell = cell(for: diamond),
                    let threadPosition = threadByCell[[cell.column, cell.row]],
                    let colorID = colorsByPosition[threadPosition]
                else { return nil }
                return RoundTube16SurfacePatch(
                    threadPosition: threadPosition,
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
        return RoundTube16SurfacePattern(patches: patches)
    }

    struct SourceStrand {
        let threadPosition: Int
        let diamonds: [SourceDiamond]
    }

    struct SourceDiamond {
        let x: Int
        let y: Int
        let risesTowardTrailingEdge: Bool
    }

    /// The 64-patch correspondence verified by the local Maru-genji comparison page.
    /// Coordinates are retained here as compact integer source data, then rectified below.
    static let sourceStrands: [SourceStrand] = [
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
        guard let cell = cell(for: diamond) else { return nil }
        return (cell.column + cell.row).isMultiple(of: 2) ? .over : .under
    }

    /// Which of the drawing's eight-by-eight cells a diamond is.
    static func cell(for diamond: SourceDiamond) -> (column: Int, row: Int)? {
        guard let faceTop = faceTopByColumnX[diamond.x] else { return nil }
        let centerY = diamond.risesTowardTrailingEdge ? diamond.y + 50 : diamond.y
        return ((diamond.x - 50) / 50, (centerY - faceTop) / 50)
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
