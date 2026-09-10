import Foundation
import Testing
@testable import Kumihimo

/// Task 025-4 step 3: **a recipe is handed to the drawer for its family.**
@MainActor
struct BraidFamilyDrawingTests {
    @Test func theFamilyIsReadOffTheBraid() throws {
        for (recipe, wanted) in [
            (BraidMethodCatalog.hiraGenji16Recipe, BraidFamily.flat(threads: 16, columns: 6)),
            (BraidMethodCatalog.maruGenji16Recipe, BraidFamily.roundTube(threads: 16)),
        ] {
            let worked = try #require(recipe.worked(on: BraidMethodCatalog.stand16))
            #expect(BraidFamily.family(of: worked.derivation) == wanted)
        }
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
            #expect(nothing.flat == nil && nothing.tube == nil)
            return
        }
        let shape = try #require(BraidFamilyDrawing.shape(of: drawing.family))
        #expect(!shape.values.isEmpty)
        let mesh = BraidFamilyDrawing.mesh(for: recipe, on: stand)
        #expect((mesh.flat != nil) != (mesh.tube != nil))
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

    /// The measured ones are the five the record names, at the values they have
    /// always had. **Nothing is changed by saying where it came from.**
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
        #expect(tube.measured["crest over nominal radius"]?.value
                == Double(RoundTube16SurfaceMesh.crestHeightRatio))
        #expect(tube.measured["one repeat over one turn"]?.value
                == Double(RoundTube16SurfacePatternGenerator.patternAspectRatio))
        // And the ones calibrated by eye are kept, and counted, not hidden.
        #expect(flat.calibratedByEye.count == 4)
        #expect(tube.calibratedByEye.count == 8)
    }
}
