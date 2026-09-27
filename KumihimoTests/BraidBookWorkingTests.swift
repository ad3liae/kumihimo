import Foundation
import Testing
@testable import Kumihimo

/// Task 067, Task 068: **the step animation works every braid as its book
/// does, on one working** (`BraidBookWorking`): on a disk, a step that goes
/// over a thread is a hand and one that goes over none an adjustment; on a
/// round stand's faces, the book's two-handed carries. **Inside a dan no
/// thread moves but as the book moves it; once the dan is done, every thread is
/// set back in the starting form**, the islands matched the way that turns them
/// least.
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
        seats.sorted { $0.value.turn < $1.value.turn }.map(\.key)
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

    /// Where a hand leaves the threads for the next: set back, if it ends a dan.
    private func leaves(_ hand: BraidBookWorking.Hand) -> [Int: BraidBookWorking.Seat] {
        hand.setting ?? hand.after
    }

    /// **Half the least gap between two neighbouring islands of the start**, in
    /// turns: as far as a setting may move a thread.
    private func halfTheGap(_ working: BraidBookWorking) throws -> Double {
        let islands = working.islandsAtStart
        var gaps = [Double]()
        for (index, island) in islands.enumerated() {
            let next = islands[(index + 1) % islands.count]
            let last = try #require(island.last.flatMap { working.homes[$0] })
            let first = try #require(next.first.flatMap { working.homes[$0] })
            gaps.append(BraidBookWorking.unit(first.turn - last.turn))
        }
        return try #require(gaps.min()) / 2
    }

    // MARK: 1. Hands and adjustments

    /// **As many hands and adjustments a pass as the books have**: 八つ金剛 8 and
    /// none, 江戸八つ組 8 and 2 (figures 5 and 10), 返し組 56 and none, and on the
    /// round stand 丸四つ組 2 (p.52), 丸源氏 4 and 平源氏 6.
    @Test(arguments: [
        ("yatsu-kongo-s-8", 8, 0), ("yatsu-kongo-z-8", 8, 0), ("edo-yatsu-8", 8, 2),
        ("yatsu-kongo-gaeshi-8", 56, 0), ("maru-yotsu-4", 2, 0),
        ("maru-genji-16", 4, 0), ("hira-genji-16", 6, 0),
    ])
    func handsAndAdjustmentsAPass(recipeID: String, hands: Int, adjustments: Int) throws {
        let pass = perPass(try working(try recipe(recipeID)))
        #expect(pass.count == hands, "\(recipeID)")
        #expect(pass.reduce(0) { $0 + $1.adjustments.count } == adjustments, "\(recipeID)")
    }

    /// **A dan as the books print it** (Task 068 1.2.1): 八つ金剛 S・Z 4 hands
    /// (p.36–38), 返し組 4 — its S and Z dan, and the hand-overs together —,
    /// 江戸八つ組 8 (p.65), 丸四つ組 2 (p.52), 丸源氏 4 (p.95), 平源氏 6 (p.96–97).
    @Test(arguments: [
        ("yatsu-kongo-s-8", 4), ("yatsu-kongo-z-8", 4), ("yatsu-kongo-gaeshi-8", 4), ("edo-yatsu-8", 8),
        ("maru-yotsu-4", 2), ("maru-genji-16", 4), ("hira-genji-16", 6),
    ])
    func handsADanAreTheBooks(recipeID: String, hands: Int) throws {
        let working = try working(try recipe(recipeID))
        #expect(working.handsADan == hands, "\(recipeID)")
        #expect(working.hands.count % hands == 0, "\(recipeID)")
    }

    /// 返し組's hand-overs are a dan's four hands of their own, not split
    /// between two.
    @Test func gaeshiHandOversAreADanTogether() throws {
        let working = try working(try recipe("yatsu-kongo-gaeshi-8"))
        let overs = working.hands.indices.filter { working.hands[$0].isHandOver }
        #expect(overs.count == 8)
        for start in stride(from: 0, to: overs.count, by: 4) {
            let group = Array(overs[start..<(start + 4)])
            #expect(group == Array(group[0]..<(group[0] + 4)))
            #expect(group[0] % 4 == 0 && working.hands[group[3]].endsADan)
        }
    }

    /// **On a disk, every hand's carry goes over a thread and every adjustment
    /// over none.**
    @Test(arguments: ["yatsu-kongo-s-8", "yatsu-kongo-z-8", "edo-yatsu-8", "yatsu-kongo-gaeshi-8"])
    func aHandGoesOverAThreadAndAnAdjustmentOverNone(recipeID: String) throws {
        let working = try working(try recipe(recipeID))
        for hand in working.hands {
            #expect(hand.carries.allSatisfy { !$0.over.isEmpty }, "\(recipeID)")
            #expect(hand.adjustments.allSatisfy { $0.over.isEmpty }, "\(recipeID)")
        }
    }

    // MARK: 2. Nothing moves inside a dan

    /// **Inside a dan no thread moves but as the book moves it** (Task 068 3.1):
    /// a thread the hand neither carries nor adjusts stands where it stood,
    /// through the carry and the settle; and each hand begins where the one
    /// before left the threads.
    @Test(arguments: BraidMethodCatalog.recipes.map(\.id))
    func nothingMovesInsideADan(recipeID: String) throws {
        let working = try working(try recipe(recipeID))
        var leftAt = working.homes
        for (index, hand) in working.hands.enumerated() {
            #expect(hand.before == leftAt, "\(recipeID) hand \(index + 1)")
            let moved = Set((hand.carries + hand.adjustments).map(\.thread))
            for (thread, seat) in hand.before where !moved.contains(thread) {
                #expect(hand.afterCarrying[thread] == seat && hand.after[thread] == seat,
                        "\(recipeID) hand \(index + 1): thread \(thread)")
            }
            leftAt = leaves(hand)
        }
    }

    /// **八つ金剛 S keeps the book's slits through a dan**: after hand 1 the north
    /// island is three threads and the south one (p.37 figure 1), and they are
    /// only set back, two to each of north, east, south and west, once hand 4
    /// is done.
    @Test func kongoSKeepsTheBooksSlitsThroughADan() throws {
        let working = try working(try recipe("yatsu-kongo-s-8"))
        #expect(working.hands[0].islands.map(\.count) == [3, 2, 1, 2])
        #expect(working.hands[0].setting == nil)
        #expect(working.hands[3].endsADan && working.hands[3].setting != nil)
        let middles = working.islandsAtStart.compactMap { island -> Double? in
            let turns = island.compactMap { working.homes[$0]?.turn }
            guard let first = turns.first else { return nil }
            return BraidBookWorking.unit(first + turns.map { BraidBookWorking.between(first, $0) }.reduce(0, +) / Double(turns.count))
        }
        let quarters: [Double] = [0, 0.25, 0.5, 0.75]
        #expect(zip(middles, quarters).allSatisfy { abs(BraidBookWorking.between($0, $1)) < 1e-9 }, "\(middles)")
    }

    // MARK: 3. Setting back at the end of a dan

    /// **Only after a dan's last hand, and then every thread stands in the
    /// starting form** (Task 068 3.2): 八つ金剛 2/2/2/2, 丸源氏 4/4/4/4, each
    /// place taken once.
    @Test(arguments: BraidMethodCatalog.recipes.map(\.id))
    func setBackOnlyAtTheEndOfADan(recipeID: String) throws {
        let working = try working(try recipe(recipeID))
        let homes = Set(working.homes.values.map { [$0.turn, $0.radius] })
        for (index, hand) in working.hands.enumerated() {
            #expect(hand.endsADan == ((index + 1) % working.handsADan == 0), "\(recipeID) hand \(index + 1)")
            if !hand.endsADan {
                #expect(hand.setting == nil, "\(recipeID) hand \(index + 1)")
            } else {
                #expect(Set(leaves(hand).values.map { [$0.turn, $0.radius] }) == homes,
                        "\(recipeID) hand \(index + 1)")
            }
        }
    }

    /// **A setting turns the threads the least it can** (Task 068 2.1): no
    /// thread moves further than half the gap to the next island. 丸四つ組's
    /// threads already stand in the starting form after every dan, so it has
    /// none; 八つ金剛's moves each thread a drawn notch.
    @Test(arguments: BraidMethodCatalog.recipes.map(\.id))
    func aSettingMovesNoThreadPastHalfTheGap(recipeID: String) throws {
        let working = try working(try recipe(recipeID))
        let half = try halfTheGap(working)
        var most = 0.0
        for hand in working.hands {
            guard let setting = hand.setting else { continue }
            for (thread, to) in setting {
                let from = try #require(hand.after[thread])
                most = max(most, abs(BraidBookWorking.between(from.turn, to.turn)))
            }
        }
        #expect(most <= half + 1e-9, "\(recipeID): \(most) against \(half)")
    }

    @Test func maruYotsuAndEdoYatsuHaveNothingToSetBack() throws {
        #expect(try working(try recipe("maru-yotsu-4")).hands.allSatisfy { $0.setting == nil })
        // 江戸八つ組's figures 5 and 10 lay the threads back in the slits the dan began in.
        #expect(try working(try recipe("edo-yatsu-8")).hands.allSatisfy { $0.setting == nil })
        let kongo = try working(try recipe("yatsu-kongo-s-8"))
        let notch = kongo.geometry.notchTurn(notches: BookDiskKongo.notchCount)
        for hand in kongo.hands {
            guard let setting = hand.setting else { continue }
            for (thread, to) in setting {
                let from = try #require(hand.after[thread])
                #expect(abs(abs(BraidBookWorking.between(from.turn, to.turn)) - notch) < 1e-9)
            }
        }
    }

    // MARK: 4. On the round stand's faces

    /// **A thread laid on a face goes between the two it is laid between**, and
    /// in towards the middle when there is no room there: 丸源氏's hand 1 lays
    /// 3面's two ends between 1面's two middle threads (p.94).
    @Test func aThreadLaidOnAFaceGoesBetweenItsNeighbours() throws {
        let working = try working(try recipe("maru-genji-16"))
        let first = working.hands[0]
        let left = try #require(first.before[16]).turn, right = try #require(first.before[1]).turn
        for carry in first.carries {
            let landing = try #require(first.afterCarrying[carry.thread])
            #expect(BraidBookWorking.between(left, landing.turn) > 0 && BraidBookWorking.between(landing.turn, right) > 0)
            #expect(landing.radius < 1)
        }
        // Every bobbin clear of every other, at the start and end of every hand.
        let apart = working.geometry.apartOnAFace
        for hand in working.hands {
            for seats in [hand.before, hand.after] {
                let all = Array(seats.values)
                for (index, one) in all.enumerated() {
                    for other in all[(index + 1)...] {
                        #expect(BraidBookWorking.distance(one, other) >= apart - 1e-9)
                    }
                }
            }
        }
    }

    /// **丸四つ組 is the textbook's** (p.52): 1面's thread to 3面 and 3面's to 1面
    /// clockwise, then 2面's to 4面 and 4面's to 2面 anticlockwise, each pair at
    /// once, each laid in the middle of the face its partner left.
    @Test func maruYotsuIsTheTextbooksRoundStand() throws {
        let working = try working(try recipe("maru-yotsu-4"))
        #expect(working.hands.count == 2)
        #expect(working.hands[0].carries.map(\.thread) == [1, 3])
        #expect(working.hands[0].carries.allSatisfy { $0.way == .clockwise })
        #expect(working.hands[1].carries.map(\.thread) == [4, 2])
        #expect(working.hands[1].carries.allSatisfy { $0.way == .anticlockwise })
        for hand in working.hands {
            #expect(Set(hand.after.values.map(\.turn)) == Set(working.homes.values.map(\.turn)))
        }
    }

    // MARK: 5. The same braid as the tables

    /// **After a pass the threads stand in the order the tables leave them**,
    /// round the stand, whatever the stand has been turned by — **the order
    /// only, not the way round they went**: 丸四つ組's hand 1 is drawn
    /// clockwise as the textbook works it (p.52), while the table the 3D reads
    /// takes it anticlockwise, until the author decides (Task 068 2.3).
    @Test(arguments: BraidMethodCatalog.recipes.map(\.id))
    func aPassLeavesTheOrderTheTablesDo(recipeID: String) throws {
        let recipe = try recipe(recipeID)
        let working = try working(recipe)
        let last = try #require(perPass(working).last)
        let tables = try tablesPass(recipe)
        let byTables = tables.keys.sorted().compactMap { tables[$0] }
        #expect(sameRound(order(leaves(last)), byTables), "\(recipeID): \(order(leaves(last))) \(byTables)")
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
        for (thread, seat) in leaves(last) {
            if let place = working.homes.first(where: { $0.value == seat })?.key { byPlace[place] = thread }
        }
        let tables = try tablesPass(recipe)
        #expect(byPlace == tables)
    }

    // MARK: 6. Islands

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
            startingSlits: BraidStartingSlits(notchCount: 32, placeOneOnward: slits), handsADan: 1
        )
        let working = try #require(BraidBookWorking(recipe: recipe, stand: BraidMethodCatalog.stand16))
        #expect(working.islandsAtStart.map(\.count).sorted() == [2, 2, 6, 6])
        #expect(working.islandsAtStart.map(\.count) == [6, 2, 6, 2] || working.islandsAtStart.map(\.count) == [2, 6, 2, 6])
    }

    // MARK: 7. A time round

    /// **A time round ends as it began**, every place showing its colour:
    /// 丸源氏's own colouring after four dan (「糸の色は4段ごとに戻ります」),
    /// 平源氏's after one (「糸の色は、【組みはじめ】と同じです」), 江戸八つ組's
    /// after two cycles (「糸の色は2段ごとに戻ります」), 丸四つ組's after one
    /// (p.52 「1段目終了」).
    @Test func timeRoundsAreTheBooks() throws {
        #expect(try working(try recipe("maru-genji-16")).passes == 4)
        #expect(try working(try recipe("hira-genji-16")).passes == 1)
        #expect(try working(try recipe("edo-yatsu-8")).passes == 2)
        #expect(try working(try recipe("maru-yotsu-4")).passes == 1)
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
            startingSlits: recipe.startingSlits, standHands: recipe.standHands, handsADan: recipe.handsADan
        )
        #expect(BraidBookWorking(recipe: renamed, stand: stand) == BraidBookWorking(recipe: recipe, stand: stand))
    }
}
