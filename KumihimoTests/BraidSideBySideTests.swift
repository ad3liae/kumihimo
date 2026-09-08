import CoreGraphics
import Foundation
import Testing
@testable import Kumihimo

/// Task 025-4, step 1: **the new path and the frozen generators, side by side.**
///
/// Both are drawn from the same colouring, at the same braid width, by the same
/// depth-buffer rule — the new path from its thread bodies, the old from its mesh
/// triangles. **Nothing here decides anything.** The judgement is the author's,
/// looking at the pictures, and the numbers below are the ones
/// `docs/measurement-procedures.md` says how to take.
@MainActor
struct BraidSideBySideTests {
    /// **Procedure 2, the silhouette's ripple — and it does not work here.**
    ///
    /// Read off these pictures it returns 0.0 per cent for *both* paths, including
    /// the frozen one that book A p96's calibration was taken on, so it is the
    /// measure that is wrong and not the braids. It is left in place, unused, and
    /// reported as unavailable rather than quietly dropped: procedure 2 reads a
    /// photograph of a braid held up, and a face-on parallel projection is not
    /// that. **No ripple figure is claimed for either path.**
    static func edgeRipple(
        of edge: [Double], pitchInPixels: Double, widthInPixels: Double
    ) -> Double {
        let window = max(2, Int((pitchInPixels * 2).rounded()))
        guard edge.count > window * 2, widthInPixels > 0 else { return 0 }
        var residuals = [Double]()
        for at in (window / 2)..<(edge.count - window / 2) {
            let slice = edge[(at - window / 2)..<(at + window / 2)]
            let mean = slice.reduce(0, +) / Double(slice.count)
            residuals.append(edge[at] - mean)
        }
        let mean = residuals.reduce(0, +) / Double(residuals.count)
        let variance = residuals.map { ($0 - mean) * ($0 - mean) }.reduce(0, +)
            / Double(residuals.count)
        return 100 * variance.squareRoot() / widthInPixels
    }

    /// Writes the numbers out beside the pictures, so the author reads the same
    /// ones this run took.
    static func record(_ text: String, named name: String) throws {
        let url = BraidFigureDrawing.directory.appendingPathComponent("\(name).txt")
        try FileManager.default.createDirectory(at: BraidFigureDrawing.directory,
                                                withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func leftEdge(_ seen: [[Bool]]) -> [Double] {
        seen.compactMap { row in
            row.firstIndex(of: true).map(Double.init)
        }
    }

    // MARK: the flat braid

    @Test func theFlatBraidIsDrawnBothWaysAndMeasured() throws {
        let assignments = BraidMethodCatalog.hiraGenji16Colouring

        // The new path.
        let built = try #require(BraidFromRecipe.build(
            BraidMethodCatalog.hiraGenji16Recipe, on: BraidMethodCatalog.stand16
        ))
        for view in built.pictures(slotCount: 16) {
            try BraidFigureDrawing.write(view.image, named: "compare-hira-new-\(view.name)")
        }
        let newPicture = BraidPicture.paint(built.lines, looking: SIMD3(0, -1, 0))
        let newSeen = (0..<newPicture.height).map { row in
            (0..<newPicture.width).map { newPicture.thread(atPixel: $0, row: row) != nil }
        }
        let newSection = try #require(BraidSectionMeasure.measure(built.lines, tube: false))
        _ = newSeen

        // The frozen generator.
        let pattern = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: assignments))
        let mesh = try #require(HiraGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        let old = try #require(BraidMeshDrawing.paint(
            BraidMeshDrawing.Mesh(positions: mesh.positions, byColour: mesh.colorGroups),
            looking: SIMD3(0, -1, 0)
        ))
        let oldImage = try #require(BraidMeshDrawing.image(of: old))
        try BraidFigureDrawing.write(oldImage, named: "compare-hira-old-front")
        // Recorded, not judged.
        let report = "section width over thickness: measured on the new path "
            + "\(newSection.widthOverThickness); the frozen generator declares "
            + "\(HiraGenjiSurfaceMeshGenerator.widthToThicknessRatio) and is built to it. "
            + "Book A's measured figure is 3.3359. "
            + "Silhouette ripple (procedure 2): unavailable -- the measure returns 0.0% "
            + "for both paths, including the one it was calibrated on, so it is the "
            + "measure that is wrong here and no figure is claimed."
        try Self.record(report, named: "compare-hira")
        #expect(newSection.widthOverThickness > 0)
    }

    // MARK: the tube

    @Test func theRoundBraidIsDrawnBothWaysAndMeasured() throws {
        let assignments = BraidMethodCatalog.maruGenji16Colouring
        let built = try #require(BraidFromRecipe.build(
            BraidMethodCatalog.maruGenji16Recipe, on: BraidMethodCatalog.stand16
        ))
        for view in built.pictures(slotCount: 16) where view.name == "slot 0" {
            try BraidFigureDrawing.write(view.image, named: "compare-maru-new-slot-0")
        }
        let newSection = try #require(BraidSectionMeasure.measure(built.lines, tube: true))

        let pattern = try #require(MaruGenjiSurfacePatternGenerator.generate(assignments: assignments))
        let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        let old = try #require(BraidMeshDrawing.paint(
            BraidMeshDrawing.Mesh(positions: mesh.positions, byColour: mesh.colorGroups),
            looking: SIMD3(0, -1, 0)
        ))
        let oldImage = try #require(BraidMeshDrawing.image(of: old))
        try BraidFigureDrawing.write(oldImage, named: "compare-maru-old")

        let report = "outer diameter: measured on the new path "
            + "\(newSection.outerDiameter ?? 0) d; the frozen generator declares a radius "
            + "of \(MaruGenjiSurfaceMeshGenerator.defaultRadius), which is not in thread "
            + "diameters, so the two cannot be compared as they stand."
        try Self.record(report, named: "compare-maru")
        #expect((newSection.outerDiameter ?? 0) > 0)
    }
}
