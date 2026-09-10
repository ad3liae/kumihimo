import CoreGraphics
import Foundation
import simd
import Testing
@testable import Kumihimo

/// The same layout, asked the same questions with the flat braid's aspect ratio.
///
/// **The flat thumbnail used not to go through a layout at all**: it divided the
/// frame's width by sixteen repeats and never read the pattern's aspect ratio, so a
/// repeat came out a fraction of its length and the braid read as running the wrong
/// way. These are the tube's own layout tests with the other ratio in them.
struct FlatUnrolledPatternThumbnailLayoutTests {
    private static let frames = [
        CGSize(width: 320, height: 96),
        CGSize(width: 180, height: 72),
        CGSize(width: 640, height: 120),
        CGSize(width: 96, height: 96),
        // The card the list actually draws, on both sizes of screen.
        CGSize(width: 361, height: 112),
        CGSize(width: 754, height: 112),
    ]

    private static var aspectRatio: Float {
        get throws { try #require(Flat16SurfacePatternGenerator.patternAspectRatio) }
    }

    /// Written beside the pictures, so the numbers in the report are the run's own.
    private static func record(_ text: String, named name: String) throws {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/task025-figures")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try text.write(to: directory.appendingPathComponent("\(name).txt"),
                       atomically: true, encoding: .utf8)
    }

    /// **Four steps at book A's measured pitch**: 4 x 0.3665 = 1.466 of the braid's
    /// own width. Not a number chosen for the card.
    @Test func theAspectRatioIsTheMeasuredOne() throws {
        let ratio = try Self.aspectRatio
        #expect(abs(ratio - 4 * Flat16SurfacePatternGenerator.stitchPitchPerBraidWidth) < 1e-6)
        #expect(abs(ratio - 1.466) < 1e-3)
    }

    @Test(arguments: frames)
    func oneRepeatKeepsTheAspectRatioInsteadOfFillingTheFrame(_ size: CGSize) throws {
        let ratio = try Self.aspectRatio
        let layout = try #require(UnrolledPatternThumbnailLayout(size: size, aspectRatio: ratio))
        #expect(layout.circumference == size.height)
        #expect(abs(layout.repeatLength - size.height * CGFloat(ratio)) < 1e-5)
        // The claim in the shape the instruction asks for.
        #expect(abs(Float(layout.repeatLength / layout.circumference) - ratio) < 1e-5)
    }

    @Test(arguments: frames)
    func theFrameIsCoveredByRepeatsThatOverhangBothEnds(_ size: CGSize) throws {
        let layout = try #require(
            UnrolledPatternThumbnailLayout(size: size, aspectRatio: try Self.aspectRatio)
        )
        #expect(layout.repeatCount >= 1)
        #expect(layout.repeatCount <= UnrolledPatternThumbnailLayout.maximumRepeatCount)
        #expect(layout.originX <= 0)
        #expect(layout.originX + CGFloat(layout.repeatCount) * layout.repeatLength >= size.width)
        let trailingOverhang = layout.originX
            + CGFloat(layout.repeatCount) * layout.repeatLength - size.width
        #expect(abs(trailingOverhang + layout.originX) < 1e-4)
        // **One repeat spare**: the covering count, and one more.
        let needed = Int((size.width / layout.repeatLength).rounded(.up))
        #expect(layout.repeatCount == min(needed + 1,
                                          UnrolledPatternThumbnailLayout.maximumRepeatCount))
    }

    /// **A point on a repeat's boundary lands in the same place from either side.**
    /// The last row of one repeat and the first row of the next have to meet, or
    /// the braid shows a seam once a repeat.
    @Test(arguments: frames)
    func theRepeatsMeetAtTheirBoundaries(_ size: CGSize) throws {
        let layout = try #require(
            UnrolledPatternThumbnailLayout(size: size, aspectRatio: try Self.aspectRatio)
        )
        for repeatIndex in 0..<(layout.repeatCount - 1) {
            for across in [Float(0), 0.5, 1] {
                let end = layout.point(surfaceCoordinate: SIMD2(across, 1),
                                       repeatIndex: repeatIndex)
                let start = layout.point(surfaceCoordinate: SIMD2(across, 0),
                                         repeatIndex: repeatIndex + 1)
                #expect(abs(end.x - start.x) < 1e-9, "repeat \(repeatIndex)")
                #expect(abs(end.y - start.y) < 1e-9, "repeat \(repeatIndex)")
            }
        }
    }

    @Test func repeatCountFollowsTheFrameWidth() throws {
        let ratio = try Self.aspectRatio
        let narrow = try #require(
            UnrolledPatternThumbnailLayout(size: CGSize(width: 120, height: 96),
                                           aspectRatio: ratio)
        )
        let wide = try #require(
            UnrolledPatternThumbnailLayout(size: CGSize(width: 480, height: 96),
                                           aspectRatio: ratio)
        )
        #expect(wide.repeatCount > narrow.repeatCount)
        #expect(wide.repeatLength == narrow.repeatLength)
    }

    @Test func anExtremeFrameStaysWithinTheRepeatLimit() throws {
        let layout = try #require(
            UnrolledPatternThumbnailLayout(size: CGSize(width: 100_000, height: 8),
                                           aspectRatio: try Self.aspectRatio)
        )
        #expect(layout.repeatCount == UnrolledPatternThumbnailLayout.maximumRepeatCount)
    }

    /// **What the card would have shown before, and what it shows now**, at the two
    /// widths the list uses. Recorded as numbers, not as a verdict.
    @Test func whatARepeatMeasuresOnTheCard() throws {
        let ratio = try Self.aspectRatio
        var lines = ["frame: repeat before (width/16), repeat now, height x ratio"]
        for size in [CGSize(width: 361, height: 112), CGSize(width: 754, height: 112)] {
            let layout = try #require(
                UnrolledPatternThumbnailLayout(size: size, aspectRatio: ratio)
            )
            lines.append(String(
                format: "%.0fx%.0f: %.1f pt, %.1f pt, %.1f pt (repeats %d)",
                size.width, size.height, size.width / 16, layout.repeatLength,
                size.height * CGFloat(ratio), layout.repeatCount
            ))
            #expect(abs(layout.repeatLength - size.height * CGFloat(ratio)) < 1e-5)
        }
        try Self.record(lines.joined(separator: "\n"), named: "flat-thumbnail-repeat")
    }
}

/// **The pattern itself must not have moved.** Only where the thumbnail puts it.
@MainActor
struct FlatPatternUnchangedByTheThumbnailTests {
    /// Every patch, its colour and its corners, hashed. Taken on the commit before
    /// the thumbnail was changed; the generator was not touched, and this says so
    /// for the next change too.
    ///
    /// **It has been touched once since, on purpose** (Task 030): the value was
    /// `0xa805_6cdc_c7b8_8a21` while an edge's stitch lean was dropped at the two
    /// ends of the repeat. The corners at rows 0 and 4 of both edges moved by
    /// `edgeStitchLean`; nothing else did, and no patch was added, removed or
    /// recoloured. Task 029's own changes did not move it — this test is what said
    /// so.
    @Test func theFlatPatternIsTheOneItWas() throws {
        let pattern = try #require(Flat16SurfacePatternGenerator.generate(
            assignments: BraidMethodCatalog.hiraGenji16Colouring))
        #expect(pattern.patches.count == Flat16SurfacePatternGenerator.patchCount)
        #expect(pattern.patches.count == 64)
        #expect(abs(pattern.aspectRatio - 1.466) < 1e-3)

        var points = [SIMD3<Float>]()
        func order(_ region: Flat16SurfaceRegion) -> Int {
            Flat16SurfaceRegion.allCases.firstIndex(of: region) ?? -1
        }
        for patch in pattern.patches.sorted(by: {
            (order($0.region), $0.row, $0.widthColumn)
                < (order($1.region), $1.row, $1.widthColumn)
        }) {
            // The colour goes into the hash as the sum of its characters, so a
            // recoloured patch shows as well as a moved one.
            let colour = Float(patch.colorID.rawValue.unicodeScalars
                .reduce(0) { $0 + Int($1.value) })
            for corner in patch.corners {
                points.append(SIMD3(corner.x, corner.y, colour))
            }
        }
        #expect(points.count == 256)
        let hash = BraidMeshHashTests.hash(points)
        try Self.record("flat pattern hash \(String(hash, radix: 16))",
                        named: "flat-pattern-hash")
        #expect(hash == 0x4d72_b9e3_6b75_b461)
    }

    private static func record(_ text: String, named name: String) throws {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/task025-figures")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try text.write(to: directory.appendingPathComponent("\(name).txt"),
                       atomically: true, encoding: .utf8)
    }
}
