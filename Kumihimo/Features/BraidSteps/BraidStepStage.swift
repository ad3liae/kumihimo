import Foundation

/// **Where every thread stands at each moment of each hand, and what the hand
/// is called** (Task 066, Task 067, Task 068): the working's round
/// (`BraidBookWorking.round`) as the drawing plays it. Before the hand, where
/// its carries set the threads down, and after it has settled — the book's
/// adjustments made. **At the end of a dan one more step sets every thread back
/// in the starting form**: it is not a hand, and the count stays at the dan's
/// last.
///
/// **The round plays on and on, and the threads go on with it** (Task 068
/// 追補1): a ball is named by the place it stands at as its dan begins, and
/// which thread it is — whose colour — follows from how many dans have gone
/// (`threads(atStep:)`). Nothing is wound back.
///
/// **A dan the book works again and again is shown once at the normal speed,
/// and the rest of the times fast-forwarded** (Task 069): one step of the
/// playback, every hand of every time really worked, so the colours are the
/// braid's own.
///
/// The places are named where they began: 「場所5」 on one, 「場所2の隣」
/// between. A braid worked on a round stand's faces is said in the book's own
/// words instead (「3面の左端と右端の糸を、1面の中央へ（左手・右手）」), and
/// its faces are what the stand is labelled with.
struct BraidStepStage {
    struct Stations: Equatable {
        /// The hand it is in its dan, or the dan's last for a setting, from 0.
        let hand: Int
        /// Hands in its dan.
        let handsInDan: Int
        /// **Setting the threads back once a dan is done**: not a hand, and
        /// nothing lit.
        let isSetting: Bool
        /// **Worked again, fast-forwarded** (Task 069): nothing lit, no arrow.
        let isFastForward: Bool
        /// The threads the step moves as it carries: a hand's carries, lit from
        /// its start until it settles; every thread a setting moves.
        let carried: Set<Int>
        let before: [Int: BraidStepFrame.Polar]
        let afterCarrying: [Int: BraidStepFrame.Polar]
        let after: [Int: BraidStepFrame.Polar]
        /// Threads the settle moves on purpose, lit as they go: the book's
        /// adjustments.
        let settled: Set<Int>
        /// The way round each moving thread goes.
        let ways: [Int: BraidStepWay]
        let arrows: [BraidStepFrame.Arrow]
        /// The hand in words, as the picture shows it.
        let sentence: String

        /// The same, fast-forwarded and said otherwise.
        func fastForwarded(saying sentence: String) -> Stations {
            Stations(
                hand: hand, handsInDan: handsInDan, isSetting: isSetting, isFastForward: true, carried: carried,
                before: before, afterCarrying: afterCarrying, after: after, settled: settled, ways: ways,
                arrows: [], sentence: sentence
            )
        }
    }

    /// A number drawn round the stand: a place's, or a face's.
    struct Label: Equatable {
        let text: String
        let turn: Double
    }

    /// **One hand or setting within a step of the playback**: a step is one
    /// of them, or a fast-forward of many.
    struct Part: Equatable {
        let stations: Stations
        let timing: BraidStepTiming
        /// The dan worked, counted through the round's dans every time the
        /// book works them.
        let dan: Int
    }

    /// **What to draw at a moment of a step**: the hand or setting, the time
    /// into it, and which thread each ball is.
    struct Moment: Equatable {
        let stations: Stations
        let time: Double
        let timing: BraidStepTiming
        let threads: [Int: Int]
    }

    let working: BraidBookWorking
    let labels: [Label]
    private let steps: [[Part]]
    /// The fast-forwards, and what is said of each when it is not played out
    /// (「この4手を6回くり返した」).
    private let doneSaying: [Int: String]
    private let handSteps: [Int]
    /// For each dan worked in a round, the place each ball stood at as the
    /// round began.
    private let fromRoundStart: [[Int: Int]]
    /// **Where the thread at each place as a round begins stood as the round
    /// before it began**: one round's turning of the threads.
    private let roundBefore: [Int: Int]
    /// Rounds until every thread is back where it began.
    private let roundsToComeBack: Int

    var geometry: BraidBookGeometry { working.geometry }
    /// Hands in a round, each shown at the normal speed once.
    var handCount: Int { handSteps.count }
    /// Steps of the playback in a round: hands, settings and fast-forwards,
    /// again and again.
    var stepCount: Int { steps.count }
    /// How long each step of a round takes.
    var durations: [Double] { steps.map { $0.reduce(0) { $0 + $1.timing.hand } } }
    /// The steps that fast-forward.
    var fastForwardSteps: Set<Int> { Set(doneSaying.keys) }

    init?(recipe: BraidRecipe, stand: BraidStand) {
        guard let working = BraidBookWorking(recipe: recipe, stand: stand),
              working.round.contains(where: { !$0.hands.isEmpty }) else { return nil }
        func polars(_ seats: [Int: BraidBookWorking.Seat]) -> [Int: BraidStepFrame.Polar] {
            seats.mapValues { BraidStepFrame.Polar(turn: $0.turn, radius: $0.radius) }
        }
        let homeTurns = working.homes.mapValues(\.turn)
        // On a place within half a drawn notch: a thread set down beside
        // another is a whole one off.
        let onAPlace: Double
        if case .disk(let notches) = working.form {
            onAPlace = working.geometry.notchTurn(notches: notches) / 2
        } else {
            onAPlace = working.geometry.faceTurn / 2
        }
        func spot(at turn: Double) -> BraidStepsStrings.Spot {
            let nearest = homeTurns.min {
                abs(BraidBookWorking.between(turn, $0.value)) < abs(BraidBookWorking.between(turn, $1.value))
            }
            let onIt = nearest.map { abs(BraidBookWorking.between(turn, $0.value)) < onAPlace } ?? false
            return BraidStepsStrings.Spot(place: nearest?.key ?? 1, isBeside: !onIt)
        }

        var steps = [[Part]]()
        var doneSaying = [Int: String]()
        var handSteps = [Int]()
        var worked = 0
        for dan in working.round {
            // The dan once, at the normal speed: its hands and its setting.
            var once = [Stations]()
            let named = dan.hands.first.flatMap { working.tableCount > 1 || $0.isHandOver ? $0.name : nil }
            let name = BraidStepsStrings.danName(named, hands: dan.hands.count, repeats: dan.repeats)
            for (index, hand) in dan.hands.enumerated() {
                let before = polars(hand.before), afterCarrying = polars(hand.afterCarrying)
                let after = polars(hand.after)
                var ways = [Int: BraidStepWay]()
                for move in hand.carries + hand.adjustments { ways[move.thread] = move.way }
                let arrows = hand.carries.compactMap { carry in
                    before[carry.thread].flatMap { from in
                        afterCarrying[carry.thread].map {
                            BraidStepFrame.Arrow(from: from.turn, to: $0.turn, way: carry.way)
                        }
                    }
                }
                let sentence: String
                if let standHand = hand.standHand {
                    sentence = BraidStepsStrings.named(name, BraidStepsStrings.standSentence(standHand))
                } else {
                    sentence = BraidStepsStrings.diskSentence(
                        carries: hand.carries.map { carry in
                            (from: spot(at: before[carry.thread]?.turn ?? 0),
                             to: spot(at: afterCarrying[carry.thread]?.turn ?? 0),
                             way: carry.way)
                        },
                        isHandOver: hand.isHandOver,
                        name: name
                    )
                }
                once.append(Stations(
                    hand: index, handsInDan: dan.hands.count, isSetting: false, isFastForward: false,
                    carried: Set(hand.carries.map(\.thread)),
                    before: before, afterCarrying: afterCarrying, after: after,
                    settled: Set(hand.adjustments.map(\.thread)), ways: ways, arrows: arrows,
                    sentence: sentence
                ))
                if let setting = hand.setting.map(polars) {
                    once.append(Stations(
                        hand: index, handsInDan: dan.hands.count, isSetting: true, isFastForward: false,
                        carried: Set(setting.keys.filter { setting[$0] != after[$0] }),
                        before: after, afterCarrying: setting, after: setting,
                        settled: [], ways: [:], arrows: [], sentence: BraidStepsStrings.setting
                    ))
                }
            }
            for stations in once {
                if !stations.isSetting { handSteps.append(steps.count) }
                steps.append([Part(stations: stations, timing: .normal, dan: worked)])
            }
            worked += 1
            // The second time to the last, fast-forwarded as one step.
            if dan.repeats > 1 {
                var fast = [Part]()
                for time in 2...dan.repeats {
                    let saying = BraidStepsStrings.repeating(named, hands: dan.hands.count, time: time, of: dan.repeats)
                    fast += once.map {
                        Part(stations: $0.fastForwarded(saying: saying), timing: .fastForward, dan: worked)
                    }
                    worked += 1
                }
                doneSaying[steps.count] = BraidStepsStrings.repeated(named, hands: dan.hands.count, times: dan.repeats)
                steps.append(fast)
            }
        }

        // Each dan's balls named back to the places they stood at as the round
        // began, dan by dan, every time the book works it.
        let places = Array(working.homes.keys)
        var fromRoundStart = [Dictionary(uniqueKeysWithValues: places.map { ($0, $0) })]
        for dan in working.round {
            for _ in 0..<dan.repeats {
                guard let current = fromRoundStart.last else { return nil }
                var next = [Int: Int]()
                for (from, to) in dan.ends {
                    guard let start = current[from] else { return nil }
                    next[to] = start
                }
                guard next.count == places.count else { return nil }
                fromRoundStart.append(next)
            }
        }
        guard let roundBefore = fromRoundStart.popLast(), fromRoundStart.count == worked else { return nil }
        var rounds = 1
        var turned = roundBefore
        while turned.contains(where: { $0.key != $0.value }), rounds <= places.count * places.count {
            turned = turned.mapValues { roundBefore[$0] ?? $0 }
            rounds += 1
        }

        switch working.form {
        case .disk:
            labels = homeTurns.sorted { $0.key < $1.key }.map { Label(text: "\($0.key)", turn: $0.value) }
        case .stand(let hands):
            labels = hands.faces.map { Label(text: BraidStepsStrings.face($0.number), turn: $0.turn) }
        }
        self.working = working
        self.steps = steps
        self.doneSaying = doneSaying
        self.handSteps = handSteps
        self.fromRoundStart = fromRoundStart
        self.roundBefore = roundBefore
        roundsToComeBack = rounds
    }

    /// **What to draw at a moment of any step**, the round played again and
    /// again: step 0 is the first hand, `stepCount` the first hand again, -1
    /// the last step of the round before. **With 「視差効果を減らす」 a
    /// fast-forward is not played out**: it stands at its end, said to be done.
    func moment(atStep step: Int, time: Double, reduceMotion: Bool) -> Moment {
        let index = Self.wrapped(step, steps.count)
        let parts = steps[index]
        if reduceMotion, let done = doneSaying[index], let last = parts.last {
            return Moment(
                stations: last.stations.fastForwarded(saying: done), time: last.timing.hand, timing: last.timing,
                threads: threads(of: last, atStep: step)
            )
        }
        var into = max(time, 0)
        for part in parts.dropLast() {
            guard into >= part.timing.hand else {
                return Moment(stations: part.stations, time: into, timing: part.timing, threads: threads(of: part, atStep: step))
            }
            into -= part.timing.hand
        }
        let last = parts[parts.count - 1]
        return Moment(stations: last.stations, time: into, timing: last.timing, threads: threads(of: last, atStep: step))
    }

    /// Every hand or setting of a step, each at its start.
    func moments(ofStep step: Int) -> [Moment] {
        steps[Self.wrapped(step, steps.count)].map {
            Moment(stations: $0.stations, time: 0, timing: $0.timing, threads: threads(of: $0, atStep: step))
        }
    }

    /// A step's first hand or setting.
    func stations(ofStep step: Int) -> Stations {
        steps[Self.wrapped(step, steps.count)][0].stations
    }

    /// **Which thread each ball is as a step begins** — the place it stood at
    /// when the braid began, whose colour it has —, the rounds before it having
    /// turned the threads on.
    func threads(atStep step: Int) -> [Int: Int] {
        threads(of: steps[Self.wrapped(step, steps.count)][0], atStep: step)
    }

    /// A hand's own step in the round, the hands counted through its dans.
    func stations(ofHand index: Int) -> Stations {
        stations(ofStep: handSteps[Self.wrapped(index, handSteps.count)])
    }

    /// The setting that follows a hand, if one does.
    func setting(afterHand index: Int) -> Stations? {
        let next = handSteps[Self.wrapped(index, handSteps.count)] + 1
        guard next < steps.count, steps[next][0].stations.isSetting, !steps[next][0].stations.isFastForward
        else { return nil }
        return steps[next][0].stations
    }

    private func threads(of part: Part, atStep step: Int) -> [Int: Int] {
        let round = Int((Double(step) / Double(steps.count)).rounded(.down))
        let times = Self.wrapped(round, roundsToComeBack)
        return fromRoundStart[part.dan].mapValues { place in
            var thread = place
            for _ in 0..<times { thread = roundBefore[thread] ?? thread }
            return thread
        }
    }

    private static func wrapped(_ value: Int, _ count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (value % count + count) % count
    }
}
