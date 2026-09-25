import Foundation

/// Which way a thread goes round the stand, seen from above (Task 061).
enum BraidStepWay: Equatable, Sendable {
    /// 右回り: clockwise from above, the way the position numbers run.
    case clockwise
    /// 左回り.
    case anticlockwise
    /// Straight over the middle: a move of exactly half the stand whose table
    /// does not say which way round. No shipped table has one.
    case across

    /// The way that goes a given distance round a rim of `count`, the short way.
    /// `nil` for no distance.
    static func shortWay(forward: Int, around count: Int) -> BraidStepWay? {
        guard count > 0 else { return nil }
        let forward = (forward % count + count) % count
        guard forward != 0 else { return nil }
        if forward * 2 == count { return .across }
        return forward * 2 < count ? .clockwise : .anticlockwise
    }
}

/// Where a thread stands between two hands (Task 061): on a place, or beside it,
/// waiting for the thread there to leave.
struct BraidStepStanding: Equatable, Sendable {
    let place: Int
    /// 0 on the place; 1 beside it, set down while the place's own thread is
    /// still there (`BraidStandState`'s queue, oldest first).
    let rank: Int
    /// The way a waiting thread came, which is the side it waits on. `nil` on
    /// the place.
    let cameBy: BraidStepWay?
}

/// **A braid's working, hand by hand, for the step animation** (Task 061).
///
/// **A hand is a step of the recipe's tables** (`BraidMethod.steps`): one thread
/// carried, or a printed step's two for a table read `.oneStepAnInstant`. The
/// closing is not a hand — it only tidies the threads back out (the author,
/// 2026-09-25: 「仮置きは次のための調整なので…段を増やす必要はない」) — and moves
/// at the end of the cycle's last hand, as `settling`. The disk's parking and
/// drift are already inside the steps (`BraidDiskNotation.method`), so nothing
/// here stands anywhere but on a place or beside one.
///
/// **Which way a carry goes round is the table's**: the short way of the move
/// it is on the disk (`braidingMoves`, in the order the steps carry them), 右回り
/// for the way the notches count. By places alone a move of half the stand has
/// no way round; its landing says (丸四つ組).
///
/// **A carry the table folds a hand-over into is shown as two** (Task 062):
/// 返し組's last dan before each turn carries four threads, and the book then
/// steps each over its partner (「隣の紐を向こう側へ跨がせる」). The table
/// writes each as one move; its `handOvers` say where the dan left the thread.
/// So the carry stops there, and after the last carry it splits come the
/// hand-overs, a hand each, in the book's order. **A hand-over is a hand**: it
/// goes over a thread, where the closing's tidying goes over none.
///
/// **Read from the recipe and the stand only**, never from a braid's name.
struct BraidStepScript: Equatable, Sendable {
    /// One thread carried from one place to another.
    struct Carry: Equatable, Sendable {
        /// Named by the place it stood at when the braid began.
        let thread: Int
        let from: Int
        let to: Int
        let way: BraidStepWay
        /// The places it goes past, in the order it passes them.
        let passing: [Int]
        /// **The threads it goes over** (Task 059's reading): those standing on
        /// or waiting beside the places it passes, and one waiting beside the
        /// place it leaves on the side it leaves by — in the order passed.
        let over: [Int]
    }

    struct Hand: Equatable, Sendable {
        /// Which of the recipe's tables this hand is from, from 0.
        let table: Int
        /// A hand-over split out of a carry, rather than a step of the table.
        let isHandOver: Bool
        /// What the table calls this hand, when it says: the table's name
        /// (「Sの組み」) for its steps, the hand-over's (「持ち替え」) for its
        /// hand-overs.
        let name: String?
        let carries: [Carry]
        /// **Moves that are not a hand, worked at the end of this one**: the
        /// cycle's closing, after its last hand. Empty for most hands.
        let settling: [Carry]
        /// Every thread's standing before the hand, after its carries, and after
        /// the settling too. `after` is the next hand's `before`.
        let before: [Int: BraidStepStanding]
        let afterCarrying: [Int: BraidStepStanding]
        let after: [Int: BraidStepStanding]
    }

    let stand: BraidStand
    let tableCount: Int
    /// How many cycles make one time round the animation.
    let cycles: Int
    let hands: [Hand]

    /// **Until every place shows the colour it began with**, a whole number of
    /// times through the tables; the animation then starts again from the top.
    /// Without `colours`, until every thread is back. No more than the stand's
    /// thread count in cycles, rounded up to whole passes: when nothing comes
    /// back within that, the loop is that long.
    ///
    /// `nil` when a table is not a cycle of the stand, or when its steps and
    /// its disk moves do not line up.
    init?(recipe: BraidRecipe, stand: BraidStand, colours: [Int: ThreadColorID] = [:]) {
        guard let methods = recipe.methods(on: stand), methods.count == recipe.rounds.count else {
            return nil
        }
        var ways = [[BraidStepWay]]()
        for (method, notation) in zip(methods, recipe.rounds) {
            guard let tableWays = Self.ways(of: method, on: notation) else { return nil }
            ways.append(tableWays)
        }
        let tables = methods.count
        let limit = tables * Int((Double(max(stand.positionCount, tables)) / Double(tables)).rounded(.up))
        guard let cycles = Self.cyclesUntilTheColoursReturn(
            methods, on: stand, colours: colours, limit: limit
        ) else { return nil }

        var plans = [[Planned]]()
        for (table, (method, notation)) in zip(methods, recipe.rounds).enumerated() {
            guard let planned = Self.plan(method, notation, ways: ways[table]) else { return nil }
            plans.append(planned)
        }

        var state = BraidStandState.start(on: stand)
        var cameBy = [Int: BraidStepWay]()
        var hands = [Hand]()
        for cycle in 0..<cycles {
            let table = cycle % tables
            let method = methods[table]
            let notation = recipe.rounds[table]
            var carriedBySplit = [BraidMove: Int]()     // a split carry -> the thread it carried
            for (index, planned) in plans[table].enumerated() {
                let before = Self.standings(state, cameBy: cameBy)
                guard let applied = state.applying(planned.step) else { return nil }
                if let handOver = planned.handOver {
                    // The hand-over takes on the thread its carry brought there.
                    guard let expected = carriedBySplit[handOver.carry], applied.carried == [expected] else {
                        return nil
                    }
                }
                var carries = [Carry]()
                for (order, (move, thread)) in zip(planned.step.moves, applied.carried).enumerated() {
                    let way = planned.ways[order]
                    carries.append(Self.carry(thread, move, way, from: before, on: stand))
                    cameBy[thread] = way
                    if let split = planned.splits[order] { carriedBySplit[split] = thread }
                }
                state = applied.state
                let afterCarrying = Self.standings(state, cameBy: cameBy)

                var settling = [Carry]()
                if index == plans[table].count - 1, !method.closing.moves.isEmpty {
                    guard let closed = state.applying(method.closing) else { return nil }
                    for (move, thread) in zip(method.closing.moves, closed.carried) {
                        guard
                            let from = stand.rimIndex(ofPositionID: move.from),
                            let to = stand.rimIndex(ofPositionID: move.to),
                            let way = BraidStepWay.shortWay(forward: to - from, around: stand.positionCount)
                        else { return nil }
                        settling.append(Self.carry(thread, move, way, from: afterCarrying, on: stand))
                        cameBy[thread] = way
                    }
                    state = closed.state
                }
                hands.append(Hand(
                    table: table, isHandOver: planned.handOver != nil,
                    name: planned.handOver != nil ? notation.handOverName : notation.name,
                    carries: carries, settling: settling,
                    before: before, afterCarrying: afterCarrying,
                    after: Self.standings(state, cameBy: cameBy)
                ))
            }
            guard state.isSettled else { return nil }
        }
        self.stand = stand
        self.tableCount = tables
        self.cycles = cycles
        self.hands = hands
    }

    /// One hand of a table, as it will be worked.
    private struct Planned {
        let step: BraidStep
        let ways: [BraidStepWay]
        /// For each move, the carry it is the first part of, if it is split.
        let splits: [BraidMove?]
        /// Set on a hand-over's own hand.
        let handOver: BraidDiskNotation.HandOver?
    }

    /// A table's hands: its steps, each carry that `handOvers` splits stopped
    /// where the dan left it, and after the last of those, the hand-overs.
    /// `nil` when a hand-over names no carry of the table, or says no way round.
    private static func plan(
        _ method: BraidMethod, _ notation: BraidDiskNotation, ways: [BraidStepWay]
    ) -> [Planned]? {
        let splits = Dictionary(
            notation.handOvers.map { ($0.carry, $0) }, uniquingKeysWith: { first, _ in first }
        )
        let moves = method.steps.flatMap(\.moves)
        guard splits.count == notation.handOvers.count, splits.keys.allSatisfy(moves.contains) else {
            return nil
        }
        func way(_ notches: Int) -> BraidStepWay? {
            BraidStepWay.shortWay(forward: notches, around: notation.notchCount)
        }
        let lastSplit = method.steps.lastIndex { $0.moves.contains { splits[$0] != nil } }
        var planned = [Planned]()
        var carried = 0
        for (index, step) in method.steps.enumerated() {
            var stepMoves = [BraidMove](), stepWays = [BraidStepWay](), stepSplits = [BraidMove?]()
            for move in step.moves {
                if let split = splits[move] {
                    guard let first = way(split.firstNotches) else { return nil }
                    stepMoves.append(BraidMove(from: move.from, to: split.via))
                    stepWays.append(first)
                    stepSplits.append(move)
                } else {
                    stepMoves.append(move)
                    stepWays.append(ways[carried])
                    stepSplits.append(nil)
                }
                carried += 1
            }
            planned.append(Planned(
                step: BraidStep(name: step.name, moves: stepMoves),
                ways: stepWays, splits: stepSplits, handOver: nil
            ))
            if index == lastSplit {
                for handOver in notation.handOvers {
                    guard let second = way(handOver.handOverNotches) else { return nil }
                    planned.append(Planned(
                        step: BraidStep(
                            name: "hand-over", moves: [BraidMove(from: handOver.via, to: handOver.carry.to)]
                        ),
                        ways: [second], splits: [nil], handOver: handOver
                    ))
                }
            }
        }
        return planned
    }

    /// The way round of each carry of a table, in the order its steps carry
    /// them: the short way of the matching disk move. `nil` when the two do not
    /// line up — a disk move that does not start from the carry's place.
    static func ways(of method: BraidMethod, on notation: BraidDiskNotation) -> [BraidStepWay]? {
        let moves = method.steps.flatMap(\.moves)
        let disk = notation.braidingMoves
        guard moves.count == disk.count else { return nil }
        var ways = [BraidStepWay]()
        for (move, notches) in zip(moves, disk) {
            guard
                notation.standPositionByRestingNotch[notches.from] == move.from,
                let way = BraidStepWay.shortWay(
                    forward: notches.to - notches.from, around: notation.notchCount
                )
            else { return nil }
            ways.append(way)
        }
        return ways
    }

    /// The fewest whole passes through the tables after which every place
    /// shows its first colour — or, without colours, holds its first thread;
    /// `limit` when none does within it. `nil` when a table does not run.
    private static func cyclesUntilTheColoursReturn(
        _ methods: [BraidMethod], on stand: BraidStand, colours: [Int: ThreadColorID], limit: Int
    ) -> Int? {
        guard let worked = BraidWorking.cycles(ofRounds: methods, on: stand, count: limit) else {
            return nil
        }
        func isBack(_ thread: Int, at place: Int) -> Bool {
            colours.isEmpty ? thread == place : colours[thread] == colours[place]
        }
        for cycles in stride(from: methods.count, through: limit, by: methods.count) {
            guard let threadByPosition = worked[cycles - 1].endState.threadByPosition else { return nil }
            if threadByPosition.allSatisfy({ isBack($0.value, at: $0.key) }) { return cycles }
        }
        return limit
    }

    private static func standings(
        _ state: BraidStandState, cameBy: [Int: BraidStepWay]
    ) -> [Int: BraidStepStanding] {
        var result = [Int: BraidStepStanding]()
        for (place, queue) in state.threadsByPosition {
            for (rank, thread) in queue.enumerated() {
                result[thread] = BraidStepStanding(
                    place: place, rank: rank, cameBy: rank == 0 ? nil : cameBy[thread]
                )
            }
        }
        return result
    }

    private static func carry(
        _ thread: Int, _ move: BraidMove, _ way: BraidStepWay,
        from before: [Int: BraidStepStanding], on stand: BraidStand
    ) -> Carry {
        let passing = passedPlaces(from: move.from, to: move.to, way: way, on: stand)
        // A thread waiting beside the place left waits on the side it came
        // from; the carry goes over it when it leaves by that side.
        let waitsOnTheWayOut: BraidStepWay = way == .clockwise ? .anticlockwise : .clockwise
        var over = before
            .filter { $0.key != thread && $0.value.place == move.from && $0.value.rank > 0
                && way != .across && $0.value.cameBy == waitsOnTheWayOut }
            .map(\.key).sorted()
        for place in passing {
            over += before
                .filter { $0.key != thread && $0.value.place == place }
                .sorted { $0.value.rank < $1.value.rank }
                .map(\.key)
        }
        return Carry(
            thread: thread, from: move.from, to: move.to, way: way, passing: passing, over: over
        )
    }

    /// The places strictly between two, going round the given way. None for a
    /// move across the middle.
    static func passedPlaces(from: Int, to: Int, way: BraidStepWay, on stand: BraidStand) -> [Int] {
        guard
            way != .across, from != to,
            let start = stand.rimIndex(ofPositionID: from),
            let end = stand.rimIndex(ofPositionID: to)
        else { return [] }
        let count = stand.positionCount
        let step = way == .clockwise ? 1 : -1
        var places = [Int]()
        var index = start
        while true {
            index = ((index + step) % count + count) % count
            if index == end { break }
            places.append(stand.positions[index].id)
        }
        return places
    }
}
