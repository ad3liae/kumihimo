import CoreGraphics
import Foundation
import simd
import Testing
@testable import Kumihimo

struct MaruGenjiThumbnailLayoutTests {
    private static let frames = [
        CGSize(width: 320, height: 96),
        CGSize(width: 180, height: 72),
        CGSize(width: 640, height: 120),
        CGSize(width: 96, height: 96),
    ]

    @Test(arguments: frames)
    func oneRepeatKeepsTheAspectRatioInsteadOfFillingTheFrame(_ size: CGSize) throws {
        let aspectRatio = MaruGenjiSurfacePatternGenerator.patternAspectRatio
        let layout = try #require(MaruGenjiThumbnailLayout(size: size, aspectRatio: aspectRatio))

        // The height carries one full turn around the braid, so one repeat along it
        // is that height times the declared aspect ratio, whatever the frame is.
        #expect(layout.circumference == size.height)
        #expect(abs(layout.repeatLength - size.height * CGFloat(aspectRatio)) < 0.000_1)
    }

    @Test(arguments: frames)
    func theFrameIsCoveredByRepeatsThatOverhangBothEnds(_ size: CGSize) throws {
        let layout = try #require(
            MaruGenjiThumbnailLayout(
                size: size,
                aspectRatio: MaruGenjiSurfacePatternGenerator.patternAspectRatio
            )
        )

        #expect(layout.repeatCount >= 1)
        #expect(layout.repeatCount <= MaruGenjiThumbnailLayout.maximumRepeatCount)
        #expect(layout.originX <= 0)
        #expect(layout.originX + CGFloat(layout.repeatCount) * layout.repeatLength >= size.width)
        // Symmetric overhang, so the crop reads as a length of braid rather than as
        // a pattern pushed against one edge.
        let trailingOverhang = layout.originX
            + CGFloat(layout.repeatCount) * layout.repeatLength - size.width
        #expect(abs(trailingOverhang + layout.originX) < 0.000_1)
    }

    @Test func repeatCountFollowsTheFrameWidth() throws {
        let aspectRatio = MaruGenjiSurfacePatternGenerator.patternAspectRatio
        let narrow = try #require(
            MaruGenjiThumbnailLayout(size: CGSize(width: 120, height: 96), aspectRatio: aspectRatio)
        )
        let wide = try #require(
            MaruGenjiThumbnailLayout(size: CGSize(width: 480, height: 96), aspectRatio: aspectRatio)
        )

        #expect(wide.repeatCount > narrow.repeatCount)
        #expect(wide.repeatLength == narrow.repeatLength)
    }

    @Test func aChevronLeansTheSameWayAndAsFarAsItDoesOnTheMesh() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        let layout = try #require(
            MaruGenjiThumbnailLayout(
                size: CGSize(width: 320, height: 96),
                aspectRatio: pattern.aspectRatio
            )
        )
        let surface = BraidStrandSurfaceBuilder.surface(for: pattern)

        #expect(surface.segments.count == MaruGenjiSurfacePatternGenerator.patchCount)
        for segment in surface.segments {
            let world = MaruGenjiSurfaceMeshGenerator.worldOffset(
                segment.centerlineDelta,
                radius: mesh.baseRadius,
                length: mesh.length,
                repeatCount: mesh.patternRepeatCount
            )
            let drawn = layout.displacement(surfaceOffset: segment.centerlineDelta)

            // Both are measured from the axis, both signed the same way around the
            // braid, so the drawn chevron and the modelled one lean identically.
            let modelled = atan2(world.x, world.y) * 180 / .pi
            let flat = atan2(Float(drawn.dy), Float(drawn.dx)) * 180 / .pi
            #expect(abs(modelled - flat) < 0.1)
            // Half the chevrons run the other way, so compare the acute angle each
            // one makes with the axis.
            let lean = atan(1 / MaruGenjiSurfacePatternGenerator.patternAspectRatio) * 180 / .pi
            #expect(abs(min(abs(modelled), 180 - abs(modelled)) - lean) < 0.1)
        }
    }

    @Test(arguments: [
        CGSize(width: 0, height: 96),
        CGSize(width: 320, height: 0),
        CGSize(width: -320, height: 96),
        CGSize(width: CGFloat.nan, height: 96),
        CGSize(width: 320, height: CGFloat.infinity),
    ])
    func invalidFrameFailsSafely(_ size: CGSize) {
        #expect(MaruGenjiThumbnailLayout(size: size, aspectRatio: 1) == nil)
    }

    @Test func invalidAspectRatioFailsSafely() {
        let size = CGSize(width: 320, height: 96)
        #expect(MaruGenjiThumbnailLayout(size: size, aspectRatio: 0) == nil)
        #expect(MaruGenjiThumbnailLayout(size: size, aspectRatio: -1) == nil)
        #expect(MaruGenjiThumbnailLayout(size: size, aspectRatio: .nan) == nil)
        #expect(MaruGenjiThumbnailLayout(size: size, aspectRatio: .infinity) == nil)
    }

    @Test func anExtremeFrameStaysWithinTheRepeatLimit() throws {
        let layout = try #require(
            MaruGenjiThumbnailLayout(
                size: CGSize(width: 1_000_000, height: 4),
                aspectRatio: 1
            )
        )

        #expect(layout.repeatCount == MaruGenjiThumbnailLayout.maximumRepeatCount)
        #expect(abs(layout.repeatLength - 4) < 0.000_1)
    }

    private var fixtureAssignments: [ThreadAssignment] {
        (1...MaruGenjiSurfacePatternGenerator.requiredThreadCount).map { position in
            ThreadAssignment(
                position: position,
                colorID: ThreadColorID(rawValue: position.isMultiple(of: 2) ? "pink" : "blue")
            )
        }
    }
}
