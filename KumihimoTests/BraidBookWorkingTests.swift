import Foundation
import Testing
@testable import Kumihimo

/// Task 067: **the step animation works every braid as its book does, on one
/// working** (`BraidBookWorking`): on a disk, a step that goes over a thread is
/// a hand and one that goes over none an adjustment; on a round stand's faces,
/// the book's two-handed carries. Islands are read off the arrangement as it
/// stands and drawn back whenever they are as they began.
@MainActor
struct BraidBookWorkingTests {
    private func working(_ recipe: BraidRecipe, colours: [ThreadAssignment]? = nil) throws -> BraidBookWorking {
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        let colouring = colours ?? recipe.colouring
        return try #require(BraidBookWorking(
            recipe: recipe, stand: stand,
            colours: Dictionary(uniqueKeysWithValues: colouring.map { ($0.position, $0.colorID) })
        ))
    }

    private func recipe(_ id: String) throws -> BraidRecipe {
        try #require(BraidMethodCatalog.recipes.first { $0.id == id })
    }

    /// The threads in order round the stand, as the seats put them.
    private func order(_ seats: [Int: BraidBookWorking.Seat]) -> [Int] {
        seats.sorted { ($0.value.turn, $0.value.offset) < ($1.value.turn, $1.value.offset) }.map(\.key)
    }

    /// The same order round, from wherever it is begun.
    private func sameRound(_ one: [Int], _ other: [Int]) -> Bool {
        guard one.count == other.count, let first = one.first, let start = other.firstIndex(of: first) else {
            return false
        }
        return one == Array(other[start...] + other[..<start])
    }

    /// Where the tables leave the threads after one pass, place by place.
    private func tablesPass(_ recipe: BraidRecipe) throws -> [Int: Int] {
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        var state = BraidStandState.start(on: stand)
        for method in try #require(recipe.methods(on: stand)) {
            state = try #require(BraidWorking.cycle(of: method, from: state)).endState
        }
        return try #require(state.threadByPosition)
    }

    private func perPass(_ working: BraidBookWorking) -> ArraySlice<BraidBookWorking.Hand> {
        working.hands.prefix(working.hands.count / working.passes)
    }

    // MARK: 1. Hands and adjustments

    /// **As many hands and adjustments a pass as the books have**: 八つ金剛 8 and
    /// none, 江戸八つ組 8 and 2 (figures 5 and 10), 返し組 56 and none,
    /// 丸四つ組 2 and 2, and on the round stand 丸源氏 4 and 平源氏 6.
    @Test(arguments: [
        ("yatsu-kongo-s-8", 8, 0), ("yatsu-kongo-z-8", 8, 0), ("edo-yatsu-8", 8, 2),
        ("yatsu-kongo-gaeshi-8", 56, 0), ("maru-yotsu-4", 2, 2),
        ("maru-genji-16", 4, 0), ("hira-genji-16", 6, 0),
    ])
    func handsAndAdjustmentsAPass(recipeID: String, hands: Int, adjustments: Int) throws {
        let pass = perPass(try working(try recipe(recipeID)))
        #expect(pass.count == hands, "\(recipeID)")
        #expect(pass.reduce(0) { $0 + $1.adjustments.count } == adjustments * (recipeID == "maru-yotsu-4" ? 2 : 1),
                "\(recipeID)")
    }

    /// **On a disk, every hand's carry goes over a thread and every adjustment
    /// over none.**
    @Test(arguments: ["yatsu-kongo-s-8", "yatsu-kongo-z-8", "edo-yatsu-8", "yatsu-kongo-gaeshi-8", "maru-yotsu-4"])
    func aHandGoesOverAThreadAndAnAdjustmentOverNone(recipeID: String) throws {
        let working = try working(try recipe(recipeID))
        for hand in working.hands {
            #expect(hand.carries.allSatisfy { !$0.over.isEmpty }, "\(recipeID)")
            #expect(hand.adjustments.allSatisfy { $0.over.isEmpty }, "\(recipeID)")
        }
    }

    // MARK: 2. Drawing back

    /// **The islands are drawn back only when they are as many and as large as
    /// they began**, and then every place is taken once: 八つ金剛 after every
    /// second hand, 丸源氏 after hands 2 and 4 of a dan.
    @Test(arguments: [("yatsu-kongo-s-8", 2), ("yatsu-kongo-z-8", 2), ("maru-genji-16", 2)])
    func drawnBackEverySecondHand(recipeID: String, every: Int) throws {
        let working = try working(try recipe(recipeID))
        let homes = Set(working.homes.values.map { [$0.turn, $0.offset] })
        for (index, hand) in working.hands.enumerated() {
            #expect(hand.standsAtHome == ((index + 1) % every == 0), "\(recipeID) hand \(index + 1)")
            if hand.standsAtHome {
                #expect(Set(hand.after.values.map { [$0.turn, $0.offset] }) == homes, "\(recipeID) hand \(index + 1)")
            }
        }
    }

    // MARK: 3. The same braid as the tables

    /// **After a pass the threads stand in the order the tables leave them**,
    /// round the stand, whatever the stand has been turned by.
    @Test(arguments: BraidMethodCatalog.recipes.map(\.id))
    func aPassLeavesTheOrderTheTablesDo(recipeID: String) throws {
        let recipe = try recipe(recipeID)
        let working = try working(recipe)
        let last = try #require(perPass(working).last)
        let tables = try tablesPass(recipe)
        let byTables = tables.keys.sorted().compactMap { tables[$0] }
        #expect(sameRound(order(last.after), byTables), "\(recipeID): \(order(last.after)) \(byTables)")
    }

    /// **On the textbook's round stand, one dan leaves every thread in the very
    /// place book C's table leaves it after one cycle** — 丸源氏 (p.94–95 against
    /// Fig.32) and 平源氏 (p.96–97 against Fig.20), place for place.
    @Test(arguments: ["maru-genji-16", "hira-genji-16"])
    func aDanOnTheRoundStandIsACycleOfBookC(recipeID: String) throws {
        let recipe = try recipe(recipeID)
        let working = try working(recipe)
        let last = try #require(perPass(working).last)
        var byPlace = [Int: Int]()
        for (thread, seat) in last.after {
            if let place = working.homes.first(where: { $0.value == seat })?.key { byPlace[place] = thread }
        }
        let tables = try tablesPass(recipe)
        #expect(byPlace == tables)
    }

    // MARK: 4. Islands

    /// **Islands as they stand**: 2/2/2/2 for 八つ金剛, 4/4/4/4 for 丸源氏 and
    /// 6/4/2/4 after its first hand, one by one for 丸四つ組.
    @Test func theIslandsAreReadOffTheArrangement() throws {
        #expect(try working(try recipe("yatsu-kongo-s-8")).islandsAtStart.map(\.count) == [2, 2, 2, 2])
        let maru = try working(try recipe("maru-genji-16"))
        #expect(maru.islandsAtStart.map(\.count) == [4, 4, 4, 4])
        #expect(maru.hands[0].islands.map(\.count) == [6, 4, 2, 4])
        #expect(try working(try recipe("maru-yotsu-4")).islandsAtStart.map(\.count) == [1, 1, 1, 1])
    }

    /// **Six, two, six, two** on a made-up disk of sixteen threads and 32
    /// notches: the same rule finds them.
    @Test func sixTwoSixTwoIsFoundByTheSameRule() throws {
        let slits = [1, 2, 3, 4, 5, 6, 9, 10, 17, 18, 19, 20, 21, 22, 25, 26]
        let base = BraidMethodCatalog.maruGenjiDisk
        let table = BraidDiskNotation(
            source: "made up", notchCount: 32, standPositionByRestingNotch: base.standPositionByRestingNotch,
            moves: base.moves, threadsPerStep: base.threadsPerStep, stepReading: base.stepReading,
            bookSteps: [BraidBookStep(moves: [BraidMove(from: 26, to: 27)]),
                        BraidBookStep(moves: [BraidMove(from: 27, to: 26)])]
        )
        let recipe = BraidRecipe(
            id: "made-up", name: "作りもの", notation: table, colouring: [], shape: BraidShapeValues(),
            startingSlits: BraidStartingSlits(notchCount: 32, placeOneOnward: slits)
        )
        let working = try #require(BraidBookWorking(recipe: recipe, stand: BraidMethodCatalog.stand16))
        #expect(working.islandsAtStart.map(\.count).sorted() == [2, 2, 6, 6])
        #expect(working.islandsAtStart.map(\.count) == [6, 2, 6, 2] || working.islandsAtStart.map(\.count) == [2, 6, 2, 6])
    }

    // MARK: 5. A time round

    /// **A time round ends as it began**, every place showing its colour:
    /// 丸源氏's own colouring after four dan (「糸の色は4段ごとに戻ります」),
    /// 平源氏's after one (「糸の色は、【組みはじめ】と同じです」), 江戸八つ組's
    /// after two cycles (「糸の色は2段ごとに戻ります」).
    @Test func timeRoundsAreTheBooks() throws {
        #expect(try working(try recipe("maru-genji-16")).passes == 4)
        #expect(try working(try recipe("hira-genji-16")).passes == 1)
        #expect(try working(try recipe("edo-yatsu-8")).passes == 2)
    }

    /// **The working reads no braid's name**, and **the tables' own moves and
    /// names do not reach the derivation**: without the book's hands the tables
    /// give the same methods.
    @Test(arguments: BraidMethodCatalog.recipes.map(\.id))
    func theBooksHandsDoNotReachTheDerivation(recipeID: String) throws {
        let recipe = try recipe(recipeID)
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        let bare = recipe.rounds.map {
            BraidDiskNotation(
                source: $0.source, notchCount: $0.notchCount,
                standPositionByRestingNotch: $0.standPositionByRestingNotch, moves: $0.moves,
                threadsPerStep: $0.threadsPerStep, stepReading: $0.stepReading
            )
        }
        let stripped = BraidRecipe(
            id: recipe.id, name: recipe.name, rounds: bare, colouring: recipe.colouring,
            shape: recipe.shape, orderRoundTheBraid: recipe.orderRoundTheBraid
        )
        #expect(stripped.methods(on: stand) == recipe.methods(on: stand))
        let renamed = BraidRecipe(
            id: "renamed", name: "別の名前", rounds: recipe.rounds, colouring: recipe.colouring,
            shape: recipe.shape, orderRoundTheBraid: recipe.orderRoundTheBraid,
            startingSlits: recipe.startingSlits, standHands: recipe.standHands
        )
        #expect(BraidBookWorking(recipe: renamed, stand: stand) == BraidBookWorking(recipe: recipe, stand: stand))
    }
}
