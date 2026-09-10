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
/// them.
///
/// **`DRAW_SHEETS=1 xcodebuild test ...` does not work.** The variable has to be
/// in the environment of the *test host*, and neither the plain form nor
/// `TEST_RUNNER_DRAW_SHEETS=1` puts it there. What does is the simulator's own
/// environment — **and it stays on the device until it is taken off again**:
///
///     xcrun simctl spawn <UDID> launchctl setenv DRAW_SHEETS 1
///     xcodebuild test ... -only-testing:KumihimoTests/BraidComparisonSheetTests \
///       -default-test-execution-time-allowance 600
///     xcrun simctl spawn <UDID> launchctl unsetenv DRAW_SHEETS
///
/// **The last line is not optional.** Left set, the next ordinary run draws the
/// sheets too and is cut off at sixty seconds — which is the whole thing this
/// switch exists to prevent, defeated from outside the code.
@MainActor
struct BraidComparisonSheetTests {

    static let pixelsPerDiameter = 32
    /// Six cycles of braid, which for both braids is one and a half repeats of the
    /// pattern -- a repeat is four cycles either way.
    static let cyclesShown = 6
    static let repeatCycles = 4

    private func colouring(
        _ named: [String: [String]], on stand: BraidStand = BraidMethodCatalog.stand16
    ) -> [ThreadAssignment] {
        BraidMethodCatalog.colouring(on: stand, named)
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
    /// `stand`, `repeatCycles` and `meshRepeats` are the braid's own; they default
    /// to the sixteen-place stand's, which is what the two Genji sheets were drawn
    /// with and still are.
    private func build(
        recipe: BraidRecipe,
        assignments: [ThreadAssignment],
        oldSolid: (perDiameter: Double, triangles: BraidComparisonSheet.Solid),
        braidWidth: Double,
        photograph: CGImage?,
        photographLabel: String,
        title: String,
        named: String,
        stand: BraidStand = BraidMethodCatalog.stand16,
        repeatCycles: Int = repeatCycles,
        meshRepeats: Int = Flat16SurfaceMesh.defaultPatternRepeatCount,
        solidLabel: String = "frozen generator",
        matchPhotographToPanels: Bool = false
    ) throws {
        let coloured = BraidRecipe(
            id: recipe.id, name: recipe.name, notation: recipe.notation,
            colouring: assignments, shape: recipe.shape,
            orderRoundTheBraid: recipe.orderRoundTheBraid
        )
        let built = try #require(BraidFromRecipe.build(
            coloured, on: stand, cycles: Self.cyclesShown + 2
        ))
        var colourOf = [Int: ThreadColorID]()
        for assignment in assignments { colourOf[assignment.position] = assignment.colorID }
        let newTriangles = BraidComparisonSheet.solid(of: built.lines, colouring: colourOf)

        // The middle six cycles of each, so neither shows its own ends — **and the
        // same six cycles of both**, taken as a share of each one's own length,
        // because a sheet whose two panels run at different scales along the braid
        // compares nothing.
        func middle(_ span: ClosedRange<Double>, _ want: Double) -> ClosedRange<Double> {
            let centre = (span.lowerBound + span.upperBound) / 2
            return (centre - want / 2)...(centre + want / 2)
        }
        var newZ = [Double]()
        for thread in built.lines.threads { newZ += built.lines.points[thread]!.map(\.z) }
        let newSpan = (newZ.min() ?? 0)...(newZ.max() ?? 1)
        // The construction was built for `cyclesShown + 2` cycles, so six of them
        // is that share of what it came out as.
        let newShown = (newSpan.upperBound - newSpan.lowerBound)
            * Double(Self.cyclesShown) / Double(Self.cyclesShown + 2)
        let newWindow = middle(newSpan, newShown)
        // The frozen mesh is as long as its repeats; six cycles is one and a half
        // of them, so the same fraction of its length.
        let oldSpan = oldSolid.triangles.along
        let oldShown = (oldSpan.upperBound - oldSpan.lowerBound)
            * Double(Self.cyclesShown) / Double(repeatCycles)
            / Double(meshRepeats)
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
                panels.append(("\(solidLabel) — \(name)", panel.lyingDown))
            }
        }
        // The author asked for new, old, new, old in that order.
        // new straight on, frozen straight on, new turned, frozen turned
        let order = [0, 1, 2, 3].filter { $0 < panels.count }
        let sheet = try #require(BraidComparisonSheet.sheet(
            panels: order.map { panels[$0] },
            photograph: photograph,
            photographLabel: photographLabel,
            legend: legend(assignments),
            title: title,
            // **Matched to the panel that is being judged**, which is the shipped
            // drawer's, not the research path's.
            photographWidth: matchPhotographToPanels
                ? panels.first { $0.label.hasPrefix(solidLabel) }.map { Double($0.panel.width) }
                : nil
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
        let perDiameter = Double(Flat16SurfaceMesh.defaultHalfWidth) * 2 / 8

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
                Flat16SurfacePatternGenerator.generate(assignments: assignments))
            let mesh = try #require(Flat16SurfaceMesh.generate(pattern: pattern))
            var byColour = mesh.colorGroups
            for (colour, indices) in mesh.boundaryColorGroups {
                byColour[colour, default: []] += indices
            }
            let solid = BraidComparisonSheet.solid(
                positions: mesh.positions, byColour: byColour, perDiameter: perDiameter
            )
            try build(recipe: BraidMethodCatalog.hiraGenji16Recipe, assignments: assignments,
                      oldSolid: (perDiameter, solid), braidWidth: 8,
                      photograph: BraidComparisonSheet.photograph(at: photograph),
                      photographLabel: label, title: title, named: name)
        }
    }

    @Test(.enabled(if: braidSheetsAreWanted))
    func theRoundBraidSheets() throws {
        // The frozen tube's own radius is not in thread diameters, so its scale is
        // matched on the one thing both paths can be measured for: the braid's
        // width. Eight diameters and a bit, from the sixteen-sided figure.
        let newWidth = 8.034024
        let perDiameter = Double(RoundTube16SurfaceMesh.defaultRadius) * 2 / newWidth

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
                RoundTube16SurfacePatternGenerator.generate(assignments: assignments))
            let mesh = try #require(RoundTube16SurfaceMesh.generate(pattern: pattern))
            let solid = BraidComparisonSheet.solid(
                positions: mesh.positions, byColour: mesh.colorGroups, perDiameter: perDiameter
            )
            try build(recipe: BraidMethodCatalog.maruGenji16Recipe, assignments: assignments,
                      oldSolid: (perDiameter, solid), braidWidth: newWidth,
                      photograph: BraidComparisonSheet.photograph(at: photograph),
                      photographLabel: label, title: title, named: name)
        }
    }

    /// Task 032 stage 0: **the eight-bobbin braids beside their own photograph.**
    ///
    /// The same sheet as the other two — same colouring both sides, same length,
    /// same camera — with one thing added that the others do without: **the
    /// reference is cut to one braid and scaled so its width is the width the
    /// panels draw a braid at.** Three braids lie in that photograph at a scale of
    /// their own, and laying a braid beside a bigger braid decides nothing
    /// (`docs/measurement-procedures.md` 3).
    ///
    /// The colouring is book A's own, which is what the photograph is of.
    @Test(.enabled(if: braidSheetsAreWanted))
    func theYatsuKongoSheets() throws {
        // The braid is eight threads round, so its width is one thread plus the
        // circle their centres stand on: `8/pi + 1` diameters. In the mesh's own
        // units one thread is the valley floor's circumference over eight.
        let floor = Double(RoundTube8SurfaceMesh.defaultRadius)
            * Double(1 - RoundTube8SurfaceMesh.crestHeightRatio)
        let perDiameter = 2 * Double.pi * floor / 8
        let braidWidth = Double(RoundTube8SurfaceMesh.defaultRadius) * 2 / perDiameter

        let photograph = try #require(BraidComparisonSheet.photograph(
            at: "\(references)/task031-photos/bookA-p8-9-zoom-b-a-S.png"))

        for (name, recipe, title, columns, rows, braidPixels, label) in [
            ("side-by-side-yatsu-kongo-s", BraidMethodCatalog.yatsuKongoS8Recipe,
             "八つ金剛組S — book A p.54's own colouring (p.8's own photograph)",
             2236..<2474, 950..<1900, 238.0, "book A p.8, the S braid (right of the three)"),
            ("side-by-side-yatsu-kongo-z", BraidMethodCatalog.yatsuKongoZ8Recipe,
             "八つ金剛組Z — book A p.55's colouring a (p.8's own photograph)",
             1296..<1542, 900..<1900, 246.0, "book A p.8, the Z-a braid (middle of the three)"),
        ] {
            let assignments = recipe.colouring
            let worked = try #require(recipe.worked(on: BraidMethodCatalog.stand8))
            let pattern = try #require(RoundTube8SurfacePatternGenerator.generate(
                stand: BraidMethodCatalog.stand8, method: worked.method,
                crossSection: worked.section, assignments: assignments
            ))
            let mesh = try #require(RoundTube8SurfaceMesh.generate(pattern: pattern))
            let solid = BraidComparisonSheet.solid(
                positions: mesh.positions, byColour: mesh.colorGroups, perDiameter: perDiameter
            )
            let reference = BraidComparisonSheet.reference(
                photograph, columns: columns, rows: rows,
                braidPixels: braidPixels, braidWidth: braidWidth,
                pixelsPerDiameter: Self.pixelsPerDiameter
            )
            try build(recipe: recipe, assignments: assignments,
                      oldSolid: (perDiameter, solid), braidWidth: braidWidth,
                      photograph: reference, photographLabel: label,
                      title: title, named: name,
                      stand: BraidMethodCatalog.stand8,
                      repeatCycles: pattern.rowCount,
                      meshRepeats: mesh.patternRepeatCount,
                      solidLabel: "the shipped drawer",
                      matchPhotographToPanels: true)
        }
    }
}

/// Off unless the environment asks, so the default run stays inside the
/// sixty-second allowance rather than the allowance being raised for a picture.
nonisolated let braidSheetsAreWanted =
    ProcessInfo.processInfo.environment["DRAW_SHEETS"] != nil
