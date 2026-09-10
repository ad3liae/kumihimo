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
        get throws { try #require(Flat16SurfacePatternGenerator.patternAspectRatioRoundTheBraid) }
    }

    private static var acrossTheWidth: Float {
        get throws { try #require(Flat16SurfacePatternGenerator.patternAspectRatio) }
    }

    // MARK: - 1. The ratio handed to the layout

    /// **Over the turn, not over the width.** The two counts are the working-out's
    /// own — six columns to a broad face, sixteen places round the braid — so the
    /// ratio is not a number chosen for the card.
    @Test func theRatioIsTheWidthsOneScaledByTheCountsRoundTheBraid() throws {
        let face = Flat16SurfacePatternGenerator.broadFaceColumnCount
        let round = Flat16SurfacePatternGenerator.boardPositionCount
        #expect(face == 6)
        #expect(round == 16)

        let ratio = try Self.roundTheBraid
        let width = try Self.acrossTheWidth
        #expect(abs(ratio - width * Float(face) / Float(round)) < 1e-6)
        #expect(abs(ratio - 0.54975) < 1e-4)

        // The width's own ratio is untouched: the mesh takes its length from it.
        #expect(abs(width - 1.466) < 1e-3)
    }

    /// The same quantity the round braid declares, which is why the two families'
    /// thumbnails come out at the same density rather than one being three times
    /// coarser than the other.
    @Test func itIsTheSameQuantityTheRoundBraidDeclares() throws {
        let flat = try Self.roundTheBraid
        let width = try Self.acrossTheWidth
        let tube = RoundTube16SurfacePatternGenerator.patternAspectRatio
        #expect(abs(tube - 0.65) < 1e-6)
        // Within a fifth of each other, where the width's ratio was 2.3 times the
        // tube's.
        #expect(abs(flat - tube) / tube < 0.2)
        #expect(abs(width - tube) / tube > 1.0)
    }

    // MARK: - 2. What the card comes out at

    @Test(arguments: [
        (CGSize(width: 361, height: 112), 7),
        (CGSize(width: 754, height: 112), 14),
    ])
    func theCardHoldsSevenRepeatsAndFourteen(_ size: CGSize, _ repeats: Int) throws {
        let ratio = try Self.roundTheBraid
        let layout = try #require(
            UnrolledPatternThumbnailLayout(size: size, aspectRatio: ratio)
        )
        #expect(layout.circumference == size.height)
        #expect(abs(layout.repeatLength - 61.572) < 1e-3)
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

        for region in Flat16SurfaceRegion.allCases {
            let span = Flat16SurfaceMesh.arcSpan(of: region)
            let columns = Flat16SurfacePatternGenerator.columnCount(in: region)
            let lane = CGFloat(span.length / Float(columns)) * layout.circumference
            #expect(abs(lane - expected) < 1e-4, "\(region) lane \(lane)")
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

        let width = try Self.acrossTheWidth
        let ratio = try Self.roundTheBraid
        let before = width
            * Float(Flat16SurfacePatternGenerator.broadFaceColumnCount) / Float(rows)
        let after = ratio
            * Float(Flat16SurfacePatternGenerator.boardPositionCount) / Float(rows)
        #expect(abs(before - after) < 1e-6)
        #expect(abs(after - 2.199) < 1e-3)

        // The same thing measured off the card: one step long over one lane high.
        let layout = try #require(
            UnrolledPatternThumbnailLayout(size: Self.iPhoneCard, aspectRatio: ratio)
        )
        let step = layout.repeatLength / CGFloat(rows)
        let lane = layout.circumference / 16
        #expect(abs(step - 15.393) < 1e-3)
        #expect(abs(lane - 7.0) < 1e-9)
        #expect(abs(Float(step / lane) - 2.199) < 1e-3)
    }

    // MARK: - 5. The four regions cover the turn exactly

    @Test func theRegionsCoverTheTurnWithNoGapAndNoOverlap() throws {
        let spans = Flat16SurfaceRegion.allCases.map {
            (region: $0, span: Flat16SurfaceMesh.arcSpan(of: $0))
        }
        // The table Task 029 wrote down, read back off `arcSpan`.
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

        // Laid end to end round the turn, each region begins where the last ended.
        let ordered = spans
            .map { ($0.region, $0.span.start < 0.5 && $0.span.start + $0.span.length > 1
                ? $0.span.start - 1 : $0.span.start, $0.span.length) }
            .map { (region: $0.0, start: $0.1 > 0.9 ? $0.1 - 1 : $0.1, length: $0.2) }
            .sorted { $0.start < $1.start }
        for (earlier, later) in zip(ordered, ordered.dropFirst()) {
            #expect(abs(earlier.start + earlier.length - later.start) < 1e-6,
                    "\(earlier.region) does not meet \(later.region)")
        }
    }

    /// **The seam falls in the middle of the right edge**, because that is where
    /// `arcSpan` cuts. Recorded rather than changed: whether to turn the drawing by
    /// a sixteenth so the four regions read in order is the author's to decide.
    @Test func theSeamFallsInTheMiddleOfTheRightEdge() {
        let edge = Flat16SurfaceMesh.arcSpan(of: .rightEdge)
        #expect(edge.start < 1)
        #expect(edge.start + edge.length > 1)
        // Exactly half of it on each side of the seam.
        #expect(abs((1 - edge.start) - edge.length / 2) < 1e-6)
    }

    // MARK: - 6. The straddling region is drawn on both sides of the seam

    /// The right edge is drawn at `x'` and at `x' - 1`, and the frame crops each.
    /// What must add up is the area: the two halves together are one edge lane's
    /// worth, no more — drawing it twice must not double it.
    @Test func theRightEdgeAppearsAtBothEndsAndAddsUpToOne() throws {
        let ratio = try Self.roundTheBraid
        let layout = try #require(
            UnrolledPatternThumbnailLayout(size: Self.iPhoneCard, aspectRatio: ratio)
        )
        let span = Flat16SurfaceMesh.arcSpan(of: .rightEdge)
        #expect(span.start + span.length > 1)

        // Where each copy lands down the frame, in points.
        let low = (start: CGFloat(span.start - 1) * layout.circumference,
                   end: CGFloat(span.start - 1 + span.length) * layout.circumference)
        let high = (start: CGFloat(span.start) * layout.circumference,
                    end: CGFloat(span.start + span.length) * layout.circumference)

        // One copy runs off the top, the other off the bottom.
        #expect(low.start < 0)
        #expect(low.end > 0)
        #expect(high.start < layout.circumference)
        #expect(high.end > layout.circumference)

        let visible = { (band: (start: CGFloat, end: CGFloat)) -> CGFloat in
            max(0, min(band.end, layout.circumference) - max(band.start, 0))
        }
        let together = visible(low) + visible(high)
        let whole = CGFloat(span.length) * layout.circumference
        #expect(abs(together - whole) < 1e-9)
        // Two lanes of thread, which is what an edge is.
        #expect(abs(together - 2 * layout.circumference / 16) < 1e-9)
    }

    /// The whole surface is drawn, not one face of it: every region's patches, and
    /// the straddling one twice.
    @Test func theCardDrawsEveryRegionAndTheSeamTwice() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: BraidReferenceColourings.bookAP97Left)
        )
        #expect(pattern.patches.count == 64)
        #expect(pattern.patches(in: .front).count == 24)

        let drawn = pattern.patches.reduce(0) { total, patch in
            let span = Flat16SurfaceMesh.arcSpan(of: patch.region)
            return total + (span.start + span.length > 1 ? 2 : 1)
        }
        // Sixty-four, with the right edge's eight drawn a second time.
        #expect(drawn == 72)
        #expect(drawn == 64 + pattern.patches(in: .rightEdge).count)

        // What a whole card holds, at seven repeats and at fourteen.
        #expect(drawn * 7 == 504)
        #expect(drawn * 14 == 1008)
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

    /// Carried to the turn's coordinates, a patch sits inside its region's span and
    /// nowhere else — this is the mapping the view does before it asks the layout
    /// anything.
    @Test func aPatchCarriesIntoItsOwnSpan() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: BraidReferenceColourings.bookAP97Left)
        )
        for patch in pattern.patches {
            let span = Flat16SurfaceMesh.arcSpan(of: patch.region)
            for corner in patch.corners {
                let carried = span.start + corner.x * span.length
                #expect(carried >= span.start - 1e-6)
                #expect(carried <= span.start + span.length + 1e-6)
            }
        }
    }
}
