import Foundation
import Testing
@testable import Kumihimo

/// Task 025-4 step 3: **a recipe is handed to the drawer for its family.**
@MainActor
struct BraidFamilyDrawingTests {
    @Test func theFamilyIsReadOffTheBraid() throws {
        for (recipe, wanted) in [
            (BraidMethodCatalog.hiraGenji16Recipe, BraidFamily.flat(threads: 16, columns: 6)),
            (BraidMethodCatalog.maruGenji16Recipe, BraidFamily.roundTube(threads: 16, turning: .bothWays)),
        ] {
            let worked = try #require(recipe.worked(on: BraidMethodCatalog.stand16))
            #expect(BraidFamily.family(of: worked.derivation) == wanted)
        }
    }

    /// **Which ways round a tube's threads are carried is read off the braid**
    /// (Task 059): 江戸八つ組 carries the four threads of one side of each pair
    /// on and the other four back, both ways in every cycle; 丸源氏 carries
    /// across the braid both ways too. Yatsu-kongo S and Z carry every thread one
    /// way, and 返し組 turns its spiral round only from one table to the next —
    /// each cycle is still one way. 丸四つ組 carries every thread a half turn,
    /// which has no way round, so it is not both ways.
    ///
    /// **Not by name**: 江戸八つ組's table under another name and id reads the
    /// same, and finds the same drawer.
    @Test func theWaysRoundAreReadOffTheBraid() throws {
        let wanted: [(BraidRecipe, BraidTurning)] = [
            (BraidMethodCatalog.yatsuKongoS8Recipe, .oneWay),
            (BraidMethodCatalog.yatsuKongoZ8Recipe, .oneWay),
            (BraidMethodCatalog.yatsuKongoGaeshi8Recipe, .oneWay),
            (BraidMethodCatalog.maruYotsu4Recipe, .oneWay),
            (BraidMethodCatalog.edoYatsu8Recipe, .bothWays),
            (BraidMethodCatalog.maruGenji16Recipe, .bothWays),
        ]
        for (recipe, turning) in wanted {
            let stand = try #require(BraidMethodCatalog.stand(for: recipe))
            let worked = try #require(recipe.worked(on: stand))
            #expect(BraidTurning.of(worked.derivation) == turning, "\(recipe.id)")
            if case let .roundTube(threads, readTurning) = BraidFamily.family(of: worked.derivation) {
                #expect(threads == stand.positionCount && readTurning == turning, "\(recipe.id)")
            } else {
                Issue.record("\(recipe.id) is not read as a tube")
            }
        }
        #expect(BraidFamilyDrawing.drawer(for: BraidMethodCatalog.edoYatsu8Recipe)
                == RoundTube8SurfaceMesh.familyTurningBothWays)
        for recipe in [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe,
                       BraidMethodCatalog.yatsuKongoGaeshi8Recipe] {
            #expect(BraidFamilyDrawing.drawer(for: recipe) == RoundTube8SurfaceMesh.family, "\(recipe.id)")
        }

        let renamed = BraidRecipe(
            id: "a-table-this-code-has-not-seen-both-ways", name: "架空の紐",
            notation: BraidMethodCatalog.edoYatsuDisk,
            colouring: BraidMethodCatalog.edoYatsu8Recipe.colouring, shape: BraidShapeValues(),
            orderRoundTheBraid: BraidMethodCatalog.edoYatsu8CrossSection
        )
        let stand = BraidMethodCatalog.stand8
        let worked = try #require(renamed.worked(on: stand))
        #expect(BraidTurning.of(worked.derivation) == .bothWays)
        #expect(BraidFamilyDrawing.drawer(for: renamed, on: stand) == RoundTube8SurfaceMesh.familyTurningBothWays)
        // The recipe book's p.48 table of the same braid reads the same.
        let recipeBook = try #require(BraidMethodCatalog.edoYatsuRecipeBookP48Disk.method(
            id: "edo-yatsu-8-recipe-book-p48", standID: stand.id,
            stepNames: BraidMethodCatalog.edoYatsuRecipeBookP48StepNames
        ))
        let section = BraidMethodCatalog.edoYatsu8Recipe.crossSection(on: stand)
        let derived = try #require(BraidDerivation.derive(stand: stand, method: recipeBook, crossSection: section))
        #expect(BraidTurning.of(derived) == .bothWays)
    }

    /// **A drawer is not promised.** A recipe of a family this app draws gets one,
    /// with the family's own shape values behind it; a recipe of a family it does
    /// not -- the eight-thread braids of Task 008 -- gets nothing, and nothing is
    /// the right answer.
    @Test(arguments: BraidMethodCatalog.recipes)
    func aRecipeFindsADrawerWhenAndOnlyWhenItsFamilyHasOne(recipe: BraidRecipe) throws {
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        let worked = try #require(recipe.worked(on: stand))
        let family = BraidFamily.family(of: worked.derivation)
        guard let drawing = BraidFamilyDrawing.drawing(for: recipe, on: stand) else {
            #expect(BraidFamilyDrawing.shape(of: family) == nil)
            let nothing = BraidFamilyDrawing.mesh(for: recipe, on: stand)
            #expect(nothing.flat == nil && nothing.tube == nil && nothing.tubeOfEight == nil
                    && nothing.tubeOfFour == nil)
            return
        }
        let shape = try #require(BraidFamilyDrawing.shape(of: drawing.family))
        #expect(!shape.values.isEmpty)
        let mesh = BraidFamilyDrawing.mesh(for: recipe, on: stand)
        // **Exactly one drawer made it.** Four families are drawn now (the tube
        // of four since Task 054), and a recipe belongs to one of them.
        let made = [mesh.flat != nil, mesh.tube != nil, mesh.tubeOfEight != nil,
                    mesh.tubeOfFour != nil]
        #expect(made.filter { $0 }.count == 1)
    }

    /// **A table this code has not seen, drawn by a family it has.** Book C's
    /// Fig.32 turned a quarter round the disk goes in as a recipe, the family comes
    /// out of the braid, and a drawing comes out the other end: the pattern from
    /// the occupancy history, the shape from the family's own values.
    @Test func aTableThisCodeHasNotSeenIsDrawnByItsFamily() throws {
        let recipe = BraidRecipe(
            id: "a-table-this-code-has-not-seen", name: "架空の紐",
            notation: BraidDiskNotation(
                source: "book C Fig.32, turned a quarter round the disk",
                notchCount: 32,
                standPositionByRestingNotch: BraidMethodCatalog.diskRestingNotches,
                moves: BraidMethodCatalog.maruGenjiDisk.moves.map {
                    BraidMove(from: ($0.from - 1 + 8) % 32 + 1, to: ($0.to - 1 + 8) % 32 + 1)
                },
                threadsPerStep: 2
            ),
            colouring: BraidMethodCatalog.colouring(on: BraidMethodCatalog.stand16, [
                "north": Array(repeating: "red", count: 4),
                "east": Array(repeating: "white", count: 4),
                "south": Array(repeating: "blue", count: 4),
                "west": Array(repeating: "white", count: 4),
            ]),
            shape: BraidShapeValues()
        )
        let worked = try #require(recipe.worked(on: BraidMethodCatalog.stand16))
        #expect(BraidFamily.family(of: worked.derivation) == RoundTube16SurfaceMesh.family)
        let mesh = try #require(
            BraidFamilyDrawing.mesh(for: recipe, on: BraidMethodCatalog.stand16).tube)
        #expect(mesh.triangleCount > 0)
        // The colours are the ones handed in, and the shape is the family's.
        #expect(Set(mesh.colorGroups.keys).isSubset(of: Set(recipe.colouring.map(\.colorID))))
        #expect(BraidMeshHashTests.hash(mesh.positions)
                == BraidMeshHashTests.hash(try {
                    let pattern = try #require(RoundTube16SurfacePatternGenerator.generate(
                        assignments: recipe.colouring))
                    return try #require(RoundTube16SurfaceMesh.generate(pattern: pattern))
                }().positions))
    }

    // MARK: what each family rests on

    /// **Every shape value says where it came from**, and the ones set by eye say
    /// that they were.
    @Test func everyShapeValueSaysWhereItCameFrom() throws {
        for shape in BraidFamilyDrawing.families {
            for (name, value) in shape.values {
                #expect(!value.source.origin.isEmpty, "\(name)")
                #expect(value.isObserved || value.isDerived || value.isDeclared, "\(name)")
                if value.isDeclared {
                    #expect(!value.isSettled, "\(name) should say it was calibrated by eye")
                }
            }
        }
    }

    /// The measured ones are the ones the record names, at the values they have
    /// always had. **Nothing is changed by saying where it came from.** The
    /// round braid's crest left them in Task 052, when it was redrawn by eye.
    @Test func theMeasuredValuesAreTheOnesTheRecordNames() throws {
        let flat = Flat16SurfaceMesh.shape
        let tube = RoundTube16SurfaceMesh.shape
        // Held against the constants themselves: **nothing is changed by saying
        // where it came from.** (They are `Float` in the drawer, so the widened
        // value is what to compare with, not the printed decimal.)
        #expect(flat.measured["width over thickness"]?.value
                == Double(Flat16SurfaceMesh.widthToThicknessRatio))
        #expect(abs((flat.measured["width over thickness"]?.value ?? 0) - 3.3359) < 1e-6)
        #expect(flat.measured["pitch of one step over braid width"]?.value
                == Double(Flat16SurfacePatternGenerator.stitchPitchPerBraidWidth))
        #expect(flat.measured["crest over half thickness"]?.value
                == Double(Flat16SurfaceMesh.crestHeightRatio))
        // **Chosen by eye since Task 052**, so it is no longer among the measured.
        #expect(tube.measured["crest over nominal radius"] == nil)
        #expect(tube.calibratedByEye["crest over nominal radius"]?.value
                == Double(RoundTube16SurfaceMesh.crestHeightRatio))
        #expect(tube.measured["one repeat over one turn"]?.value
                == Double(RoundTube16SurfacePatternGenerator.patternAspectRatio))
        // And the ones calibrated by eye are kept, and counted, not hidden.
        // **Eleven since the Task 050 rework**: every cell is drawn as a bundle,
        // and how high two of them meet along the braid and across it, how the
        // lens pinches, how much the end that laps over stands up and the end
        // that goes under sinks, how far a buried tip goes on, how far it sinks,
        // how much it narrows, and how far the floor lies below a rim are set by
        // eye against the photographs, as are the outline's exponent and the size
        // on screen. **The eight of them that shape a bundle are every figure
        // `Flat16BundleShape` carries**, so none of them is left out of the
        // record.
        #expect(flat.calibratedByEye.count == 11)
        // Two more are solved from those rather than set: how wide a bundle is,
        // and how far its swell reaches.
        #expect(flat.workedOut.count == 2)
        // Fifteen since the Task 047 rework: every cell is drawn as a bundle, and
        // how far it laps and tucks, how wide it is, how it narrows at each end,
        // and how its buried tip and the floor sink are set by eye against the
        // photographs, as are the cross-section and the fibre count.
        // Nineteen since Task 052: the crest joined them, drawn rounder by eye,
        // and so did how softly the cross-section meets its rim, how high the rim
        // resting on the previous row stands, and how long the end lying over the
        // other arm of a V keeps its height.
        #expect(tube.calibratedByEye.count == 19)
    }
}
