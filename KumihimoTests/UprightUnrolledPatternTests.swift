import CoreGraphics
import Foundation
import Testing
import simd
@testable import Kumihimo

/// **The braid stood upright**, which is how the list's card shows it.
///
/// The layout used to assume a frame wider than it is tall, with the turn around
/// the braid down the height. The card's left third is taller than it is wide, so
/// the two directions swap. What must not swap is the drawing: **a rotation is not
/// a rescale**, so one repeat has to stay `aspectRatio` times the braid's width
/// whichever way round it sits, and a chevron has to keep its angle.
@Suite struct UprightUnrolledPatternTests {
    /// The card's left third on an iPhone: taller than it is wide, which is the
    /// case the old layout could not draw.
    static let frame = CGSize(width: 110, height: 112)

    static var tubeRatio: Float { RoundTube16SurfacePatternGenerator.patternAspectRatio }
    static func flatRatio() throws -> Float {
        try #require(Flat16SurfacePatternGenerator.patternAspectRatio)
    }

    @Test("One repeat is the braid's width times the aspect ratio, upright too",
          arguments: [
              CGSize(width: 110, height: 112),
              CGSize(width: 240, height: 96),
              CGSize(width: 60, height: 400),
          ])
    func oneRepeatKeepsItsProportion(frame: CGSize) throws {
        for ratio in [Self.tubeRatio, try Self.flatRatio()] {
            let upright = try #require(UnrolledPatternThumbnailLayout(
                size: frame, aspectRatio: ratio, orientation: .alongTheHeight
            ))
            // Across the braid is the frame's width now, not its height.
            #expect(upright.circumference == frame.width)
            #expect(abs(Float(upright.repeatLength / upright.circumference) - ratio) < 1e-5)
        }
    }

    /// Turning the frame on its side and the braid with it gives the same layout,
    /// read the other way round. This is what "the arithmetic is written once"
    /// means, checked rather than asserted in a comment.
    @Test func uprightIsTheSameLayoutTurnedSideways() throws {
        let lying = try #require(UnrolledPatternThumbnailLayout(
            size: CGSize(width: Self.frame.height, height: Self.frame.width),
            aspectRatio: Self.tubeRatio,
            orientation: .alongTheWidth
        ))
        let upright = try #require(UnrolledPatternThumbnailLayout(
            size: Self.frame,
            aspectRatio: Self.tubeRatio,
            orientation: .alongTheHeight
        ))
        #expect(upright.circumference == lying.circumference)
        #expect(upright.repeatLength == lying.repeatLength)
        #expect(upright.repeatCount == lying.repeatCount)
        #expect(upright.originAlongTheBraid == lying.originAlongTheBraid)

        // The same surface coordinate lands at swapped frame coordinates.
        let coordinate = SIMD2<Float>(0.3, 0.7)
        let onItsSide = lying.point(surfaceCoordinate: coordinate, repeatIndex: 2)
        let standing = upright.point(surfaceCoordinate: coordinate, repeatIndex: 2)
        #expect(abs(standing.x - onItsSide.y) < 1e-9)
        #expect(abs(standing.y - onItsSide.x) < 1e-9)

        let offset = SIMD2<Float>(0.1, -0.25)
        let lyingStep = lying.displacement(surfaceOffset: offset)
        let uprightStep = upright.displacement(surfaceOffset: offset)
        #expect(abs(uprightStep.dx - lyingStep.dy) < 1e-9)
        #expect(abs(uprightStep.dy - lyingStep.dx) < 1e-9)
    }

    /// Enough repeats to overhang both ends, down the height this time.
    @Test func theRepeatsFillTheHeightAndOverhangBothEnds() throws {
        let layout = try #require(UnrolledPatternThumbnailLayout(
            size: Self.frame, aspectRatio: Self.tubeRatio, orientation: .alongTheHeight
        ))
        let needed = (Self.frame.height / layout.repeatLength).rounded(.up)
        #expect(layout.repeatCount == Int(needed) + 1)
        #expect(layout.originAlongTheBraid <= 0)
        #expect(
            layout.originAlongTheBraid + CGFloat(layout.repeatCount) * layout.repeatLength
                >= Self.frame.height
        )

        // Row 0 of one repeat sits where the last row of the one before it ends.
        for index in 1..<layout.repeatCount {
            let start = layout.point(surfaceCoordinate: SIMD2(0.5, 0), repeatIndex: index)
            let end = layout.point(surfaceCoordinate: SIMD2(0.5, 1), repeatIndex: index - 1)
            #expect(abs(start.y - end.y) < 1e-9)
            #expect(abs(start.x - end.x) < 1e-9)
        }
    }

    /// **The card draws the drawer's own patches**, not a second drawing made for
    /// the card. The counts are the generators' own.
    ///
    /// The flat braid has **64 patches over its whole cross-section** — six lanes
    /// across each of two faces and two at each edge, four steps along one repeat
    /// — of which the card draws the **24 on the front**. The tube has 64 and the
    /// card draws all of them, because a tube's whole surface is one face unrolled.
    @Test func theCardDrawsTheDrawersOwnPatches() throws {
        let flat = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: BraidReferenceColourings.bookAP97Left)
        )
        #expect(flat.patches.count == Flat16SurfacePatternGenerator.patchCount)
        #expect(flat.patches.count == 64)
        #expect(flat.patches(in: .front).count == 24)
        #expect(flat.rowCount == 4)
        // Six lanes across the face, four steps along the repeat.
        #expect(flat.patches(in: .front).count == 6 * flat.rowCount)
        // The whole cross-section, once, and nothing counted twice.
        #expect(
            Flat16SurfaceRegion.allCases
                .map { flat.patches(in: $0).count }
                .reduce(0, +) == flat.patches.count
        )

        let tube = try #require(
            RoundTube16SurfacePatternGenerator.generate(
                assignments: BraidReferenceColourings.bookAP94MaruGenji
            )
        )
        #expect(tube.patches.count == RoundTube16SurfacePatternGenerator.patchCount)
        #expect(tube.patches.count == 64)
    }

    /// **All eight columns come out**, so the card opens the whole tube and not
    /// one face of it. The drawing is an eight-by-eight grid of cells; a patch's
    /// column is which eighth of the way round the braid its middle sits in.
    @Test func allEightColumnsOfTheTubeAreDrawn() throws {
        let tube = try #require(
            RoundTube16SurfacePatternGenerator.generate(
                assignments: BraidReferenceColourings.bookAP94MaruGenji
            )
        )
        var columns = Set<Int>()
        for patch in tube.patches {
            let middle = patch.corners.map(\.x).reduce(0, +) / Float(patch.corners.count)
            let column = Int((middle * 8).rounded(.down))
            columns.insert(min(max(column, 0), 7))
        }
        #expect(columns.count == 8)
        #expect(columns == Set(0...7))

        // The columns fill the frame's width, edge to edge, when stood upright.
        let layout = try #require(UnrolledPatternThumbnailLayout(
            size: Self.frame, aspectRatio: Self.tubeRatio, orientation: .alongTheHeight
        ))
        let across = tube.patches.flatMap { $0.corners.map(\.x) }
        let lowest = try #require(across.min())
        let highest = try #require(across.max())
        #expect(abs(layout.point(surfaceCoordinate: SIMD2(lowest, 0), repeatIndex: 0).x) < 1e-6)
        #expect(
            abs(layout.point(surfaceCoordinate: SIMD2(highest, 0), repeatIndex: 0).x
                - Self.frame.width) < 1e-6
        )
    }
}
