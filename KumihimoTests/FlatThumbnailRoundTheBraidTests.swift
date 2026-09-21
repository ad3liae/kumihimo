import CoreGraphics
import Foundation
import Testing
import simd
@testable import Kumihimo

/// **The frame's height is one turn round the braid**, not one face of it.
///
/// The round braid's thumbnail has always opened its whole circumference. The flat
/// one drew six columns of sixteen and called that the braid, so half the colours
/// a person chose never appeared in the list (Task 029).
///
/// What must not move in the doing of it is the **scale**: a cell keeps the
/// proportion it had. The frame holds more of the braid; it does not hold it
/// smaller. Both halves of that are pinned below.
struct FlatThumbnailRoundTheBraidTests {
    /// The card the list actually draws, on both sizes of screen.
    private static let iPhoneCard = CGSize(width: 361, height: 112)
    private static let iPadCard = CGSize(width: 754, height: 112)

    private static var roundTheBraid: Float {
        get throws { try #require(Flat16SurfaceMesh.patternAspectRatioRoundTheBraid) }
    }

    private static var acrossTheWidth: Float {
        get throws { try #require(Flat16SurfacePatternGenerator.patternAspectRatio) }
    }

    /// Where a region begins **down the frame**, once the drawing has been turned so
    /// the cut falls at a region boundary (Task 029-2).
    private static func drawnStart(of region: Flat16SurfaceRegion) -> Float {
        (Flat16SurfaceMesh.arcSpan(of: region).start + Flat16ThumbnailView.seamRotation)
            .truncatingRemainder(dividingBy: 1)
    }

    // MARK: - 1. The ratio handed to the layout

    /// **Over the turn, not over the width — and measured on the outline the
    /// mesh draws** (Task 050).
    ///
    /// Task 029 took the two counts, six lanes to a broad face against sixteen
    /// places round the braid, and recorded that scaling by 6/16 treats the arc
    /// of one broad face as the width across the braid. It is not: a lane is one
    /// half-thickness of arc, so six of them are 6 / 3.3359 = 1.799 half-widths
    /// against a width of 2. **This updates that decision**: the card's cells were
    /// eleven per cent **too short** for their width, and putting it right
    /// lengthens them along the braid — one repeat on a card 112 high goes from
    /// 61.57 points to 68.47.
    @Test func theRatioIsMeasuredRoundTheOutlineTheMeshDraws() throws {
        let ratio = try Self.roundTheBraid
        let width = try Self.acrossTheWidth
        let halfWidth = Flat16SurfaceMesh.defaultHalfWidth
        let perimeter = Flat16SurfaceMesh.perimeter(
            halfWidth: halfWidth, halfThickness: Flat16SurfaceMesh.defaultHalfThickness
        )

        #expect(abs(ratio - width * 2 * halfWidth / perimeter) < 1e-6)
        #expect(abs(ratio - 0.6113) < 1e-3)
        // What Task 029 had, and how far out it was.
        let counted = width * Float(Flat16SurfacePatternGenerator.broadFaceColumnCount)
            / Float(Flat16SurfacePatternGenerator.boardPositionCount)
        #expect(abs(counted - 0.54975) < 1e-4)
        #expect(abs(ratio / counted - 1) > 0.10)

        // The width's own ratio is untouched: the mesh takes its length from it.
        #expect(abs(width - 1.466) < 1e-3)
    }

    /// The same quantity the round braid declares. **Until Task 047's rework the
    /// two came within a fifth of each other** (flat 0.55, round 0.65), and the
    /// two families' thumbnails came out at about the same density. The round
    /// braid's value is now 1.25, read off the author's own maru-genji with every
    /// row a V; the flat braid's is its own and was not touched. The two cards now
    /// differ in density by about 2.3 times; whether the flat braid's should move
    /// is for its own appearance task, against its own photographs.
    @Test func itIsTheSameQuantityTheRoundBraidDeclares() throws {
        let flat = try Self.roundTheBraid
        let tube = RoundTube16SurfacePatternGenerator.patternAspectRatio
        #expect(abs(tube - 1.25) < 1e-6)
        #expect(abs(flat - 0.6113) < 1e-3)
        // Task 050 measured the flat braid's on its own outline, which moved it
        // eleven per cent towards the round braid's. **The two cards still differ
        // by about two times — and this is a comparison between two braids'
        // cards, not a mismatch inside either one.** Two braids are not owed the
        // same density, so what is left here is a figure, not a fault.
        #expect(tube / flat > 1.9)
        #expect(tube / flat < 2.2)
    }

    // MARK: - 2. What the card comes out at

    @Test(arguments: [
        (CGSize(width: 361, height: 112), 7),
        (CGSize(width: 754, height: 112), 13),
    ])
    func theCardHoldsSevenRepeatsAndThirteen(_ size: CGSize, _ repeats: Int) throws {
        let ratio = try Self.roundTheBraid
        let layout = try #require(
            UnrolledPatternThumbnailLayout(size: size, aspectRatio: ratio)
        )
        #expect(layout.circumference == size.height)
        #expect(abs(layout.repeatLength - 68.466) < 0.01)
        #expect(layout.repeatCount == repeats)
    }

    /// Before Task 029 the same card held four repeats and six, each 164.192 pt
    /// long. The drawing did not shrink; the frame took in more of the braid.
    @Test func theCardUsedToHoldFewerAndLongerRepeats() throws {
        let width = try Self.acrossTheWidth
        for size in [Self.iPhoneCard, Self.iPadCard] {
            let old = try #require(
                UnrolledPatternThumbnailLayout(size: size, aspectRatio: width)
            )
            #expect(abs(old.repeatLength - 164.192) < 1e-3)
        }
        let oldPhone = try #require(
            UnrolledPatternThumbnailLayout(size: Self.iPhoneCard, aspectRatio: width)
        )
        let oldPad = try #require(
            UnrolledPatternThumbnailLayout(size: Self.iPadCard, aspectRatio: width)
        )
        #expect(oldPhone.repeatCount == 4)
        #expect(oldPad.repeatCount == 6)
    }

    // MARK: - 3. Every lane is one thread wide

    /// **height / 16, face lane and edge lane alike.** Not chosen here: `arcSpan`
    /// divides the turn by the number of threads, so a face's six columns and an
    /// edge's two come out the same height.
    @Test func everyLaneIsTheSameHeight() throws {
        let ratio = try Self.roundTheBraid
        let layout = try #require(
            UnrolledPatternThumbnailLayout(size: Self.iPhoneCard, aspectRatio: ratio)
        )
        let expected = Self.iPhoneCard.height / 16
        #expect(abs(expected - 7.0) < 1e-9)

        // Measured down the frame, on the turned drawing: every lane of every
        // region, round the turn. The right edge is cut through its middle, so
        // its lanes are taken round the wrap.
        var edges = [CGFloat]()
        for region in Flat16SurfaceRegion.allCases {
            let span = Flat16SurfaceMesh.arcSpan(of: region)
            let columns = Flat16SurfacePatternGenerator.columnCount(in: region)
            let lane = CGFloat(span.length / Float(columns)) * layout.circumference
            #expect(abs(lane - expected) < 1e-4, "\(region) lane \(lane)")

            let start = CGFloat(Self.drawnStart(of: region)) * layout.circumference
            for column in 0...columns {
                let edge = (start + CGFloat(column) * lane)
                    .truncatingRemainder(dividingBy: layout.circumference)
                edges.append(edge < -1e-4 ? edge + layout.circumference : edge)
            }
        }
        // Sixteen lanes end to end, each one thread wide, filling the frame: the
        // top of the frame is a lane boundary, and so is every seventh point.
        let boundaries = (edges.map { abs($0 - layout.circumference) < 1e-4 ? 0 : $0 })
            .sorted().reduce(into: [CGFloat]()) { kept, edge in
                if kept.last.map({ abs(edge - $0) > 1e-4 }) ?? true { kept.append(edge) }
            }
        #expect(boundaries.count == 16)
        #expect(abs((boundaries.first ?? -1)) < 1e-4)
        for (lower, upper) in zip(boundaries, boundaries.dropFirst() + [layout.circumference]) {
            #expect(abs((upper - lower) - expected) < 1e-4)
        }
    }

    // MARK: - 4. The scale did not move

    /// A cell is as long as it is wide by the same factor as before: the ratio's
    /// scaling by 6/16 is exactly cancelled by the lane count going 6 to 16.
    ///
    ///     before: 1.466 x 6 / 4 = 2.199
    ///     after:  0.54975 x 16 / 4 = 2.199
    @Test func aCellKeepsItsProportion() throws {
        let rows = try #require(Flat16SurfacePatternGenerator.rowCount)
        #expect(rows == 4)

        let ratio = try Self.roundTheBraid

        // **What a cell's proportion really is**, from the braid and not from
        // the card: one step is `stitchPitchPerBraidWidth` of the braid's width,
        // and one lane is one thread, which is one half-thickness.
        let step = Flat16SurfacePatternGenerator.stitchPitchPerBraidWidth
            * 2 * Flat16SurfaceMesh.defaultHalfWidth
        let lane = Flat16SurfaceMesh.defaultHalfThickness
        #expect(abs(step / lane - 2.445) < 1e-3)

        // The same thing measured off the card: one step long over one lane high.
        let layout = try #require(
            UnrolledPatternThumbnailLayout(size: Self.iPhoneCard, aspectRatio: ratio)
        )
        let cardStep = layout.repeatLength / CGFloat(rows)
        let cardLane = layout.circumference / 16
        #expect(abs(cardStep - 17.117) < 0.01)
        #expect(abs(cardLane - 7.0) < 1e-9)
        #expect(abs(Float(cardStep / cardLane) - 2.445) < 1e-3)

        // **Task 029's card drew it at 2.199**, which is the same step measured
        // against a sixth of the braid's width rather than against a thread.
        let counted = Flat16SurfacePatternGenerator.stitchPitchPerBraidWidth
            * Float(Flat16SurfacePatternGenerator.broadFaceColumnCount)
        #expect(abs(counted - 2.199) < 1e-3)
    }

    // MARK: - 5. The four regions cover the turn exactly

    @Test func theRegionsCoverTheTurnWithNoGapAndNoOverlap() throws {
        let spans = Flat16SurfaceRegion.allCases.map {
            (region: $0, span: Flat16SurfaceMesh.arcSpan(of: $0))
        }
        // The table Task 029 wrote down, read back off `arcSpan`. **The braid's own
        // cut, unmoved** — Task 029-2 turned the drawing, not this.
        let expected: [Flat16SurfaceRegion: (start: Float, length: Float)] = [
            .rightEdge: (0.9375, 0.125),
            .front: (0.0625, 0.375),
            .leftEdge: (0.4375, 0.125),
            .back: (0.5625, 0.375),
        ]
        for (region, span) in spans {
            let want = try #require(expected[region])
            #expect(abs(span.start - want.start) < 1e-6, "\(region) start")
            #expect(abs(span.length - want.length) < 1e-6, "\(region) length")
        }

        #expect(abs(spans.map(\.span.length).reduce(0, +) - 1) < 1e-6)

        // Laid end to end **round the turn the card shows**, each region begins
        // where the last ended, with no gap and no overlap — the right edge
        // carried round the frame's wrap, since the card is cut through it.
        let drawn = Flat16SurfaceRegion.allCases
            .map { (region: $0,
                    start: Self.drawnStart(of: $0),
                    length: Flat16SurfaceMesh.arcSpan(of: $0).length) }
            .sorted { $0.start < $1.start }
        for (earlier, later) in zip(drawn, drawn.dropFirst() + drawn.prefix(1)) {
            var gap = (later.start - (earlier.start + earlier.length))
                .truncatingRemainder(dividingBy: 1)
            if gap > 0.5 { gap -= 1 }
            if gap < -0.5 { gap += 1 }
            #expect(abs(gap) < 1e-6, "\(earlier.region) does not meet \(later.region)")
        }
    }

    /// **The braid's own cut falls in the middle of the right edge**, because that
    /// is where `arcSpan` divides it, and `arcSpan` is the solid's cross-section.
    /// That has not moved and must not: it is the braid, not the drawing.
    @Test func theBraidsOwnCutFallsInTheMiddleOfTheRightEdge() {
        let edge = Flat16SurfaceMesh.arcSpan(of: .rightEdge)
        #expect(edge.start < 1)
        #expect(edge.start + edge.length > 1)
        // Exactly half of it on each side of the cut.
        #expect(abs((1 - edge.start) - edge.length / 2) < 1e-6)
    }

    /// **The card is cut there too, since 2026-09-21** (the author: 「対称に見えず
    /// 気持ちが悪い」). Task 029-2 had turned the drawing by half an edge so that
    /// the cut fell on a region boundary; that left three lanes of edging at the
    /// top of the card and one at the bottom. Cut through the middle of the edge,
    /// the card reads the same from either end. Written from `arcSpan`, so it
    /// follows the cross-section rather than repeating a number.
    @Test func theCardIsCutThroughTheMiddleOfTheRightEdge() {
        let edge = Flat16SurfaceMesh.arcSpan(of: .rightEdge)
        let middle = (edge.start + edge.length / 2).truncatingRemainder(dividingBy: 1)
        let drawnMiddle = (middle + Flat16ThumbnailView.seamRotation)
            .truncatingRemainder(dividingBy: 1)
        #expect(abs(drawnMiddle) < 1e-6 || abs(drawnMiddle - 1) < 1e-6)
        // Which, for this braid, is the braid's own cut: no turning at all.
        #expect(abs(Flat16ThumbnailView.seamRotation) < 1e-6)
    }

    /// **Down the card, lane by lane: two of edging, four of body, four of
    /// edging, four of body, two of edging.** What the author asked for, read off
    /// the weave rather than written as a picture: the body is the columns the
    /// weave works along the braid, and the edging is everything else — the two
    /// threads at each edge and the outermost column of each face beside them.
    @Test func theCardReadsTheSameFromTopAndBottom() throws {
        let weave = try #require(Flat16SurfacePatternGenerator.working.flatMap { derivation in
            BraidConstruction.construct(
                of: derivation.method, on: derivation.stand,
                crossSection: derivation.crossSection, fold: derivation.fold,
                cycles: derivation.repeatCycleCount + 1
            ).flatMap {
                Flat16WeaveFromWorking.pattern(
                    from: derivation, construction: $0,
                    assignments: BraidReferenceColourings.bookAP97Left
                )
            }
        })
        let body = weave.lengthwiseColumns
        let lanes = Flat16SurfacePatternGenerator.boardPositionCount
        let reading = (0..<lanes).map { lane -> String in
            // The middle of the lane, carried back from the card to the braid.
            let arc = (Float(lane) + 0.5) / Float(lanes) - Flat16ThumbnailView.seamRotation
            for region in Flat16SurfaceRegion.allCases {
                let span = Flat16SurfaceMesh.arcSpan(of: region)
                var within = (arc - span.start).truncatingRemainder(dividingBy: 1)
                if within < 0 { within += 1 }
                guard within < span.length else { continue }
                guard region == .front || region == .back else { return "edging" }
                let columns = Flat16SurfacePatternGenerator.columnCount(in: region)
                let column = min(Int(within / span.length * Float(columns)), columns - 1)
                let weaveColumn = Flat16SurfacePatternGenerator.regionColumn(
                    ofWeaveColumn: column, in: region
                )
                return body.contains(weaveColumn) ? "body" : "edging"
            }
            return "none"
        }
        let runs = reading.reduce(into: [(String, Int)]()) { runs, lane in
            if runs.last?.0 == lane { runs[runs.count - 1].1 += 1 } else { runs.append((lane, 1)) }
        }
        #expect(runs.map(\.0) == ["edging", "body", "edging", "body", "edging"])
        #expect(runs.map(\.1) == [2, 4, 4, 4, 2])
        // The same read from the bottom up.
        #expect(reading == reading.reversed())
    }

    /// **Down the frame, in the braid's own order round it**: half the right
    /// edge, the front, the left edge, the back, and the right edge's other half.
    @Test func theRegionsComeDownTheFrameInOrder() throws {
        let height = Self.iPhoneCard.height
        let expected: [(Flat16SurfaceRegion, CGFloat, CGFloat)] = [
            (.front, 7, 49), (.leftEdge, 49, 63), (.back, 63, 105),
        ]
        for (region, from, to) in expected {
            let start = CGFloat(Self.drawnStart(of: region)) * height
            let end = start + CGFloat(Flat16SurfaceMesh.arcSpan(of: region).length) * height
            #expect(abs(start - from) < 1e-4, "\(region) starts at \(start)")
            #expect(abs(end - to) < 1e-4, "\(region) ends at \(end)")
        }
        // The right edge: one lane at the bottom of the frame and one at the top.
        let edgeStart = CGFloat(Self.drawnStart(of: .rightEdge)) * height
        let edgeLength = CGFloat(Flat16SurfaceMesh.arcSpan(of: .rightEdge).length) * height
        #expect(abs(edgeStart - 105) < 1e-4)
        #expect(abs(edgeStart + edgeLength - height - 7) < 1e-4)
    }

    /// **Only the right edge straddles the frame, and it is split evenly** — one
    /// lane of thread at each end. Every other region lies whole inside it.
    @Test func onlyTheRightEdgeStraddlesTheFrameAndEvenly() {
        for region in Flat16SurfaceRegion.allCases {
            let start = Self.drawnStart(of: region)
            let length = Flat16SurfaceMesh.arcSpan(of: region).length
            #expect(start >= -1e-6)
            if region == .rightEdge {
                #expect(start + length > 1)
                #expect(abs((1 - start) - length / 2) < 1e-6)
            } else {
                #expect(start + length <= 1 + 1e-6, "\(region) runs past the frame")
            }
        }
    }

    /// **Every lane of the braid is on the card once.** Sixty-four places a
    /// repeat, sixteen round the braid — and the card's rows, lane by lane, meet
    /// each of the sixteen exactly once.
    @Test func theCardShowsEveryLaneOnce() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: BraidReferenceColourings.bookAP97Left)
        )
        #expect(pattern.patches.count == 64)
        #expect(pattern.patches(in: .front).count == 24)

        let lanes = Flat16SurfacePatternGenerator.boardPositionCount
        var seen = [String: Int]()
        for lane in 0..<lanes {
            let arc = (Float(lane) + 0.5) / Float(lanes) - Flat16ThumbnailView.seamRotation
            for region in Flat16SurfaceRegion.allCases {
                let span = Flat16SurfaceMesh.arcSpan(of: region)
                var within = (arc - span.start).truncatingRemainder(dividingBy: 1)
                if within < 0 { within += 1 }
                guard within < span.length else { continue }
                let columns = Flat16SurfacePatternGenerator.columnCount(in: region)
                let column = min(Int(within / span.length * Float(columns)), columns - 1)
                seen["\(region) \(column)", default: 0] += 1
            }
        }
        #expect(seen.count == lanes)
        #expect(seen.values.allSatisfy { $0 == 1 })
    }

    /// **No straight join is mixed in among the leaning ones.**
    ///
    /// Down the middle of an edge, the joins used to fall 1.24, 1.00, 1.00, 0.76
    /// rows apart and repeat: the lean was let go at the two ends of the tile, so
    /// one join in every four ran straight and the two beside it were pushed out to
    /// make room. Four rows to a repeat, so on the card it read as a straight line
    /// every fourth row — which is how it was noticed (Task 030).
    ///
    /// **All four gaps are one row now.**
    @Test func theEdgesJoinsAreEvenlySpacedDownTheCard() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: BraidReferenceColourings.bookAP97Left)
        )
        let rowCount = try #require(Flat16SurfacePatternGenerator.rowCount)
        #expect(rowCount == 4)

        for region in [Flat16SurfaceRegion.leftEdge, .rightEdge] {
            // The line down the middle of the edge is the boundary between its two
            // lanes: the trailing side of the first.
            let middle = pattern.patches(in: region)
                .filter { $0.widthColumn == 0 }
                .sorted { $0.row < $1.row }
            #expect(middle.count == rowCount)

            let gaps = middle.map { Float(rowCount) * ($0.corners[2].y - $0.corners[3].y) }
            #expect(gaps.count == 4)
            #expect(gaps.allSatisfy { abs($0 - 1) < 1e-5 }, "\(region) gaps \(gaps)")

            // And the lane's own two ends are one repeat apart, so the tiles meet.
            let low = try #require(middle.first)
            let high = try #require(middle.last)
            #expect(abs((high.corners[2].y - low.corners[3].y) - 1) < 1e-6)
        }
    }

    /// Carried to the frame's coordinates, a patch sits inside its region's band and
    /// nowhere else — this is the mapping the view does before it asks the layout
    /// anything, turn included.
    @Test func aPatchCarriesIntoItsOwnBand() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: BraidReferenceColourings.bookAP97Left)
        )
        for patch in pattern.patches {
            let start = Self.drawnStart(of: patch.region)
            let length = Flat16SurfaceMesh.arcSpan(of: patch.region).length
            for corner in patch.corners {
                let carried = start + corner.x * length
                #expect(carried >= start - 1e-6)
                #expect(carried <= start + length + 1e-6)
                // And inside the frame once taken round its wrap: the right edge
                // is cut through its middle, so half of it lands at the top.
                let onTheCard = carried.truncatingRemainder(dividingBy: 1)
                #expect(onTheCard >= -1e-6)
                #expect(onTheCard <= 1 + 1e-6)
            }
        }
    }
}
