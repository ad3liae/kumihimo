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
/// which thread it is — whose colour — follows from how many rounds have gone
/// (`threads(atStep:)`). Nothing is wound back.
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
    }

    /// A number drawn round the stand: a place's, or a face's.
    struct Label: Equatable {
        let text: String
        let turn: Double
    }

    let working: BraidBookWorking
    let labels: [Label]
    private let steps: [Stations]
    /// The dan each step is in.
    private let danOfStep: [Int]
    private let handSteps: [Int]
    /// For each dan of the round, the place each ball stood at as the round
    /// began.
    private let fromRoundStart: [[Int: Int]]
    /// **Where the thread at each place as a round begins stood as the round
    /// before it began**: one round's turning of the threads.
    private let roundBefore: [Int: Int]
    /// Rounds until every thread is back where it began.
    private let roundsToComeBack: Int

    var geometry: BraidBookGeometry { working.geometry }
    /// Hands in a round.
    var handCount: Int { handSteps.count }
    /// Hands and settings in a round: what the playback steps through, again
    /// and again.
    var stepCount: Int { steps.count }

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

        var steps = [Stations]()
        var danOfStep = [Int]()
        var handSteps = [Int]()
        for (danIndex, dan) in working.round.enumerated() {
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
                // 返し組's S dan: 「Sの組み（この4手を6回くり返す）」.
                let named = working.tableCount > 1 || hand.isHandOver ? hand.name : nil
                let name = BraidStepsStrings.danName(named, hands: dan.hands.count, repeats: dan.repeats)
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
                handSteps.append(steps.count)
                danOfStep.append(danIndex)
                steps.append(Stations(
                    hand: index, handsInDan: dan.hands.count, isSetting: false,
                    carried: Set(hand.carries.map(\.thread)),
                    before: before, afterCarrying: afterCarrying, after: after,
                    settled: Set(hand.adjustments.map(\.thread)), ways: ways, arrows: arrows,
                    sentence: sentence
                ))
                if let setting = hand.setting.map(polars) {
                    danOfStep.append(danIndex)
                    steps.append(Stations(
                        hand: index, handsInDan: dan.hands.count, isSetting: true,
                        carried: Set(setting.keys.filter { setting[$0] != after[$0] }),
                        before: after, afterCarrying: setting, after: setting,
                        settled: [], ways: [:], arrows: [], sentence: BraidStepsStrings.setting
                    ))
                }
            }
        }

        // Each dan's balls named back to the places they stood at as the round
        // began, dan by dan.
        let places = Array(working.homes.keys)
        var fromRoundStart = [Dictionary(uniqueKeysWithValues: places.map { ($0, $0) })]
        for dan in working.round {
            guard let current = fromRoundStart.last else { return nil }
            var next = [Int: Int]()
            for (from, to) in dan.ends {
                guard let start = current[from] else { return nil }
                next[to] = start
            }
            guard next.count == places.count else { return nil }
            fromRoundStart.append(next)
        }
        guard let roundBefore = fromRoundStart.popLast() else { return nil }
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
        self.danOfStep = danOfStep
        self.handSteps = handSteps
        self.fromRoundStart = fromRoundStart
        self.roundBefore = roundBefore
        roundsToComeBack = rounds
    }

    /// **Any step, the round played again and again**: step 0 is the first
    /// hand, `stepCount` the first hand again, -1 the last step of the round
    /// before.
    func stations(ofStep step: Int) -> Stations {
        steps[Self.wrapped(step, steps.count)]
    }

    /// **Which thread each ball is at a step** — the place it stood at when the
    /// braid began, whose colour it has —, the rounds before it having turned
    /// the threads on.
    func threads(atStep step: Int) -> [Int: Int] {
        let index = Self.wrapped(step, steps.count)
        let round = Int((Double(step) / Double(steps.count)).rounded(.down))
        let times = Self.wrapped(round, roundsToComeBack)
        return fromRoundStart[danOfStep[index]].mapValues { place in
            var thread = place
            for _ in 0..<times { thread = roundBefore[thread] ?? thread }
            return thread
        }
    }

    /// A hand's own step in the round, the hands counted through its dans.
    func stations(ofHand index: Int) -> Stations {
        stations(ofStep: handSteps[Self.wrapped(index, handSteps.count)])
    }

    /// The setting that follows a hand, if one does.
    func setting(afterHand index: Int) -> Stations? {
        let next = handSteps[Self.wrapped(index, handSteps.count)] + 1
        guard next < steps.count, steps[next].isSetting else { return nil }
        return steps[next]
    }

    private static func wrapped(_ value: Int, _ count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (value % count + count) % count
    }
}
