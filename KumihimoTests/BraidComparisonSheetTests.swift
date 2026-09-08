import CoreGraphics
import Foundation
import Testing
@testable import Kumihimo

/// Task 025-4 step 2, made again to the author's conditions: **the same colouring,
/// the same length, the same scale, the same camera, one sheet a braid.**
///
/// No numbers on the sheets. The judgement is the author's.
///
/// **These draw pictures; they decide nothing, and they are slow** — four
/// supersampled panels a sheet, over half a million triangles. They are off unless
/// `DRAW_SHEETS` is set in the environment, so the default run stays inside
/// `AGENTS.md`'s sixty-second allowance instead of the allowance being raised for
/// them. To make the sheets:
///
///     DRAW_SHEETS=1 xcodebuild test ... \
///       -only-testing:KumihimoTests/BraidComparisonSheetTests \
///       -default-test-execution-time-allowance 600
@MainActor
struct BraidComparisonSheetTests {

    static let pixelsPerDiameter = 32
    /// Six cycles of braid, which for both braids is one and a half repeats of the
    /// pattern -- a repeat is four cycles either way.
    static let cyclesShown = 6
    static let repeatCycles = 4

    private func colouring(_ named: [String: [String]]) -> [ThreadAssignment] {
        BraidMethodCatalog.colouring(on: BraidMethodCatalog.stand16, named)
    }

    private func legend(_ assignments: [ThreadAssignment])
        -> [(thread: Int, colour: ThreadColorValue, name: String)] {
        assignments.sorted { $0.position < $1.position }.map { assignment in
            let colour = ThreadColorCatalog.colors.first { $0.id == assignment.colorID }
                ?? ThreadColorCatalog.defaultColor
            return (assignment.position, colour.value, assignment.colorID.rawValue)
        }
    }

    /// Draws one braid both ways and lays the sheet out.
    private func build(
        recipe: BraidRecipe,
        assignments: [ThreadAssignment],
        oldSolid: (perDiameter: Double, triangles: BraidComparisonSheet.Solid),
        braidWidth: Double,
        photograph: String,
        photographLabel: String,
        title: String,
        named: String
    ) throws {
        let coloured = BraidRecipe(
            id: recipe.id, name: recipe.name, notation: recipe.notation,
            colouring: assignments, shape: recipe.shape,
            orderRoundTheBraid: recipe.orderRoundTheBraid
        )
        let built = try #require(BraidFromRecipe.build(
            coloured, on: BraidMethodCatalog.stand16, cycles: Self.cyclesShown + 2
        ))
        var colourOf = [Int: ThreadColorID]()
        for assignment in assignments { colourOf[assignment.position] = assignment.colorID }
        let newTriangles = BraidComparisonSheet.solid(of: built.lines, colouring: colourOf)

        // The middle six cycles of each, so neither shows its own ends.
        let shown = Double(Self.cyclesShown * built.lines.construction.layersPerCycle)
        func middle(_ span: ClosedRange<Double>, _ want: Double) -> ClosedRange<Double> {
            let centre = (span.lowerBound + span.upperBound) / 2
            return (centre - want / 2)...(centre + want / 2)
        }
        var newZ = [Double]()
        for thread in built.lines.threads { newZ += built.lines.points[thread]!.map(\.z) }
        let newWindow = middle((newZ.min() ?? 0)...(newZ.max() ?? 1), shown)
        // The frozen mesh is as long as its repeats; six cycles is one and a half
        // of them, so the same fraction of its length.
        let oldSpan = oldSolid.triangles.along
        let oldShown = (oldSpan.upperBound - oldSpan.lowerBound)
            * Double(Self.cyclesShown) / Double(Self.repeatCycles)
            / Double(HiraGenjiSurfaceMeshGenerator.defaultPatternRepeatCount)
        let oldWindow = middle(oldSpan, min(oldShown, oldSpan.upperBound - oldSpan.lowerBound))

        var panels = [(label: String, panel: BraidComparisonSheet.Panel)]()
        for turned in [false, true] {
            let eye = BraidComparisonSheet.camera(turned: turned)
            let name = turned ? "turned 30° round the braid, 20° above" : "straight on"
            if let panel = BraidComparisonSheet.paint(
                triangles: newTriangles, looking: eye, window: newWindow,
                acrossWanted: braidWidth, pixelsPerDiameter: Self.pixelsPerDiameter
            ) {
                panels.append(("new path — \(name)", panel.lyingDown))
            }
            if let panel = BraidComparisonSheet.paint(
                triangles: oldSolid.triangles.triangles, looking: eye, window: oldWindow,
                acrossWanted: braidWidth, pixelsPerDiameter: Self.pixelsPerDiameter
            ) {
                panels.append(("frozen generator — \(name)", panel.lyingDown))
            }
        }
        // The author asked for new, old, new, old in that order.
        // new straight on, frozen straight on, new turned, frozen turned
        let order = [0, 1, 2, 3].filter { $0 < panels.count }
        let sheet = try #require(BraidComparisonSheet.sheet(
            panels: order.map { panels[$0] },
            photograph: BraidComparisonSheet.photograph(at: photograph),
            photographLabel: photographLabel,
            legend: legend(assignments),
            title: title
        ))
        try BraidFigureDrawing.write(sheet, named: named)
    }

    private var references: String {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build").path
    }

    @Test(.enabled(if: braidSheetsAreWanted))
    func theFlatBraidSheets() throws {
        // The frozen mesh in thread diameters and the new path's axes. Its width is
        // eight diameters, which is what fixes the scale.
        let perDiameter = Double(HiraGenjiSurfaceMeshGenerator.defaultHalfWidth) * 2 / 8

        for (name, named, title, photograph, label) in [
            ("side-by-side-hira",
             ["north": ["natural", "natural", "natural", "natural"],
              "east": ["yellow", "red", "red", "yellow"],
              "south": ["natural", "natural", "natural", "natural"],
              "west": ["green", "light-blue", "light-blue", "green"]],
             "平源氏 — book A p97 left (colour only what is worked sideways)",
             "\(references)/task007f-references/bookA-p97-hiragenji-steps-6-7-and-variants.png",
             "book A p97 (the sample's own photograph)"),
            ("side-by-side-hira-p96",
             ["north": ["purple", "purple", "black", "orange"],
              "east": ["pink", "pink", "pink", "pink"],
              "south": ["purple", "purple", "black", "orange"],
              "west": ["pink", "pink", "pink", "pink"]],
             "平源氏 — book A p96 (the colouring its photograph is of)",
             "\(references)/task007f-references/bookA-p96-title-and-finished-braid.png",
             "book A p96 (the finished braid)"),
        ] {
            let assignments = colouring(named)
            let pattern = try #require(
                HiraGenjiSurfacePatternGenerator.generate(assignments: assignments))
            let mesh = try #require(HiraGenjiSurfaceMeshGenerator.generate(pattern: pattern))
            var byColour = mesh.colorGroups
            for (colour, indices) in mesh.boundaryColorGroups {
                byColour[colour, default: []] += indices
            }
            let solid = BraidComparisonSheet.solid(
                positions: mesh.positions, byColour: byColour, perDiameter: perDiameter
            )
            try build(recipe: BraidMethodCatalog.hiraGenji16Recipe, assignments: assignments,
                      oldSolid: (perDiameter, solid), braidWidth: 8,
                      photograph: photograph, photographLabel: label,
                      title: title, named: name)
        }
    }

    @Test(.enabled(if: braidSheetsAreWanted))
    func theRoundBraidSheets() throws {
        // The frozen tube's own radius is not in thread diameters, so its scale is
        // matched on the one thing both paths can be measured for: the braid's
        // width. Eight diameters and a bit, from the sixteen-sided figure.
        let newWidth = 8.034024
        let perDiameter = Double(MaruGenjiSurfaceMeshGenerator.defaultRadius) * 2 / newWidth

        for (name, named, title, photograph, label) in [
            ("side-by-side-maru",
             ["north": ["brown", "brown", "brown", "brown"],
              "east": ["brown", "brown", "white", "white"],
              "south": ["white", "white", "white", "white"],
              "west": ["white", "white", "brown", "brown"]],
             "丸源氏 — book A p95 arrow feather (the far half against the near half)",
             "\(references)/task020-references/bookA-p95-yagasuri.png",
             "book A p95 (arrow feather)"),
            ("side-by-side-maru-stripe",
             ["north": ["brown", "white", "white", "brown"],
              "east": ["yellow", "yellow", "yellow", "yellow"],
              "south": ["brown", "white", "white", "brown"],
              "west": ["yellow", "yellow", "yellow", "yellow"]],
             "丸源氏 — book A p95 vertical stripe",
             "\(references)/task020-references/bookA-p95-tatejima.png",
             "book A p95 (vertical stripe)"),
        ] {
            let assignments = colouring(named)
            let pattern = try #require(
                MaruGenjiSurfacePatternGenerator.generate(assignments: assignments))
            let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))
            let solid = BraidComparisonSheet.solid(
                positions: mesh.positions, byColour: mesh.colorGroups, perDiameter: perDiameter
            )
            try build(recipe: BraidMethodCatalog.maruGenji16Recipe, assignments: assignments,
                      oldSolid: (perDiameter, solid), braidWidth: newWidth,
                      photograph: photograph, photographLabel: label,
                      title: title, named: name)
        }
    }
}

/// Off unless the environment asks, so the default run stays inside the
/// sixty-second allowance rather than the allowance being raised for a picture.
nonisolated let braidSheetsAreWanted =
    ProcessInfo.processInfo.environment["DRAW_SHEETS"] != nil
