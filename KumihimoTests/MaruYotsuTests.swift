import Foundation
import Testing
@testable import Kumihimo

/// Task 054: 丸四つ組, the first braid of four threads, and the drawer for its
/// family.
///
/// **The three checks of Task 025-5's step 6, on this braid**: it goes in as a
/// table, a colouring and measured values and nothing else; the working-out,
/// the figure and the stacking take it without being touched; and its family is
/// read off the braid and has a drawer that returns a mesh.
@MainActor
struct MaruYotsuTests {
    private var recipe: BraidRecipe { BraidMethodCatalog.maruYotsu4Recipe }
    private var stand: BraidStand { BraidMethodCatalog.stand4 }

    // MARK: - The table (025-5, 1)

    /// **Book A p.56's two steps run as one cycle of the four-place stand**: the
    /// upright pair swapped, then the flat pair, the threads carried 1, 3, 2, 4
    /// and nothing left for the closing.
    @Test func theTableIsACycleOfTheFourPlaceStand() throws {
        let worked = try #require(recipe.worked(on: stand))
        #expect(BraidMethodCatalog.stand(for: recipe) == stand)
        #expect(worked.method.steps.map { $0.moves.map { [$0.from, $0.to] } }
                == [[[1, 3], [3, 1]], [[2, 4], [4, 2]]])
        #expect(worked.method.closing.moves.isEmpty)
        #expect(BraidMethodCatalog.maruYotsu4.steps.map(\.name) == ["uprightPair", "flatPair"])
        #expect(BraidMethodCatalog.maruYotsuDisk.braidingMoves.allSatisfy {
            BraidMethodCatalog.maruYotsuDisk.notches($0) == 15
        })
    }

    /// **Every thread goes two places a cycle** — half the ring — so the stand
    /// comes round in two cycles. The eight-thread braids go two places too,
    /// of eight.
    @Test func everyThreadGoesTwoPlacesACycle() throws {
        let worked = try #require(recipe.worked(on: stand))
        #expect(worked.derivation.repeatCycleCount == 2)
        for course in worked.derivation.courses {
            for (from, to) in zip(course.slots, course.slots.dropFirst()) {
                #expect((to - from + 4) % 4 == 2, "thread \(course.threadPosition)")
            }
        }
    }

    // MARK: - Three things and nothing else (025-5, 6)

    @Test func nothingElseHadToBeDeclared() throws {
        #expect(recipe.orderRoundTheBraid == nil)
        #expect(recipe.crossSection(on: stand).source == .standRim)
        #expect(recipe.shape == BraidShapeValues())
        let worked = try #require(recipe.worked(on: stand))
        #expect(worked.derivation.fold == nil)
        let figure = try #require(BraidFigureBuilder.tube(
            from: worked.derivation, assignments: recipe.colouring
        ))
        #expect(figure.columns.count == 4)
        let stacking = try #require(BraidStacking.stacking(
            of: worked.method, on: stand, crossSection: worked.section,
            fold: worked.derivation.fold, cycles: 5
        ))
        #expect(stacking.pitchPerCycle.isDerived)
    }

    /// **The family is read off the braid**, a tube of four, and its drawer
    /// returns a mesh — the only drawer that does.
    @Test func theFamilyIsATubeOfFourAndItsDrawerMakesAMesh() throws {
        let worked = try #require(recipe.worked(on: stand))
        #expect(BraidFamily.family(of: worked.derivation) == RoundTube4SurfaceMesh.family)
        #expect(BraidFamilyDrawing.drawer(for: recipe) == RoundTube4SurfaceMesh.family)
        let mesh = BraidFamilyDrawing.mesh(for: recipe, on: stand)
        let tube = try #require(mesh.tubeOfFour)
        #expect(tube.triangleCount > 0)
        #expect(mesh.flat == nil && mesh.tube == nil && mesh.tubeOfEight == nil)
        // And the eight-thread drawer does not take it, nor this one an eight.
        #expect(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, method: worked.method, crossSection: worked.section,
            assignments: recipe.colouring
        ) == nil)
        let eight = BraidMethodCatalog.yatsuKongoS8Recipe
        let workedEight = try #require(eight.worked(on: BraidMethodCatalog.stand8))
        #expect(RoundTube4SurfacePatternGenerator.generate(
            stand: BraidMethodCatalog.stand8, method: workedEight.method,
            crossSection: workedEight.section, assignments: eight.colouring
        ) == nil)
    }

    // MARK: - The drawing

    /// **The solid's cells carry the figure's colours, place by place and row
    /// by row**, and with colouring b a place keeps its colour: the columns
    /// run white, purple, white, purple, straight along the braid, as
    /// photograph b's do. The pairs arrive half a cycle apart.
    @Test func theSolidsCellsCarryTheFiguresColours() throws {
        let worked = try #require(recipe.worked(on: stand))
        let drawn = try #require(RoundTube4SurfacePatternGenerator.generate(
            stand: stand, rounds: worked.derivation.rounds, crossSection: worked.section,
            assignments: recipe.colouring
        ))
        #expect(drawn.rowCount == 2)
        #expect(drawn.columnsCarried == 2)
        #expect(drawn.drawnPhaseByColumn == [0.5, 1, 0.5, 1])
        guard case let .tube(figure) = BraidPatternForRecipe.figure(
            for: recipe, assignments: recipe.colouring, repeats: 1
        ) else {
            Issue.record("丸四つの模様図は筒として描けるはずです")
            return
        }
        for row in 0..<drawn.rowCount {
            for place in 0..<4 {
                let shape = try #require(figure.appearance(atColumn: place, row: row))
                let middle = (Float(place) + 0.5) / 4
                let along = Float(row) / Float(drawn.rowCount)
                let cell = try #require(drawn.surface.segments.first {
                    abs($0.centerlineStart.x - middle) < 1e-4
                        && $0.centerlineStart.y <= along + 1e-4
                        && $0.centerlineEnd.y > along + 1e-4
                })
                #expect(cell.colorID == shape.colorID, "row \(row), place \(place)")
                #expect(cell.colorID.rawValue == (place % 2 == 0 ? "byakugun" : "nibi"))
            }
        }
    }

    /// **Which thread of a pair goes first does not reach the drawing.** Book A
    /// prints the right hand and the left for a step and not their order.
    /// Swapped, or read one thread an instant either way round, the occupancy
    /// history, the figure and every vertex of the mesh are the same; only the
    /// laying instants move, and nothing drawn reads them.
    @Test func whichThreadOfAPairGoesFirstDoesNotReachTheDrawing() throws {
        let asPrinted = BraidMethodCatalog.maruYotsuDisk
        let swapped = [(17, 2), (1, 18), (2, 1), (18, 17), (25, 10), (9, 26), (10, 9), (26, 25)]
        func variant(_ moves: [BraidMove], _ reading: BraidDiskNotation.StepReading) -> BraidRecipe {
            BraidRecipe(
                id: "maru-yotsu-variant", name: "丸四つ組",
                notation: BraidDiskNotation(
                    source: asPrinted.source, notchCount: 32,
                    standPositionByRestingNotch: asPrinted.standPositionByRestingNotch,
                    moves: moves, threadsPerStep: 2, stepReading: reading
                ),
                colouring: recipe.colouring, shape: BraidShapeValues()
            )
        }
        let reference = try #require(recipe.worked(on: stand))
        let referenceMesh = try #require(BraidFamilyDrawing.mesh(for: recipe, on: stand).tubeOfFour)
        let swappedMoves = swapped.map(BraidMove.init(from:to:))
        for other in [
            variant(swappedMoves, .oneStepAnInstant),
            variant(asPrinted.moves, .oneThreadAnInstant),
            variant(swappedMoves, .oneThreadAnInstant),
        ] {
            let worked = try #require(other.worked(on: stand))
            #expect(worked.derivation.courses.map(\.slots) == reference.derivation.courses.map(\.slots))
            let mesh = try #require(BraidFamilyDrawing.mesh(for: other, on: stand).tubeOfFour)
            #expect(mesh.positions.count == referenceMesh.positions.count)
            #expect(BraidMeshHashTests.hash(mesh.positions)
                    == BraidMeshHashTests.hash(referenceMesh.positions))
        }
        #expect(reference.derivation.passingsWithinOneInstant.isEmpty)
    }

    /// **The card shows something at every pixel**, a run or the cell beneath
    /// it: the tube is closed.
    @Test func theCardShowsSomethingEverywhere() throws {
        let worked = try #require(recipe.worked(on: stand))
        let pattern = try #require(RoundTube4SurfacePatternGenerator.generate(
            stand: stand, rounds: worked.derivation.rounds, crossSection: worked.section,
            assignments: recipe.colouring
        ))
        let map = RoundTube4CardImage.shownMap(for: pattern)
        #expect(map.height == 4 * RoundTube4CardImage.pixelsPerColumn)
        #expect(map.shown.allSatisfy { $0 != nil })
    }

    /// **The mesh is the shape it was when it was last set by eye** (Task 054).
    /// Moves only on purpose. It was `0x506f_2561_7c50_30c5` while the bundles
    /// were the eight-thread tube's height and head, which read as gnocchi (the
    /// author, 2026-09-22), and `0x4ae7_8577_341e_6bf1` before their right ends
    /// were pointed and their lean made stronger (the same day); the vertex
    /// count did not change.
    @Test func theMeshIsTheShapeItWas() throws {
        let mesh = try #require(BraidFamilyDrawing.mesh(for: recipe, on: stand).tubeOfFour)
        #expect(mesh.positions.count == 4_560)
        #expect(BraidMeshHashTests.hash(mesh.positions) == 0x05ee_28f8_d5c8_3939)
    }

    // MARK: - The preset

    /// **Four threads offer 丸四つ**, and it is the recipe's own preset.
    @Test func fourThreadsOfferMaruYotsu() throws {
        #expect(BraidPresetCatalog.availablePresets(threadCount: 4) == [BraidPresetCatalog.maruYotsu])
        #expect(BraidMethodCatalog.recipe(for: .maruYotsu4) == recipe)
        #expect(BraidPresetCatalog.maruYotsu.displayName == "丸四つ")
        #expect(BraidPresetCatalog.availablePresets(threadCount: 12).isEmpty)
    }
}
