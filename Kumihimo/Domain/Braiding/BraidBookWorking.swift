import Foundation

/// **How the stand is drawn, as far as the working needs it** (Task 066, Task
/// 068): how large a bobbin is, and how far apart the threads of an island
/// stand. The working places every thread by these, so that no two are drawn
/// on top of each other.
struct BraidBookGeometry: Equatable, Sendable {
    let placeCount: Int
    /// A bobbin's radius, in units of the rim's radius.
    let ballRadius: Double

    /// How far apart two bobbins stand at the least, beyond touching, in units
    /// of the rim's radius.
    static let clearance: Double = 0.04
    /// **A face of a round stand drawn as a fan** (the textbook's figures): its
    /// threads this far apart, in turns, so a face of six still leaves room
    /// before the next face.
    static let fan: Double = 1.0 / 20

    init(placeCount: Int) {
        self.placeCount = placeCount
        ballRadius = min(0.15, 0.4 * sin(.pi / Double(max(placeCount, 1))))
    }

    /// Two neighbours on the rim drawn this far apart at the least, in turns:
    /// apart, with a little room between. Two bobbins on the rim a turn share
    /// `t` apart are 2 sin(πt) apart.
    var least: Double { asin(min(1, ballRadius + Self.clearance / 2)) / .pi }

    /// **How far apart two neighbouring notches of a disk are drawn**: a notch,
    /// spread just far enough to part two bobbins when a notch would put them
    /// on top of each other.
    func notchTurn(notches: Int) -> Double {
        let notch = 1 / Double(max(notches, 1))
        let touching = asin(min(1, ballRadius)) / .pi
        return notch < touching ? least : notch
    }

    /// How far apart the threads of a round stand's face are drawn.
    var faceTurn: Double { max(Self.fan, least) }

    /// The least distance between two bobbins' middles for a thread laid among
    /// others on a face: touching, and a little more.
    var apartOnAFace: Double { 2 * ballRadius + Self.clearance / 4 }
}

/// **A braid worked as its book works it, hand by hand, for the step
/// animation** (Task 067, Task 068). The derivation never reads any of it.
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
///   threads taken from faces and laid on others at once, straight over the
///   mirror or round the rim.
///
/// **Inside a dan no thread moves but as the book moves it** (the author,
/// 2026-09-27: 「1手動かすたびに位置を調整しない」). On a disk a thread is
/// drawn where the notch it lands in was last drawn, or a notch's drawn width
/// on from its neighbour; on a face, between the two threads the book lays it
/// between, a little in towards the middle where there is no room. **At the end
/// of a dan every thread is set back in the starting form** (「最後に井の形に
/// 揃えてリセット」) — not a hand. The islands, read off the arrangement by the
/// gap between neighbours, are matched in their order round to the islands of
/// the start, the matching that turns the threads least.
///
/// A time round is a whole number of passes through the tables, until every
/// place shows the colour it began with.
struct BraidBookWorking: Equatable, Sendable {
    /// Where a thread is drawn: in turns clockwise from the top, and how far
    /// from the middle, the rim being 1.
    struct Seat: Equatable, Sendable {
        let turn: Double
        let radius: Double
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
        /// Where the book leaves the threads: after the adjustments.
        let after: [Int: Seat]
        /// The islands after the hand, each its threads clockwise.
        let islands: [[Int]]
        /// The last hand of a dan.
        let endsADan: Bool
        /// **Where every thread is set back to once the dan is done**, when that
        /// moves any; `nil` for any other hand.
        let setting: [Int: Seat]?
        /// The book's hand, on a round stand's faces.
        let standHand: BraidStandHands.StandHand?
    }

    let form: Form
    let geometry: BraidBookGeometry
    /// Where each place's thread stands at the start.
    let homes: [Int: Seat]
    /// The islands at the start, each its places clockwise.
    let islandsAtStart: [[Int]]
    let tableCount: Int
    /// Hands to a dan: the book's 「1段目終了」.
    let handsADan: Int
    /// Passes through the tables in one time round.
    let passes: Int
    let hands: [Hand]

    init?(recipe: BraidRecipe, stand: BraidStand, colours: [Int: ThreadColorID] = [:]) {
        let count = stand.positionCount
        guard count > 0, stand.positionIDs == Array(1...count) else { return nil }
        let geometry = BraidBookGeometry(placeCount: count)
        let limit = max(count, 1)
        if let standHands = recipe.standHands {
            guard !standHands.hands.isEmpty,
                  let worked = Self.onTheStand(
                      standHands, count: count, colours: colours, limit: limit, geometry: geometry
                  )
            else { return nil }
            form = .stand(standHands)
            homes = worked.homes
            islandsAtStart = standHands.faces.map(\.places)
            tableCount = 1
            handsADan = standHands.hands.count
            passes = worked.passes
            hands = worked.hands
        } else if let slits = recipe.startingSlits, slits.placeOneOnward.count == count,
                  let handsADan = recipe.handsADan, handsADan > 0,
                  recipe.rounds.allSatisfy({ !$0.bookSteps.isEmpty }) {
            let disk = Disk(
                notches: slits.notchCount, count: count, starting: slits.placeOneOnward,
                notchTurn: geometry.notchTurn(notches: slits.notchCount)
            )
            guard let worked = Self.onTheDisk(
                recipe: recipe, disk: disk, colours: colours, limit: limit, handsADan: handsADan
            ) else { return nil }
            form = .disk(notches: slits.notchCount)
            homes = disk.homes
            islandsAtStart = disk.homeIslands
            tableCount = recipe.rounds.count
            self.handsADan = handsADan
            passes = worked.passes
            hands = worked.hands
        } else {
            return nil
        }
        self.geometry = geometry
    }

    // MARK: The disk

    private static func onTheDisk(
        recipe: BraidRecipe, disk start: Disk, colours: [Int: ThreadColorID], limit: Int, handsADan: Int
    ) -> (passes: Int, hands: [Hand])? {
        var disk = start
        let begun = disk.colours(colours)
        var hands = [Hand]()
        var northAtStart = [Int: Int]()
        var takenAtStart = [Int: Set<Int>]()
        var passes = limit
        for pass in 1...limit {
            for (table, notation) in recipe.rounds.enumerated() {
                guard let north = disk.slitDrawnAtTheNorth() else { return nil }
                let drift: Int
                if let was = northAtStart[table], let taken = takenAtStart[table] {
                    drift = disk.shortest(north - was)
                    guard Set(taken.map { disk.wrapped($0 + drift) }) == disk.taken else { return nil }
                } else {
                    northAtStart[table] = north
                    takenAtStart[table] = disk.taken
                    drift = 0
                }
                var open: (part: PartHand, name: String?, isHandOver: Bool)?
                var failed = false
                func close() {
                    guard let current = open else { return }
                    open = nil
                    let after = disk.seats()
                    let islands = disk.islands()
                    let endsADan = (hands.count + 1) % handsADan == 0
                    var setting: [Int: Seat]?
                    if endsADan {
                        switch disk.setBack() {
                        case .moved(let seats): setting = seats
                        case .unmoved: setting = nil
                        case nil: failed = true
                        }
                    }
                    hands.append(Hand(
                        table: table, name: current.name, isHandOver: current.isHandOver,
                        carries: current.part.carries, adjustments: current.part.adjustments,
                        before: current.part.before, afterCarrying: current.part.afterCarrying,
                        after: after, islands: islands, endsADan: endsADan, setting: setting,
                        standHand: nil
                    ))
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
                        open?.part.adjustments += moved
                    }
                    guard !failed else { return nil }
                }
                close()
                guard !failed else { return nil }
            }
            if disk.colours(colours) == begun {
                passes = pass
                break
            }
        }
        // A time round ends a dan: it is where the drawing starts again.
        guard hands.count % handsADan == 0 else { return nil }
        return (passes, hands)
    }

    /// A hand being worked: its carries, and the adjustments after them.
    private struct PartHand {
        let carries: [Move]
        var adjustments = [Move]()
        let before: [Int: Seat]
        let afterCarrying: [Int: Seat]
    }

    /// What setting back in the starting form did.
    private enum SetBack {
        case unmoved
        case moved([Int: Seat])
    }

    /// The book's disk: each thread's notch, and where each notch a thread
    /// stands in, or has stood in since the dan began, is drawn.
    private struct Disk {
        let notches: Int
        let count: Int
        let notchTurn: Double
        /// Where each place's thread starts.
        let home: [Int: Int]
        /// Where each place's thread is drawn at the start, and after each dan.
        let homeTurn: [Int: Double]
        /// The islands at the start, each its places clockwise.
        let homeIslands: [[Int]]
        var slit: [Int: Int]
        /// Notch -> the turn it is drawn at.
        var shown: [Int: Double]

        init(notches: Int, count: Int, starting: [Int], notchTurn: Double) {
            self.notches = notches
            self.count = count
            self.notchTurn = notchTurn
            let home = Dictionary(uniqueKeysWithValues: starting.enumerated().map { ($0.offset + 1, $0.element) })
            self.home = home
            slit = home
            let islands = Self.runs(home, notches: notches, count: count)
            homeIslands = islands
            // Place 1's island with its middle at the top; each island's
            // threads a notch's drawn width apart about its middle.
            let first = islands.first { $0.contains(1) } ?? [1]
            let firstNotches = Self.unwrapped(first.compactMap { home[$0] }, notches: notches)
            let firstMiddle = firstNotches.reduce(0, +) / Double(max(firstNotches.count, 1))
            let rotation = -((firstMiddle - 1) / Double(notches))
            var turns = [Int: Double]()
            for island in islands {
                let positions = Self.unwrapped(island.compactMap { home[$0] }, notches: notches)
                let middle = positions.reduce(0, +) / Double(max(positions.count, 1))
                let centre = (middle - 1) / Double(notches) + rotation
                for (place, position) in zip(island, positions) {
                    turns[place] = BraidBookWorking.unit(centre + (position - middle) * notchTurn)
                }
            }
            homeTurn = turns
            var shown = [Int: Double]()
            for (place, notch) in home { shown[notch] = turns[place] }
            self.shown = shown
        }

        var homes: [Int: Seat] { homeTurn.mapValues { Seat(turn: $0, radius: 1) } }
        var taken: Set<Int> { Set(slit.values) }

        func wrapped(_ notch: Int) -> Int { ((notch - 1) % notches + notches) % notches + 1 }

        /// The short way round, in notches, + clockwise.
        func shortest(_ forward: Int) -> Int {
            let forward = (forward % notches + notches) % notches
            return forward * 2 <= notches ? forward : forward - notches
        }

        func seats() -> [Int: Seat] {
            slit.compactMapValues { notch in shown[notch].map { Seat(turn: $0, radius: 1) } }
        }

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

        static func unwrapped(_ notchesOf: [Int], notches: Int) -> [Double] {
            guard let first = notchesOf.first else { return [] }
            var out = [Double(first)]
            for (previous, notch) in zip(notchesOf, notchesOf.dropFirst()) {
                out.append((out.last ?? 0) + Double(((notch - previous) % notches + notches) % notches))
            }
            return out
        }

        /// The place whose home a thread is drawn at, if any.
        private func place(at notch: Int) -> Int? {
            guard let turn = shown[notch] else { return nil }
            return homeTurn.first { abs(BraidBookWorking.between($0.value, turn)) < 1e-9 }?.key
        }

        /// The colour at each place's home, or the thread when no colours are given.
        func colours(_ colours: [Int: ThreadColorID]) -> [Int: String] {
            var out = [Int: String]()
            for (thread, notch) in slit {
                if let place = place(at: notch) { out[place] = colours[thread]?.rawValue ?? "\(thread)" }
            }
            return out
        }

        /// The slit of the thread drawn where place 1's island's first thread
        /// began.
        func slitDrawnAtTheNorth() -> Int? {
            guard let north = homeIslands.first(where: { $0.contains(1) })?.first else { return nil }
            return slit.values.first { place(at: $0) == north }
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

        /// **Moves the threads in the given slits at once**, and no other. Each
        /// is drawn where its new notch was drawn since the dan began — a slit
        /// just left —, or else a notch's drawn width on from the nearest
        /// thread. False when a slit is empty or a landing taken.
        mutating func apply(_ moves: [BraidMove]) -> Bool {
            var movers = [Int]()
            for move in moves {
                guard let thread = slit.first(where: { $0.value == move.from })?.key else { return false }
                movers.append(thread)
            }
            let staying = slit.filter { !movers.contains($0.key) }.values.sorted()
            for (move, thread) in zip(moves, movers) {
                guard !staying.contains(move.to) else { return false }
                slit[thread] = move.to
            }
            for move in moves where shown[move.to] == nil {
                guard let nearest = staying.min(by: { abs(shortest($0 - move.to)) < abs(shortest($1 - move.to)) }),
                      let there = shown[nearest] else { continue }
                shown[move.to] = there + Double(shortest(move.to - nearest)) * notchTurn
            }
            return true
        }

        /// **Every thread set back in the starting form**: the islands as they
        /// stand matched, in their order round, to the islands of the start —
        /// the matching that turns the threads least —, each thread to its
        /// match's place. `nil` when the islands are not the start's.
        mutating func setBack() -> SetBack? {
            let runs = islands()
            guard runs.count == homeIslands.count, !runs.isEmpty else { return nil }
            var best: (cost: Double, places: [Int: Int])?
            for shift in 0..<runs.count {
                var places = [Int: Int]()
                var cost = 0.0
                for (index, run) in runs.enumerated() {
                    let island = homeIslands[(index + shift) % homeIslands.count]
                    guard island.count == run.count else { cost = .infinity; break }
                    for (thread, place) in zip(run, island) {
                        guard let notch = slit[thread], let now = shown[notch], let to = homeTurn[place] else {
                            return nil
                        }
                        places[thread] = place
                        cost += abs(BraidBookWorking.between(now, to))
                    }
                }
                if cost < (best?.cost ?? .infinity) { best = (cost, places) }
            }
            guard let best else { return nil }
            var drawn = [Int: Double]()
            for (thread, place) in best.places {
                guard let notch = slit[thread], let turn = homeTurn[place] else { return nil }
                drawn[notch] = turn
            }
            shown = drawn
            return best.cost < 1e-9 ? .unmoved : .moved(seats())
        }
    }

    // MARK: The stand's faces

    private static func onTheStand(
        _ hands: BraidStandHands, count: Int, colours: [Int: ThreadColorID], limit: Int,
        geometry: BraidBookGeometry
    ) -> (homes: [Int: Seat], passes: Int, hands: [Hand])? {
        guard Set(hands.faces.flatMap(\.places)) == Set(1...count),
              hands.faces.flatMap(\.places).count == count else { return nil }
        let step = geometry.faceTurn
        let apart = geometry.apartOnAFace
        let byNumber = Dictionary(uniqueKeysWithValues: hands.faces.map { ($0.number, $0) })
        func homeSeats(_ face: BraidStandHands.Face, count: Int) -> [Seat] {
            (0..<count).map {
                Seat(turn: BraidBookWorking.unit(face.turn + (Double($0) - Double(count - 1) / 2) * step), radius: 1)
            }
        }
        // Each face's threads, clockwise, and where each is drawn.
        var faces = [Int: [Int]]()
        var seats = [Int: Seat]()
        for face in hands.faces {
            faces[face.number] = face.places
            for (place, seat) in zip(face.places, homeSeats(face, count: face.places.count)) { seats[place] = seat }
        }
        let homes = seats
        func coloursAtHome() -> [Int: String] {
            var out = [Int: String]()
            for (place, home) in homes {
                if let thread = seats.first(where: { $0.value == home })?.key {
                    out[place] = colours[thread]?.rawValue ?? "\(thread)"
                }
            }
            return out
        }
        let begun = coloursAtHome()
        var worked = [Hand]()
        var passes = limit
        for pass in 1...limit {
            for (index, hand) in hands.hands.enumerated() {
                let before = seats
                // Take every thread of the hand first, each from where it stands.
                var taken = [(carry: BraidStandHands.Carry, thread: Int)]()
                for carry in hand.carries {
                    guard let face = byNumber[carry.face], let threads = faces[carry.face] else { return nil }
                    let at: Int
                    if let end = carry.end {
                        at = end == face.clockwiseFirst ? carry.fromTheEnd : threads.count - 1 - carry.fromTheEnd
                    } else {
                        guard threads.count == 1 else { return nil }
                        at = 0
                    }
                    guard threads.indices.contains(at) else { return nil }
                    taken.append((carry, threads[at]))
                }
                for (carry, thread) in taken {
                    faces[carry.face]?.removeAll { $0 == thread }
                    seats[thread] = nil
                }
                // Then lay them, those laid at one spot together, each drawn
                // between the threads it is laid between; no other moves.
                var laid = Set<Int>()
                for (carry, thread) in taken where !laid.contains(thread) {
                    guard let face = byNumber[carry.toFace], var threads = faces[carry.toFace] else { return nil }
                    let together = taken.filter {
                        !laid.contains($0.thread) && $0.carry.toFace == carry.toFace
                            && Self.together($0.carry.spot, carry.spot)
                    }
                    let ordered = (together.filter { Self.side(of: $0.carry.spot) == face.clockwiseFirst }
                        + together.filter { Self.side(of: $0.carry.spot) != face.clockwiseFirst }).map(\.thread)
                    let at: Int
                    switch carry.spot {
                    case .face: at = 0
                    case .centre: at = threads.count / 2
                    case .insideEnd(let end):
                        at = end == face.clockwiseFirst ? min(1, threads.count) : max(threads.count - 1, 0)
                    case .end(let end): at = end == face.clockwiseFirst ? 0 : threads.count
                    }
                    let left = at > 0 ? seats[threads[at - 1]]?.turn : nil
                    let right = at < threads.count ? seats[threads[at]]?.turn : nil
                    threads.insert(contentsOf: ordered, at: at)
                    faces[carry.toFace] = threads
                    guard let placed = Self.lay(
                        ordered.count, between: left, and: right, onFaceAt: face.turn, step: step,
                        apart: apart, clearOf: Array(seats.values)
                    ) else { return nil }
                    for (thread, seat) in zip(ordered, placed) { seats[thread] = seat }
                    laid.formUnion(ordered)
                }
                let after = seats
                let islands = hands.faces.compactMap { faces[$0.number] }.filter { !$0.isEmpty }
                let endsADan = index == hands.hands.count - 1
                var setting: [Int: Seat]?
                if endsADan {
                    var back = [Int: Seat]()
                    for face in hands.faces {
                        guard let threads = faces[face.number], threads.count == face.places.count else { return nil }
                        for (thread, seat) in zip(threads, homeSeats(face, count: threads.count)) { back[thread] = seat }
                    }
                    if back != seats { setting = back }
                    seats = back
                }
                worked.append(Hand(
                    table: 0, name: nil, isHandOver: false,
                    carries: taken.map { Move(thread: $0.thread, way: hand.way, over: []) },
                    adjustments: [], before: before, afterCarrying: after, after: after,
                    islands: islands, endsADan: endsADan, setting: setting, standHand: hand
                ))
            }
            if coloursAtHome() == begun {
                passes = pass
                break
            }
        }
        return (homes, passes, worked)
    }

    /// **Where threads laid together on a face are drawn**: evenly between the
    /// two they are laid between — or a step past the one there is, or at the
    /// face's middle on an empty face —, on the rim if they touch none there,
    /// else as little in towards the middle as parts them.
    private static func lay(
        _ count: Int, between left: Double?, and right: Double?, onFaceAt middleOfFace: Double,
        step: Double, apart: Double, clearOf others: [Seat]
    ) -> [Seat]? {
        let from: Double, to: Double
        switch (left, right) {
        case let (l?, r?): from = l; to = l + unit(r - l)
        case let (l?, nil): from = l; to = l + 2 * step
        case let (nil, r?): from = r - 2 * step; to = r
        case (nil, nil): from = middleOfFace - step; to = middleOfFace + step
        }
        let middle = (from + to) / 2
        for inward in 0...50 {
            let radius = 1 - Double(inward) / 100
            // Apart from each other, at this radius, by at least `apart`.
            let parting = count > 1 ? asin(min(1, apart / 2 / radius)) / .pi : 0
            let spacing = max((to - from) / Double(count + 1), parting)
            let seats = (0..<count).map {
                Seat(turn: unit(middle + (Double($0) - Double(count - 1) / 2) * spacing), radius: radius)
            }
            if seats.allSatisfy({ seat in others.allSatisfy { distance(seat, $0) >= apart - 1e-9 } }) {
                return seats
            }
        }
        return nil
    }

    /// Laid at one spot: both at a face's middle, or the same spot.
    private static func together(_ one: BraidStandHands.Spot, _ other: BraidStandHands.Spot) -> Bool {
        switch (one, other) {
        case (.centre, .centre): true
        default: one == other
        }
    }

    private static func side(of spot: BraidStandHands.Spot) -> BraidStandHands.End? {
        switch spot {
        case .centre(let end), .insideEnd(let end), .end(let end): end
        case .face: nil
        }
    }

    /// Between two seats' middles, the rim being 1.
    static func distance(_ one: Seat, _ other: Seat) -> Double {
        let angle = 2 * .pi * (one.turn - other.turn)
        let squared = one.radius * one.radius + other.radius * other.radius
            - 2 * one.radius * other.radius * cos(angle)
        return max(0, squared).squareRoot()
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
