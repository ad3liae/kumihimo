import Foundation

/// One thread lifted from one position and set down at another.
///
/// **A move names positions, not threads.** Which thread it carries depends on
/// where the work has got to, so it is the state that answers that and the table
/// stays the same on every repeat. The old per-braid tables named the thread as
/// well, which is why they had to be rebuilt each cycle.
struct BraidMove: Hashable, Sendable {
    let from: Int
    let to: Int
}

/// The moves worked at one instant. Threads moved in the same step are moved
/// together — the books say "take the outer two of the east group" and mean both
/// hands at once.
struct BraidStep: Equatable, Sendable {
    /// The name the source gives the step. **Not read by the derivation.**
    let name: String
    let moves: [BraidMove]
}

/// A way of braiding: a stand, and an ordered sequence of steps that returns the
/// stand to its own arrangement once through.
///
/// **The order of the steps is not decoration. It decides which thread lies over
/// which**: where two threads cross, the one moved later in the cycle lies on
/// top, because it is laid down on what is already there.
struct BraidMethod: Equatable, Sendable {
    let id: String
    let standID: String

    /// One cycle's steps, in working order.
    let steps: [BraidStep]

    /// The tidying up at the end of the cycle, which spreads the groups back out
    /// after the arrivals have crowded their middles. It is one more instant, and
    /// the last one — for the outermost places of the braid it is the only instant
    /// at which they receive a thread.
    let closing: BraidStep

    /// Every instant of one cycle, the closing included.
    var instants: [BraidStep] { steps + [closing] }

    var instantCount: Int { instants.count }

    var allMoves: [BraidMove] { instants.flatMap(\.moves) }
}

/// Which thread stands where, part way through a cycle.
///
/// A position holds a queue rather than a single thread. Part way through a cycle
/// it really does hold two: a thread arrives at the middle of a group before the
/// thread already there has been spread outwards, and the closing step is what
/// undoes that. **A move takes the thread that has stood there longest**, which is
/// the one the newcomer was set down beside. That single rule reproduces both
/// known tables, whose own wording had to name the thread to say the same thing.
struct BraidStandState: Equatable, Sendable {
    /// Threads at each position, oldest arrival first.
    private(set) var threadsByPosition: [Int: [Int]]

    init(threadsByPosition: [Int: [Int]]) {
        self.threadsByPosition = threadsByPosition
    }

    /// One thread at each position, numbered to match it. The arrangement every
    /// method here starts from.
    static func start(on stand: BraidStand) -> BraidStandState {
        BraidStandState(
            threadsByPosition: Dictionary(
                uniqueKeysWithValues: stand.positionIDs.map { ($0, [$0]) }
            )
        )
    }

    /// True when every position holds exactly one thread, which is what a cycle
    /// boundary looks like.
    var isSettled: Bool { threadsByPosition.values.allSatisfy { $0.count == 1 } }

    /// The settled arrangement as one thread per position. `nil` part way through
    /// a cycle, where a position may hold two.
    var threadByPosition: [Int: Int]? {
        guard isSettled else { return nil }
        return threadsByPosition.compactMapValues(\.first)
    }

    var positionByThread: [Int: Int]? {
        guard let threadByPosition else { return nil }
        return Dictionary(uniqueKeysWithValues: threadByPosition.map { ($0.value, $0.key) })
    }

    /// The state after one step, and which thread each move carried.
    ///
    /// Every departure is taken before any arrival is set down, so the moves of a
    /// step happen together rather than one after another.
    /// The threads come back in the order the step lists its moves.
    func applying(_ step: BraidStep) -> (state: BraidStandState, carried: [Int])? {
        var next = threadsByPosition
        var carried = [Int]()

        for move in step.moves {
            guard let queue = next[move.from], let thread = queue.first else { return nil }
            next[move.from] = Array(queue.dropFirst())
            carried.append(thread)
        }
        for (move, thread) in zip(step.moves, carried) {
            next[move.to, default: []].append(thread)
        }
        return (BraidStandState(threadsByPosition: next), carried)
    }
}

/// What one worked cycle did: the arrangement it started from, which thread each
/// move carried at each instant, and the arrangement it left behind.
///
/// **The end state is worked out by applying the steps, never written down.** Both
/// of the older per-braid tables wrote it by hand alongside the moves, so the same
/// fact had two sources and nothing checked they agreed.
struct BraidCycle: Equatable, Sendable {
    struct Instant: Equatable, Sendable {
        /// 1 for the first step; the closing is `method.instantCount`.
        let ordinal: Int
        let step: BraidStep
        /// The thread each move of this step carried, in the order `step.moves`
        /// lists them.
        let carried: [Int]
    }

    let startState: BraidStandState
    let instants: [Instant]
    let endState: BraidStandState

    var allCarried: [(instant: Int, move: BraidMove, thread: Int)] {
        instants.flatMap { instant in
            zip(instant.step.moves, instant.carried).map { (instant.ordinal, $0, $1) }
        }
    }
}

enum BraidWorking {
    /// Works one cycle from the given arrangement. `nil` when a move has nothing
    /// to lift, or when the cycle does not leave every position holding one
    /// thread — either of which means the table is not a cycle of this stand.
    static func cycle(of method: BraidMethod, from state: BraidStandState) -> BraidCycle? {
        var current = state
        var instants = [BraidCycle.Instant]()
        for (index, step) in method.instants.enumerated() {
            guard let applied = current.applying(step) else { return nil }
            instants.append(
                BraidCycle.Instant(ordinal: index + 1, step: step, carried: applied.carried)
            )
            current = applied.state
        }
        guard current.isSettled else { return nil }
        return BraidCycle(startState: state, instants: instants, endState: current)
    }

    /// Consecutive cycles from the stand's starting arrangement.
    static func cycles(of method: BraidMethod, on stand: BraidStand, count: Int) -> [BraidCycle]? {
        guard count > 0 else { return nil }
        var state = BraidStandState.start(on: stand)
        var result = [BraidCycle]()
        for _ in 0..<count {
            guard let worked = cycle(of: method, from: state) else { return nil }
            result.append(worked)
            state = worked.endState
        }
        return result
    }

    /// How many cycles the stand takes to come back to the arrangement it started
    /// from. **Worked out, not assumed.** `nil` if it never does inside `limit`,
    /// which would mean the table is not a repeat at all.
    static func repeatCycleCount(
        of method: BraidMethod,
        on stand: BraidStand,
        limit: Int = 64
    ) -> Int? {
        let start = BraidStandState.start(on: stand)
        var state = start
        for count in 1...max(1, limit) {
            guard let worked = cycle(of: method, from: state) else { return nil }
            state = worked.endState
            if state == start { return count }
        }
        return nil
    }
}
