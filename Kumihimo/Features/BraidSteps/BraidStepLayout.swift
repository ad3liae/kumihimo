import Foundation

/// **Where the step animation draws each place of the stand** (Task 066): at the
/// slit the book's starting diagram puts its thread in (`BraidRecipe
/// .startingSlits`), so the eight-bobbin braids stand two by two, north, east,
/// south and west — 「実際に丸台を使う時も金剛は2本ずつ東西南北よせるんだよ、
/// その方が組みやすいから」 (the author, 2026-09-26).
///
/// **An island** is a run of places each nearer the next than the places are
/// apart on average. The stand is turned so that the island holding place 1 has
/// its middle at the top, where the colouring screen puts place 1. Where the
/// book's slits would put two bobbins of an island on top of each other, the
/// island is spread about its middle just far enough to part them, with a
/// little room between (`clearance`).
///
/// **Drawing only**: the script's hands and ways are worked on the stand's places
/// and do not change. A recipe with no starting diagram is drawn on the stand's
/// own rim, evenly spaced.
struct BraidStepLayout: Equatable {
    let stand: BraidStand
    /// The places in their islands, round the rim clockwise from place 1's.
    let islands: [[Int]]
    /// A bobbin's radius, in units of the rim's radius.
    let ballRadius: Double
    /// **How far apart two neighbouring slits are drawn inside an island**, in
    /// turns: the book's notch, or spread as the islands are. `nil` for a stand
    /// drawn evenly, with no slits behind it.
    let notchTurn: Double?
    /// Each place's angle, in turns clockwise from the top.
    private let turns: [Int: Double]

    /// How far apart two bobbins stand at the least, beyond touching, in units
    /// of the rim's radius.
    static let clearance: Double = 0.04

    init(stand: BraidStand, startingSlits: BraidStartingSlits?) {
        self.stand = stand
        let count = stand.positionCount
        ballRadius = min(0.15, 0.4 * sin(.pi / Double(max(count, 1))))
        guard
            let slits = startingSlits, slits.notchCount > 0, count > 0,
            slits.placeOneOnward.count == count, stand.positionIDs == Array(1...count)
        else {
            turns = Dictionary(uniqueKeysWithValues: stand.positions.map { ($0.id, $0.rim) })
            islands = stand.positions.map { [$0.id] }
            notchTurn = nil
            return
        }
        // The book's angle of each place, clockwise, in the order round the disk.
        let book = slits.placeOneOnward.enumerated()
            .map { (place: $0.offset + 1, turn: Self.unit(Double($0.element - 1) / Double(slits.notchCount))) }
            .sorted { $0.turn < $1.turn }
        func gap(after index: Int) -> Double {
            Self.unit(book[(index + 1) % count].turn - book[index].turn)
        }
        let average = 1 / Double(count)
        let breaks = book.indices.filter { gap(after: $0) >= average - 1e-9 }
        guard let lastBreak = breaks.last else {
            // Every gap narrower than the average cannot happen round a whole turn.
            turns = Dictionary(uniqueKeysWithValues: stand.positions.map { ($0.id, $0.rim) })
            islands = stand.positions.map { [$0.id] }
            notchTurn = nil
            return
        }
        var grouped = [[Int]]()           // indices into `book`
        var index = (lastBreak + 1) % count
        for _ in 0..<count {
            if grouped.isEmpty || breaks.contains((index + count - 1) % count) {
                grouped.append([index])
            } else {
                grouped[grouped.count - 1].append(index)
            }
            index = (index + 1) % count
        }

        // Two bobbins on the rim a turn share `t` apart are 2 sin(πt) apart:
        // they touch at `touching`, and are spread, when they would overlap,
        // to `least`.
        let touching = asin(min(1, ballRadius)) / .pi
        let least = asin(min(1, ballRadius + Self.clearance / 2)) / .pi
        let notch = 1 / Double(slits.notchCount)
        notchTurn = notch < touching ? least : notch
        var middles = [Double](), spread = [[Double]]()
        for members in grouped {
            let gaps = zip(members, members.dropFirst()).map { gap(after: $0.0) }
            let span = gaps.reduce(0, +)
            let middle = book[members[0]].turn + span / 2
            let wide = gaps.map { $0 < touching ? least : $0 }
            let wideSpan = wide.reduce(0, +)
            var offsets = [-wideSpan / 2]
            for step in wide { offsets.append((offsets.last ?? 0) + step) }
            middles.append(middle)
            spread.append(offsets)
        }
        let first = grouped.firstIndex { $0.contains { book[$0].place == 1 } } ?? 0
        let turn = -middles[first]
        var placed = [Int: Double]()
        var ordered = [[Int]]()
        for step in 0..<grouped.count {
            let island = (first + step) % grouped.count
            let members = grouped[island]
            for (member, offset) in zip(members, spread[island]) {
                placed[book[member].place] = Self.unit(middles[island] + offset + turn)
            }
            ordered.append(members.map { book[$0].place })
        }
        turns = placed
        islands = ordered
    }

    /// A place's angle, in turns clockwise from the top.
    func turn(of place: Int) -> Double {
        turns[place] ?? stand.position(withID: place)?.rim ?? 0
    }

    /// How far round, in turns, the next place is from this one the given way:
    /// `+1` clockwise, `-1` anticlockwise.
    func gap(from place: Int, side: Int) -> Double {
        let here = turn(of: place)
        let others = stand.positionIDs.filter { $0 != place }.map {
            Self.unit(side > 0 ? turn(of: $0) - here : here - turn(of: $0))
        }
        return others.min() ?? 1
    }

    /// **Where a thread waits beside a place**, on the `side` it came from
    /// (`+1` clockwise of it, `-1` anticlockwise), `rank` in the queue.
    ///
    /// Clear of its place's bobbin and of the next place's that way. Where there
    /// is room at the rim — the open side of an island — it stands out beside
    /// its place, as it did before Task 066. On the side of its island's partner
    /// there is none: it stands in from the rim, as far round towards the
    /// partner as it can while clear of both, and **clear of the partner all the
    /// way as it slides on to its place** once that is free.
    func beside(_ place: Int, side: Int, rank: Int) -> (turn: Double, radius: Double) {
        let here = turn(of: place)
        let rank = Double(rank)
        let radius = 1 - rank * BraidStepFrame.besideInset
        let spacing = 1 / Double(max(stand.positionCount, 1))
        let room = gap(from: place, side: side)
        let clear = clearTurn(at: radius)
        if 2 * clear <= room {
            let offset = min(max(rank * BraidStepFrame.besideShare * spacing, clear), room - clear)
            return (here + Double(side) * offset, radius)
        }
        let standing = 2 * ballRadius + Self.clearance
        let passing = 2 * ballRadius + Self.clearance / 2
        let tries = 20, samples = 24
        for step in stride(from: tries, through: 0, by: -1) {
            let offset = room / 2 * Double(step) / Double(tries)
            let inside = min(radius, clearRadius(at: offset))
            guard Self.distance(inside, offset, 1, room) >= standing else { continue }
            let clearOnTheWay = (0...samples).allSatisfy { sample in
                let share = Double(sample) / Double(samples)
                return Self.distance(inside + (1 - inside) * share, offset * (1 - share), 1, room) >= passing
            }
            if clearOnTheWay { return (here + Double(side) * offset, inside) }
        }
        return (here, min(radius, 1 - standing))
    }

    /// The least angle, in turns, between a bobbin at `radius` and one on the
    /// rim for the two to stand clear of each other.
    func clearTurn(at radius: Double) -> Double {
        let reach = 2 * ballRadius + Self.clearance
        let cosine = (1 + radius * radius - reach * reach) / (2 * radius)
        if cosine >= 1 { return 0 }
        if cosine <= -1 { return 0.5 }
        return acos(cosine) / (2 * .pi)
    }

    /// The furthest out a bobbin can stand, `turn` round from one on the rim,
    /// and be clear of it.
    func clearRadius(at turn: Double) -> Double {
        let reach = 2 * ballRadius + Self.clearance
        let angle = 2 * .pi * turn
        let under = reach * reach - sin(angle) * sin(angle)
        guard under > 0 else { return 1 }
        return cos(angle) - under.squareRoot()
    }

    /// How far apart two points are, each given by its distance from the middle
    /// and its angle in turns.
    private static func distance(
        _ radius: Double, _ turn: Double, _ otherRadius: Double, _ otherTurn: Double
    ) -> Double {
        let angle = 2 * .pi * (turn - otherTurn)
        return max(0, radius * radius + otherRadius * otherRadius - 2 * radius * otherRadius * cos(angle)).squareRoot()
    }

    private static func unit(_ turn: Double) -> Double {
        let value = turn.truncatingRemainder(dividingBy: 1)
        return value < 0 ? value + 1 : value
    }
}
