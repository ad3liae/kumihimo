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
    /// Which step along the braid inside one repeat this appearance stands at.
    let row: Int
    /// Region-local width and repeat-local length coordinates.
    let corners: [SIMD2<Float>]
}

struct HiraGenjiSurfacePattern: Equatable, Sendable {
    let patches: [HiraGenjiSurfacePatch]
    /// Steps along the braid in one repeat.
    let rowCount: Int
    /// Length of one repeat divided by the braid's width. The mesh derives its
    /// length from this and the cross-section rather than carrying a length of
    /// its own, so a stitch cannot come out the wrong shape.
    let aspectRatio: Float

    func patches(in region: HiraGenjiSurfaceRegion) -> [HiraGenjiSurfacePatch] {
        patches.filter { $0.region == region }
    }
}

/// Lays the flat braid's surface out for the mesh: four regions round the
/// cross-section, six lanes across each face and two at each edge, and one step
/// along the braid for every worked cycle.
///
/// This file decides **where** each place is. **Which thread stands there** comes
/// from `HiraGenjiWeavePattern`, which Task 007F derived from the move rules and
/// checked against book A's two controlled samples. The correspondence this file
/// used to carry — a table hand-written from one cycle's move order — was refuted
/// there and is gone.
enum HiraGenjiSurfacePatternGenerator {
    static let requiredThreadCount = 16
    static let broadFaceColumnCount = HiraGenjiWeaveDerivation.columnCount
    static let edgeColumnCount = HiraGenjiWeaveDerivation.edgeThreadCount

    /// Steps along the braid in one repeat. Four, from the move rules, where the
    /// old hand-written table had two.
    static var rowCount: Int? { HiraGenjiWeavePatternGenerator.rowCount }

    static var patchCount: Int? {
        rowCount.map { 2 * broadFaceColumnCount * $0 + 2 * edgeColumnCount * $0 }
    }

    /// How far a stitch join leans, as a fraction of one step along the braid.
    ///
    /// **Zero because the references do not settle it.** It was 0.4, carried over
    /// from the two-step layout and measured from nothing. Measuring it twice
    /// over, by two methods, gave:
    ///
    /// - book A p96: 0.023 by phase correlation, 0.048 by structure tensor — and
    ///   the correlation fit's residual (1.32 px) is larger than the amplitude it
    ///   found (1.00 px), so that reference cannot tell a lean from none at all
    /// - book B p23: 0.128 and 0.039 — the two methods disagree threefold, on a
    ///   braid only 68 px across
    ///
    /// The four readings span 0.023 to 0.128 and agree nowhere near the fifteen
    /// per cent the task asks for. All of them do refute 0.4, by three to
    /// seventeen times.
    ///
    /// **Zero is the right answer, not a placeholder.** Book A p97 settles it.
    /// Its colour-variant caption reads "colour the middle two of faces 2 and 4
    /// one way and the far and near two another, and the *edging* comes out in
    /// arrow-feather". Faces 2 and 4 are the threads carried across; what they
    /// pattern is the edging, not the body. The gold-and-brown sample beside it
    /// has no diagonal anywhere in its body — only short crosswise units in
    /// courses. The braid's body has no lean to draw.
    ///
    /// The lean book A p96's grey band seems to show is the twist stripe of the
    /// yarn itself, which stage 4 draws, not the boundary of a unit.
    static let faceStitchLean: Float = 0
    /// The edges were never measured either. Left alone here so that stage 2.5c
    /// changed only what it set out to; it is the same open question.
    static let edgeStitchLean: Float = 0.24

    /// One step along the braid, as a fraction of the braid's width.
    ///
    /// Measured, not chosen. Two finished braids in the references were
    /// de-skewed, their stitch pitch found by autocorrelation along the braid and
    /// their width read off the colour profile across it:
    ///
    /// - book A p96, the No.30 sample: pitch 43.5 px, width 124 px → 0.351
    /// - book B p23, "23 平源氏組": pitch 26 px, width 68 px → 0.382
    ///
    /// They agree to 8.8 per cent, inside the fifteen the task asks for, so the
    /// figure is their mean. Book A p97's colour variant is not used: it is
    /// photographed knotted, with too short a straight run for the width to be
    /// read — the same reason Task 007F left it out of its width comparison.
    ///
    /// The value this replaced was a length of 3.4 hard-coded in the mesh, which
    /// made a stitch 0.098 of the braid's width — three and a half times too fine.
    static let stitchPitchPerBraidWidth: Float = 0.3665

    /// Length of one repeat over the braid's width. Four steps to a repeat.
    static var patternAspectRatio: Float? {
        rowCount.map { Float($0) * stitchPitchPerBraidWidth }
    }

    static func generate(assignments: [ThreadAssignment]) -> HiraGenjiSurfacePattern? {
        guard
            let rowCount,
            let aspectRatio = patternAspectRatio,
            let weave = HiraGenjiWeavePatternGenerator.generate(assignments: assignments),
            weave.columnCount == broadFaceColumnCount,
            weave.rowCount == rowCount
        else {
            return nil
        }

        var patches = [HiraGenjiSurfacePatch]()
        for region in HiraGenjiSurfaceRegion.allCases {
            let columnCount = columnCount(in: region)
            let offsets = stitchBoundaryOffsets(region: region, columnCount: columnCount)
            for row in 0..<rowCount {
                for column in 0..<columnCount {
                    guard
                        let place = occupant(
                            of: weave,
                            region: region,
                            column: column,
                            row: row
                        )
                    else {
                        return nil
                    }
                    patches.append(HiraGenjiSurfacePatch(
                        region: region,
                        threadRole: place.role,
                        threadPosition: place.threadPosition,
                        colorID: place.colorID,
                        widthColumn: column,
                        row: row,
                        corners: corners(
                            column: column,
                            row: row,
                            rowCount: rowCount,
                            columnCount: columnCount,
                            lean: offsets
                        )
                    ))
                }
            }
        }

        guard patches.count == patchCount else { return nil }
        return HiraGenjiSurfacePattern(
            patches: patches,
            rowCount: rowCount,
            aspectRatio: aspectRatio
        )
    }

    static func columnCount(in region: HiraGenjiSurfaceRegion) -> Int {
        switch region {
        case .front, .back: return broadFaceColumnCount
        case .leftEdge, .rightEdge: return edgeColumnCount
        }
    }

    private struct Occupant {
        let threadPosition: Int
        let colorID: ThreadColorID
        let role: HiraGenjiThreadRole
    }

    /// Which thread the weave puts at one place in one region.
    ///
    /// The regions are a ring: `crossSectionPoint` runs the front from `+x` to
    /// `-x` and the back back again from `-x` to `+x`. A weave column has to come
    /// out at the same place across the width on both faces — it is one column of
    /// the braid, not two — so the front's lane order runs against the weave's and
    /// the back's runs with it.
    ///
    /// The edges hold two threads through the thickness rather than two lanes
    /// across the braid. The left edge is entered from the front and the right
    /// edge from the back, so their two lanes are in opposite orders.
    private static func occupant(
        of weave: HiraGenjiWeavePattern,
        region: HiraGenjiSurfaceRegion,
        column: Int,
        row: Int
    ) -> Occupant? {
        switch region {
        case .front, .back:
            let face: HiraGenjiBraidFace = region == .front ? .front : .back
            let weaveColumn = region == .front
                ? broadFaceColumnCount - 1 - column
                : column
            guard let patch = weave.patch(column: weaveColumn, row: row, face: face) else {
                return nil
            }
            return Occupant(
                threadPosition: patch.threadPosition,
                colorID: patch.colorID,
                role: patch.course == .lengthwise ? .inner : .outer
            )
        case .leftEdge, .rightEdge:
            let edge: HiraGenjiBraidEdge = region == .leftEdge ? .left : .right
            let half: HiraGenjiBraidFace
            if region == .leftEdge {
                half = column == 0 ? .front : .back
            } else {
                half = column == 0 ? .back : .front
            }
            guard
                let place = weave.threadsAtEdge(row: row, edge: edge)
                    .first(where: { $0.half == half })
            else {
                return nil
            }
            // Everything that reaches an edge is worked across the braid.
            return Occupant(
                threadPosition: place.threadPosition,
                colorID: place.colorID,
                role: .outer
            )
        }
    }

    /// One patch's corners: leading low, leading high, trailing high, trailing
    /// low, in region-local width and repeat-local length.
    static func corners(
        column: Int,
        row: Int,
        rowCount: Int,
        columnCount: Int,
        lean: Float
    ) -> [SIMD2<Float>] {
        corners(
            column: column,
            row: row,
            rowCount: rowCount,
            columnCount: columnCount,
            lean: leanOffsets(amplitude: lean, columnCount: columnCount)
        )
    }

    private static func corners(
        column: Int,
        row: Int,
        rowCount: Int,
        columnCount: Int,
        lean offsets: [Float]
    ) -> [SIMD2<Float>] {
        let u0 = Float(column) / Float(columnCount)
        let u1 = Float(column + 1) / Float(columnCount)
        let leftLow = boundary(row, rowCount: rowCount, offset: offsets[column])
        let leftHigh = boundary(row + 1, rowCount: rowCount, offset: offsets[column])
        let rightLow = boundary(row, rowCount: rowCount, offset: offsets[column + 1])
        let rightHigh = boundary(row + 1, rowCount: rowCount, offset: offsets[column + 1])
        return [
            SIMD2<Float>(u0, leftLow),
            SIMD2<Float>(u0, leftHigh),
            SIMD2<Float>(u1, rightHigh),
            SIMD2<Float>(u1, rightLow),
        ]
    }

    /// Where one stitch join sits along the repeat. The ends of the repeat are
    /// held straight so independently instanced infinite-length tiles stay exact;
    /// the joins inside it lean.
    private static func boundary(_ index: Int, rowCount: Int, offset: Float) -> Float {
        let straight = Float(index) / Float(rowCount)
        guard index > 0, index < rowCount else { return straight }
        return straight + offset / Float(rowCount)
    }

    /// Produces the staggered join between the appearances in one lane. Adjacent
    /// columns lean opposite ways, and the two faces lean opposite ways to each
    /// other so the braid reads the same from either side.
    private static func stitchBoundaryOffsets(
        region: HiraGenjiSurfaceRegion,
        columnCount: Int
    ) -> [Float] {
        let amplitude = region == .front || region == .back ? faceStitchLean : edgeStitchLean
        return leanOffsets(
            amplitude: region == .back ? -amplitude : amplitude,
            columnCount: columnCount
        )
    }

    private static func leanOffsets(amplitude: Float, columnCount: Int) -> [Float] {
        (0...columnCount).map { boundary in
            guard boundary > 0, boundary < columnCount else { return 0 }
            let sign: Float = boundary.isMultiple(of: 2) ? -1 : 1
            return sign * amplitude
        }
    }
}
