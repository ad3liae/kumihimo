import CoreGraphics
import Foundation

/// How long each part of a hand takes, in seconds (Task 061). **The author
/// decides the speed**; these follow the reviewer's 0.8 s a hand and 0.4 s
/// between.
enum BraidStepTiming {
    /// The carried thread lit and its arrow shown, before it moves.
    static let lead: Double = 0.35
    /// Sliding round the rim to where it goes.
    static let carry: Double = 0.8
    /// The closing's tidying, and a thread waiting beside a place moving on to it.
    static let settle: Double = 0.3
    /// Still, before the next hand.
    static let rest: Double = 0.4

    static var hand: Double { lead + carry + settle + rest }
}

/// **Where everything on the stand is at one moment of a hand** (Task 061), on
/// a stand of unit radius seen from above: place 1 at the top, the places
/// running clockwise, as the colouring screen draws them. x runs right and y
/// down, so a point can be scaled straight onto a canvas.
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

    struct Arrow: Equatable {
        let from: Int
        let to: Int
        let way: BraidStepWay
    }

    /// **In drawing order**: the threads that stay first, the carried ones last,
    /// so a carried thread and its line lie over the ones it passes.
    let balls: [Ball]
    /// Shown from the start of the hand until its carry lands.
    let arrows: [Arrow]

    /// How far beside its place a waiting thread stands, as a share of the
    /// spacing between places, and how far in towards the middle.
    static let besideShare: Double = 0.34
    static let besideInset: Double = 0.14
    /// How far out a carried thread rides at the middle of its slide, so it is
    /// seen to go over the threads it passes.
    static let lift: Double = 0.1

    static func at(
        _ time: Double, of hand: BraidStepScript.Hand, on stand: BraidStand, reduceMotion: Bool
    ) -> BraidStepFrame {
        let carried = Set(hand.carries.map(\.thread))
        let settled = Set(hand.settling.map(\.thread))
        let ways = Dictionary(
            (hand.carries + hand.settling).map { ($0.thread, $0.way) },
            uniquingKeysWith: { _, last in last }
        )
        let carryStart = BraidStepTiming.lead
        let settleStart = carryStart + BraidStepTiming.carry
        let settleEnd = settleStart + BraidStepTiming.settle

        func polar(_ thread: Int, in standings: [Int: BraidStepStanding]) -> Polar? {
            standings[thread].map { polarPoint(of: $0, on: stand) }
        }

        var balls = [Ball]()
        for thread in hand.before.keys.sorted() {
            guard
                let before = polar(thread, in: hand.before),
                let after = polar(thread, in: hand.after)
            else { continue }
            let middle = carried.contains(thread) ? polar(thread, in: hand.afterCarrying) ?? after : before
            let point: Polar
            if reduceMotion {
                // Switched, not slid (the reviewer's 2.2 6): the arrow still shows.
                point = time < carryStart + BraidStepTiming.carry / 2 ? before
                    : time < settleEnd ? middle : after
            } else if time < carryStart {
                point = before
            } else if time < settleStart {
                let share = carried.contains(thread) ? eased((time - carryStart) / BraidStepTiming.carry) : 0
                point = slide(from: before, to: middle, way: ways[thread], share: share, lift: Self.lift)
            } else if time < settleEnd {
                let share = eased((time - settleStart) / BraidStepTiming.settle)
                point = slide(
                    from: middle, to: after, way: settled.contains(thread) ? ways[thread] : nil,
                    share: share, lift: 0
                )
            } else {
                point = after
            }
            balls.append(Ball(
                thread: thread, point: point.cartesian,
                isCarried: (carried.contains(thread) || settled.contains(thread)) && time < settleEnd
            ))
        }
        balls = balls.filter { !$0.isCarried } + balls.filter(\.isCarried)
        let arrows = time < settleStart
            ? hand.carries.map { Arrow(from: $0.from, to: $0.to, way: $0.way) }
            : []
        return BraidStepFrame(balls: balls, arrows: arrows)
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

    /// Where a standing thread is drawn: on its place, or beside it on the side
    /// it came from and a little in.
    static func polarPoint(of standing: BraidStepStanding, on stand: BraidStand) -> Polar {
        let rim = stand.position(withID: standing.place)?.rim ?? 0
        guard standing.rank > 0 else { return Polar(turn: rim, radius: 1) }
        let rank = Double(standing.rank)
        let spacing = 1 / Double(max(stand.positionCount, 1))
        switch standing.cameBy {
        case .clockwise?:
            return Polar(turn: rim - rank * besideShare * spacing, radius: 1 - rank * besideInset)
        case .anticlockwise?:
            return Polar(turn: rim + rank * besideShare * spacing, radius: 1 - rank * besideInset)
        case .across?, nil:
            return Polar(turn: rim, radius: 1 - rank * 2 * besideInset)
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
