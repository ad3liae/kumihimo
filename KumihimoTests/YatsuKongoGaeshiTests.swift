import Foundation
import Testing
@testable import Kumihimo

/// Task 053: **八つ金剛返し組 (8S&Z-スパイラル)**, from the disk book's p.38-39 —
/// six dan of S, a hand-over, six dan of Z, a hand-over back.
///
/// What holds it up: the book's own numbers (p.38) run on its disk and come back
/// to the starting slits after one 工程 (p.39); the S part is the S table and the
/// Z part the Z table; **the braid's stitches are the same all through — only
/// the pattern turns** (the author, 2026-09-22: 「模様だけが変わるもの」); and the
/// pattern walks one way round the braid for the S part and the other way for
/// the Z part — the く — read off the occupancy history, so no colouring can hide
/// it.
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

    /// **One 工程 is six tables and brings every thread back to the slit it
    /// began at** (p.39: 「1工程終了 … スリット番号は、必ず【組みはじめ】と同じ」).
    /// The derivation finds the repeat by working the tables in turn; it is not
    /// told.
    @Test func oneKouteiBringsEveryThreadHome() throws {
        let worked = try worked()
        #expect(recipe.rounds.count == 6)
        #expect(worked.derivation.rounds.count == 6)
        #expect(worked.derivation.repeatCycleCount == 6)
        for course in worked.derivation.courses {
            #expect(course.slots.first == course.slots.last)
        }
        #expect(worked.derivation.fold == nil)
        #expect(BraidFamily.family(of: worked.derivation) == .roundTube(threads: 8))
        #expect(BraidMethodCatalog.stand(for: recipe) == stand)
    }

    /// **Three cycles of S and three of Z, each hand-over part of the dan before
    /// it.** Each cycle carries every thread two places, back for S and on for
    /// Z, as the S and Z tables do — except that in the last cycle of each part
    /// the four threads of its second dan go four: **the hand-over lifts the
    /// threads that dan has just laid** (p.38 [4] 8→6…, [8] 32→2…) and, read in
    /// the order round the braid, lays them two places further the same way.
    /// No thread is braided twice in a cycle, and no layer is added.
    @Test func theSPartIsSAndTheZPartIsZ() throws {
        let worked = try worked()
        let rounds = worked.derivation.rounds
        for index in [0, 1] { #expect(carries(rounds[index]) == Array(repeating: -2, count: 8)) }
        // Four places is half a turn, which has no shorter way round: it reads
        // as +4 either way.
        #expect(carries(rounds[2]) == Array(repeating: -2, count: 4) + Array(repeating: 4, count: 4))
        for index in [3, 4] { #expect(carries(rounds[index]) == Array(repeating: 2, count: 8)) }
        #expect(carries(rounds[5]) == Array(repeating: 2, count: 4) + Array(repeating: 4, count: 4))
        // Dan by dan, the S part is the S table itself (p.37, the disk turned).
        let s = BraidMethodCatalog.yatsuKongoS8
        for dan in 0..<2 {
            #expect(Set(rounds[0].steps[(4 * dan)..<(4 * dan + 4)].flatMap(\.moves))
                    == Set(s.steps[(4 * dan)..<(4 * dan + 4)].flatMap(\.moves)), "dan \(dan + 1)")
        }
        // Every table is a cycle of the stand on its own, braiding all eight.
        for round in rounds {
            #expect(BraidWorking.cycle(of: round, from: .start(on: stand)) != nil)
            #expect(round.steps.count == 8)
        }
        // On the book's disk: the last S dan (the printed one moved on five
        // notches) lands on 8, 24, 16 and 32, and those are what [4] lifts.
        let lastS = BookDiskKongo.dan([(17, 3), (1, 19), (25, 11), (9, 27)], driftPerDan: 1, times: 5)
        #expect(Set(lastS.map(\.1)) == [8, 16, 24, 32])
    }

    /// **The reading is guarded**: a step that lifts a thread laid earlier than
    /// the step just before it is refused, not folded in.
    @Test func aThreadLaidEarlierCannotBeLiftedAgainInTheSameCycle() {
        let s = [(17, 3), (1, 19), (25, 11), (9, 27)]
        // After two dan, lift a thread the first dan laid (notch 3 is where
        // 17 went; the second dan has moved on a notch).
        let refused = BookDiskKongo.rounds(
            source: "test", placeOneOnward: [2, 9, 10, 17, 18, 25, 26, 1],
            rounds: [[s, BookDiskKongo.dan(s, driftPerDan: 1, times: 1), [(3, 5)]]]
        )
        #expect(refused == nil)
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
            crossSection: worked.section, cycles: 6
        ))
        let columns = try #require(occupancy.columns(.landing))
        let grid = try #require(occupancy.grid(atColumns: columns, rows: 6))
        func turned(_ row: [Int], by shift: Int) -> [Int] { (0..<8).map { row[(($0 + shift) % 8 + 8) % 8] } }
        // S: each row is the one before turned two places.
        for row in 0..<2 { #expect(grid[row + 1] == turned(grid[row], by: 2), "S cycle \(row + 1)") }
        // Z: turned two places the other way.
        for row in 3..<5 { #expect(grid[row + 1] == turned(grid[row], by: -2), "Z cycle \(row - 2)") }
        // And back where it began at the end of the 工程.
        let last = try #require(occupancy.grid(atColumns: columns, rows: 7)?.last)
        #expect(last == grid[0])
    }

    // MARK: - The drawing

    /// **The stitches are the S and Z braids' own all the way through**: six
    /// cycles to a repeat, every cell a cycle long, every place half a pitch
    /// from the next — the turn changes which thread is where, not the lattice
    /// (the author, 2026-09-22), and every run leans the same way.
    @Test func theStitchesDoNotChangeOnlyThePattern() throws {
        let worked = try worked()
        let pattern = try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, rounds: worked.derivation.rounds,
            crossSection: worked.section, assignments: recipe.colouring
        ))
        #expect(pattern.rowCount == 6)
        #expect(pattern.columnsCarried == -2)
        let rows = Float(pattern.rowCount)
        #expect(pattern.surface.segments.count == 48)
        for cell in pattern.surface.segments {
            #expect(abs((cell.centerlineEnd.y - cell.centerlineStart.y) * rows - 1) < 1e-4)
        }
        // Half a pitch from one place to the next, as S has it.
        let sRecipe = BraidMethodCatalog.yatsuKongoS8Recipe
        let sWorked = try #require(sRecipe.worked(on: stand))
        let s = try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, method: sWorked.method, crossSection: sWorked.section,
            assignments: recipe.colouring
        ))
        func starts(_ pattern: RoundTube8SurfacePattern) -> Set<String> {
            let rows = Float(pattern.rowCount)
            return Set(pattern.surface.segments.map {
                let start = ($0.centerlineStart.y * rows * 2).rounded() / 2
                return "\($0.centerlineStart.x):\(start.truncatingRemainder(dividingBy: 1))"
            })
        }
        #expect(starts(pattern) == starts(s))
        // One stitch all through: every run leans the same way, S part and Z
        // part alike (the author, 2026-09-22).
        #expect(pattern.leanBySegment.allSatisfy { $0 == RoundTube8SurfacePatternGenerator.stitchLean })
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
                == [.yatsuKongoS8, .yatsuKongoZ8, .yatsuKongoGaeshi8, .edoYatsu8])
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
