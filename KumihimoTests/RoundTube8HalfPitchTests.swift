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
        let belly = (bundle.bellyStartCycles + bundle.bellyEndCycles) / 2
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

    /// **The same check rejects the placement it replaced**: bundles begun at
    /// their arrivals (Task 032), ¼, ¾, ½, 1 … on S.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func theArrivalPlacementWouldFail(recipe: BraidRecipe) throws {
        let drawn = try pattern(recipe)
        let atArrivals = bundles(drawn).map { bundle in
            Bundle(place: bundle.place,
                   belly: bundle.belly - drawn.drawnPhaseBySlot[bundle.place]
                       + drawn.arrivalPhaseBySlot[bundle.place])
        }
        #expect(!failures(atArrivals).isEmpty)
        // S's arrivals, as Task 032 recorded them.
        if recipe.id == BraidMethodCatalog.yatsuKongoS8Recipe.id {
            #expect(drawn.arrivalPhaseBySlot == [0.25, 0.75, 0.5, 1, 0.25, 0.75, 0.5, 1])
            #expect(drawn.drawnPhaseBySlot == [0.5, 1, 0.5, 1, 0.5, 1, 0.5, 1])
        }
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
        #expect(drawn.surface.segments.count == 64)
        for segment in drawn.surface.segments {
            let slot = Int((segment.centerlineStart.x * 8).rounded(.down))
            let row = segment.centerlineStart.y * rows + 1 - drawn.drawnPhaseBySlot[slot]
            #expect(abs(row - row.rounded()) < 1e-4)
            let course = try #require(derivation.courses.first { $0.threadPosition == segment.threadPosition })
            #expect(course.slots[Int(row.rounded())] == slot, "thread \(segment.threadPosition)")
        }
        for (arrival, drawn) in zip(drawn.arrivalPhaseBySlot, drawn.drawnPhaseBySlot) {
            let apart = abs(arrival - drawn).truncatingRemainder(dividingBy: 1)
            #expect(min(apart, 1 - apart) <= 0.25 + 1e-6)
        }
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
}
