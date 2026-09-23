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
            source: "test", placeOneOnward: [1, 2, 9, 10, 17, 18, 25, 26],
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
    /// (the author, 2026-09-22). Each cell leans the way its thread was carried:
    /// S's way in the S part, Z's in the Z part.
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
        // Both leans, as many of each: three cycles of each part.
        #expect(pattern.leanBySegment.filter { $0 < 0 }.count == 24)
        #expect(pattern.leanBySegment.filter { $0 > 0 }.count == 24)
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
        // The book's colouring (p.38 組みはじめ): slits 1・2 and 17・18 orange,
        // 9・10 and 25・26 pink, pair by pair at places 1・2 … 7・8.
        let byPosition = Dictionary(uniqueKeysWithValues: recipe.colouring.map { ($0.position, $0.colorID.rawValue) })
        #expect([1, 2, 5, 6].map { byPosition[$0] } == ["orange", "orange", "orange", "orange"])
        #expect([3, 4, 7, 8].map { byPosition[$0] } == ["pink", "pink", "pink", "pink"])
    }

    // MARK: - Every colour turns back (Task 055)

    /// **Every colour turns back as one line** (the author, 2026-09-23:
    /// 「全ての色が折り返す」): whichever pair of the stand's places 1・2, 3・4,
    /// 5・6, 7・8 a colour is laid on, its two threads stand side by side at every
    /// cycle's end, through the S part, the hand-over and the Z part — read off
    /// the occupancy history, so the drawing cannot hide it.
    ///
    /// **And the pairs are where that holds, not a choice of colouring**: the
    /// same check over two threads that are not one pair (places 2 and 3) finds
    /// them apart after the turn. Until Task 055 the book's pairs stood at
    /// 8・1, 2・3 …, and it was the author's 1・2 that came apart.
    @Test func everyPairStaysOneLineThroughTheTurn() throws {
        let worked = try worked()
        let occupancy = try #require(BraidOccupancy.history(
            ofRounds: worked.derivation.rounds, on: stand,
            crossSection: worked.section, cycles: worked.derivation.repeatCycleCount
        ))
        let columns = try #require(occupancy.columns(.landing))
        let grid = try #require(occupancy.grid(atColumns: columns, rows: worked.derivation.repeatCycleCount))
        func sideBySide(_ one: Int, _ other: Int, in row: [Int]) -> Bool {
            guard let a = row.firstIndex(of: one), let b = row.firstIndex(of: other) else { return false }
            let gap = abs(a - b)
            return gap == 1 || gap == row.count - 1
        }
        for pair in [(1, 2), (3, 4), (5, 6), (7, 8)] {
            for (index, row) in grid.enumerated() {
                #expect(sideBySide(pair.0, pair.1, in: row), "places \(pair.0)・\(pair.1), cycle \(index)")
            }
        }
        #expect(grid.contains { !sideBySide(2, 3, in: $0) })
    }

    /// **On the drawing too, a pair is one line all the way through** (Task
    /// 055): for S, Z and 返し組, every run whose partner is laid half a cycle
    /// after it, beside it, leans toward that partner — so its tail goes under
    /// a run of its own colour line, and a colour laid on a pair turns back
    /// without a fragment of another colour. Until Task 055 the runs leaned the
    /// carry's way, which in Z and in the last cycle before each turn put the
    /// tail under the next pair.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe,
                      BraidMethodCatalog.yatsuKongoGaeshi8Recipe])
    func everyRunLeansTowardThePartnerLaidAfterIt(recipe: BraidRecipe) throws {
        let worked = try #require(recipe.worked(on: stand))
        let drawn = try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, rounds: worked.derivation.rounds,
            crossSection: worked.section, assignments: recipe.colouring
        ))
        let rows = Float(drawn.rowCount)
        let partner = [1: 2, 2: 1, 3: 4, 4: 3, 5: 6, 6: 5, 7: 8, 8: 7]
        let cells = drawn.surface.segments
        var leading = 0
        for (index, cell) in cells.enumerated() {
            let place = Int((cell.centerlineStart.x * 8).rounded(.down))
            let start = cell.centerlineStart.y * rows
            // The partner's run half a cycle later, beside it.
            guard let later = cells.first(where: { other in
                guard other.threadPosition == partner[cell.threadPosition] else { return false }
                let gap = (other.centerlineStart.y * rows - start - 0.5)
                    .truncatingRemainder(dividingBy: rows)
                return abs(gap) < 1e-4 || abs(abs(gap) - rows) < 1e-4
            }) else { continue }
            let there = Int((later.centerlineStart.x * 8).rounded(.down))
            let side = ((there - place) % 8 + 8) % 8
            guard side == 1 || side == 7 else { continue }
            leading += 1
            #expect(drawn.leanBySegment[index] == (side == 1 ? 1 : -1),
                    "\(recipe.id): thread \(cell.threadPosition) at place \(place + 1), cycle \(start)")
        }
        #expect(leading == cells.count / 2)
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
