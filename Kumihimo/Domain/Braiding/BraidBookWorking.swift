import Foundation

/// **A braid worked as its book works it, hand by hand, for the step
/// animation** (Task 067). The derivation never reads any of it.
///
/// Two ways a book writes the hands, one working:
///
/// - **On a disk** (`BraidDiskNotation.bookSteps`, the threads starting in
///   `BraidRecipe.startingSlits`): each thread at a notch, each printed step
///   moving threads notch to notch. **A step whose thread goes over another —
///   a thread on a notch it passes the short way — is a hand; a step that goes
///   over none is an adjustment**, made as the hand before it settles, and not
///   counted. The book's notch numbers drift as it goes; a table worked again
///   is turned by the drift, and lifts whichever thread stands in the slit.
/// - **On a round stand's faces** (`BraidRecipe.standHands`): each hand two
///   threads taken from the ends of a face and laid on another, straight over
///   the mirror.
///
/// **Islands are read off the arrangement as it stands**: threads nearer their
/// neighbour than the threads are apart on average stand together. **Whenever
/// the islands are as many and as large as they began, each is drawn back to
/// where one of that size began** — not a hand; it moves as the hand settles.
/// A time round is a whole number of passes through the tables, until every
/// place shows the colour it began with.
struct BraidBookWorking: Equatable, Sendable {
    /// Where a thread is drawn: the middle of its island, in turns clockwise
    /// from the top, and how many steps from that middle, + clockwise — a step
    /// being a notch of the disk, or a face's fan.
    struct Seat: Equatable, Sendable {
        let turn: Double
        let offset: Double
    }

    enum Form: Equatable, Sendable {
        case disk(notches: Int)
        case stand(BraidStandHands)
    }

    /// One thread moved: the way round it goes, and the threads it goes over.
    struct Move: Equatable, Sendable {
        let thread: Int
        let way: BraidStepWay
        let over: [Int]
    }

    struct Hand: Equatable, Sendable {
        /// Which of the recipe's tables it is from, from 0.
        let table: Int
        /// The table's name for it, or the hand-over's, when the book gives one.
        let name: String?
        let isHandOver: Bool
        let carries: [Move]
        /// Moves that go over no thread, made as the hand settles.
        let adjustments: [Move]
        let before: [Int: Seat]
        let afterCarrying: [Int: Seat]
        let after: [Int: Seat]
        /// The islands after the hand, each its threads clockwise.
        let islands: [[Int]]
        /// **The islands stand where they began** after the hand: as many and as
        /// large, each drawn back.
        let standsAtHome: Bool
        /// The book's words for the carries, on a round stand.
        let standCarries: [BraidStandHands.Carry]
    }

    let form: Form
    /// Where each place's thread stands at the start.
    let homes: [Int: Seat]
    /// The islands at the start, each its places clockwise.
    let islandsAtStart: [[Int]]
    let tableCount: Int
    /// Passes through the tables in one time round.
    let passes: Int
    let hands: [Hand]

    init?(recipe: BraidRecipe, stand: BraidStand, colours: [Int: ThreadColorID] = [:]) {
        let count = stand.positionCount
        guard count > 0, stand.positionIDs == Array(1...count) else { return nil }
        let limit = max(count, 1)
        if let standHands = recipe.standHands {
            guard let worked = Self.onTheStand(standHands, count: count, colours: colours, limit: limit) else {
                return nil
            }
            form = .stand(standHands)
            homes = worked.homes
            islandsAtStart = standHands.faces.map(\.places)
            tableCount = 1
            passes = worked.passes
            hands = worked.hands
        } else if let slits = recipe.startingSlits, slits.placeOneOnward.count == count,
                  recipe.rounds.allSatisfy({ !$0.bookSteps.isEmpty }) {
            guard let worked = Self.onTheDisk(
                recipe: recipe, slits: slits, count: count, colours: colours, limit: limit
            ) else { return nil }
            form = .disk(notches: slits.notchCount)
            homes = worked.homes
            islandsAtStart = Disk.runs(
                Dictionary(uniqueKeysWithValues: slits.placeOneOnward.enumerated().map { ($0.offset + 1, $0.element) }),
                notches: slits.notchCount, count: count
            )
            tableCount = recipe.rounds.count
            passes = worked.passes
            hands = worked.hands
        } else {
            return nil
        }
    }

    // MARK: The disk

    private static func onTheDisk(
        recipe: BraidRecipe, slits: BraidStartingSlits, count: Int,
        colours: [Int: ThreadColorID], limit: Int
    ) -> (homes: [Int: Seat], passes: Int, hands: [Hand])? {
        var disk = Disk(notches: slits.notchCount, count: count, starting: slits.placeOneOnward)
        let homes = disk.seats()
        let start = disk.colours(colours)
        var hands = [Hand]()
        var northAtStart = [Int: Int]()
        var takenAtStart = [Int: Set<Int>]()
        var passes = limit
        for pass in 1...limit {
            for (table, notation) in recipe.rounds.enumerated() {
                guard let north = disk.slitDrawnAtTheNorth() else { return nil }
                let drift: Int
                if let was = northAtStart[table], let taken = takenAtStart[table] {
                    drift = disk.wrappedDistance(north - was)
                    guard Set(taken.map { disk.wrapped($0 + drift) }) == disk.taken else { return nil }
                } else {
                    northAtStart[table] = north
                    takenAtStart[table] = disk.taken
                    drift = 0
                }
                var open: (hand: PartHand, name: String?, isHandOver: Bool)?
                func close() {
                    guard let current = open else { return }
                    let standsAtHome = disk.drawBackIfAsTheyBegan()
                    hands.append(Hand(
                        table: table, name: current.name, isHandOver: current.isHandOver,
                        carries: current.hand.carries, adjustments: current.hand.adjustments,
                        before: current.hand.before, afterCarrying: current.hand.afterCarrying,
                        after: disk.seats(), islands: disk.islands(), standsAtHome: standsAtHome,
                        standCarries: []
                    ))
                    open = nil
                }
                for step in notation.bookSteps {
                    let moves = step.moves.map {
                        BraidMove(from: disk.wrapped($0.from + drift), to: disk.wrapped($0.to + drift))
                    }
                    // Whether it goes over a thread is read before it moves.
                    guard let moved = disk.moves(moves) else { return nil }
                    if moved.contains(where: { !$0.over.isEmpty }) {
                        close()
                        let before = disk.seats()
                        guard disk.apply(moves) else { return nil }
                        open = (
                            PartHand(carries: moved, before: before, afterCarrying: disk.seats()),
                            step.isHandOver ? notation.handOverName : notation.name,
                            step.isHandOver
                        )
                    } else {
                        guard disk.apply(moves) else { return nil }
                        open?.hand.adjustments += moved
                    }
                }
                close()
            }
            if disk.colours(colours) == start {
                passes = pass
                break
            }
        }
        return (homes, passes, hands)
    }

    /// A hand being worked: its carries, and the adjustments after them.
    private struct PartHand {
        let carries: [Move]
        var adjustments = [Move]()
        let before: [Int: Seat]
        let afterCarrying: [Int: Seat]
    }

    /// The book's disk: each thread's notch, and how far each has been drawn
    /// back.
    private struct Disk {
        let notches: Int
        let count: Int
        /// Where each place's thread starts: the home of that place.
        let home: [Int: Int]
        /// Turns the disk so that place 1's island has its middle at the top.
        let rotation: Double
        /// The islands at the start, each its places clockwise.
        let homeIslands: [[Int]]
        var slit: [Int: Int]
        var drawnBack: [Int: Int]

        init(notches: Int, count: Int, starting: [Int]) {
            self.notches = notches
            self.count = count
            let home = Dictionary(uniqueKeysWithValues: starting.enumerated().map { ($0.offset + 1, $0.element) })
            self.home = home
            slit = home
            drawnBack = Dictionary(uniqueKeysWithValues: (1...count).map { ($0, 0) })
            let islands = Self.runs(home, notches: notches, count: count)
            homeIslands = islands
            let first = islands.first { $0.contains(1) } ?? [1]
            let positions = Self.unwrapped(first.compactMap { home[$0] }, notches: notches)
            let middle = positions.reduce(0, +) / Double(max(positions.count, 1))
            rotation = -((middle - 1) / Double(notches))
        }

        var taken: Set<Int> { Set(slit.values) }

        func wrapped(_ notch: Int) -> Int { ((notch - 1) % notches + notches) % notches + 1 }

        /// The short way round from one notch to another, + clockwise.
        func wrappedDistance(_ forward: Int) -> Int {
            let forward = (forward % notches + notches) % notches
            return forward * 2 <= notches ? forward : forward - notches
        }

        func drawnAt(_ thread: Int) -> Int { wrapped((slit[thread] ?? 0) - (drawnBack[thread] ?? 0)) }

        /// The runs of neighbouring threads, each clockwise.
        func islands() -> [[Int]] { Self.runs(slit, notches: notches, count: count) }

        /// Threads nearer their neighbour than the threads are apart on
        /// average stand together; each run clockwise, from a gap.
        static func runs(_ slit: [Int: Int], notches: Int, count: Int) -> [[Int]] {
            let byNotch = slit.sorted { $0.value < $1.value }
            guard !byNotch.isEmpty else { return [] }
            let apart = Double(notches) / Double(max(count, 1))
            func gap(after index: Int) -> Int {
                let next = byNotch[(index + 1) % byNotch.count].value
                return ((next - byNotch[index].value) % notches + notches) % notches
            }
            guard let lastBreak = byNotch.indices.last(where: { Double(gap(after: $0)) >= apart - 1e-9 }) else {
                return [byNotch.map(\.key)]
            }
            var runs = [[Int]]()
            var index = (lastBreak + 1) % byNotch.count
            for _ in byNotch.indices {
                let previous = (index + byNotch.count - 1) % byNotch.count
                if runs.isEmpty || Double(gap(after: previous)) >= apart - 1e-9 {
                    runs.append([byNotch[index].key])
                } else {
                    runs[runs.count - 1].append(byNotch[index].key)
                }
                index = (index + 1) % byNotch.count
            }
            return runs
        }

        /// A run's threads where they are drawn, in notches, unwrapped from its first.
        func unwrapped(_ run: [Int]) -> [Double] {
            Self.unwrapped(run.map { drawnAt($0) }, notches: notches)
        }

        static func unwrapped(_ notchesOf: [Int], notches: Int) -> [Double] {
            guard let first = notchesOf.first else { return [] }
            var out = [Double(first)]
            for (previous, notch) in zip(notchesOf, notchesOf.dropFirst()) {
                out.append((out.last ?? 0) + Double(((notch - previous) % notches + notches) % notches))
            }
            return out
        }

        func seats() -> [Int: Seat] {
            var seats = [Int: Seat]()
            for run in islands() {
                let positions = unwrapped(run)
                let middle = positions.reduce(0, +) / Double(positions.count)
                let turn = BraidBookWorking.unit((middle - 1) / Double(notches) + rotation)
                for (thread, position) in zip(run, positions) {
                    seats[thread] = Seat(turn: turn, offset: position - middle)
                }
            }
            return seats
        }

        /// The colour at each place's home, or the thread when no colours are given.
        func colours(_ colours: [Int: ThreadColorID]) -> [Int: String] {
            var out = [Int: String]()
            for (thread, _) in slit {
                if let place = home.first(where: { wrapped($0.value) == drawnAt(thread) })?.key {
                    out[place] = colours[thread]?.rawValue ?? "\(thread)"
                }
            }
            return out
        }

        /// The slit of the thread drawn where place 1's island's first thread
        /// began.
        func slitDrawnAtTheNorth() -> Int? {
            guard let place = homeIslands.first(where: { $0.contains(1) })?.first,
                  let notch = home[place] else { return nil }
            return slit.first { drawnAt($0.key) == notch }?.value
        }

        /// The threads in the given slits, as they would move at once: the way
        /// round each goes, and the threads it goes over. `nil` when a slit is
        /// empty.
        func moves(_ moves: [BraidMove]) -> [Move]? {
            var movers = [Int]()
            for move in moves {
                guard let thread = slit.first(where: { $0.value == move.from })?.key else { return nil }
                movers.append(thread)
            }
            let staying = slit.filter { !movers.contains($0.key) }
            var out = [Move]()
            for (move, thread) in zip(moves, movers) {
                let forward = ((move.to - move.from) % notches + notches) % notches
                let clockwise = forward * 2 <= notches
                let passed = clockwise
                    ? (1..<max(forward, 1)).map { wrapped(move.from + $0) }
                    : (1..<max(notches - forward, 1)).map { wrapped(move.from - $0) }
                let over = passed.compactMap { notch in staying.first { $0.value == notch }?.key }
                let way = BraidStepWay.shortWay(forward: forward, around: notches) ?? .clockwise
                out.append(Move(thread: thread, way: way, over: over))
            }
            return out
        }

        /// Moves the threads in the given slits at once. False when a slit is
        /// empty or a landing taken.
        mutating func apply(_ moves: [BraidMove]) -> Bool {
            var movers = [Int]()
            for move in moves {
                guard let thread = slit.first(where: { $0.value == move.from })?.key else { return false }
                movers.append(thread)
            }
            let staying = slit.filter { !movers.contains($0.key) }
            for (move, thread) in zip(moves, movers) {
                guard !staying.values.contains(move.to) else { return false }
                slit[thread] = move.to
                // Drawn as the thread it lands beside is.
                if let nearest = staying.min(by: {
                    abs(wrappedDistance($0.value - move.to)) < abs(wrappedDistance($1.value - move.to))
                }) {
                    drawnBack[thread] = drawnBack[nearest.key] ?? 0
                }
            }
            return true
        }

        /// **Draws every island back to where one of its size began** when the
        /// islands are as many and as large as they began. True when they are.
        mutating func drawBackIfAsTheyBegan() -> Bool {
            let runs = islands()
            guard runs.map(\.count).sorted() == homeIslands.map(\.count).sorted() else { return false }
            let seats = seats()
            var used = Set<Int>()
            for run in runs {
                guard let turn = run.first.flatMap({ seats[$0]?.turn }) else { return false }
                let candidates = homeIslands.indices.filter { !used.contains($0) && homeIslands[$0].count == run.count }
                guard let chosen = candidates.min(by: {
                    abs(BraidBookWorking.between(turn, homeTurn($0))) < abs(BraidBookWorking.between(turn, homeTurn($1)))
                }) else { return false }
                used.insert(chosen)
                for (thread, place) in zip(run, homeIslands[chosen]) {
                    guard let at = slit[thread], let notch = home[place] else { return false }
                    drawnBack[thread] = wrappedDistance(at - notch)
                }
            }
            return true
        }

        private func homeTurn(_ island: Int) -> Double {
            let positions = Self.unwrapped(homeIslands[island].compactMap { home[$0] }, notches: notches)
            let middle = positions.reduce(0, +) / Double(max(positions.count, 1))
            return BraidBookWorking.unit((middle - 1) / Double(notches) + rotation)
        }
    }

    // MARK: The stand's faces

    private static func onTheStand(
        _ hands: BraidStandHands, count: Int, colours: [Int: ThreadColorID], limit: Int
    ) -> (homes: [Int: Seat], passes: Int, hands: [Hand])? {
        var faces = Dictionary(uniqueKeysWithValues: hands.faces.map { ($0.number, $0.places) })
        guard Set(faces.values.joined()) == Set(1...count) else { return nil }
        let byNumber = Dictionary(uniqueKeysWithValues: hands.faces.map { ($0.number, $0) })
        func seats() -> [Int: Seat] {
            var out = [Int: Seat]()
            for face in hands.faces {
                let threads = faces[face.number] ?? []
                for (index, thread) in threads.enumerated() {
                    out[thread] = Seat(turn: face.turn, offset: Double(index) - Double(threads.count - 1) / 2)
                }
            }
            return out
        }
        func islands() -> [[Int]] { hands.faces.compactMap { faces[$0.number] }.filter { !$0.isEmpty } }
        let homes = seats()
        let startSizes = islands().map(\.count).sorted()
        func coloursAtHome() -> [Int: String] {
            let now = seats()
            var out = [Int: String]()
            for (place, seat) in homes {
                if let thread = now.first(where: { $0.value == seat })?.key {
                    out[place] = colours[thread]?.rawValue ?? "\(thread)"
                }
            }
            return out
        }
        let start = coloursAtHome()
        var worked = [Hand]()
        var passes = limit
        for pass in 1...limit {
            for carries in hands.hands {
                let before = seats()
                // Take every thread of the hand first, each from where it stands.
                var taken = [(carry: BraidStandHands.Carry, thread: Int)]()
                for carry in carries {
                    guard let face = byNumber[carry.face], let threads = faces[carry.face] else { return nil }
                    let index = carry.end == face.clockwiseFirst
                        ? carry.fromTheEnd : threads.count - 1 - carry.fromTheEnd
                    guard threads.indices.contains(index) else { return nil }
                    taken.append((carry, threads[index]))
                }
                for (carry, thread) in taken {
                    faces[carry.face]?.removeAll { $0 == thread }
                }
                // Then lay them: the two laid at a middle together, the rest in turn.
                var laid = Set<Int>()
                for (index, item) in taken.enumerated() where !laid.contains(index) {
                    guard let face = byNumber[item.carry.toFace], var threads = faces[item.carry.toFace] else {
                        return nil
                    }
                    switch item.carry.spot {
                    case .centre:
                        func toTheMiddle(_ index: Int) -> Bool {
                            if case .centre = taken[index].carry.spot { return true }
                            return false
                        }
                        let together = taken.indices.filter {
                            !laid.contains($0) && taken[$0].carry.toFace == item.carry.toFace && toTheMiddle($0)
                        }
                        // The thread laid on the side that comes first clockwise goes first.
                        func comesFirst(_ index: Int) -> Bool {
                            if case .centre(let end) = taken[index].carry.spot { return end == face.clockwiseFirst }
                            return false
                        }
                        let ordered = together.filter(comesFirst) + together.filter { !comesFirst($0) }
                        threads.insert(contentsOf: ordered.map { taken[$0].thread }, at: threads.count / 2)
                        laid.formUnion(together)
                    case .insideEnd(let end):
                        let at = end == face.clockwiseFirst ? min(1, threads.count) : max(threads.count - 1, 0)
                        threads.insert(item.thread, at: at)
                        laid.insert(index)
                    case .end(let end):
                        threads.insert(item.thread, at: end == face.clockwiseFirst ? 0 : threads.count)
                        laid.insert(index)
                    }
                    faces[item.carry.toFace] = threads
                }
                let after = seats()
                worked.append(Hand(
                    table: 0, name: nil, isHandOver: false,
                    carries: taken.map { Move(thread: $0.thread, way: .across, over: []) },
                    adjustments: [], before: before, afterCarrying: after, after: after,
                    islands: islands(), standsAtHome: islands().map(\.count).sorted() == startSizes,
                    standCarries: carries
                ))
            }
            if coloursAtHome() == start {
                passes = pass
                break
            }
        }
        return (homes, passes, worked)
    }

    // MARK: Angles

    static func unit(_ turn: Double) -> Double {
        let value = turn.truncatingRemainder(dividingBy: 1)
        return value < 0 ? value + 1 : value
    }

    /// The short way from one angle to another, in turns, signed.
    static func between(_ from: Double, _ to: Double) -> Double {
        var value = (to - from).truncatingRemainder(dividingBy: 1)
        if value > 0.5 { value -= 1 }
        if value < -0.5 { value += 1 }
        return value
    }
}
