import Foundation

/// **Where every thread stands at each moment of each hand, and what the hand
/// is called** (Task 066, Task 067): the working (`BraidBookWorking`) turned
/// into angles on the drawn stand. Before the hand, where its carries set the
/// threads down, and after it has settled — the adjustments made, and the
/// islands drawn back when they are as they began.
///
/// The places are named where they began: 「場所5」 on one, 「場所2の隣」
/// between. A braid worked on a round stand's faces is said in the book's own
/// words instead (「3面の左端と右端の糸を、1面の中央へ（左手・右手）」), and
/// its faces are what the stand is labelled with.
struct BraidStepStage {
    struct Stations: Equatable {
        /// The threads the hand carries, lit from its start until it settles.
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
    let layout: BraidStepLayout
    let labels: [Label]
    private let byHand: [Stations]

    var handCount: Int { byHand.count }

    init?(recipe: BraidRecipe, stand: BraidStand, colours: [Int: ThreadColorID] = [:]) {
        guard let working = BraidBookWorking(recipe: recipe, stand: stand, colours: colours),
              !working.hands.isEmpty else { return nil }
        let layout = BraidStepLayout(placeCount: stand.positionCount)
        let step = layout.stepTurn(for: working.form)
        func turn(_ seat: BraidBookWorking.Seat) -> Double {
            BraidBookWorking.unit(seat.turn + seat.offset * step)
        }
        func polars(_ seats: [Int: BraidBookWorking.Seat]) -> [Int: BraidStepFrame.Polar] {
            seats.mapValues { BraidStepFrame.Polar(turn: turn($0), radius: 1) }
        }
        let homeTurns = working.homes.mapValues(turn)
        func spot(at turn: Double) -> BraidStepsStrings.Spot {
            let nearest = homeTurns.min {
                abs(BraidBookWorking.between(turn, $0.value)) < abs(BraidBookWorking.between(turn, $1.value))
            }
            // On it within half a drawn step: an island spread about its middle
            // moves its threads a little off where they began.
            let onIt = nearest.map { abs(BraidBookWorking.between(turn, $0.value)) < step / 2 } ?? false
            return BraidStepsStrings.Spot(place: nearest?.key ?? 1, isBeside: !onIt)
        }

        byHand = working.hands.map { hand in
            let before = polars(hand.before), afterCarrying = polars(hand.afterCarrying)
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
            if hand.standCarries.isEmpty {
                sentence = BraidStepsStrings.diskSentence(
                    carries: hand.carries.map { carry in
                        (from: spot(at: before[carry.thread]?.turn ?? 0),
                         to: spot(at: afterCarrying[carry.thread]?.turn ?? 0),
                         way: carry.way)
                    },
                    isHandOver: hand.isHandOver,
                    name: working.tableCount > 1 || hand.isHandOver ? hand.name : nil
                )
            } else {
                sentence = BraidStepsStrings.standSentence(hand.standCarries)
            }
            return Stations(
                carried: Set(hand.carries.map(\.thread)),
                before: before, afterCarrying: afterCarrying, after: polars(hand.after),
                settled: Set(hand.adjustments.map(\.thread)), ways: ways, arrows: arrows,
                sentence: sentence
            )
        }
        switch working.form {
        case .disk:
            labels = homeTurns.sorted { $0.key < $1.key }.map { Label(text: "\($0.key)", turn: $0.value) }
        case .stand(let hands):
            labels = hands.faces.map { Label(text: "\($0.number)", turn: $0.turn) }
        }
        self.working = working
        self.layout = layout
    }

    func stations(ofHand index: Int) -> Stations {
        byHand[min(max(index, 0), byHand.count - 1)]
    }
}
