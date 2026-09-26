import Foundation
import Testing
@testable import Kumihimo

/// Task 008: the eight-bobbin yatsu-kongo braids, S and Z.
///
/// **Since Task 053 the tables are the disk book's p.37 (S) and p.36 (Z)**, each
/// transcribed from its own figure (`BookDiskKongo`): **every thread ends two
/// places round the stand a cycle**, back for S and on for Z. Until then they
/// were book A p.54's picture read with the author's ruling of 2026-09-10, which
/// carried three (`BraidMethodCatalog.yatsuKongoBookAP54Disk`, kept for the
/// comparison).
///
/// **The two reference colourings of Task 008 are no longer reproduced.** They
/// are a black-box simulator's output: a checkerboard needs an odd carry, and the
/// disk book's is even. They are kept, with what the table now makes of them,
/// and with book A's table still making the checkerboard — the disagreement is
/// recorded, not hidden (`docs/tasks/053-yatsu-kongo-gaeshi.md`).
@MainActor
struct YatsuKongoTests {
    private var stand: BraidStand { BraidMethodCatalog.stand8 }

    // MARK: - The table runs

    /// **1.** The table is a cycle of the eight-place stand: eight braiding moves,
    /// one a figure of the book and so one an instant (Task 053), and a closing.
    ///
    /// The closing is empty here, and that is right: every thread is braided every
    /// cycle, so nothing is left over to be tidied back into place. The tidying
    /// moves on the disk carry threads that have already been braided, and a thread
    /// is named by where it rested when the cycle began either way.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func theTableRunsAsACycleOfTheEightPlaceStand(recipe: BraidRecipe) throws {
        let worked = try #require(recipe.worked(on: stand))
        #expect(worked.derivation.threadCount == 8)
        #expect(recipe.notation.braidingMoves.count == 8)
        #expect(recipe.notation.repositioningMoves.count == 8)
        #expect(worked.method.instantCount == 9)
        #expect(worked.method.steps.count == 8)
        #expect(worked.method.steps.allSatisfy { $0.moves.count == 1 })
        #expect(worked.method.closing.moves.isEmpty)
        // **Nothing is lost by laying a pair at once**: its two threads never have
        // to pass each other, so there is no over and under for an order to decide.
        #expect(worked.derivation.passingsWithinOneInstant.isEmpty)
        // A tube: nothing runs along the braid, so there is no fold.
        #expect(worked.derivation.fold == nil)
        #expect(BraidFamily.family(of: worked.derivation) == .roundTube(threads: 8, turning: .oneWay))
        // The stand is found from the table, not named by hand.
        #expect(BraidMethodCatalog.stand(for: recipe) == stand)
    }

    /// **2.** The net move: every thread two places back for S, and two on for Z
    /// (Task 053). **Fixed place by place**, because "it turns" is the claim the
    /// whole table rests on.
    @Test func everyThreadEndsTwoPlacesRoundTheStand() throws {
        let back = try netMove(of: BraidMethodCatalog.yatsuKongoS8Recipe)
        let on = try netMove(of: BraidMethodCatalog.yatsuKongoZ8Recipe)
        #expect(back == [1: 7, 2: 8, 3: 1, 4: 2, 5: 3, 6: 4, 7: 5, 8: 6])
        #expect(on == [1: 3, 2: 4, 3: 5, 4: 6, 5: 7, 6: 8, 7: 1, 8: 2])
        // **A dan moves one thread of every pair** (the book: 1段 = four figures):
        // the first four figures move the threads of one parity of place, the
        // last four the other.
        for recipe in [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe] {
            let worked = try #require(recipe.worked(on: stand))
            let firstDan = worked.method.steps.prefix(4).flatMap(\.moves).map(\.from)
            let secondDan = worked.method.steps.suffix(4).flatMap(\.moves).map(\.from)
            #expect(Set(firstDan.map { $0 % 2 }).count == 1, "\(firstDan)")
            #expect(Set(secondDan.map { $0 % 2 }).count == 1, "\(secondDan)")
            #expect(firstDan[0] % 2 != secondDan[0] % 2)
        }
        // And book A p.54's table, which the app shipped until Task 053, carried
        // three.
        let bookA = try bookAP54Method()
        for step in bookA.steps { for move in step.moves { #expect((move.to - move.from + 8) % 8 == 5) } }
    }

    /// **3.** One cycle drops no thread and makes no second copy of one.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func oneCycleLosesNoThreadAndDuplicatesNone(recipe: BraidRecipe) throws {
        let worked = try #require(recipe.worked(on: stand))
        let cycle = try #require(BraidWorking.cycle(
            of: worked.method, from: BraidStandState.start(on: stand)
        ))
        let ended = try #require(cycle.endState.threadByPosition)
        #expect(Set(ended.keys) == Set(1...8))
        #expect(Set(ended.values) == Set(1...8))
        // Each thread is carried exactly once a cycle.
        let carried = cycle.allCarried.map(\.thread)
        #expect(carried.sorted() == Array(1...8))
    }

    // MARK: - The two reference colourings

    /// **4. The reference simulator's colourings (Task 008), and what they now
    /// show.** The checkerboard colouring came out a checkerboard under book A's
    /// table and still does; **under the disk book's it comes out in stripes along
    /// the braid** — white at every second place, blue and pink changing places
    /// each cycle — because a carry of two keeps a place's parity and a carry of
    /// three flips it. The simulator is a black box; the author chose the book
    /// (Task 053), and this records the disagreement rather than dropping it.
    @Test func theCheckerboardColouringNowComesOutInStripes() throws {
        let checker = BraidReferenceColourings.yatsuKongoChecker
        let grid = try colourGrid(method: BraidMethodCatalog.yatsuKongoS8, colouring: checker)
        #expect(grid.count == 4)
        for row in grid {
            // White holds one parity of place, row after row.
            #expect((0..<8).allSatisfy { (row[$0] == "white") == (grid[0][$0] == "white") }, "\(grid)")
        }
        #expect(grid[1] != grid[0])
        // Book A's table still makes the simulator's checkerboard.
        let bookA = try colourGrid(method: try bookAP54Method(), colouring: checker)
        #expect(bookA[0] == ["white", "blue", "white", "pink", "white", "blue", "white", "pink"])
        #expect(bookA[1] == ["pink", "white", "blue", "white", "pink", "white", "blue", "white"])
    }

    /// The diagonal colouring still comes out a diagonal: every row is the one
    /// before it turned two places round.
    @Test func theDiagonalColouringComesOutADiagonal() throws {
        let grid = try colourGrid(
            method: BraidMethodCatalog.yatsuKongoZ8,
            colouring: BraidReferenceColourings.yatsuKongoDiagonal
        )
        #expect(grid.count == 4)
        for (row, next) in zip(grid, grid.dropFirst() + [grid[0]]) {
            #expect(next == (0..<8).map { row[($0 + 6) % 8] }, "\(grid)")
        }
        #expect(grid[1] != grid[0])
    }

    /// **5. The guard.** Swap the diagonals instead of turning the braid — every
    /// thread to the place opposite, which is the reading the reference colourings
    /// were used to throw out — and **both patterns stop moving.** Every row comes
    /// out the same as the first, so neither a checkerboard nor a diagonal can
    /// appear, whatever the colouring.
    ///
    /// **This is here to show the tests above can fail**, not because anything
    /// should ever braid this way.
    @Test func swappingTheDiagonalsInsteadOfTurningStopsThePatternDead() throws {
        let swapped = diagonalSwap
        for colouring in [BraidReferenceColourings.yatsuKongoChecker,
                          BraidReferenceColourings.yatsuKongoDiagonal] {
            let grid = try colourGrid(method: swapped, colouring: colouring)
            #expect(grid.count == 2)                   // the swap is its own undoing
            #expect(grid.allSatisfy { $0 == grid[0] })
            // ...and the real table does not do that.
            let turning = try colourGrid(
                method: BraidMethodCatalog.yatsuKongoS8, colouring: colouring
            )
            #expect(turning.contains { $0 != turning[0] })
        }
    }

    // MARK: - Z is the mirror of S

    /// **6.** Z is S reflected: every move of every step goes from `9 - from` to
    /// `9 - to`, in the same order. **Since Task 053 each was transcribed from its
    /// own figure** (p.37 and p.36), so this is a check on the two transcriptions,
    /// where it used to be how Z was made.
    @Test func zIsTheMirrorOfS() {
        let s = BraidMethodCatalog.yatsuKongoS8
        let z = BraidMethodCatalog.yatsuKongoZ8
        #expect(s.steps.count == z.steps.count)
        // Dan by dan. **Inside a dan the two books print opposite pairs in
        // different orders** — p.37 starts S with the left and right pairs'
        // mirror images the other way round — and the order inside a dan does not
        // reach the drawing (`RoundTube8SurfaceTests
        // .swappingTheOrderInsideADanDoesNotMoveTheMesh`).
        for dan in 0..<2 {
            let mine = Set(s.steps[(4 * dan)..<(4 * dan + 4)].flatMap(\.moves).map {
                BraidMove(from: 9 - $0.from, to: 9 - $0.to)
            })
            let theirs = Set(z.steps[(4 * dan)..<(4 * dan + 4)].flatMap(\.moves))
            #expect(mine == theirs, "dan \(dan + 1)")
        }
        #expect(z.closing.moves == s.closing.moves.map {
            BraidMove(from: 9 - $0.from, to: 9 - $0.to)
        })
    }

    /// **7.** The two lean opposite ways. The pattern walks round the braid two
    /// slots a cycle for S and two the other way for Z — **the sign of the shift
    /// in the occupancy grid**, read off the threads themselves so no colouring can
    /// hide it.
    @Test func theDiagonalsOfSAndZLeanOppositeWays() throws {
        let sShift = try rowShift(of: BraidMethodCatalog.yatsuKongoS8Recipe)
        let zShift = try rowShift(of: BraidMethodCatalog.yatsuKongoZ8Recipe)
        let s = try #require(sShift)
        let z = try #require(zShift)
        #expect(s == 2)
        #expect(z == 8 - 2)
        #expect((s + z) % 8 == 0)
    }

    /// **8.** Offered for eight threads and for nothing else.
    @Test func theyAreOfferedOnlyForEightThreads() {
        for count in [4, 12, 16] {
            #expect(!BraidPresetCatalog.availablePresets(threadCount: count)
                .contains { [.yatsuKongoS8, .yatsuKongoZ8, .yatsuKongoGaeshi8].contains($0.id) })
        }
        // 返し組 beside them since Task 053 (`YatsuKongoGaeshiTests`), and
        // 江戸八つ since Task 009 (`EdoYatsuTests`).
        #expect(BraidPresetCatalog.availablePresets(threadCount: 8)
                == [BraidPresetCatalog.yatsuKongoS, BraidPresetCatalog.yatsuKongoZ,
                    BraidPresetCatalog.yatsuKongoGaeshi, BraidPresetCatalog.edoYatsu])
    }

    /// **The figure needs no drawer.** It was the whole of what this braid could
    /// show while the eight-thread family had none; Task 031 gave the family a
    /// drawer, and the figure is unchanged by that, which is the point — a figure
    /// is built from the move table and a colouring and from nothing else.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func theFigureIsDrawnWhateverTheFamilyHasForADrawer(recipe: BraidRecipe) throws {
        #expect(BraidFamilyDrawing.drawer(for: recipe) == RoundTube8SurfaceMesh.family)
        guard case let .tube(figure) = BraidPatternForRecipe.figure(
            for: recipe, assignments: recipe.colouring
        ) else {
            Issue.record("八つ金剛の模様図は筒として描けるはずです")
            return
        }
        #expect(figure.columns.count == 8)
        #expect(figure.rowCount == 4)
        #expect(!figure.unsettled.isEmpty)
    }

    /// **What the two braids ship is book A's own colouring, and it is the same
    /// one for both** (the author, 2026-09-10): p.54 for S, p.55's a for Z, each
    /// printing thread 105 yellow on the upright pair and 108 orange on the flat
    /// pair.
    ///
    /// **Colouring them alike is the point.** With the same threads in the same
    /// places, the only difference left between S and Z is which way the spiral
    /// leans — which is what `theDiagonalsOfSAndZLeanOppositeWays` measures.
    @Test func bothBraidsShipBookAsOwnColouringAndItIsTheSameOne() {
        // Pair by pair since Task 055: 1・2 and 5・6, 3・4 and 7・8.
        let upright = ["amerry-f-501", "amerry-f-501", "amerry-f-501", "amerry-f-501"]      // 1, 2, 5, 6
        let flat = ["amerry-f-504", "amerry-f-504", "amerry-f-504", "amerry-f-504"]         // 3, 4, 7, 8
        for colouring in [BraidMethodCatalog.yatsuKongoS8Recipe.colouring,
                          BraidMethodCatalog.yatsuKongoZ8Recipe.colouring] {
            let byPosition = Dictionary(uniqueKeysWithValues: colouring.map {
                ($0.position, $0.colorID.rawValue)
            })
            #expect([1, 2, 5, 6].map { byPosition[$0] ?? "" } == upright)
            #expect([3, 4, 7, 8].map { byPosition[$0] ?? "" } == flat)
        }
        #expect(BraidMethodCatalog.yatsuKongoS8Recipe.colouring
                == BraidMethodCatalog.yatsuKongoZ8Recipe.colouring)
    }

    /// What is open is said, not hidden: the tables' source is not the source of
    /// record.
    @Test func whatIsNotSettledIsCarriedOnTheBraid() throws {
        let section = BraidMethodCatalog.yatsuKongoS8Recipe.crossSection(on: stand)
        let note = try #require(section.unsettled)
        #expect(note.contains("not the source of record"))
        // Nothing about the shape has been measured, and nothing pretends otherwise.
        #expect(BraidMethodCatalog.yatsuKongoS8Recipe.shape.all.isEmpty)
        #expect(BraidMethodCatalog.yatsuKongoZ8Recipe.shape.all.isEmpty)
    }

    // MARK: - Working the grids out

    /// Where each thread rests at the end of one cycle, by where it rested at the
    /// start.
    private func netMove(of recipe: BraidRecipe) throws -> [Int: Int] {
        let worked = try #require(recipe.worked(on: stand))
        var result = [Int: Int]()
        for step in worked.method.steps {
            for move in step.moves { result[move.from] = move.to }
        }
        return result
    }

    /// One row a cycle, one cell a slot round the braid: **the colour resting
    /// there**, which is the face pattern (`docs/architecture.md`, 組み台の力学).
    private func colourGrid(
        method: BraidMethod, colouring: [ThreadAssignment]
    ) throws -> [[String]] {
        let grid = try threadGrid(method: method)
        let colours = Dictionary(uniqueKeysWithValues: colouring.map {
            ($0.position, $0.colorID.rawValue)
        })
        return try grid.map { row in try row.map { try #require(colours[$0]) } }
    }

    private func threadGrid(method: BraidMethod) throws -> [[Int]] {
        let section = BraidCrossSection.tube(of: stand)
        let rows = try #require(BraidWorking.repeatCycleCount(of: method, on: stand))
        let occupancy = try #require(BraidOccupancy.history(
            of: method, on: stand, crossSection: section, cycles: rows
        ))
        // The closing pairs nothing here, so every slot is a column of its own.
        let columns = try #require(occupancy.columns(.landing))
        #expect(columns == Array(0..<8))
        return try #require(occupancy.grid(atColumns: columns, rows: rows))
    }

    /// How far round the braid the pattern walks in one cycle, or `nil` when the
    /// rows are not one rotation of the first.
    private func rowShift(of recipe: BraidRecipe) throws -> Int? {
        let worked = try #require(recipe.worked(on: stand))
        let grid = try threadGrid(method: worked.method)
        guard grid.count > 1 else { return nil }
        return (0..<8).first { shift in
            grid[1] == (0..<8).map { grid[0][($0 + shift) % 8] }
        }
    }

    /// The reading the reference colourings threw out: every thread straight across
    /// to the place opposite, worked in the same order as the real table.
    private var diagonalSwap: BraidMethod {
        let order = [8, 4, 2, 6, 1, 5, 7, 3]
        return BraidMethod(
            id: "yatsu-kongo-8-with-the-diagonals-swapped",
            standID: stand.id,
            steps: order.map {
                BraidStep(name: "swap \($0)", moves: [BraidMove(from: $0, to: ($0 + 3) % 8 + 1)])
            },
            closing: BraidStep(name: "closing", moves: [])
        )
    }

    /// Book A p.54's table, which the app shipped until Task 053.
    private func bookAP54Method() throws -> BraidMethod {
        try #require(BraidMethodCatalog.yatsuKongoBookAP54Disk.method(
            id: "yatsu-kongo-s-8-book-a-p54", standID: stand.id,
            stepNames: BraidMethodCatalog.yatsuKongoStepNames
        ))
    }
}
