import Foundation

/// **Where the step animation is, and whether it is moving** (Task 061).
///
/// Worked out from a clock rather than stepped by a timer: at any moment the
/// position is the hand and the time into it, found from where it was when it
/// last started. Opening shows **hand 1 before it moves, stopped**; the person
/// starts it. Going back a hand is standing at an earlier hand's start — the
/// script already says how everything stands there.
///
/// **The steps are counted on and on, never wrapped** (Task 068 追補1): the
/// stage plays its round again and again, the threads going on with it, and
/// going back from the first step is the round before's last.
///
/// **A step may take longer than a hand** (Task 069): a dan the book works
/// again and again is fast-forwarded as one step, and going back passes it,
/// to the step before it.
struct BraidStepPlayback: Equatable {
    struct Position: Equatable {
        /// The step, from 0: any whole number, before 0 included.
        let hand: Int
        /// Seconds into it.
        let time: Double
    }

    /// How long each step of a round takes, in seconds; the round repeats.
    let durations: [Double]
    /// The steps of a round going back does not stop at: the fast-forwards.
    let passedGoingBack: Set<Int>

    /// Where it stood when it last started or stopped.
    private(set) var hand = 0
    private(set) var time: Double = 0
    /// When it started; `nil` while stopped.
    private(set) var runningSince: Date?
    /// Running one hand only: it stops at the start of the next.
    private(set) var stopsAtNextHand = false

    /// Where each step of a round begins, from the round's start.
    private let starts: [Double]
    private let roundDuration: Double

    init(durations: [Double] = [BraidStepTiming.normal.hand], passedGoingBack: Set<Int> = []) {
        let durations = durations.isEmpty ? [BraidStepTiming.normal.hand] : durations.map { max($0, 0.01) }
        self.durations = durations
        self.passedGoingBack = passedGoingBack
        var starts = [Double]()
        var total = 0.0
        for duration in durations {
            starts.append(total)
            total += duration
        }
        self.starts = starts
        roundDuration = total
    }

    var isRunning: Bool { runningSince != nil }
    /// Playing on through the hands, which is what the play button shows as
    /// playing. One hand stepped through is not.
    var isPlaying: Bool { isRunning && !stopsAtNextHand }

    func duration(of hand: Int) -> Double { durations[Self.wrapped(hand, durations.count)] }

    func position(at date: Date) -> Position {
        guard let runningSince else { return Position(hand: hand, time: time) }
        let elapsed = time + max(0, date.timeIntervalSince(runningSince))
        if stopsAtNextHand, elapsed >= duration(of: hand) {
            return Position(hand: hand + 1, time: 0)
        }
        return position(atClock: clock(of: hand) + elapsed)
    }

    /// True once a hand stepped through has reached the next: time to `settle`.
    func hasFinishedStepping(at date: Date) -> Bool {
        guard let runningSince, stopsAtNextHand else { return false }
        return time + date.timeIntervalSince(runningSince) >= duration(of: hand)
    }

    mutating func play(at date: Date) {
        if isRunning { anchor(at: date) } else { runningSince = date }
        stopsAtNextHand = false
    }

    mutating func pause(at date: Date) {
        stop(at: position(at: date))
    }

    /// Stopped: work the rest of this hand and stop at the next. Running: stand
    /// at the start of the next hand, stopped.
    mutating func stepForward(at date: Date) {
        let now = position(at: date)
        if isRunning {
            stop(at: Position(hand: now.hand + 1, time: 0))
        } else {
            anchor(at: date)
            runningSince = date
            stopsAtNextHand = true
        }
    }

    /// To the start of this hand if it has begun, else to the start of the one
    /// before — **never to a fast-forward**, but to the step before it (Task
    /// 069). Always stopped.
    mutating func stepBack(at date: Date) {
        let now = position(at: date)
        var target = now.time > 0 ? now.hand : now.hand - 1
        var passed = 0
        while passedGoingBack.contains(Self.wrapped(target, durations.count)), passed < durations.count {
            target -= 1
            passed += 1
        }
        stop(at: Position(hand: target, time: 0))
    }

    /// Stops a hand stepped through where it ended.
    mutating func settle(at date: Date) {
        guard hasFinishedStepping(at: date) else { return }
        stop(at: position(at: date))
    }

    private mutating func stop(at position: Position) {
        hand = position.hand
        time = position.time
        runningSince = nil
        stopsAtNextHand = false
    }

    private mutating func anchor(at date: Date) {
        let now = position(at: date)
        hand = now.hand
        time = now.time
        if runningSince != nil { runningSince = date }
    }

    /// Seconds from the start of round 0 to the start of a step.
    private func clock(of hand: Int) -> Double {
        let round = Int((Double(hand) / Double(durations.count)).rounded(.down))
        return Double(round) * roundDuration + starts[Self.wrapped(hand, durations.count)]
    }

    private func position(atClock clock: Double) -> Position {
        let round = (clock / roundDuration).rounded(.down)
        let within = clock - round * roundDuration
        let index = starts.lastIndex { $0 <= within + 1e-12 } ?? 0
        return Position(hand: Int(round) * durations.count + index, time: max(0, within - starts[index]))
    }

    private static func wrapped(_ value: Int, _ count: Int) -> Int {
        (value % count + count) % count
    }
}
