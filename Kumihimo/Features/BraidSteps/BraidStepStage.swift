import Foundation

/// **Where every thread stands at each moment of each hand** of a script (Task
/// 066): before the hand, where its carry sets the thread down, and after it
/// has settled.
///
/// **A braid with the book's own disk behind it is drawn as the book works
/// it** (`BraidDiskNotation.bookHands`): each thread at the slit the book puts
/// it in, a carried thread set down beside the pair across the stand as the
/// book sets it — 八つ金剛 S's first hand takes the south pair's right-hand
/// thread round outside the east pair to beside the north pair's right-hand one
/// (the author, 2026-09-26). The book's slits drift a notch a dan; **whenever
/// the threads stand in pairs again, the pairs are drawn back to north, east,
/// south and west** as the hand settles — not a hand of its own.
///
/// Any other braid is drawn on the stand's places, a thread arriving at a place
/// still taken waiting beside it (`BraidStepFrame.polarPoint`).
struct BraidStepStage {
    struct Stations: Equatable {
        /// The threads the hand carries, lit from its start until it settles.
        let carried: Set<Int>
        let before: [Int: BraidStepFrame.Polar]
        let afterCarrying: [Int: BraidStepFrame.Polar]
        let after: [Int: BraidStepFrame.Polar]
        /// Threads the settle moves on purpose, lit as they go: the closing's
        /// tidying, or a thread the book lifts again.
        let settled: Set<Int>
        /// The way round each moving thread goes: its carry's, or its settle's.
        let ways: [Int: BraidStepWay]
        let arrows: [BraidStepFrame.Arrow]
        /// **The hand in words, as the picture shows it**, when the stand is
        /// drawn from the book's disk; `nil` to read the script's own.
        let sentence: String?
    }

    let script: BraidStepScript
    let layout: BraidStepLayout
    /// One a hand, when the stand is drawn from the book's disk.
    private let fromTheBook: [Stations]?

    var isDrawnFromTheBook: Bool { fromTheBook != nil }

    init(script: BraidStepScript, recipe: BraidRecipe?, layout: BraidStepLayout) {
        self.script = script
        self.layout = layout
        fromTheBook = recipe.flatMap { Self.fromTheBook(script: script, recipe: $0, layout: layout) }
    }

    func stations(ofHand index: Int) -> Stations {
        if let fromTheBook, fromTheBook.indices.contains(index) { return fromTheBook[index] }
        return Self.stations(of: script.hands[index], on: layout)
    }

    /// A hand drawn on the stand's places.
    static func stations(of hand: BraidStepScript.Hand, on layout: BraidStepLayout) -> Stations {
        func polar(_ standings: [Int: BraidStepStanding]) -> [Int: BraidStepFrame.Polar] {
            standings.mapValues { BraidStepFrame.polarPoint(of: $0, on: layout) }
        }
        return Stations(
            carried: Set(hand.carries.map(\.thread)),
            before: polar(hand.before), afterCarrying: polar(hand.afterCarrying), after: polar(hand.after),
            settled: Set(hand.settling.map(\.thread)),
            ways: Dictionary(
                (hand.carries + hand.settling).map { ($0.thread, $0.way) }, uniquingKeysWith: { _, last in last }
            ),
            arrows: hand.carries.map {
                BraidStepFrame.Arrow(from: layout.turn(of: $0.from), to: layout.turn(of: $0.to), way: $0.way)
            },
            sentence: nil
        )
    }

    // MARK: The book's disk

    /// **Works the book's moves through the whole script**, table by table, in
    /// the book's slits: each time a table comes round again the book's slits
    /// have drifted, so its moves are turned by the drift (the book's later dan
    /// are its printed one moved round), and **the thread is whichever stands in
    /// the slit the book lifts** — the book lifts the same pair first every
    /// dan, where the table, repeated in places, would start a quarter turn
    /// round each time round. The braid is the same either way: inside a dan
    /// the table's moves are the same, only their order differs.
    ///
    /// `nil` when the recipe has no book disk, or when the book's moves do not
    /// match the script's hands — the first time round, each hand's carry is
    /// the book's — and the stand is then drawn on its places.
    private static func fromTheBook(
        script: BraidStepScript, recipe: BraidRecipe, layout: BraidStepLayout
    ) -> [Stations]? {
        let count = script.stand.positionCount
        guard
            let slits = recipe.startingSlits, slits.placeOneOnward.count == count,
            let notchTurn = layout.notchTurn,
            recipe.rounds.allSatisfy({ !$0.bookHands.isEmpty })
        else { return nil }
        let notches = slits.notchCount
        var disk = BookDisk(
            notches: notches, places: count, notchTurn: notchTurn, layout: layout,
            slitOf: Dictionary(uniqueKeysWithValues: (1...count).map { ($0, slits.placeOneOnward[$0 - 1]) })
        )
        let startingIslands = disk.islandSizes()
        // When each table first begins: the slit drawn first at the north, and
        // the slits taken. The book's slits look the same a quarter turn round,
        // so **the drift is read off the pair drawn at the north**, which the
        // drawing keeps there.
        var northAtStart = [Int: Int]()
        var takenAtStart = [Int: Set<Int>]()
        var stations = [Stations]()
        var index = 0
        for cycle in 0..<script.cycles {
            let table = cycle % recipe.rounds.count
            let bookHands = recipe.rounds[table].bookHands
            guard index + bookHands.count <= script.hands.count, let north = disk.slitDrawnFirstAtTheNorth()
            else { return nil }
            let drift: Int
            if let was = northAtStart[table], let taken = takenAtStart[table] {
                drift = ((north - was) % notches + notches) % notches
                guard Set(taken.map { disk.wrapped($0 + drift) }) == Set(disk.slitOf.values) else { return nil }
            } else {
                northAtStart[table] = north
                takenAtStart[table] = Set(disk.slitOf.values)
                drift = 0
            }
            var threadAt = [Int: Int]()
            for (thread, standing) in script.hands[index].before where standing.rank == 0 {
                threadAt[standing.place] = thread
            }
            for (offset, moves) in bookHands.enumerated() {
                let hand = script.hands[index + offset]
                guard hand.table == table, let first = moves.first,
                      let carriedThread = disk.thread(in: disk.wrapped(first.from + drift))
                else { return nil }
                // The first time round, the book's carry is the script's.
                if cycle < recipe.rounds.count,
                   threadAt[first.thread] != carriedThread || hand.carries.map(\.thread) != [carriedThread] {
                    return nil
                }
                let before = disk.polars()
                let fromLabel = disk.label(of: carriedThread)
                var afterCarrying = before
                var settled = Set<Int>()
                var ways = [Int: BraidStepWay]()
                for (number, move) in moves.enumerated() {
                    guard let thread = disk.thread(in: disk.wrapped(move.from + drift)) else { return nil }
                    let way = BraidStepWay.shortWay(forward: move.to - move.from, around: notches)
                        .flatMap { $0 == .across ? hand.carries.first?.way : $0 }
                    disk.move(thread, by: Self.notches(move, way: way, count: notches))
                    if let way { ways[thread] = way }
                    if number == 0 {
                        afterCarrying = disk.polars()
                    } else {
                        settled.insert(thread)
                    }
                }
                let carryWay = ways[carriedThread] ?? hand.carries.first?.way ?? .clockwise
                let toLabel = disk.label(at: afterCarrying[carriedThread]?.turn ?? 0)
                if disk.islandSizes() == startingIslands { disk.drawBackToTheCompass() }
                let after = disk.polars()
                let arrow = before[carriedThread].flatMap { from in
                    afterCarrying[carriedThread].map {
                        BraidStepFrame.Arrow(from: from.turn, to: $0.turn, way: carryWay)
                    }
                }
                stations.append(Stations(
                    carried: [carriedThread],
                    before: before, afterCarrying: afterCarrying, after: after,
                    settled: settled, ways: ways, arrows: arrow.map { [$0] } ?? [],
                    sentence: BraidStepsStrings.bookSentence(
                        from: fromLabel, to: toLabel, way: carryWay, hand: hand, tableCount: script.tableCount
                    )
                ))
            }
            index += bookHands.count
        }
        guard index == script.hands.count else { return nil }
        return stations
    }

    /// How many notches a move goes round the book's disk the given way, + clockwise.
    private static func notches(_ move: BraidDiskNotation.BookMove, way: BraidStepWay?, count: Int) -> Int {
        let forward = ((move.to - move.from) % count + count) % count
        switch way {
        case .clockwise?: return forward
        case .anticlockwise?: return forward == 0 ? 0 : forward - count
        case .across?, nil: return forward * 2 <= count ? forward : forward - count
        }
    }

    /// The book's disk as drawn: each thread's slit, and where each slit is
    /// drawn.
    private struct BookDisk {
        let notches: Int
        let places: Int
        let notchTurn: Double
        let layout: BraidStepLayout
        var slitOf: [Int: Int]
        /// Where each slit a thread stands in, or has just left, is drawn.
        var shown: [Int: Double]

        init(notches: Int, places: Int, notchTurn: Double, layout: BraidStepLayout, slitOf: [Int: Int]) {
            self.notches = notches
            self.places = places
            self.notchTurn = notchTurn
            self.layout = layout
            self.slitOf = slitOf
            shown = Dictionary(uniqueKeysWithValues: slitOf.map { ($0.value, layout.turn(of: $0.key)) })
        }

        func thread(in slit: Int) -> Int? {
            slitOf.first { $0.value == slit }?.key
        }

        /// The slit drawn where the stand's first island begins — at the north,
        /// its anticlockwise place. `nil` when no thread is drawn there.
        func slitDrawnFirstAtTheNorth() -> Int? {
            guard let place = layout.islands.first?.first else { return nil }
            let turn = layout.turn(of: place)
            return slitOf.values.first { slit in
                shown[slit].map { abs(Self.between($0, turn)) < 1e-9 } ?? false
            }
        }

        func polars() -> [Int: BraidStepFrame.Polar] {
            slitOf.compactMapValues { slit in shown[slit].map { BraidStepFrame.Polar(turn: $0, radius: 1) } }
        }

        /// **A thread set down in a slit** is drawn where that slit was last
        /// drawn if it has just been left, or else a notch's drawn width on
        /// from the nearest thread, the side the slit is on.
        mutating func move(_ thread: Int, by notchCount: Int) {
            guard let from = slitOf[thread] else { return }
            let to = wrapped(from + notchCount)
            slitOf[thread] = to
            let others = slitOf.filter { $0.key != thread }.map(\.value)
            if shown[to] != nil, !others.contains(to) { return }
            guard let nearest = others.min(by: { abs(short($0, to)) < abs(short($1, to)) }),
                  let there = shown[nearest] else { return }
            shown[to] = there + Double(short(nearest, to)) * notchTurn
        }

        /// The runs of neighbouring threads, each by its slits clockwise, and
        /// how many are in each, smallest first.
        func islands() -> [[Int]] {
            let occupied = Set(slitOf.values).sorted()
            guard !occupied.isEmpty else { return [] }
            let apart = notches / max(places, 1)
            var runs = [[Int]]()
            var start = 0
            for index in occupied.indices {
                let next = occupied[(index + 1) % occupied.count]
                if ((next - occupied[index]) % notches + notches) % notches >= apart {
                    start = (index + 1) % occupied.count
                    break
                }
            }
            for step in 0..<occupied.count {
                let slit = occupied[(start + step) % occupied.count]
                if let last = runs.last?.last,
                   ((slit - last) % notches + notches) % notches < apart {
                    runs[runs.count - 1].append(slit)
                } else {
                    runs.append([slit])
                }
            }
            return runs
        }

        func islandSizes() -> [Int] { islands().map(\.count).sorted() }

        /// **Every pair drawn back to the compass point it is nearest**, its
        /// threads in the places the stand's islands draw.
        mutating func drawBackToTheCompass() {
            let homes = layout.islands
            var taken = Set<Int>()
            var drawn = [Int: Double]()
            for run in islands() {
                let turns = run.compactMap { shown[$0] }
                guard turns.count == run.count, let first = turns.first else { return }
                let middle = first + turns.map { Self.between(first, $0) }.reduce(0, +) / Double(turns.count)
                guard let home = homes.indices.filter({ !taken.contains($0) && homes[$0].count == run.count })
                    .min(by: { distance(to: $0, from: middle) < distance(to: $1, from: middle) })
                else { return }
                taken.insert(home)
                for (slit, place) in zip(run, homes[home]) { drawn[slit] = layout.turn(of: place) }
            }
            shown = drawn
        }

        /// The place-name of where a thread stands: 「場所5」, or 「場所2の隣」
        /// between the places.
        func label(of thread: Int) -> BraidStepsStrings.Spot {
            label(at: slitOf[thread].flatMap { shown[$0] } ?? 0)
        }

        func label(at turn: Double) -> BraidStepsStrings.Spot {
            let nearest = layout.stand.positionIDs.min {
                abs(Self.between(turn, layout.turn(of: $0))) < abs(Self.between(turn, layout.turn(of: $1)))
            } ?? 1
            let onIt = abs(Self.between(turn, layout.turn(of: nearest))) < 1e-6
            return BraidStepsStrings.Spot(place: nearest, isBeside: !onIt)
        }

        private func distance(to home: Int, from turn: Double) -> Double {
            let places = layout.islands[home]
            let first = layout.turn(of: places[0])
            let middle = first + places.map { Self.between(first, layout.turn(of: $0)) }.reduce(0, +)
                / Double(places.count)
            return abs(Self.between(turn, middle))
        }

        func wrapped(_ slit: Int) -> Int {
            ((slit - 1) % notches + notches) % notches + 1
        }

        /// The short way from one slit to another, + clockwise.
        private func short(_ from: Int, _ to: Int) -> Int {
            let forward = ((to - from) % notches + notches) % notches
            return forward * 2 <= notches ? forward : forward - notches
        }

        /// The short way from one angle to another, in turns, signed.
        static func between(_ from: Double, _ to: Double) -> Double {
            var value = (to - from).truncatingRemainder(dividingBy: 1)
            if value > 0.5 { value -= 1 }
            if value < -0.5 { value += 1 }
            return value
        }
    }
}
