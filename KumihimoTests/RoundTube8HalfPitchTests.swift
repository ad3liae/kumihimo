import Foundation
import simd
import Testing
@testable import Kumihimo

/// Task 048: **the bundles of the eight-thread tube are staggered half a pitch
/// from one place round the braid to the next**, so the braid is a clean spiral
/// (the author: "never a whole pitch apart").
///
/// A pitch `P` is the distance along the braid between corresponding points of
/// two bundles in a row at one place — one cycle. The point read is each
/// bundle's belly, the middle of its widest stretch, off the cells the product
/// generates.
@MainActor
struct RoundTube8HalfPitchTests {

    private var stand: BraidStand { BraidMethodCatalog.stand8 }

    private func worked(_ recipe: BraidRecipe) throws -> (method: BraidMethod, section: BraidCrossSection) {
        let worked = try #require(recipe.worked(on: stand))
        return (worked.method, worked.section)
    }

    private func pattern(
        _ recipe: BraidRecipe, assignments: [ThreadAssignment]? = nil
    ) throws -> RoundTube8SurfacePattern {
        let worked = try worked(recipe)
        return try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, method: worked.method, crossSection: worked.section,
            assignments: assignments ?? recipe.colouring
        ))
    }

    /// A bundle as a place round the braid and where its belly is along it, in
    /// cycles.
    struct Bundle { let place: Int; let belly: Float }

    /// The bundles of a pattern over `repeats` repeats laid end to end.
    private func bundles(_ pattern: RoundTube8SurfacePattern, repeats: Int = 3) -> [Bundle] {
        let rows = Float(pattern.rowCount)
        let bundle = RoundTube8Bundle.standard
        let belly = bundle.crestAtCycles
        return (0..<repeats).flatMap { repeatIndex in
            pattern.surface.segments.map {
                Bundle(place: Int(($0.centerlineStart.x * 8).rounded(.down)),
                       belly: ($0.centerlineStart.y + Float(repeatIndex)) * rows + belly)
            }
        }
    }

    /// **Where the half-pitch condition fails**, for any set of bundles: for
    /// every pair of neighbouring places round the braid (8 to 1 included),
    /// every bundle at one must have a bundle at the other exactly half a pitch
    /// away — never level with it, a quarter off, or a whole pitch apart.
    private func failures(_ bundles: [Bundle]) -> [String] {
        let byPlace = Dictionary(grouping: bundles, by: \.place)
        let span = (bundles.map(\.belly).min() ?? 0)...(bundles.map(\.belly).max() ?? 0)
        var out = [String]()
        for place in 0..<8 {
            let next = (place + 1) % 8
            for mine in byPlace[place] ?? [] {
                // Only where the neighbour's bundles reach either side.
                guard mine.belly - 1 > span.lowerBound, mine.belly + 1 < span.upperBound else { continue }
                let nearest = (byPlace[next] ?? []).map { $0.belly - mine.belly }
                    .min { abs($0) < abs($1) } ?? .infinity
                if abs(abs(nearest) - 0.5) > 1e-4 {
                    out.append("place \(place + 1)→\(next + 1) at \(mine.belly): nearest \(nearest) P")
                }
            }
        }
        return out
    }

    /// **The product's bundles meet it**, S and Z, all eight pairs round the
    /// braid and across the joins between repeats.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func everyPlaceIsHalfAPitchFromTheNext(recipe: BraidRecipe) throws {
        let drawn = try pattern(recipe)
        let found = failures(bundles(drawn))
        #expect(found.isEmpty, "\(found.prefix(4))")
    }

    /// **The half pitch is the table's** (Task 053): a place's cells begin in
    /// the half of the cycle its thread arrives in, and every place arrives in the
    /// other half from its neighbours. The same check rejects bundles begun at
    /// the instant each thread arrives, which the disk book spreads over the
    /// eight figures of a cycle.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func theHalfPitchIsTheHalfOfTheCycleAPlaceArrivesIn(recipe: BraidRecipe) throws {
        let drawn = try pattern(recipe)
        for place in 0..<8 {
            let arrival = drawn.arrivalPhaseBySlot[place]
            #expect(drawn.drawnPhaseByColumn[place] == (arrival <= 0.5 ? 0.5 : 1))
            let next = drawn.arrivalPhaseBySlot[(place + 1) % 8]
            #expect((arrival <= 0.5) != (next <= 0.5), "places \(place + 1) and \(place + 2)")
        }
        // Begun at the instant each thread arrives instead: not half a pitch.
        let atArrivals = bundles(drawn).map { bundle in
            Bundle(place: bundle.place,
                   belly: bundle.belly - drawn.drawnPhaseByColumn[bundle.place]
                       + drawn.arrivalPhaseBySlot[bundle.place])
        }
        #expect(!failures(atArrivals).isEmpty)
    }

    /// **Followed the way the bundles lean** (the carry's direction), each place
    /// round is half a pitch further along — the same sign every step, all the
    /// way round, so eight places come back to the start four pitches on, with
    /// no step of a whole pitch and none back. Read off the product's bundles.
    ///
    /// **The stagger by itself has no direction**: half a pitch on and half a
    /// pitch back land on bundles alike. Which way the spiral climbs is the
    /// lean's, which comes from the table; this checks that walking that way
    /// never stalls or jumps, not that the stagger chose it.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func followingTheLeanTheSpiralClimbsHalfAPitchAPlace(recipe: BraidRecipe) throws {
        let drawn = try pattern(recipe)
        let all = bundles(drawn, repeats: 4)
        let byPlace = Dictionary(grouping: all, by: \.place)
        let step = Int(drawn.leanDirection)
        guard let start = byPlace[0]?.sorted(by: { $0.belly < $1.belly })[drawn.rowCount] else {
            Issue.record("no bundle to start from")
            return
        }
        var here = start
        for _ in 0..<8 {
            let next = ((here.place + step) % 8 + 8) % 8
            let found = try #require((byPlace[next] ?? []).first { abs($0.belly - here.belly - 0.5) < 1e-4 },
                                     "no bundle half a pitch on from place \(here.place + 1)")
            here = found
        }
        #expect(here.place == start.place)
        #expect(abs(here.belly - start.belly - 4) < 1e-4)
    }

    /// **Every drawn cell is still the thread the braiding put there**: moving
    /// a cell along to its drawn place never moves it into another cycle. Each
    /// cell's start less its drawn phase is a whole row, and in that row the
    /// occupancy history has this cell's thread at this place. The drawn phase
    /// is never more than a quarter of a cycle from the arrival.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func everyDrawnCellIsTheThreadTheBraidingPutThere(recipe: BraidRecipe) throws {
        let worked = try worked(recipe)
        let derivation = try #require(BraidDerivation.derive(
            stand: stand, method: worked.method, crossSection: worked.section
        ))
        let drawn = try pattern(recipe)
        let rows = Float(drawn.rowCount)
        #expect(drawn.surface.segments.count == 32)
        for segment in drawn.surface.segments {
            let column = Int((segment.centerlineStart.x * 8).rounded(.down))
            let row = segment.centerlineStart.y * rows + 1 - drawn.drawnPhaseByColumn[column]
            #expect(abs(row - row.rounded()) < 1e-4)
            let cycle = Int(row.rounded())
            let course = try #require(derivation.courses.first { $0.threadPosition == segment.threadPosition })
            // The cell is the thread standing at its place in that cycle, and
            // the column is that place (Task 053).
            #expect(course.slots[cycle] == column,
                    "thread \(segment.threadPosition), cycle \(cycle)")
        }
        #expect(drawn.arrivalPhaseBySlot.count == 8)
        #expect(drawn.drawnPhaseByColumn.count == 8)
    }

    /// **The shape does not depend on the colours**: two colourings, one mesh.
    @Test func theShapeIsTheSameWhateverTheColours() throws {
        let recipe = BraidMethodCatalog.yatsuKongoS8Recipe
        let plain = (1...8).map { ThreadAssignment(position: $0, colorID: ThreadColorID(rawValue: "natural")) }
        let one = (1...8).map { ThreadAssignment(position: $0, colorID: ThreadColorID(rawValue: $0 == 3 ? "blue" : "natural")) }
        let a = try #require(RoundTube8SurfaceMesh.generate(pattern: pattern(recipe, assignments: plain)))
        let b = try #require(RoundTube8SurfaceMesh.generate(pattern: pattern(recipe, assignments: one)))
        #expect(BraidMeshHashTests.hash(a.positions) == BraidMeshHashTests.hash(b.positions))
    }

    // MARK: - Task 048's rework: the colour spiral

    /// The author's colouring for the spiral sketch: places 1-8 blue, blue,
    /// red, red, blue, blue, red, red (2026-09-20).
    private var authorColouring: [ThreadAssignment] {
        ["blue", "blue", "red", "red", "blue", "blue", "red", "red"].enumerated().map {
            ThreadAssignment(position: $0.offset + 1, colorID: ThreadColorID(rawValue: $0.element))
        }
    }

    /// The cells of one drawn column, in order along the braid.
    private func column(
        _ index: Int, of pattern: RoundTube8SurfacePattern
    ) -> [BraidStrandSegment] {
        pattern.surface.segments
            .filter { Int(($0.centerlineStart.x * 8).rounded(.down)) == index }
            .sorted { $0.centerlineStart.y < $1.centerlineStart.y }
    }

    /// **With the author's colouring the colour changes at every cell down a
    /// column** — one bundle at a time, as the sketch has it, never two of a
    /// colour in a row (the author, 2026-09-20: 「2ピッチずつ色が入れ替わっている
    /// が金剛組ではこのようにはならない」).
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func theColourChangesEveryCellDownAColumn(recipe: BraidRecipe) throws {
        let drawn = try pattern(recipe, assignments: authorColouring)
        for index in 0..<8 {
            let colours = column(index, of: drawn).map(\.colorID)
            #expect(colours.count == drawn.rowCount)
            for (here, next) in zip(colours, colours.dropFirst()) {
                #expect(here != next, "column \(index + 1) runs \(here.rawValue) twice")
            }
            // And round again across the repeat's join.
            #expect(colours.first != colours.last)
        }
    }

    /// **The same check rejects book A p.54's table** (shipped until Task 053)
    /// drawn the way the disk book's is, a place to a column: the author's
    /// colouring runs two cells of a colour down its columns. That is what Task
    /// 048 turned the braid a column a cycle to hide; the disk book's table does
    /// not need it.
    @Test func bookAsTableWouldRunTwoCellsOfAColour() throws {
        let method = try #require(BraidMethodCatalog.yatsuKongoBookAP54Disk.method(
            id: "yatsu-kongo-s-8-book-a-p54", standID: stand.id,
            stepNames: BraidMethodCatalog.yatsuKongoStepNames
        ))
        let derivation = try #require(BraidDerivation.derive(
            stand: stand, method: method,
            crossSection: BraidMethodCatalog.yatsuKongoS8Recipe.crossSection(on: stand)
        ))
        let colours = Dictionary(uniqueKeysWithValues: authorColouring.map { ($0.position, $0.colorID) })
        var twoInARow = 0
        for slot in 0..<8 {
            let down = (0..<derivation.repeatCycleCount).map { cycle -> ThreadColorID in
                let course = derivation.courses.first { $0.slots[cycle] == slot }
                return colours[course?.threadPosition ?? 0] ?? ThreadColorID(rawValue: "")
            }
            for (here, next) in zip(down, down.dropFirst()) where here == next { twoInARow += 1 }
        }
        #expect(twoInARow > 0, "book A's table had no colour twice in a row")
    }

    /// **A colour band is one pair of threads, followed half a pitch at a time**
    /// — and which pair is settled by the table, not by the colours: the step
    /// half a pitch on, round the braid the way the runs lean, joins the threads
    /// that begin at places 1 and 2, 3 and 4, 5 and 6, 7 and 8 — **the disk
    /// book's pairs** since Task 055, where they stand and which way the runs
    /// lean both having been put right for it.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func aBandFollowsOnePairOfThreads(recipe: BraidRecipe) throws {
        let worked = try worked(recipe)
        let derivation = try #require(BraidDerivation.derive(
            stand: stand, method: worked.method, crossSection: worked.section
        ))
        var startingSlot = [Int: Int]()
        for course in derivation.courses { startingSlot[course.threadPosition] = course.slots[0] }
        let drawn = try pattern(recipe, assignments: authorColouring)
        let rows = Float(drawn.rowCount)
        let lean = Int(drawn.leanDirection)

        // Walk a band: from a cell, half a pitch on in the column the runs lean
        // towards, eight steps round the braid — across the join into the next
        // repeat where it gets there (a repeat is four cycles since Task 053).
        var here = try #require(drawn.surface.segments.first {
            Int(($0.centerlineStart.x * 8).rounded(.down)) == 0
                && $0.centerlineStart.y * rows > 0
        })
        var along = here.centerlineStart.y * rows
        var threads = [here.threadPosition]
        for _ in 0..<8 {
            let column = Int((here.centerlineStart.x * 8).rounded(.down))
            let next = ((column + lean) % 8 + 8) % 8
            along += 0.5
            let wanted = along
            here = try #require(drawn.surface.segments.first {
                guard Int(($0.centerlineStart.x * 8).rounded(.down)) == next else { return false }
                let gap = ($0.centerlineStart.y * rows - wanted).truncatingRemainder(dividingBy: rows)
                return abs(gap) < 1e-4 || abs(abs(gap) - rows) < 1e-4
            }, "the band stops after \(threads.count) cells")
            threads.append(here.threadPosition)
        }
        // **Whole pairs, one after the other** (Task 055): every two steps are
        // the two threads of one of the disk book's pairs, 1・2 … 7・8, the
        // first laid then its partner — never a thread of one pair with a
        // thread of the next.
        let slots = threads.compactMap { startingSlot[$0] }
        #expect(slots.count == threads.count)
        let offset = slots[0] ^ 1 == slots[1] ? 0 : 1
        for index in stride(from: offset, to: slots.count - 1, by: 2) {
            #expect(slots[index] ^ 1 == slots[index + 1],
                    "places \(slots[index] + 1) and \(slots[index + 1] + 1) are not a pair: \(threads)")
        }
        // So with the author's colouring the whole band is one colour.
        let colours = Set(threads.map { thread in
            authorColouring.first { $0.position == thread }?.colorID
        })
        #expect(colours.count == 1, "\(threads)")
    }
}
