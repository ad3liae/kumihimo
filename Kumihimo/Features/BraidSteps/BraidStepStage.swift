import Foundation

/// **Where every thread stands at each moment of each hand, and what the hand
/// is called** (Task 066, Task 067, Task 068): the working (`BraidBookWorking`)
/// as the drawing plays it. Before the hand, where its carries set the threads
/// down, and after it has settled — the book's adjustments made. **At the end
/// of a dan one more step sets every thread back in the starting form**: it is
/// not a hand, and the count stays at the dan's last.
///
/// The places are named where they began: 「場所5」 on one, 「場所2の隣」
/// between. A braid worked on a round stand's faces is said in the book's own
/// words instead (「3面の左端と右端の糸を、1面の中央へ（左手・右手）」), and
/// its faces are what the stand is labelled with.
struct BraidStepStage {
    struct Stations: Equatable {
        /// The hand it is, or whose dan it ends, from 0.
        let hand: Int
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
    private let handSteps: [Int]

    var geometry: BraidBookGeometry { working.geometry }
    /// Hands in a time round.
    var handCount: Int { working.hands.count }
    /// Hands and settings in a time round: what the playback steps through.
    var stepCount: Int { steps.count }

    init?(recipe: BraidRecipe, stand: BraidStand, colours: [Int: ThreadColorID] = [:]) {
        guard let working = BraidBookWorking(recipe: recipe, stand: stand, colours: colours),
              !working.hands.isEmpty else { return nil }
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
        var handSteps = [Int]()
        for (index, hand) in working.hands.enumerated() {
            let before = polars(hand.before), afterCarrying = polars(hand.afterCarrying), after = polars(hand.after)
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
                sentence = BraidStepsStrings.standSentence(standHand)
            } else {
                sentence = BraidStepsStrings.diskSentence(
                    carries: hand.carries.map { carry in
                        (from: spot(at: before[carry.thread]?.turn ?? 0),
                         to: spot(at: afterCarrying[carry.thread]?.turn ?? 0),
                         way: carry.way)
                    },
                    isHandOver: hand.isHandOver,
                    name: working.tableCount > 1 || hand.isHandOver ? hand.name : nil
                )
            }
            handSteps.append(steps.count)
            steps.append(Stations(
                hand: index, isSetting: false, carried: Set(hand.carries.map(\.thread)),
                before: before, afterCarrying: afterCarrying, after: after,
                settled: Set(hand.adjustments.map(\.thread)), ways: ways, arrows: arrows,
                sentence: sentence
            ))
            if let setting = hand.setting.map(polars) {
                steps.append(Stations(
                    hand: index, isSetting: true,
                    carried: Set(setting.keys.filter { setting[$0] != after[$0] }),
                    before: after, afterCarrying: setting, after: setting,
                    settled: [], ways: [:], arrows: [], sentence: BraidStepsStrings.setting
                ))
            }
        }
        switch working.form {
        case .disk:
            labels = homeTurns.sorted { $0.key < $1.key }.map { Label(text: "\($0.key)", turn: $0.value) }
        case .stand(let hands):
            labels = hands.faces.map { Label(text: "\($0.number)", turn: $0.turn) }
        }
        self.working = working
        self.steps = steps
        self.handSteps = handSteps
    }

    /// The playback's step: a hand, or a setting after one.
    func stations(ofStep index: Int) -> Stations {
        steps[min(max(index, 0), steps.count - 1)]
    }

    /// A hand's own step.
    func stations(ofHand index: Int) -> Stations {
        stations(ofStep: handSteps[min(max(index, 0), handSteps.count - 1)])
    }

    /// The setting that follows a hand, if one does.
    func setting(afterHand index: Int) -> Stations? {
        let next = handSteps[min(max(index, 0), handSteps.count - 1)] + 1
        guard next < steps.count, steps[next].isSetting else { return nil }
        return steps[next]
    }
}
