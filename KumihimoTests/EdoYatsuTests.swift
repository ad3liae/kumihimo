import Foundation
import Testing
@testable import Kumihimo

/// Task 009: 江戸八つ組, book A p.48, the second braid on the eight-place stand.
///
/// **The three checks of Task 025-5's step 6, on this braid**: it goes in as a
/// table, a colouring and measured values and nothing else; the working-out,
/// the figure and the stacking take it without being touched; and its family is
/// read off the braid.
@MainActor
struct EdoYatsuTests {
    private var recipe: BraidRecipe { BraidMethodCatalog.edoYatsu8Recipe }
    private var stand: BraidStand { BraidMethodCatalog.stand8 }

    // MARK: - The table (025-5, 1)

    /// **Book A p.48's four steps run as one cycle of the eight-place stand**:
    /// two threads a step, all eight carried once, nothing left for the closing.
    /// The carries are seven to nine notches and the tidies one.
    @Test func theTableIsACycleOfTheEightPlaceStand() throws {
        let worked = try #require(recipe.worked(on: stand))
        #expect(BraidMethodCatalog.stand(for: recipe) == stand)
        #expect(worked.method.steps.map { $0.moves.map { [$0.from, $0.to] } }
                == [[[8, 2], [4, 6]], [[6, 8], [2, 4]], [[1, 7], [5, 3]], [[7, 5], [3, 1]]])
        #expect(worked.method.closing.moves.isEmpty)
        #expect(BraidMethodCatalog.edoYatsu8.steps.map(\.name) == BraidMethodCatalog.edoYatsuStepNames)
        let disk = BraidMethodCatalog.edoYatsuDisk
        #expect(disk.braidingMoves.allSatisfy { (7...9).contains(disk.notches($0)) })
    }

    /// **Odd places go two back and even places two on, each cycle**: the two
    /// colours turn opposite ways round the braid, so it is not a spiral. The
    /// reviewer's permutation, 1→7 2→4 3→1 4→6 5→3 6→8 7→5 8→2.
    @Test func oddPlacesGoTwoBackAndEvenPlacesTwoOn() throws {
        let worked = try #require(recipe.worked(on: stand))
        for course in worked.derivation.courses {
            for (from, to) in zip(course.slots, course.slots.dropFirst()) {
                let wanted = course.threadPosition % 2 == 1 ? 6 : 2
                #expect((to - from + 8) % 8 == wanted, "thread \(course.threadPosition)")
            }
        }
        let afterOneCycle = Dictionary(uniqueKeysWithValues: worked.method.steps
            .flatMap(\.moves).map { ($0.from, $0.to) })
        #expect((1...8).map { afterOneCycle[$0] } == [7, 4, 1, 6, 3, 8, 5, 2])
        // Parity is kept, so each place keeps its colour: figure 5 is figure 1.
        #expect(worked.derivation.repeatCycleCount == 4)
    }

    // MARK: - Three things and nothing else (025-5, 6)

    @Test func nothingElseHadToBeDeclared() throws {
        #expect(recipe.crossSection(on: stand).order == stand.positionIDs)
        #expect(recipe.crossSection(on: stand).source == .standRim)
        #expect(recipe.shape == BraidShapeValues())
        let worked = try #require(recipe.worked(on: stand))
        #expect(worked.derivation.fold == nil)
        #expect(BraidFamily.family(of: worked.derivation) == .roundTube(threads: 8))
        let figure = try #require(BraidFigureBuilder.tube(
            from: worked.derivation, assignments: recipe.colouring
        ))
        #expect(figure.columns.count == 8)
        let stacking = try #require(BraidStacking.stacking(
            of: worked.method, on: stand, crossSection: worked.section,
            fold: worked.derivation.fold, cycles: 5
        ))
        #expect(stacking.pitchPerCycle.isDerived)
    }

    /// **Book A p.48's two colours alternate round the stand**, 131 (`pink`) in
    /// 8, 2, 4, 6 and 129 (`white`) in 1, 3, 5, 7.
    @Test func theColouringAlternates() {
        let byPosition = Dictionary(uniqueKeysWithValues: recipe.colouring.map { ($0.position, $0.colorID.rawValue) })
        #expect([8, 2, 4, 6].map { byPosition[$0] } == ["pink", "pink", "pink", "pink"])
        #expect([1, 3, 5, 7].map { byPosition[$0] } == ["white", "white", "white", "white"])
    }

    // MARK: - The drawing (the eight-thread tube's drawer, as it is)

    /// **Drawn by the eight-thread tube's drawer, with its own shape**: the
    /// family is read off the braid and that drawer returns a mesh, the only
    /// one that does.
    @Test func theEightThreadTubesDrawerMakesAMesh() throws {
        #expect(BraidFamilyDrawing.drawer(for: recipe) == RoundTube8SurfaceMesh.family)
        let mesh = BraidFamilyDrawing.mesh(for: recipe, on: stand)
        let tube = try #require(mesh.tubeOfEight)
        #expect(tube.triangleCount > 0)
        #expect(mesh.flat == nil && mesh.tube == nil && mesh.tubeOfFour == nil)
    }

    /// **The threads do move, two places a cycle each, even places on and odd
    /// places back**; so the carry has no single number. A table that moved
    /// nothing would also keep each place's colour — this is not that.
    ///
    /// Each place is fed from two places back or two on, and parity is kept,
    /// so a place keeps its colour: pink columns and white alternate straight
    /// along the braid, the pairs half a pitch apart. The repeat is four
    /// cycles, counted by thread, and its four rows look alike.
    @Test func theThreadsMoveAndEachPlaceKeepsItsColour() throws {
        let worked = try #require(recipe.worked(on: stand))
        let drawn = try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, rounds: worked.derivation.rounds, crossSection: worked.section,
            assignments: recipe.colouring
        ))
        // Slot s is place s + 1: even places (odd slots) are fed from two back.
        #expect(drawn.columnsCarriedBySlot == [-2, 2, -2, 2, -2, 2, -2, 2])
        #expect(drawn.columnsCarried == nil)
        #expect(drawn.rowCount == 4)
        #expect(drawn.drawnPhaseByColumn == [1, 0.5, 1, 0.5, 1, 0.5, 1, 0.5])
        // **The two colours lean opposite ways** (Task 055's rule on this braid):
        // a run leans the other way from its own carry, and here the carries
        // differ by place. So there is no one lean, and the pattern is not a
        // spiral but a herringbone.
        #expect(drawn.leanDirection == nil)
        #expect(Set(drawn.leanBySegment) == [-1, 1])
        for slot in 0..<8 {
            let middle = (Float(slot) + 0.5) / 8
            let colours = Set(drawn.surface.segments
                .filter { abs($0.centerlineStart.x - middle) < 1e-4 }.map(\.colorID.rawValue))
            #expect(colours == [slot % 2 == 0 ? "white" : "pink"], "slot \(slot)")
        }
    }

    /// **The mesh is what the eight-thread drawer made of this braid when it
    /// was added** (Task 009). Nothing was shaped for it; moves only on purpose.
    @Test func theMeshIsTheShapeItWas() throws {
        let mesh = try #require(BraidFamilyDrawing.mesh(for: recipe, on: stand).tubeOfEight)
        #expect(mesh.positions.count == 18_240)
        #expect(BraidMeshHashTests.hash(mesh.positions) == 0x4120_520e_ed66_35d5)
    }

    // MARK: - The preset

    /// **Eight threads offer 江戸八つ** beside yatsu-kongo, and it is the
    /// recipe's own preset.
    @Test func eightThreadsOfferEdoYatsu() {
        #expect(BraidPresetCatalog.availablePresets(threadCount: 8).contains(BraidPresetCatalog.edoYatsu))
        #expect(BraidMethodCatalog.recipe(for: .edoYatsu8) == recipe)
        #expect(BraidPresetCatalog.edoYatsu.displayName == "江戸八つ")
        for count in [4, 12, 16] {
            #expect(!BraidPresetCatalog.availablePresets(threadCount: count).contains(BraidPresetCatalog.edoYatsu))
        }
    }
}
