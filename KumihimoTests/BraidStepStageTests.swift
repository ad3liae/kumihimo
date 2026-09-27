import CoreGraphics
import Foundation
import Testing
@testable import Kumihimo

/// Task 066, Task 067: **the step animation as drawn** — every thread at the
/// angle the working puts it, the hands in words as the picture shows them,
/// no two bobbins on top of each other.
@MainActor
struct BraidStepStageTests {
    private func stage(_ recipe: BraidRecipe, colours: [ThreadAssignment]? = nil) throws -> BraidStepStage {
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        let colouring = colours ?? recipe.colouring
        return try #require(BraidStepStage(
            recipe: recipe, stand: stand,
            colours: Dictionary(uniqueKeysWithValues: colouring.map { ($0.position, $0.colorID) })
        ))
    }

    private func recipe(_ id: String) throws -> BraidRecipe {
        try #require(BraidMethodCatalog.recipes.first { $0.id == id })
    }

    private func sentences(_ stage: BraidStepStage) -> [String] {
        (0..<stage.handCount).map { stage.stations(ofHand: $0).sentence }
    }

    private func between(_ from: Double, _ to: Double) -> Double { BraidBookWorking.between(from, to) }

    private func homeTurn(_ stage: BraidStepStage, _ place: Int) -> Double {
        stage.labels.first { $0.text == "\(place)" }?.turn ?? -1
    }

    // MARK: 1. 八つ金剛 and 江戸八つ組 on the book's disk

    /// **八つ金剛 S's hand 1 takes the south pair's right-hand thread round
    /// outside the east pair to beside the north pair's right-hand one** (p.37
    /// figure 1, slit 20 to slit 6), and every dan is the printed one.
    @Test func kongoSIsTheBooksDisk() throws {
        let stage = try stage(try recipe("yatsu-kongo-s-8"))
        let first = stage.stations(ofHand: 0)
        #expect(first.carried == [5])
        #expect(first.sentence == "場所5の糸を、左回りに場所2の隣へ")
        let before = try #require(first.before[5]), landing = try #require(first.afterCarrying[5])
        #expect(abs(between(homeTurn(stage, 5), before.turn)) < 1e-9)
        #expect(between(homeTurn(stage, 2), landing.turn) > 0)
        let middle = BraidStepFrame.slide(from: before, to: landing, way: .anticlockwise, share: 0.5, lift: 0)
        #expect(abs(between(0.25, middle.turn)) < 0.06)
        let said = sentences(stage)
        #expect(Array(said[0..<4]) == [
            "場所5の糸を、左回りに場所2の隣へ", "場所1の糸を、左回りに場所6の隣へ",
            "場所3の糸を、左回りに場所8の隣へ", "場所7の糸を、左回りに場所4の隣へ",
        ])
        for dan in stride(from: 4, to: said.count, by: 4) {
            #expect(Array(said[dan..<(dan + 4)]) == Array(said[0..<4]), "from hand \(dan + 1)")
        }
    }

    /// 8Z's hand 1 is S's mirror, and its dans repeat too.
    @Test func kongoZIsSsMirror() throws {
        let said = sentences(try stage(try recipe("yatsu-kongo-z-8")))
        #expect(said.first == "場所2の糸を、右回りに場所5の隣へ")
        for dan in stride(from: 4, to: said.count, by: 4) {
            #expect(Array(said[dan..<(dan + 4)]) == Array(said[0..<4]))
        }
    }

    /// **江戸八つ組's hand 1 sets place 1's thread down in slit 11, beside place
    /// 3 on place 2's side** (figure 1), and hand 4's settle lays it on into
    /// place 3 (figure 5: an adjustment, not a hand).
    @Test func edoYatsuIsTheTextbooksDisk() throws {
        let stage = try stage(try recipe("edo-yatsu-8"))
        let first = stage.stations(ofHand: 0)
        #expect(first.sentence == "場所1の糸を、右回りに場所3の隣へ")
        let landing = try #require(first.afterCarrying[1])
        #expect(between(homeTurn(stage, 2), landing.turn) > 0 && between(landing.turn, homeTurn(stage, 3)) > 0)
        let fourth = stage.stations(ofHand: 3)
        #expect(fourth.settled == [1])
        #expect(abs(between(homeTurn(stage, 3), try #require(fourth.after[1]).turn)) < 1e-9)
    }

    /// 返し組 says its tables and its hand-overs, in the book's words.
    @Test func gaeshiSaysItsTablesAndHandOvers() throws {
        let said = sentences(try stage(try recipe("yatsu-kongo-gaeshi-8")))
        #expect(said.first?.hasPrefix("Sの組み：") == true)
        let overs = said.filter { $0.hasPrefix("持ち替え：") }
        #expect(overs.count == 8)
        #expect(overs.allSatisfy { $0.contains("隣の糸を越えて") })
        #expect(said.contains { $0.hasPrefix("Zの組み：") })
    }

    /// 丸四つ組 carries two at once, and sets them down beside the places they
    /// are tidied into.
    @Test func maruYotsuCarriesTwoAtOnce() throws {
        let stage = try stage(try recipe("maru-yotsu-4"))
        #expect(stage.stations(ofHand: 0).sentence == "場所1の糸を左回りに場所3の隣へ、場所3の糸を左回りに場所1の隣へ")
        #expect(stage.stations(ofHand: 0).settled == [1, 3])
    }

    // MARK: 2. 丸源氏 and 平源氏 on the textbook's round stand

    /// **丸源氏's four hands, in the textbook's words** (p.94–95), carried
    /// straight over the mirror; the stand labelled with its faces, 1面 at the
    /// top, 2面 on the left, 3面 at the bottom, 4面 on the right.
    @Test func maruGenjiIsTheTextbooksRoundStand() throws {
        let stage = try stage(try recipe("maru-genji-16"))
        #expect(Array(sentences(stage).prefix(4)) == [
            "3面の左端と右端の糸を、1面の中央へ（左手・右手）",
            "1面の左端と右端の糸を、3面の中央へ（左手・右手）",
            "4面の奥と手前の糸を、2面の中央へ（右手・左手）",
            "2面の奥と手前の糸を、4面の中央へ（右手・左手）",
        ])
        #expect(stage.labels == [
            .init(text: "1", turn: 0), .init(text: "4", turn: 0.25),
            .init(text: "3", turn: 0.5), .init(text: "2", turn: 0.75),
        ])
        let first = stage.stations(ofHand: 0)
        #expect(first.carried.count == 2)
        #expect(first.ways.values.allSatisfy { $0 == .across })
        // The left hand's thread lands left of the middle of 1面, the right hand's right.
        let landings = first.carried.compactMap { first.afterCarrying[$0]?.turn }.map { between(0, $0) }.sorted()
        #expect(landings.count == 2 && landings[0] < 0 && landings[1] > 0)
    }

    /// 平源氏's fifth and sixth hands, in the textbook's words (p.96–97).
    @Test func hiraGenjiSaysTheTextbooksWords() throws {
        let said = sentences(try stage(try recipe("hira-genji-16")))
        #expect(said[2] == "3面の左から2番目と右から2番目の糸を、1面の中央へ（左手・右手）")
        #expect(said[4] == "3面の左端の糸を1面の左端の糸の右側へ、3面の右端の糸を1面の右端の糸の左側へ（左手・右手）")
        #expect(said[5] == "1面の左端と右端の糸を、3面の左端と右端へ（左手・右手）")
    }

    // MARK: 3. No two bobbins on top of each other

    /// **At no moment of any hand do two bobbins overlap**, but for a carried
    /// one passing over the threads it goes by, which it is drawn over on
    /// purpose, and a thread the settle moves on purpose. At the start and end
    /// of every hand none at all overlap.
    @Test(arguments: BraidMethodCatalog.recipes.map(\.id))
    func noTwoBobbinsOverlap(recipeID: String) throws {
        let stage = try stage(try recipe(recipeID))
        let least = 2 * stage.layout.ballRadius
        func check(_ balls: [BraidStepFrame.Ball], _ label: String) {
            for (index, one) in balls.enumerated() {
                for other in balls[(index + 1)...] {
                    let distance = hypot(one.point.x - other.point.x, one.point.y - other.point.y)
                    #expect(distance >= least - 1e-9, "\(recipeID) \(label): threads \(one.thread) and \(other.thread)")
                }
            }
        }
        for number in 0..<stage.handCount {
            let stations = stage.stations(ofHand: number)
            for reduceMotion in [false, true] {
                for time in stride(from: 0.0, through: BraidStepTiming.hand, by: 0.05) {
                    let frame = BraidStepFrame.at(time, of: stations, carried: stations.carried, reduceMotion: reduceMotion)
                    check(frame.balls.filter { !$0.isCarried }, "hand \(number + 1) at \(time)")
                }
            }
            for time in [0, BraidStepTiming.hand] {
                let frame = BraidStepFrame.at(time, of: stations, carried: stations.carried, reduceMotion: false)
                check(frame.balls, "hand \(number + 1) standing at \(time)")
            }
        }
    }

    // MARK: 4. Moving and playing

    /// **A carried thread slides round the rim the way it goes** and rides a
    /// little out as it passes; with 「視差効果を減らす」 it is switched, never part
    /// way. 江戸八つ組's hand 1 takes place 1's thread clockwise past place 2.
    @Test func theCarriedThreadSlidesTheWayItGoes() throws {
        let stage = try stage(try recipe("edo-yatsu-8"))
        let stations = stage.stations(ofHand: 0)
        let middle = BraidStepTiming.lead + BraidStepTiming.carry / 2
        let frame = BraidStepFrame.at(middle, of: stations, carried: stations.carried, reduceMotion: false)
        let ball = try #require(frame.balls.last)
        #expect(ball.thread == 1 && ball.isCarried)
        var turn = atan2(Double(ball.point.x), -Double(ball.point.y)) / (2 * .pi)
        if turn < 0 { turn += 1 }
        #expect(between(homeTurn(stage, 2), turn) > 0 && between(turn, homeTurn(stage, 3)) > 0)
        #expect(hypot(ball.point.x, ball.point.y) > 1)
        let landing = try #require(stations.afterCarrying[1])
        #expect(frame.arrows == [BraidStepFrame.Arrow(from: homeTurn(stage, 1), to: landing.turn, way: .clockwise)])
        let places = [stations.before, stations.afterCarrying, stations.after].compactMap { $0[1] }.map(\.cartesian)
        for time in stride(from: 0.0, through: BraidStepTiming.hand, by: 0.05) {
            let still = BraidStepFrame.at(time, of: stations, carried: stations.carried, reduceMotion: true)
            let point = try #require(still.balls.first { $0.thread == 1 }).point
            #expect(places.contains { abs($0.x - point.x) < 1e-9 && abs($0.y - point.y) < 1e-9 })
        }
    }

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
