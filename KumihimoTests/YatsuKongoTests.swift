import Foundation
import Testing
@testable import Kumihimo

/// Task 008: the eight-bobbin yatsu-kongo braids, S and Z.
///
/// **The move table is not a copy of a printed table.** Book C's figure for this
/// braid is not to hand; the table is book A p54's picture read with the author's
/// ruling of 2026-09-10 on where a carried thread lands (`docs/architecture.md`,
/// 詰め直しの入り方). What that ruling settles is the net move: **every thread ends
/// three places anticlockwise of where it began**, so the braid turns, rather than
/// the diagonal pairs simply swapping, which would leave it standing still.
///
/// These tests hold that reading up against the two reference colourings recorded
/// in `docs/tasks/008-yatsu-kongo-8.md` — a checkerboard and a diagonal — and
/// against the alternative it displaced.
@MainActor
struct YatsuKongoTests {
    private var stand: BraidStand { BraidMethodCatalog.stand8 }

    // MARK: - The table runs

    /// **1.** The table is a cycle of the eight-place stand: eight braiding moves,
    /// each its own instant, and a closing.
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
        #expect(worked.method.closing.moves.isEmpty)
        // A tube: nothing runs along the braid, so there is no fold.
        #expect(worked.derivation.fold == nil)
        #expect(BraidFamily.family(of: worked.derivation) == .roundTube(threads: 8))
        // The stand is found from the table, not named by hand.
        #expect(BraidMethodCatalog.stand(for: recipe) == stand)
    }

    /// **2.** The net move: every thread three places anticlockwise for S, and three
    /// clockwise for Z. **Fixed place by place**, because "it turns" is the claim
    /// the whole table rests on.
    @Test func everyThreadEndsThreePlacesRoundTheStand() throws {
        let anticlockwise = try netMove(of: BraidMethodCatalog.yatsuKongoS8Recipe)
        let clockwise = try netMove(of: BraidMethodCatalog.yatsuKongoZ8Recipe)
        #expect(anticlockwise == [1: 6, 2: 7, 3: 8, 4: 1, 5: 2, 6: 3, 7: 4, 8: 5])
        #expect(clockwise == [1: 4, 2: 5, 3: 6, 4: 7, 5: 8, 6: 1, 7: 2, 8: 3])
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

    /// **4.** The checkerboard colouring comes out a checkerboard and the diagonal
    /// one comes out a diagonal — **as the derivation works them out**, not as the
    /// task document worked them out by hand.
    ///
    /// The rows here run the other way from the grid printed in
    /// `docs/tasks/008-yatsu-kongo-8.md` for S and the same way for Z, which is the
    /// freedom a tube has and nothing more: it has no origin and no printed
    /// direction, so which way up it is held is not fixed
    /// (`docs/architecture.md`, 一致は偶然ではない).
    @Test func theCheckerboardColouringComesOutACheckerboard() throws {
        let grid = try colourGrid(of: BraidMethodCatalog.yatsuKongoS8Recipe)
        #expect(grid == [
            ["white", "blue", "white", "pink", "white", "blue", "white", "pink"],
            ["pink", "white", "blue", "white", "pink", "white", "blue", "white"],
            ["white", "pink", "white", "blue", "white", "pink", "white", "blue"],
            ["blue", "white", "pink", "white", "blue", "white", "pink", "white"],
            ["white", "blue", "white", "pink", "white", "blue", "white", "pink"],
            ["pink", "white", "blue", "white", "pink", "white", "blue", "white"],
            ["white", "pink", "white", "blue", "white", "pink", "white", "blue"],
            ["blue", "white", "pink", "white", "blue", "white", "pink", "white"],
        ])
    }

    @Test func theDiagonalColouringComesOutADiagonal() throws {
        let grid = try colourGrid(of: BraidMethodCatalog.yatsuKongoZ8Recipe)
        #expect(grid == [
            ["green", "yellow", "white", "white", "green", "yellow", "white", "white"],
            ["yellow", "white", "white", "green", "yellow", "white", "white", "green"],
            ["white", "white", "green", "yellow", "white", "white", "green", "yellow"],
            ["white", "green", "yellow", "white", "white", "green", "yellow", "white"],
            ["green", "yellow", "white", "white", "green", "yellow", "white", "white"],
            ["yellow", "white", "white", "green", "yellow", "white", "white", "green"],
            ["white", "white", "green", "yellow", "white", "white", "green", "yellow"],
            ["white", "green", "yellow", "white", "white", "green", "yellow", "white"],
        ])
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
        for colouring in [BraidMethodCatalog.yatsuKongoS8Colouring,
                          BraidMethodCatalog.yatsuKongoZ8Colouring] {
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
    /// `9 - to`, in the same order. **Nothing here was transcribed twice**, which is
    /// the point of making Z by reflecting the table rather than writing it out.
    @Test func zIsTheMirrorOfS() {
        let s = BraidMethodCatalog.yatsuKongoS8
        let z = BraidMethodCatalog.yatsuKongoZ8
        #expect(s.steps.count == z.steps.count)
        for (mine, theirs) in zip(s.steps, z.steps) {
            #expect(theirs.moves == mine.moves.map {
                BraidMove(from: 9 - $0.from, to: 9 - $0.to)
            })
        }
        #expect(z.closing.moves == s.closing.moves.map {
            BraidMove(from: 9 - $0.from, to: 9 - $0.to)
        })
        // And on the disk the two tables are the same table, reflected.
        #expect(BraidMethodCatalog.yatsuKongoZDisk.moves
                == BraidMethodCatalog.yatsuKongoSDisk.moves.map {
                    BraidMove(from: notchAcross($0.from), to: notchAcross($0.to))
                })
    }

    /// **7.** The two lean opposite ways. The pattern walks round the braid three
    /// slots a cycle for S and three the other way for Z — **the sign of the shift
    /// in the occupancy grid**, read off the threads themselves so no colouring can
    /// hide it.
    @Test func theDiagonalsOfSAndZLeanOppositeWays() throws {
        let sShift = try rowShift(of: BraidMethodCatalog.yatsuKongoS8Recipe)
        let zShift = try rowShift(of: BraidMethodCatalog.yatsuKongoZ8Recipe)
        let s = try #require(sShift)
        let z = try #require(zShift)
        #expect(s == 3)
        #expect(z == 8 - 3)
        #expect((s + z) % 8 == 0)
    }

    /// **8.** Offered for eight threads and for nothing else.
    @Test func theyAreOfferedOnlyForEightThreads() {
        for count in [4, 12, 16] {
            #expect(!BraidPresetCatalog.availablePresets(threadCount: count)
                .contains { $0.id == .yatsuKongoS8 || $0.id == .yatsuKongoZ8 })
        }
        #expect(BraidPresetCatalog.availablePresets(threadCount: 8)
                == [BraidPresetCatalog.yatsuKongoS, BraidPresetCatalog.yatsuKongoZ])
    }

    /// **The eight-thread family has no drawer**, so there is no solid braid — and
    /// the figure needs none, so there is still a pattern to look at.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func nothingDrawsTheEightThreadFamilyAndTheFigureDoesNotCare(recipe: BraidRecipe) throws {
        #expect(BraidFamilyDrawing.drawer(for: recipe) == nil)
        #expect(BraidFamilyDrawing.drawing(for: recipe, on: stand) == nil)
        guard case let .tube(figure) = BraidPatternForRecipe.figure(
            for: recipe, assignments: recipe.colouring
        ) else {
            Issue.record("八つ金剛の模様図は筒として描けるはずです")
            return
        }
        #expect(figure.columns.count == 8)
        #expect(figure.rowCount == 8)
        #expect(!figure.unsettled.isEmpty)
    }

    /// What is open is said, not hidden: which thread of a pair goes first.
    @Test func whatIsNotSettledIsCarriedOnTheBraid() throws {
        let section = BraidMethodCatalog.yatsuKongoS8Recipe.crossSection(on: stand)
        let note = try #require(section.unsettled)
        #expect(note.contains("carried first"))
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

    private func colourGrid(of recipe: BraidRecipe) throws -> [[String]] {
        let worked = try #require(recipe.worked(on: stand))
        return try colourGrid(method: worked.method, colouring: recipe.colouring)
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

    /// Notch `n` reflected in the line through the mark, which is what carries
    /// position `p` to position `9 - p`.
    private func notchAcross(_ notch: Int) -> Int {
        let raw = (30 - notch) % 32
        return raw <= 0 ? raw + 32 : raw
    }
}
