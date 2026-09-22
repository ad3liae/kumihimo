import Foundation
import Testing
@testable import Kumihimo

/// Task 053: **八つ金剛返し組 (8S&Z-スパイラル)**, from the disk book's p.38-39 —
/// six dan of S, a hand-over, six dan of Z, a hand-over back.
///
/// What holds it up: the book's own numbers (p.38) run on its disk and come back
/// to the starting slits after one 工程 (p.39); the S part is the S table and the
/// Z part the Z table; and **the pattern walks one way round the braid for the S
/// part and the other way for the Z part** — the く the author asked for — read
/// off the occupancy history, so no colouring can hide it.
@MainActor
struct YatsuKongoGaeshiTests {

    private var stand: BraidStand { BraidMethodCatalog.stand8 }
    private var recipe: BraidRecipe { BraidMethodCatalog.yatsuKongoGaeshi8Recipe }

    private func worked() throws -> (method: BraidMethod, section: BraidCrossSection,
                                     derivation: BraidDerivation) {
        try #require(recipe.worked(on: stand))
    }

    /// Every carry of one table, as how far round it took its thread.
    private func carries(_ method: BraidMethod) -> [Int] {
        method.steps.flatMap(\.moves).map {
            RoundTube8SurfacePatternGenerator.shortestWayRound(from: $0.from, to: $0.to, around: 8)
        }
    }

    // MARK: - The table

    /// **One 工程 is eight tables and brings every thread back to the slit it
    /// began at** (p.39: 「1工程終了 … スリット番号は、必ず【組みはじめ】と同じ」).
    /// The derivation finds the repeat by working the tables in turn; it is not
    /// told.
    @Test func oneKouteiBringsEveryThreadHome() throws {
        let worked = try worked()
        #expect(recipe.rounds.count == 8)
        #expect(worked.derivation.rounds.count == 8)
        #expect(worked.derivation.repeatCycleCount == 8)
        for course in worked.derivation.courses {
            #expect(course.slots.first == course.slots.last)
        }
        #expect(worked.derivation.fold == nil)
        #expect(BraidFamily.family(of: worked.derivation) == .roundTube(threads: 8))
        #expect(BraidMethodCatalog.stand(for: recipe) == stand)
    }

    /// **Three cycles of S, the hand-over, three of Z, the hand-over back.** Each
    /// S cycle carries every thread two places back and each Z cycle two on, as
    /// the S and Z tables do. **Each hand-over moves four threads two places the
    /// way the part before it went** — read in the order round the braid, the
    /// book's 8→6 is a dan's worth of S again, and 32→2 a dan's worth of Z
    /// (`BookDiskKongo`).
    @Test func theSPartIsSAndTheZPartIsZ() throws {
        let worked = try worked()
        let rounds = worked.derivation.rounds
        for index in [0, 1, 2] { #expect(carries(rounds[index]) == Array(repeating: -2, count: 8)) }
        #expect(carries(rounds[3]) == Array(repeating: -2, count: 4))
        for index in [4, 5, 6] { #expect(carries(rounds[index]) == Array(repeating: 2, count: 8)) }
        #expect(carries(rounds[7]) == Array(repeating: 2, count: 4))
        // Dan by dan, the S part is the S table itself (p.37, the disk turned).
        let s = BraidMethodCatalog.yatsuKongoS8
        for dan in 0..<2 {
            #expect(Set(rounds[0].steps[(4 * dan)..<(4 * dan + 4)].flatMap(\.moves))
                    == Set(s.steps[(4 * dan)..<(4 * dan + 4)].flatMap(\.moves)), "dan \(dan + 1)")
        }
        // Every table is a cycle of the stand on its own.
        for round in rounds {
            #expect(BraidWorking.cycle(of: round, from: .start(on: stand)) != nil)
        }
    }

    /// **The book's printed numbers come out of the disk** — the S dan p.38
    /// prints, moved on a notch a dan, and the Z dan moved back — and each
    /// hand-over moves the threads the dan before it moved.
    @Test func theHandOverMovesTheThreadsTheDanBeforeItMoved() throws {
        let worked = try worked()
        let cycles = try #require(BraidWorking.cycles(
            ofRounds: worked.derivation.rounds, on: stand, count: 8
        ))
        func threads(_ cycle: BraidCycle, dan: Int) -> Set<Int> {
            Set(cycle.allCarried.map(\.thread)[(4 * dan)..<(4 * dan + 4)])
        }
        // The last dan of the S part, and the hand-over after it.
        #expect(threads(cycles[2], dan: 1) == Set(cycles[3].allCarried.map(\.thread)))
        #expect(threads(cycles[6], dan: 1) == Set(cycles[7].allCarried.map(\.thread)))
        // On the book's disk: the last S dan (the printed one moved on five
        // notches) lands on 8, 24, 16 and 32, and those are what [4] lifts.
        let lastS = BookDiskKongo.dan([(17, 3), (1, 19), (25, 11), (9, 27)], driftPerDan: 1, times: 5)
        #expect(Set(lastS.map(\.1)) == [8, 16, 24, 32])
    }

    // MARK: - The く

    /// **The pattern walks two places one way a cycle through the S part and two
    /// the other way through the Z part** — rows of the occupancy history, one a
    /// table, each the one before turned round. That turning back every six dan
    /// is the く. Read off the threads, so no colouring can hide it.
    @Test func thePatternWalksBackThroughSAndOnThroughZ() throws {
        let worked = try worked()
        let occupancy = try #require(BraidOccupancy.history(
            ofRounds: worked.derivation.rounds, on: stand,
            crossSection: worked.section, cycles: 8
        ))
        let columns = try #require(occupancy.columns(.landing))
        let grid = try #require(occupancy.grid(atColumns: columns, rows: 8))
        func turned(_ row: [Int], by shift: Int) -> [Int] { (0..<8).map { row[(($0 + shift) % 8 + 8) % 8] } }
        // S: each row is the one before turned two places.
        for row in 0..<3 { #expect(grid[row + 1] == turned(grid[row], by: 2), "S cycle \(row + 1)") }
        // Z: turned two places the other way.
        for row in 4..<7 { #expect(grid[row + 1] == turned(grid[row], by: -2), "Z cycle \(row - 3)") }
        // And back where it began at the end of the 工程.
        let last = try #require(occupancy.grid(atColumns: columns, rows: 9)?.last)
        #expect(last == grid[0])
    }

    // MARK: - The drawing

    /// **Seven cycles to a repeat**: six of S and Z, and the two hand-overs a dan
    /// — half a cycle — each. **At a turn the stagger slips half a pitch**: the
    /// places the hand-over moves took a thread in the dan before too, so their
    /// cells there are half a cycle long, and the other places' a cycle and a
    /// half. Everywhere else a cell is a cycle. Each cell leans the way its
    /// thread was carried: S's way in the S part and after its hand-over, Z's in
    /// the Z part and after its own.
    @Test func theTurnIsHalfACycleAndACycleAndAHalf() throws {
        let worked = try worked()
        let pattern = try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, rounds: worked.derivation.rounds,
            crossSection: worked.section, assignments: recipe.colouring
        ))
        #expect(pattern.rowCount == 7)
        #expect(pattern.columnsCarried == -2)
        let rows = Float(pattern.rowCount)
        let lengths = pattern.surface.segments.map {
            (($0.centerlineEnd.y - $0.centerlineStart.y) * rows * 2).rounded() / 2
        }
        #expect(lengths.filter { $0 == 0.5 }.count == 8)
        #expect(lengths.filter { $0 == 1.5 }.count == 8)
        #expect(lengths.allSatisfy { [0.5, 1, 1.5].contains($0) })
        // Every place's cells run end to end over exactly one repeat.
        for place in 0..<8 {
            let cells = pattern.surface.segments.filter { Int(($0.centerlineStart.x * 8).rounded(.down)) == place }
            let total = cells.reduce(Float(0)) { $0 + $1.centerlineEnd.y - $1.centerlineStart.y }
            #expect(abs(total - 1) < 1e-4, "place \(place + 1)")
        }
        // Both leans, and as many of each: the S part and its hand-over, the Z
        // part and its own, are the same length.
        #expect(pattern.leanBySegment.count == pattern.surface.segments.count)
        #expect(pattern.leanBySegment.filter { $0 < 0 }.count == pattern.leanBySegment.filter { $0 > 0 }.count)
    }

    /// **The S part is drawn as S draws it**: over the first three cycles, the
    /// same thread stands at the same place from the same moment, and leans the
    /// same way.
    @Test func theSPartIsDrawnAsSDrawsIt() throws {
        let worked = try worked()
        let gaeshi = try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, rounds: worked.derivation.rounds,
            crossSection: worked.section, assignments: recipe.colouring
        ))
        let sRecipe = BraidMethodCatalog.yatsuKongoS8Recipe
        let sWorked = try #require(sRecipe.worked(on: stand))
        let s = try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, method: sWorked.method, crossSection: sWorked.section,
            assignments: recipe.colouring
        ))
        func cells(_ pattern: RoundTube8SurfacePattern, upTo cycles: Float) -> Set<String> {
            let rows = Float(pattern.rowCount)
            return Set(pattern.surface.segments.enumerated().compactMap { index, cell in
                let start = cell.centerlineStart.y * rows
                let end = cell.centerlineEnd.y * rows
                guard start > 0, end <= cycles + 1e-4 else { return nil }
                return "\(cell.threadPosition)@\(cell.centerlineStart.x):\(start)-\(end) \(pattern.leanBySegment[index])"
            })
        }
        #expect(cells(gaeshi, upTo: 3) == cells(s, upTo: 3))
        #expect(!cells(s, upTo: 3).isEmpty)
    }

    // MARK: - Offered

    /// Offered for eight threads, beside S and Z, and drawn by the eight-thread
    /// tube's drawer.
    @Test func itIsOfferedForEightThreadsAndDrawnByTheTube() {
        #expect(BraidPresetCatalog.availablePresets(threadCount: 8).map(\.id)
                == [.yatsuKongoS8, .yatsuKongoZ8, .yatsuKongoGaeshi8])
        #expect(BraidMethodCatalog.recipe(for: .yatsuKongoGaeshi8) == recipe)
        #expect(BraidFamilyDrawing.drawer(for: recipe) == RoundTube8SurfaceMesh.family)
        // The book's colouring: pink upright, orange flat.
        let byPosition = Dictionary(uniqueKeysWithValues: recipe.colouring.map { ($0.position, $0.colorID.rawValue) })
        #expect([8, 1, 4, 5].map { byPosition[$0] } == ["pink", "pink", "pink", "pink"])
        #expect([2, 3, 6, 7].map { byPosition[$0] } == ["orange", "orange", "orange", "orange"])
    }

    // MARK: - The derivation with tables in turn

    /// **A list of one table is the table**: the derivation, the cycles and the
    /// repeat are what they were. And a list only repeats a whole number of times
    /// through: S then Z comes back after one of each, not after S alone.
    @Test func tablesInTurnReduceToOneTableAndRepeatWholeLists() throws {
        let s = BraidMethodCatalog.yatsuKongoS8
        let z = BraidMethodCatalog.yatsuKongoZ8
        let one = try #require(BraidDerivation.derive(stand: stand, method: s))
        let list = try #require(BraidDerivation.derive(stand: stand, rounds: [s]))
        #expect(one == list)
        #expect(BraidWorking.repeatCycleCount(ofRounds: [s, z], on: stand) == 2)
        #expect(BraidWorking.repeatCycleCount(of: s, on: stand) == 4)
        // S three times and Z three times — a 返し組 without its hand-overs —
        // comes back too, in six.
        #expect(BraidWorking.repeatCycleCount(ofRounds: [s, s, s, z, z, z], on: stand) == 6)
    }
}
