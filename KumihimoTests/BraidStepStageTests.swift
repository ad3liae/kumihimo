import CoreGraphics
import Foundation
import Testing
@testable import Kumihimo

/// Task 066, Task 067, Task 068: **the step animation as drawn** — every
/// thread at the angle the working puts it, the hands in words as the picture
/// shows them, the threads set back once a dan is done, no two bobbins on top
/// of each other.
@MainActor
struct BraidStepStageTests {
    private func stage(_ recipe: BraidRecipe) throws -> BraidStepStage {
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        return try #require(BraidStepStage(recipe: recipe, stand: stand))
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
        // The round is the one dan (Task 068 追補1): the book's 「【1】〜【4】をくり返す」.
        #expect(sentences(stage) == [
            "場所5の糸を、左回りに場所2の隣へ", "場所1の糸を、左回りに場所6の隣へ",
            "場所3の糸を、左回りに場所8の隣へ", "場所7の糸を、左回りに場所4の隣へ",
        ])
    }

    /// 8Z's hand 1 is S's mirror, and its round is one dan too.
    @Test func kongoZIsSsMirror() throws {
        let said = sentences(try stage(try recipe("yatsu-kongo-z-8")))
        #expect(said.first == "場所2の糸を、右回りに場所5の隣へ")
        #expect(said.count == 4)
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

    /// **返し組 says its tables and its hand-overs, in the book's words, each
    /// dan once**, the S and Z dans with how many times they are worked (Task
    /// 068 追補1), counted 1 to 4 in each dan.
    @Test func gaeshiSaysItsTablesAndHandOvers() throws {
        let stage = try stage(try recipe("yatsu-kongo-gaeshi-8"))
        let said = sentences(stage)
        #expect(said.count == 16)
        #expect(said[0..<4].allSatisfy { $0.hasPrefix("Sの組み（この4手を6回くり返す）：") })
        #expect(said[4..<8].allSatisfy { $0.hasPrefix("持ち替え：") && $0.contains("隣の糸を越えて") })
        #expect(said[8..<12].allSatisfy { $0.hasPrefix("Zの組み（この4手を6回くり返す）：") })
        #expect(said[12..<16].allSatisfy { $0.hasPrefix("持ち替え：") && $0.contains("隣の糸を越えて") })
        let counts = (0..<stage.handCount).map { stage.stations(ofHand: $0) }.map { "\($0.hand + 1)/\($0.handsInDan)" }
        #expect(counts == Array(repeating: ["1/4", "2/4", "3/4", "4/4"], count: 4).flatMap { $0 })
    }

    // MARK: 2. Setting back once a dan is done

    /// **八つ金剛 S sets its threads back after hand 4, and only then** (Task
    /// 068): one step more, 「位置をそろえる」, not a hand — the count stays at 4
    /// —, nothing lit and no arrow, every thread slid the short way to the
    /// starting form.
    @Test func kongoSSetsItsThreadsBackAfterADan() throws {
        let stage = try stage(try recipe("yatsu-kongo-s-8"))
        #expect(stage.stepCount == stage.handCount + stage.handCount / 4)
        let steps = (0..<stage.stepCount).map { stage.stations(ofStep: $0) }
        #expect(steps.map(\.isSetting) == (0..<stage.stepCount).map { $0 % 5 == 4 })
        let setting = steps[4]
        #expect(setting.hand == 3 && setting.handsInDan == 4 && setting.sentence == "位置をそろえる")
        #expect(setting.arrows.isEmpty && setting.settled.isEmpty)
        #expect(setting.before == steps[3].after)
        #expect(setting.carried == Set(1...8))
        #expect(stage.setting(afterHand: 3) == setting && stage.setting(afterHand: 0) == nil)
        for time in stride(from: 0.0, through: BraidStepTiming.hand, by: 0.05) {
            let frame = BraidStepFrame.at(time, of: setting, carried: setting.carried, reduceMotion: false)
            #expect(frame.balls.allSatisfy { !$0.isCarried } && frame.arrows.isEmpty)
            #expect(frame.balls.allSatisfy { abs(hypot($0.point.x, $0.point.y) - 1) < 1e-9 })
        }
    }

    // MARK: 3. 丸四つ組 as the textbook works it (p.52)

    /// **丸四つ組 in the textbook's words** (p.52), and nothing to set back.
    @Test func maruYotsuSaysTheTextbooksWords() throws {
        let stage = try stage(try recipe("maru-yotsu-4"))
        #expect(sentences(stage) == [
            "1面の糸を3面へ、3面の糸を1面へ（時計回り、同時に）",
            "2面の糸を4面へ、4面の糸を2面へ（反時計回り、同時に）",
        ])
        #expect(stage.stepCount == stage.handCount)
        #expect(stage.stations(ofHand: 0).carried == [1, 3] && stage.stations(ofHand: 1).carried == [2, 4])
        #expect(stage.stations(ofHand: 0).settled.isEmpty)
    }

    /// **Hand 1 turns clockwise and hand 2 anticlockwise, the two threads at
    /// once, and neither further than half a turn** (Task 068 2.1, 3.4): the
    /// thread's angle, followed through every moment of the hand, goes half a
    /// turn the book's way and never past it — not on, and back. The threads
    /// not carried never move.
    @Test func maruYotsuTurnsTheTextbooksWaysAndNoFurther() throws {
        let stage = try stage(try recipe("maru-yotsu-4"))
        for (hand, sign) in [(0, 1.0), (1, -1.0)] {
            let stations = stage.stations(ofHand: hand)
            var turned = [Int: Double]()
            var last = [Int: Double]()
            var most = [Int: Double]()
            for time in stride(from: 0.0, through: BraidStepTiming.hand, by: 0.01) {
                let frame = BraidStepFrame.at(time, of: stations, carried: stations.carried, reduceMotion: false)
                for ball in frame.balls {
                    var turn = atan2(Double(ball.point.x), -Double(ball.point.y)) / (2 * .pi)
                    if turn < 0 { turn += 1 }
                    if let before = last[ball.thread] {
                        let step = between(before, turn)
                        #expect(step * sign >= -1e-9, "hand \(hand + 1): thread \(ball.thread) turns back")
                        turned[ball.thread, default: 0] += step
                    }
                    last[ball.thread] = turn
                    most[ball.thread] = max(most[ball.thread] ?? 0, abs(turned[ball.thread] ?? 0))
                }
                // The two carried threads have always turned alike: at once.
                let carried = stations.carried.sorted().compactMap { turned[$0] }
                #expect(carried.count < 2 || abs(carried[0] - carried[1]) < 1e-9, "hand \(hand + 1) at \(time)")
            }
            for thread in 1...4 {
                let whole = turned[thread] ?? 0
                if stations.carried.contains(thread) {
                    #expect(abs(whole - sign * 0.5) < 1e-9, "hand \(hand + 1): thread \(thread) \(whole)")
                    #expect((most[thread] ?? 0) <= 0.5 + 1e-9, "hand \(hand + 1): thread \(thread)")
                } else {
                    #expect((most[thread] ?? 0) < 1e-9, "hand \(hand + 1): thread \(thread)")
                }
            }
        }
    }

    // MARK: 4. 丸源氏 and 平源氏 on the textbook's round stand

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
        // 「1面」, not 「1」: not to be read as the colouring screen's place 1 (Task 068 追補1).
        #expect(stage.labels == [
            .init(text: "1面", turn: 0), .init(text: "4面", turn: 0.25),
            .init(text: "3面", turn: 0.5), .init(text: "2面", turn: 0.75),
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

    // MARK: 5. No two bobbins on top of each other

    /// **At no moment of any hand or setting do two bobbins overlap**, but for
    /// a carried one passing over the threads it goes by, which it is drawn
    /// over on purpose, and a thread the settle moves on purpose. At the start
    /// and end of every step none at all overlap.
    @Test(arguments: BraidMethodCatalog.recipes.map(\.id))
    func noTwoBobbinsOverlap(recipeID: String) throws {
        let stage = try stage(try recipe(recipeID))
        let least = 2 * stage.geometry.ballRadius
        func check(_ balls: [BraidStepFrame.Ball], _ label: String) {
            for (index, one) in balls.enumerated() {
                for other in balls[(index + 1)...] {
                    let distance = hypot(one.point.x - other.point.x, one.point.y - other.point.y)
                    #expect(distance >= least - 1e-9, "\(recipeID) \(label): threads \(one.thread) and \(other.thread)")
                }
            }
        }
        for number in 0..<stage.stepCount {
            let stations = stage.stations(ofStep: number)
            for reduceMotion in [false, true] {
                for time in stride(from: 0.0, through: BraidStepTiming.hand, by: 0.05) {
                    let frame = BraidStepFrame.at(time, of: stations, carried: stations.carried, reduceMotion: reduceMotion)
                    check(frame.balls.filter { !$0.isCarried }, "step \(number + 1) at \(time)")
                }
            }
            for time in [0, BraidStepTiming.hand] {
                let frame = BraidStepFrame.at(time, of: stations, carried: stations.carried, reduceMotion: false)
                check(frame.balls, "step \(number + 1) standing at \(time)")
            }
        }
    }

    // MARK: 6. The round played on and on

    /// **The round plays again and again, and the threads go on with it**
    /// (Task 068 追補1): at every step the balls start where the step before
    /// left them, the same thread in each — over the end of a round and back
    /// past the first step alike. Nothing is wound back: after one round of
    /// 八つ金剛 S the threads are not where they began.
    @Test(arguments: BraidMethodCatalog.recipes.map(\.id))
    func theThreadsGoOnFromRoundToRound(recipeID: String) throws {
        let stage = try stage(try recipe(recipeID))
        let count = stage.stepCount
        for step in (-2 * count + 1)...(3 * count) {
            let now = stage.stations(ofStep: step), was = stage.stations(ofStep: step - 1)
            let threads = stage.threads(atStep: step), threadsBefore = stage.threads(atStep: step - 1)
            #expect(Set(threads.values) == Set(1...threads.count), "\(recipeID) step \(step)")
            for (ball, thread) in threads {
                let there = try #require(now.before[ball])
                let ballBefore = try #require(threadsBefore.first { $0.value == thread }?.key)
                let left = try #require(was.after[ballBefore])
                #expect(abs(between(there.turn, left.turn)) < 1e-9 && abs(there.radius - left.radius) < 1e-9,
                        "\(recipeID) step \(step): thread \(thread)")
            }
        }
        if recipeID == "yatsu-kongo-s-8" {
            #expect(stage.threads(atStep: count) != stage.threads(atStep: 0))
        }
    }

    // MARK: 7. Moving and playing

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
        var playback = BraidStepPlayback()
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
        // Back past the first step: the round before's last (Task 068 追補1).
        playback.stepBack(at: after)
        #expect(playback.position(at: after) == .init(hand: -1, time: 0))

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
