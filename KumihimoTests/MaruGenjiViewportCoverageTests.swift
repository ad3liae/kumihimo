import Foundation
import simd
import Testing
@testable import Kumihimo

@MainActor
struct MaruGenjiViewportCoverageTests {
    @Test(arguments: [
        SIMD2<Float>(393, 420),
        SIMD2<Float>(744, 700),
        SIMD2<Float>(834, 720),
        SIMD2<Float>(1_194, 700),
    ])
    func representativeViewportIsCoveredAtMinimumScale(_ viewport: SIMD2<Float>) throws {
        let coverage = try #require(calculate(viewport: viewport))

        #expect(coverage.tileCount > 0)
        #expect(!coverage.tileCount.isMultiple(of: 2))
        #expect(coverage.tileCount <= MaruGenjiViewportCoverageCalculator.maximumTileCount)
        #expect(coverage.coveredLength >= coverage.requiredLength)
    }

    @Test func widerViewportUsesAtLeastAsManyTilesWithoutChangingTileGeometry() throws {
        let narrow = try #require(calculate(viewport: SIMD2<Float>(393, 420)))
        let wide = try #require(calculate(viewport: SIMD2<Float>(1_194, 700)))

        #expect(wide.tileCount >= narrow.tileCount)
        #expect(wide.coveredLength == Float(wide.tileCount) * MaruGenjiSurfaceMeshGenerator.defaultLength)
    }

    @Test(arguments: [
        SIMD2<Float>(393, 420),
        SIMD2<Float>(744, 700),
        SIMD2<Float>(834, 720),
        SIMD2<Float>(1_194, 700),
    ])
    func theDerivedTileLengthLeavesHeadroomUnderTheSafetyLimit(
        _ viewport: SIMD2<Float>
    ) throws {
        let coverage = try #require(calculate(viewport: viewport))

        // One tile is four repeats, each nearly a turn of braid long, so the tiling
        // has to sit far below the limit instead of pressing against it.
        #expect(coverage.tileCount <= MaruGenjiViewportCoverageCalculator.maximumTileCount / 3)
        #expect(coverage.coveredLength >= coverage.requiredLength)
    }

    @Test(arguments: [
        SIMD2<Float>(393, 420),
        SIMD2<Float>(1_194, 700),
    ])
    func defaultZoomShowsAFewRepeatsRatherThanAFineThread(_ viewport: SIMD2<Float>) {
        let visibleHeight = 2 * MaruGenjiRealityView.cameraDistance
            * tan(MaruGenjiRealityView.verticalFieldOfView / 2)
        let visibleWidth = visibleHeight * viewport.x / viewport.y
        let repeatLength = MaruGenjiSurfaceMeshGenerator.defaultLength
            / Float(MaruGenjiSurfaceMeshGenerator.defaultPatternRepeatCount)

        // A repeat is a little under one turn of braid, so a few of them fit across
        // the screen at rest. Anything near the pre-Task-005F eight would mean the
        // wrap had been squashed again.
        #expect((1.5...4.5).contains(visibleWidth / repeatLength))
    }

    @Test(arguments: [
        SIMD2<Float>(0, 420),
        SIMD2<Float>(-1, 420),
        SIMD2<Float>(.nan, 420),
        SIMD2<Float>(393, .infinity),
    ])
    func invalidViewportFailsSafely(_ viewport: SIMD2<Float>) {
        #expect(calculate(viewport: viewport) == nil)
    }

    @Test func invalidProjectionInputsFailSafely() {
        let viewport = SIMD2<Float>(393, 420)
        #expect(calculate(viewport: viewport, cameraDistance: 0) == nil)
        #expect(calculate(viewport: viewport, verticalFieldOfView: -.pi / 3) == nil)
        #expect(calculate(viewport: viewport, verticalFieldOfView: .nan) == nil)
        #expect(calculate(viewport: viewport, minimumScale: 0) == nil)
        #expect(calculate(viewport: viewport, tileLength: .infinity) == nil)
    }

    @Test func extremeViewportStopsAtTheSafetyLimit() throws {
        let coverage = try #require(calculate(viewport: SIMD2<Float>(1_000_000, 1)))

        #expect(coverage.tileCount == MaruGenjiViewportCoverageCalculator.maximumTileCount)
        #expect(!coverage.tileCount.isMultiple(of: 2))
    }

    @Test func tileOffsetsAreCenteredAndJoinWithoutGapOrOverlap() throws {
        let tileLength = MaruGenjiSurfaceMeshGenerator.defaultLength
        let offsets = try #require(
            MaruGenjiViewportCoverageCalculator.tileOffsets(
                tileCount: 5,
                tileLength: tileLength
            )
        )

        #expect(offsets == [-2 * tileLength, -tileLength, 0, tileLength, 2 * tileLength])
        for pair in zip(offsets, offsets.dropFirst()) {
            #expect(pair.1 - pair.0 == tileLength)
        }
    }

    @Test func invalidTileLayoutFailsSafely() {
        #expect(MaruGenjiViewportCoverageCalculator.tileOffsets(tileCount: 0, tileLength: 1) == nil)
        #expect(MaruGenjiViewportCoverageCalculator.tileOffsets(tileCount: 2, tileLength: 1) == nil)
        #expect(MaruGenjiViewportCoverageCalculator.tileOffsets(
            tileCount: MaruGenjiViewportCoverageCalculator.maximumTileCount + 2,
            tileLength: 1
        ) == nil)
        #expect(MaruGenjiViewportCoverageCalculator.tileOffsets(tileCount: 1, tileLength: .nan) == nil)
    }

    private func calculate(
        viewport: SIMD2<Float>,
        cameraDistance: Float = MaruGenjiRealityView.cameraDistance,
        verticalFieldOfView: Float = MaruGenjiRealityView.verticalFieldOfView,
        minimumScale: Float = MaruGenjiViewerController.minimumScale,
        tileLength: Float = MaruGenjiSurfaceMeshGenerator.defaultLength
    ) -> MaruGenjiViewportCoverage? {
        MaruGenjiViewportCoverageCalculator.calculate(
            viewportSize: viewport,
            cameraDistance: cameraDistance,
            verticalFieldOfView: verticalFieldOfView,
            minimumScale: minimumScale,
            tileLength: tileLength
        )
    }
}
