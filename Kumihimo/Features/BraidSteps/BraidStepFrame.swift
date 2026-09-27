import CoreGraphics
import Foundation

/// How long each part of a hand takes, in seconds (Task 061). **The author
/// decides the speed**; the normal follows the reviewer's 0.8 s a hand and
/// 0.4 s between.
struct BraidStepTiming: Equatable {
    /// The carried thread lit and its arrow shown, before it moves.
    let lead: Double
    /// Sliding round the rim to where it goes.
    let carry: Double
    /// The closing's tidying, and a thread waiting beside a place moving on to it.
    let settle: Double
    /// Still, before the next hand.
    let rest: Double

    var hand: Double { lead + carry + settle + rest }

    static let normal = BraidStepTiming(lead: 0.35, carry: 0.8, settle: 0.3, rest: 0.4)
    /// **A hand fast-forwarded** (Task 069): about a quarter of a second, no
    /// time before it moves.
    static let fastForward = BraidStepTiming(lead: 0, carry: 0.17, settle: 0.05, rest: 0.03)
}

/// **Where everything on the stand is at one moment of a hand** (Task 061), on
/// a stand of unit radius seen from above: place 1 at the top, the places
/// running clockwise, as the colouring screen draws them. x runs right and y
/// down, so a point can be scaled straight onto a canvas. Every thread stands
/// where the working puts it (`BraidStepStage`, Task 067).
///
/// A pure function of the hand and the time into it, so going back a hand is
/// only asking for an earlier one.
struct BraidStepFrame: Equatable {
    struct Ball: Equatable {
        /// Named by the place it stood at when the braid began.
        let thread: Int
        let point: CGPoint
        /// Lit: carried in this hand, or moved by its settling.
        let isCarried: Bool
    }

    /// From where the carried thread stands to where it is set down, in turns
    /// clockwise from the top, the way it goes.
    struct Arrow: Equatable {
        let from: Double
        let to: Double
        let way: BraidStepWay
    }

    /// **In drawing order**: the threads that stay first, the carried ones last,
    /// so a carried thread and its line lie over the ones it passes.
    let balls: [Ball]
    /// Shown from the start of the hand until its carry lands.
    let arrows: [Arrow]

    /// How far out a carried thread rides at the middle of its slide, so it is
    /// seen to go over the threads it passes.
    static let lift: Double = 0.1

    /// **A hand at a moment**: each thread slides from where it stands before
    /// the hand to where the carry sets it down, then settles to where it stands
    /// after — the book's adjustments (Task 067). **A setting at the end of a
    /// dan** (Task 068) slides every thread it moves the short way to the
    /// starting form, lighting none and lifting none. **A hand fast-forwarded**
    /// (Task 069) lights none and shows no arrow.
    static func at(
        _ time: Double, of stations: BraidStepStage.Stations, carried: Set<Int>, reduceMotion: Bool,
        timing: BraidStepTiming = .normal
    ) -> BraidStepFrame {
        let settled = stations.settled
        let ways = stations.ways
        let carryStart = timing.lead
        let settleStart = carryStart + timing.carry
        let settleEnd = settleStart + timing.settle
        let lights = !stations.isSetting && !stations.isFastForward

        var balls = [Ball]()
        for thread in stations.before.keys.sorted() {
            guard let before = stations.before[thread], let after = stations.after[thread] else { continue }
            let middle = carried.contains(thread) ? stations.afterCarrying[thread] ?? after : before
            let point: Polar
            if reduceMotion {
                // Switched, not slid (the reviewer's 2.2 6): the arrow still shows.
                point = time < carryStart + timing.carry / 2 ? before
                    : time < settleEnd ? middle : after
            } else if time < carryStart {
                point = before
            } else if time < settleStart {
                let share = carried.contains(thread) ? eased((time - carryStart) / timing.carry) : 0
                point = slide(
                    from: before, to: middle, way: ways[thread], share: share,
                    lift: stations.isSetting ? 0 : Self.lift
                )
            } else if time < settleEnd {
                let share = eased((time - settleStart) / timing.settle)
                point = slide(
                    from: middle, to: after, way: settled.contains(thread) ? ways[thread] : nil,
                    share: share, lift: 0
                )
            } else {
                point = after
            }
            balls.append(Ball(
                thread: thread, point: point.cartesian,
                isCarried: (carried.contains(thread) || settled.contains(thread)) && time < settleEnd && lights
            ))
        }
        balls = balls.filter { !$0.isCarried } + balls.filter(\.isCarried)
        return BraidStepFrame(balls: balls, arrows: time < settleStart && lights ? stations.arrows : [])
    }

    /// A point by its angle, in turns clockwise from the top, and its distance
    /// from the middle.
    struct Polar: Equatable {
        let turn: Double
        let radius: Double

        var cartesian: CGPoint {
            let angle = 2 * Double.pi * turn
            return CGPoint(x: radius * sin(angle), y: -radius * cos(angle))
        }
    }

    /// Part way from one point to another: round the rim the given way, or the
    /// short way when none is given; straight over the middle for `.across`.
    static func slide(from start: Polar, to end: Polar, way: BraidStepWay?, share: Double, lift: Double) -> Polar {
        guard share > 0 else { return start }
        guard share < 1 else { return end }
        if way == .across {
            let a = start.cartesian, b = end.cartesian
            let x = a.x + (b.x - a.x) * share, y = a.y + (b.y - a.y) * share
            return Polar(turn: atan2(x, -y) / (2 * .pi), radius: (x * x + y * y).squareRoot())
        }
        var forward = (end.turn - start.turn).truncatingRemainder(dividingBy: 1)
        if forward < 0 { forward += 1 }
        let distance: Double
        switch way {
        case .clockwise?: distance = forward
        case .anticlockwise?: distance = forward - 1
        default: distance = forward <= 0.5 ? forward : forward - 1
        }
        return Polar(
            turn: start.turn + distance * share,
            radius: start.radius + (end.radius - start.radius) * share + lift * sin(.pi * share)
        )
    }

    private static func eased(_ share: Double) -> Double {
        let share = min(max(share, 0), 1)
        return share * share * (3 - 2 * share)
    }
}
