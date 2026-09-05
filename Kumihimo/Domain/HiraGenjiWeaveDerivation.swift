import Foundation

/// Where each thread of the flat braid goes.
///
/// Two things go into this and they are kept apart on purpose.
///
/// **The cross-section is given.** Six threads across the front, six across the
/// back, and two at each edge lying one behind the other. Two sources support it
/// on their own: the author's account of the braid, and the finished braid
/// photographed in book A p96, whose face measures six columns wide (see
/// `crossSectionPlace(ofBoardPosition:)`). It is not derived here and nothing
/// here may contradict it.
///
/// **Which thread is at which of those places, and when, comes from the move
/// rules.** `HiraGenjiSimulation` is the only source for that: its six moves and
/// its end repositioning were checked against book A, book B and book C in
/// `HiraGenjiMoveRuleSourcesTests` and agree on all sixteen threads.
///
/// The map between the two — board position to place in the cross-section — is
/// read off the reference photographs, not guessed and not searched for. See
/// `crossSectionPlace(ofBoardPosition:)`.
///
/// An earlier version of this file carried the stand's ring into the
/// cross-section as a cyclic order, so that threads next to each other on the
/// stand came out next to each other in the braid. Book A p96's finished braid
/// refutes that; the reasoning is recorded with the map below.
enum HiraGenjiWeaveDerivation {
    static let threadCount = HiraGenjiSimulation.requiredThreadCount
    static let boardPositionCount = 16

    /// Columns across one face of the braid.
    static let columnCount = 6

    /// Threads at each edge, lying one behind the other through the thickness.
    static let edgeThreadCount = 2

    /// A place in the braid's cross-section.
    enum Place: Equatable, Sendable {
        case face(HiraGenjiBraidFace, column: Int)
        case edge(HiraGenjiBraidEdge)
    }

    /// Where each board position sits in the braid's cross-section.
    ///
    /// **Read from book A p96, not derived.** The braid there is worked with
    /// faces 1 and 3 in four colours and faces 2 and 4 all in one. The starting
    /// diagram gives face 1, west to east, as mauve, mauve, black, vermilion —
    /// board positions 15, 16, 1, 2. The finished braid photographed at the head
    /// of the same page reads, across its width:
    ///
    ///     salmon | mauve | mauve | vermilion | black | salmon
    ///
    /// in bands measuring 16, 20, 20, 24, 24 and 16 pixels — six columns of one
    /// thread each. Black is therefore column 4 and vermilion column 3, so board
    /// position 1 is at column 4 and board position 2 at column 3. Everything
    /// else follows from the two reflections below: `positionThroughTheBraid`
    /// puts each pair in one column, and `positionAcrossTheBraid` fixes the
    /// mirror column, leaving only which pair of the east and west groups holds
    /// the outermost column and which holds the edge. That last choice is a
    /// phase, not a shape — the two answers are the same braid one row apart —
    /// and it is taken to match book A p97's caption, which groups the outer two
    /// of each side ("奥と手前2本") apart from the middle two ("中央の2本").
    ///
    /// The one assumption is the old one: call the north side of the stand the
    /// front of the braid.
    ///
    /// Note what this is **not**. Going round the stand, face 1 reads mauve,
    /// mauve, black, vermilion; going across the braid it reads mauve, mauve,
    /// vermilion, black. Black and vermilion change places. No rotation or
    /// reflection of the ring can do that, because board positions 1 and 2 are
    /// neighbours on the ring and stay neighbours, in order, under any map that
    /// keeps the cyclic order. Carrying the ring across as an order is refuted by
    /// this photograph.
    static func crossSectionPlace(ofBoardPosition boardPosition: Int) -> Place? {
        placesByBoardPosition[boardPosition]
    }

    private static let placesByBoardPosition: [Int: Place] = [
        14: .face(.front, column: 0),
        16: .face(.front, column: 1),
        15: .face(.front, column: 2),
        2: .face(.front, column: 3),
        1: .face(.front, column: 4),
        3: .face(.front, column: 5),

        11: .face(.back, column: 0),
        9: .face(.back, column: 1),
        10: .face(.back, column: 2),
        7: .face(.back, column: 3),
        8: .face(.back, column: 4),
        6: .face(.back, column: 5),

        12: .edge(.left),
        13: .edge(.left),
        4: .edge(.right),
        5: .edge(.right),
    ]

    /// Position across the width on one axis, edges included: the left edge sits
    /// one step outside column 0 and the right edge one step outside the last.
    ///
    /// Lets a course be measured without a special case for the edges. A step of
    /// one is a turn at an edge; a longer step is a crossing of the braid.
    static func widthPosition(ofBoardPosition boardPosition: Int) -> Int? {
        switch crossSectionPlace(ofBoardPosition: boardPosition) {
        case .face(_, let column): return column
        case .edge(.left): return -1
        case .edge(.right): return columnCount
        case nil: return nil
        }
    }

    static func isOnTheFront(boardPosition: Int) -> Bool? {
        switch crossSectionPlace(ofBoardPosition: boardPosition) {
        case .face(let face, _): return face == .front
        case .edge: return nil
        case nil: return nil
        }
    }

    /// The board position in the same column on the other face — the thread lying
    /// directly under this one through the thickness of the braid.
    ///
    /// Reflection in the plane of the braid. The line it turns about on the stand
    /// runs between board positions 4 and 5 and between 12 and 13, the middles of
    /// the east and west groups. A thread moved between the north and the south
    /// group has to come out at the same place across the width, because the move
    /// does not vacate that place for anyone else.
    static func positionThroughTheBraid(from boardPosition: Int) -> Int {
        wrapped(9 - boardPosition)
    }

    /// The board position facing this one across the width — column `c` against
    /// column `columnCount - 1 - c`, and one edge against the other.
    ///
    /// Reflection in the braid's own centre line, turning about the middles of the
    /// north and south groups.
    static func positionAcrossTheBraid(from boardPosition: Int) -> Int {
        wrapped(1 - boardPosition)
    }

    private static func wrapped(_ raw: Int) -> Int {
        let value = raw % boardPositionCount
        let positive = value < 0 ? value + boardPositionCount : value
        return positive == 0 ? boardPositionCount : positive
    }

    static func allMoves(in cycle: HiraGenjiCycle) -> [HiraGenjiThreadMove] {
        cycle.moveEvents.flatMap(\.moves) + cycle.endRepositioning.moves
    }

    /// The moves of one cycle paired off, two threads to a pair, under the given
    /// reflection.
    ///
    /// `nil` when any move has no partner — a thread shifted on its own, which the
    /// author says this braid never does.
    static func movePairs(
        in cycle: HiraGenjiCycle,
        underReflection reflect: (Int) -> Int
    ) -> [(HiraGenjiThreadMove, HiraGenjiThreadMove)]? {
        let moves = allMoves(in: cycle)
        let bySource = Dictionary(
            moves.map { ($0.sourceBoardPosition, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        guard bySource.count == moves.count else { return nil }

        var pairs = [(HiraGenjiThreadMove, HiraGenjiThreadMove)]()
        for move in moves where move.sourceBoardPosition < reflect(move.sourceBoardPosition) {
            guard
                let partner = bySource[reflect(move.sourceBoardPosition)],
                partner.destinationBoardPosition == reflect(move.destinationBoardPosition)
            else {
                return nil
            }
            pairs.append((move, partner))
        }
        return pairs.count * 2 == moves.count ? pairs : nil
    }

    /// The board positions one thread visits over a whole repeat.
    static func orbit(ofThread threadPosition: Int, cycleCount: Int) -> Set<Int>? {
        guard let courses = courses(cycleCount: cycleCount) else { return nil }
        return courses.first { $0.threadPosition == threadPosition }
            .map { Set($0.boardPositions) }
    }

    /// How many cycles the braid takes to come back to where it started. Derived
    /// by running the simulation, not assumed: `nil` if it never does inside
    /// `limit`, which would mean the move rules had changed under us.
    static func repeatCycleCount(limit: Int = 64) -> Int? {
        var state = HiraGenjiBoardState.initial
        for cycle in 1...max(1, limit) {
            guard let next = HiraGenjiSimulation.cycle(from: state) else { return nil }
            state = next.endState
            if state == .initial { return cycle }
        }
        return nil
    }

    /// The course of every thread over `cycleCount` cycles, in thread order.
    static func courses(cycleCount: Int) -> [HiraGenjiThreadCourse]? {
        guard cycleCount > 0 else { return nil }
        let states = HiraGenjiSimulation.boardStates(cycleCount: cycleCount)
        guard states.count == cycleCount + 1 else { return nil }

        let byThread = states.map(\.boardPositionsByThread)
        guard byThread.allSatisfy({ $0.count == threadCount }) else { return nil }

        let outerPositions = Set(
            HiraGenjiBoardState.initial.east + HiraGenjiBoardState.initial.west
        )
        return (1...threadCount).compactMap { threadPosition in
            let samples = byThread.enumerated().compactMap { cycle, positions in
                positions[threadPosition].flatMap { boardPosition in
                    crossSectionPlace(ofBoardPosition: boardPosition).flatMap { place in
                        widthPosition(ofBoardPosition: boardPosition).map { width in
                            HiraGenjiThreadCourse.Sample(
                                cycle: cycle,
                                boardPosition: boardPosition,
                                place: place,
                                widthPosition: width
                            )
                        }
                    }
                }
            }
            guard samples.count == states.count else { return nil }
            return HiraGenjiThreadCourse(
                threadPosition: threadPosition,
                role: outerPositions.contains(threadPosition) ? .outer : .inner,
                samples: samples
            )
        }
    }
}

/// One thread's run through the braid over a whole number of cycles.
struct HiraGenjiThreadCourse: Equatable, Sendable {
    struct Sample: Equatable, Sendable {
        /// Which cycle boundary this sample stands at. The braid advances one step
        /// per cycle, so this is also the position along the braid, in cycles.
        let cycle: Int
        let boardPosition: Int
        let place: HiraGenjiWeaveDerivation.Place
        /// Across the width on one axis, the edges one step outside the columns.
        let widthPosition: Int

        var column: Int? {
            if case .face(_, let column) = place { return column }
            return nil
        }

        var face: HiraGenjiBraidFace? {
            if case .face(let face, _) = place { return face }
            return nil
        }

        var edge: HiraGenjiBraidEdge? {
            if case .edge(let edge) = place { return edge }
            return nil
        }
    }

    let threadPosition: Int
    /// The role the existing pattern assigns. Carried so a derived classification
    /// can be checked against it, never used to make one.
    let role: HiraGenjiThreadRole
    let samples: [Sample]

    var boardPositions: [Int] { samples.map(\.boardPosition) }
    var widthPositions: [Int] { samples.map(\.widthPosition) }
    var places: [HiraGenjiWeaveDerivation.Place] { samples.map(\.place) }

    /// A thread whose place across the width never changes runs along the braid;
    /// one whose place changes is carried across it. Read off the course, not off
    /// the role.
    var runsAlongTheBraid: Bool { Set(widthPositions).count == 1 }

    /// How far the thread moves across the braid in total, in thread widths. Free
    /// of any choice about how fast the braid advances.
    var widthTravel: Int {
        zip(widthPositions, widthPositions.dropFirst()).reduce(0) { $0 + abs($1.1 - $1.0) }
    }

    /// True when the thread changes face at every single cycle, which is what a
    /// thread running along the braid and turning over does. Threads that reach an
    /// edge are on neither face there, so this is false for them.
    var alternatesFace: Bool {
        let faces = samples.map(\.face)
        guard faces.allSatisfy({ $0 != nil }), faces.count > 1 else { return false }
        return zip(faces, faces.dropFirst()).allSatisfy { $0 != $1 }
    }

    /// Total course length once the braid's advance per cycle is named. Measured
    /// in thread widths: a column is one thread across, and the two faces are one
    /// thread apart. The advance is a drawing choice, so it is a parameter.
    func length(advancePerCycle: Float) -> Float {
        zip(samples, samples.dropFirst()).reduce(0) { total, pair in
            let across = Float(pair.1.widthPosition - pair.0.widthPosition)
            let through: Float = pair.0.face == pair.1.face ? 0 : 1
            return total + (across * across + through * through
                + advancePerCycle * advancePerCycle).squareRoot()
        }
    }

    /// The edge the thread turns at between two samples, if it turns at all: a
    /// step of one that has the thread at an edge at one end of it.
    func turnEdge(afterCycle cycle: Int) -> HiraGenjiBraidEdge? {
        guard samples.indices.contains(cycle), samples.indices.contains(cycle + 1) else {
            return nil
        }
        let from = samples[cycle]
        let to = samples[cycle + 1]
        guard abs(to.widthPosition - from.widthPosition) == 1 else { return nil }
        return from.edge ?? to.edge
    }
}

enum HiraGenjiBraidEdge: Equatable, Sendable, CaseIterable {
    case left
    case right
}
