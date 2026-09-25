import CoreGraphics
import Foundation
import Testing
@testable import Kumihimo

/// Task 061: **a braid's working, hand by hand, on a round stand seen from
/// above.** A hand is a step of the tables (`BraidMethod.steps`); the closing is
/// not a hand and moves at the end of the cycle's last one; the way round is
/// the short way of the table's disk move; a thread that arrives at a place
/// still taken waits beside it, on the side it came from.
@MainActor
struct BraidStepScriptTests {
    private func script(
        _ recipe: BraidRecipe, colours: [ThreadAssignment]? = nil
    ) throws -> BraidStepScript {
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        let colouring = colours ?? recipe.colouring
        return try #require(BraidStepScript(
            recipe: recipe, stand: stand,
            colours: Dictionary(uniqueKeysWithValues: colouring.map { ($0.position, $0.colorID) })
        ))
    }

    private func byPlace(_ names: [String], count: Int) -> [ThreadAssignment] {
        (1...count).map {
            ThreadAssignment(position: $0, colorID: ThreadColorID(rawValue: names[($0 - 1) % names.count]))
        }
    }

    private struct Seen: Equatable {
        let from: Int, to: Int, way: BraidStepWay, passing: [Int]
    }

    private func seen(_ carry: BraidStepScript.Carry) -> Seen {
        Seen(from: carry.from, to: carry.to, way: carry.way, passing: carry.passing)
    }

    // MARK: 1. 江戸八つ組

    /// **Eight hands a cycle and no closing**, and each is the reviewer's table:
    /// the places, the way round, and the place passed over.
    @Test func edoYatsuIsTheTextbooksEightHands() throws {
        let recipe = BraidMethodCatalog.edoYatsu8Recipe
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        #expect(try #require(recipe.methods(on: stand)).first?.closing.moves.isEmpty == true)
        let script = try script(recipe)
        #expect(script.hands.allSatisfy { $0.carries.count == 1 && $0.settling.isEmpty })
        let expected: [Seen] = [
            Seen(from: 7, to: 1, way: .clockwise, passing: [8]),
            Seen(from: 5, to: 7, way: .clockwise, passing: [6]),
            Seen(from: 3, to: 5, way: .clockwise, passing: [4]),
            Seen(from: 1, to: 3, way: .clockwise, passing: [2]),
            Seen(from: 8, to: 6, way: .anticlockwise, passing: [7]),
            Seen(from: 2, to: 8, way: .anticlockwise, passing: [1]),
            Seen(from: 4, to: 2, way: .anticlockwise, passing: [3]),
            Seen(from: 6, to: 4, way: .anticlockwise, passing: [5]),
        ]
        #expect(script.hands.prefix(8).compactMap(\.carries.first).map(seen) == expected)
        // The second cycle is the same table: the same places and ways.
        #expect(script.hands.suffix(8).compactMap(\.carries.first).map(seen) == expected)
        // Hand 1 goes over the thread standing at place 8.
        #expect(script.hands[0].carries.first?.over == [8])
    }

    /// **The thread set down at place 1 by hand 1 waits beside place 1's own
    /// thread, on the side it came from (place 8's)**, and stands on place 1
    /// once hand 4 has taken that thread away.
    @Test func edoYatsuSetsTheNewThreadBesideUntilThePlaceIsFree() throws {
        let script = try script(BraidMethodCatalog.edoYatsu8Recipe)
        let stand = script.stand
        let afterFirst = script.hands[0].after
        let atOne = afterFirst.filter { $0.value.place == 1 }
        #expect(atOne.count == 2)
        #expect(afterFirst[1] == BraidStepStanding(place: 1, rank: 0, cameBy: nil))
        #expect(afterFirst[7] == BraidStepStanding(place: 1, rank: 1, cameBy: .clockwise))
        // Drawn between place 8 (7/8 of a turn) and place 1 (the top).
        let beside = BraidStepFrame.polarPoint(of: try #require(afterFirst[7]), on: stand)
        let turn = (beside.turn + 1).truncatingRemainder(dividingBy: 1)
        #expect(turn > 0.875 && turn < 1)

        for hand in 1...2 {
            #expect(script.hands[hand].after.filter { $0.value.place == 1 }.count == 2)
        }
        let afterFourth = script.hands[3].after
        #expect(afterFourth.filter { $0.value.place == 1 }.map(\.key) == [7])
        #expect(afterFourth[7] == BraidStepStanding(place: 1, rank: 0, cameBy: nil))
    }

    /// **Sixteen hands and every place back to its colour** — two cycles
    /// (the textbook: 「糸の色は2段ごとに戻ります」), under the textbook's colouring
    /// and the author's (places 1・5 pink, 2・6 white, 3・7 blue, 4・8 green). Not
    /// after one.
    @Test(arguments: ["textbook", "author"])
    func edoYatsuComesBackInSixteenHands(colouring: String) throws {
        let recipe = BraidMethodCatalog.edoYatsu8Recipe
        let colours = colouring == "author"
            ? byPlace(["pink", "white", "blue", "green"], count: 8)
            : recipe.colouring
        let script = try script(recipe, colours: colours)
        #expect(script.cycles == 2)
        #expect(script.hands.count == 16)

        let colourAt = Dictionary(uniqueKeysWithValues: colours.map { ($0.position, $0.colorID) })
        func coloursByPlace(_ standings: [Int: BraidStepStanding]) -> [Int: ThreadColorID?] {
            Dictionary(uniqueKeysWithValues: standings.filter { $0.value.rank == 0 }
                .map { ($0.value.place, colourAt[$0.key]) })
        }
        let start = coloursByPlace(script.hands[0].before)
        #expect(coloursByPlace(try #require(script.hands.last).after) == start)
        #expect(coloursByPlace(script.hands[7].after) != start)
    }

    // MARK: 2. 丸四つ組

    /// **Two threads a hand, both 左回り, on opposite sides**: the one from the
    /// top goes down by place 4, the one from the bottom up by place 2.
    @Test func maruYotsuCarriesTwoLeftAboutOnOppositeSides() throws {
        let script = try script(BraidMethodCatalog.maruYotsu4Recipe)
        #expect(script.hands.allSatisfy { $0.carries.count == 2 })
        #expect(script.hands.allSatisfy { $0.carries.allSatisfy { $0.way == .anticlockwise } })
        #expect(script.hands[0].carries.map(seen) == [
            Seen(from: 1, to: 3, way: .anticlockwise, passing: [4]),
            Seen(from: 3, to: 1, way: .anticlockwise, passing: [2]),
        ])
        #expect(script.hands[1].carries.map(seen) == [
            Seen(from: 2, to: 4, way: .anticlockwise, passing: [1]),
            Seen(from: 4, to: 2, way: .anticlockwise, passing: [3]),
        ])
    }

    // MARK: 3. 八つ金剛 S・Z

    /// **As many hands a cycle as the table has steps, and S and Z go opposite
    /// ways** (S 左回り, Z 右回り: `BraidOrientationTests`).
    @Test func yatsuKongoSAndZTurnOppositeWays() throws {
        for (recipe, way) in [
            (BraidMethodCatalog.yatsuKongoS8Recipe, BraidStepWay.anticlockwise),
            (BraidMethodCatalog.yatsuKongoZ8Recipe, BraidStepWay.clockwise),
        ] {
            let stand = try #require(BraidMethodCatalog.stand(for: recipe))
            let method = try #require(recipe.methods(on: stand)?.first)
            let script = try script(recipe)
            #expect(script.hands.count == method.steps.count * script.cycles)
            #expect(script.hands.allSatisfy { $0.carries.allSatisfy { $0.way == way } }, "\(recipe.id)")
        }
    }

    /// **The disk's drift is not drawn**: between hands every thread stands on
    /// a place or beside it, and the stand drawn at a hand's start and end puts
    /// each ball exactly there — for every shipped braid.
    @Test(arguments: BraidMethodCatalog.recipes.map(\.id))
    func betweenHandsEveryThreadIsOnAPlaceOrBesideIt(recipeID: String) throws {
        let recipe = try #require(BraidMethodCatalog.recipes.first { $0.id == recipeID })
        let script = try script(recipe)
        let places = Set(script.stand.positionIDs)
        for hand in script.hands {
            for standings in [hand.before, hand.afterCarrying, hand.after] {
                #expect(standings.count == script.stand.positionCount)
                #expect(standings.values.allSatisfy { places.contains($0.place) && $0.rank <= 1 })
            }
            for (time, standings) in [(0.0, hand.before), (BraidStepTiming.hand, hand.after)] {
                let frame = BraidStepFrame.at(time, of: hand, on: script.stand, reduceMotion: false)
                for ball in frame.balls {
                    let standing = try #require(standings[ball.thread])
                    let expected = BraidStepFrame.polarPoint(of: standing, on: script.stand).cartesian
                    #expect(abs(ball.point.x - expected.x) < 1e-9 && abs(ball.point.y - expected.y) < 1e-9)
                }
            }
        }
        // A time round starts and ends with every thread on its place.
        #expect(script.hands.first?.before.values.allSatisfy { $0.rank == 0 } == true)
        #expect(script.hands.last?.after.values.allSatisfy { $0.rank == 0 } == true)
    }

    // MARK: 4. 八つ金剛返し組

    /// **The hands come table by table, and the way round turns at the tables'
    /// turn**: three tables of S 左回り, three of Z 右回り — the hand-overs too.
    @Test func yatsuKongoGaeshiTurnsAtTheTurnOfTables() throws {
        let script = try script(BraidMethodCatalog.yatsuKongoGaeshi8Recipe)
        #expect(script.tableCount == 6)
        let counts = [8, 8, 12, 8, 8, 12]
        #expect(script.hands.prefix(56).map(\.table) == (0..<6).flatMap { Array(repeating: $0, count: counts[$0]) })
        for hand in script.hands {
            let way: BraidStepWay = hand.table < 3 ? .anticlockwise : .clockwise
            #expect(hand.carries.allSatisfy { $0.way == way }, "table \(hand.table + 1)")
        }
    }

    /// Task 062: **the hand-over is four hands of its own**, after the dan's
    /// four carries: each thread steps over its partner — the thread it was
    /// paired with from the start, places 1・2, 3・4, 5・6, 7・8 — to the far
    /// side, 左回り in the S tables ([4]) and 右回り in the Z ([8]). The carries
    /// before them are the dan's own, two places like every other.
    @Test func gaeshisHandOversAreHandsOfTheirOwn() throws {
        let script = try script(BraidMethodCatalog.yatsuKongoGaeshi8Recipe)
        func partner(_ thread: Int) -> Int { thread % 2 == 1 ? thread + 1 : thread - 1 }
        for (table, way) in [(2, BraidStepWay.anticlockwise), (5, .clockwise)] {
            let hands = script.hands.filter { $0.table == table }.prefix(12)
            #expect(hands.count == 12)
            #expect(hands.map(\.isHandOver) == Array(repeating: false, count: 8) + Array(repeating: true, count: 4))
            for hand in hands.suffix(4) {
                let carry = try #require(hand.carries.first)
                #expect(hand.carries.count == 1 && hand.settling.isEmpty)
                #expect(carry.way == way)
                #expect(carry.passing.count == 1)                   // two places: over the one between
                #expect(carry.over == [partner(carry.thread)], "thread \(carry.thread)")
                #expect(hand.name == "持ち替え")
            }
            for hand in hands.prefix(8).suffix(4) {                 // the dan the hand-over carries on
                let carry = try #require(hand.carries.first)
                #expect(carry.way == way && carry.passing.count == 1)
                #expect(hand.name == (table < 3 ? "Sの組み" : "Zの組み"))
            }
        }
    }

    /// **Split, the carries leave every thread where the table's own moves do**
    /// — at the end of every cycle, over a whole time round.
    @Test func splittingTheHandOversLeavesTheThreadsWhereTheTableDoes() throws {
        let recipe = BraidMethodCatalog.yatsuKongoGaeshi8Recipe
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        let script = try script(recipe)
        let methods = try #require(recipe.methods(on: stand))
        let worked = try #require(BraidWorking.cycles(ofRounds: methods, on: stand, count: script.cycles))
        var cycleEnds = [Int]()
        for (index, hand) in script.hands.enumerated()
        where index == script.hands.count - 1 || script.hands[index + 1].table != hand.table {
            cycleEnds.append(index)
        }
        #expect(cycleEnds.count == script.cycles)
        for (cycle, index) in cycleEnds.enumerated() {
            let table = try #require(worked[cycle].endState.threadByPosition)
            let drawn = Dictionary(uniqueKeysWithValues: script.hands[index].after.map { ($0.value.place, $0.key) })
            #expect(script.hands[index].after.values.allSatisfy { $0.rank == 0 })
            #expect(drawn == table, "cycle \(cycle + 1)")
        }
    }

    /// **What the screens are shown of a table does not reach the working**:
    /// the same tables without their names and hand-overs make the same
    /// methods. And only 返し組's tables have either.
    @Test func theTablesNamesAndHandOversAreNotRead() throws {
        let recipe = BraidMethodCatalog.yatsuKongoGaeshi8Recipe
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        let bare = BraidRecipe(
            id: recipe.id, name: recipe.name,
            rounds: recipe.rounds.map {
                BraidDiskNotation(
                    source: $0.source, notchCount: $0.notchCount,
                    standPositionByRestingNotch: $0.standPositionByRestingNotch, moves: $0.moves,
                    threadsPerStep: $0.threadsPerStep, stepReading: $0.stepReading
                )
            },
            colouring: recipe.colouring, shape: recipe.shape, orderRoundTheBraid: recipe.orderRoundTheBraid
        )
        #expect(recipe.methods(on: stand) == bare.methods(on: stand))
        #expect(recipe.rounds.map(\.handOvers.count) == [0, 0, 4, 0, 0, 4])
        for other in BraidMethodCatalog.recipes where other.id != recipe.id {
            #expect(other.rounds.allSatisfy { $0.handOvers.isEmpty && $0.name == nil }, "\(other.id)")
            #expect(try script(other).hands.allSatisfy { !$0.isHandOver && $0.name == nil })
        }
    }

    /// **Every braided disk move goes the way its places do** wherever the
    /// places say — only a move of half the stand leaves it to the landing.
    @Test(arguments: BraidMethodCatalog.recipes.map(\.id))
    func theDiskMoveGoesTheWayThePlacesDo(recipeID: String) throws {
        let recipe = try #require(BraidMethodCatalog.recipes.first { $0.id == recipeID })
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        let methods = try #require(recipe.methods(on: stand))
        for (method, notation) in zip(methods, recipe.rounds) {
            let ways = try #require(BraidStepScript.ways(of: method, on: notation))
            for (move, way) in zip(method.steps.flatMap(\.moves), ways) {
                let byPlaces = try #require(BraidStepWay.shortWay(
                    forward: move.to - move.from, around: stand.positionCount
                ))
                if byPlaces != .across { #expect(way == byPlaces, "\(move.from)→\(move.to)") }
                #expect(way != .across)
            }
        }
    }

    // MARK: 5. 丸源氏

    /// **The closing is not a hand**: eight hands a cycle, and the closing's
    /// eight tidying moves ride at the end of the eighth, which leaves every
    /// thread on its place.
    @Test func maruGenjisClosingRidesOnTheLastHand() throws {
        let recipe = BraidMethodCatalog.maruGenji16Recipe
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        let method = try #require(recipe.methods(on: stand)?.first)
        #expect(method.closing.moves.count == 8)
        let script = try script(recipe)
        #expect(script.hands.count == method.steps.count * script.cycles)
        for (index, hand) in script.hands.enumerated() {
            if index % method.steps.count == method.steps.count - 1 {
                #expect(hand.settling.map { BraidMove(from: $0.from, to: $0.to) } == method.closing.moves)
                #expect(hand.after.values.allSatisfy { $0.rank == 0 })
            } else {
                #expect(hand.settling.isEmpty)
            }
        }
        // Before the closing, arrivals wait beside places still taken.
        #expect(script.hands[method.steps.count - 1].afterCarrying.values.contains { $0.rank == 1 })
    }

    // MARK: 6. The name is not read

    /// **The same table under another name gives the same script.**
    @Test func theScriptDoesNotReadTheBraidsName() throws {
        let recipe = BraidMethodCatalog.edoYatsu8Recipe
        let renamed = BraidRecipe(
            id: "not-a-braid", name: "架空", rounds: recipe.rounds, colouring: recipe.colouring,
            shape: recipe.shape, orderRoundTheBraid: recipe.orderRoundTheBraid
        )
        #expect(try script(renamed) == script(recipe))
    }

    // MARK: The words

    @Test func handsReadAsOneSentence() throws {
        let edo = try script(BraidMethodCatalog.edoYatsu8Recipe)
        #expect(BraidStepsStrings.sentence(for: edo.hands[0], tableCount: edo.tableCount)
                == "場所7の糸を、右回りに場所1へ")
        #expect(BraidStepsStrings.sentence(for: edo.hands[4], tableCount: edo.tableCount)
                == "場所8の糸を、左回りに場所6へ")
        let yotsu = try script(BraidMethodCatalog.maruYotsu4Recipe)
        #expect(BraidStepsStrings.sentence(for: yotsu.hands[0], tableCount: yotsu.tableCount)
                == "場所1の糸を左回りに場所3へ、場所3の糸を左回りに場所1へ")
        #expect(BraidStepsStrings.count(3, of: 16) == "3 / 16 手目")
    }

    /// Task 062: **返し組 says which, in the book's words**, and no braid's
    /// sentence says 「表」 or 「段」.
    @Test func gaeshisHandsSayTheirTablesAndHandOvers() throws {
        let gaeshi = try script(BraidMethodCatalog.yatsuKongoGaeshi8Recipe)
        let sentences = gaeshi.hands.map { BraidStepsStrings.sentence(for: $0, tableCount: gaeshi.tableCount) }
        #expect(sentences.allSatisfy { sentence in
            ["Sの組み：", "Zの組み：", "持ち替え："].contains { sentence.hasPrefix($0) }
        })
        #expect(sentences[0] == "Sの組み：場所5の糸を、左回りに場所3へ")
        // Table 3 is hands 17-28: its dan, then the hand-overs from hand 25.
        #expect(sentences[24] == "持ち替え：場所8の糸を、隣の糸を越えて場所6へ")
        #expect(sentences[28] == "Zの組み：場所7の糸を、右回りに場所1へ")
        for recipe in BraidMethodCatalog.recipes {
            let script = try script(recipe)
            for hand in script.hands {
                let sentence = BraidStepsStrings.sentence(for: hand, tableCount: script.tableCount)
                #expect(!sentence.contains("表") && !sentence.contains("段"), "\(recipe.id): \(sentence)")
            }
        }
    }

    // MARK: The frame

    /// **A carried thread slides round the rim the way it goes** and rides a
    /// little out as it passes; with 「視差効果を減らす」 it is switched, never
    /// part way.
    @Test func theCarriedThreadSlidesTheWayItGoes() throws {
        let script = try script(BraidMethodCatalog.edoYatsu8Recipe)
        let hand = script.hands[0]
        let middle = BraidStepTiming.lead + BraidStepTiming.carry / 2
        let frame = BraidStepFrame.at(middle, of: hand, on: script.stand, reduceMotion: false)
        let ball = try #require(frame.balls.last)
        #expect(ball.thread == 7 && ball.isCarried)
        var turn = atan2(Double(ball.point.x), -Double(ball.point.y)) / (2 * .pi)
        if turn < 0 { turn += 1 }
        #expect(turn > 0.75 && turn < 1)        // between place 7 and place 1, by place 8
        #expect(hypot(ball.point.x, ball.point.y) > 1)
        #expect(frame.arrows == [BraidStepFrame.Arrow(from: 7, to: 1, way: .clockwise)])

        let places = [hand.before, hand.afterCarrying, hand.after].compactMap { $0[7] }
            .map { BraidStepFrame.polarPoint(of: $0, on: script.stand).cartesian }
        for time in stride(from: 0.0, through: BraidStepTiming.hand, by: 0.05) {
            let still = BraidStepFrame.at(time, of: hand, on: script.stand, reduceMotion: true)
            let point = try #require(still.balls.first { $0.thread == 7 }).point
            #expect(places.contains { abs($0.x - point.x) < 1e-9 && abs($0.y - point.y) < 1e-9 })
        }
    }

    // MARK: Playing

    @Test func playbackOpensStoppedBeforeTheFirstHandAndStepsBothWays() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let hand = BraidStepTiming.hand
        var playback = BraidStepPlayback(handCount: 16)
        #expect(!playback.isRunning)
        #expect(playback.position(at: start.addingTimeInterval(10)) == .init(hand: 0, time: 0))

        playback.stepForward(at: start)
        #expect(playback.isRunning && !playback.isPlaying)
        #expect(playback.position(at: start.addingTimeInterval(hand / 2)).hand == 0)
        let after = start.addingTimeInterval(hand + 0.1)
        #expect(playback.hasFinishedStepping(at: after))
        playback.settle(at: after)
        #expect(!playback.isRunning)
        #expect(playback.position(at: after) == .init(hand: 1, time: 0))

        playback.stepBack(at: after)
        #expect(playback.position(at: after) == .init(hand: 0, time: 0))
        playback.stepBack(at: after)
        #expect(playback.position(at: after) == .init(hand: 15, time: 0))

        playback.play(at: after)
        #expect(playback.isPlaying)
        let later = after.addingTimeInterval(2.5 * hand)
        let there = playback.position(at: later)
        #expect(there.hand == 1 && abs(there.time - hand / 2) < 1e-9)
        playback.pause(at: later)
        #expect(!playback.isRunning)
        #expect(playback.position(at: later.addingTimeInterval(5)) == there)
        playback.stepBack(at: later)
        #expect(playback.position(at: later) == .init(hand: 1, time: 0))
    }
}
