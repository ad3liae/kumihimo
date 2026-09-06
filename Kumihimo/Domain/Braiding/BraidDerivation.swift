import Foundation

/// One thread's run through the braid over a whole repeat.
struct BraidThreadCourse: Equatable, Sendable {
    let threadPosition: Int

    /// The slot the thread stands at, at each cycle boundary. `repeatCycleCount + 1`
    /// long, the last equal to the first.
    let slots: [Int]

    /// The instant of each cycle at which this thread was moved. **This is what
    /// decides over and under**: where two threads cross, the one moved later in
    /// the cycle was laid on top of the other.
    let layingInstants: [Int]

    var visitedSlots: Set<Int> { Set(slots) }

    /// A thread that keeps to two slots for the whole repeat runs along the braid,
    /// turning over from one face to the other; anything else is carried across
    /// it. **Read off the course**, with no appeal to which group of the stand the
    /// thread started in.
    var runsAlongTheBraid: Bool { visitedSlots.count == 2 }
}

/// One run of a thread past other threads, and which side of them it takes.
///
/// **A crossing does not have one side.** A thread carried across the braid goes
/// under the threads running along it and over another thread carried the other
/// way at the same row, because the second of those was moved before it and the
/// first after it. So the sides are kept per meeting, and the summary used for
/// the face is the side taken against the threads that hold the columns.
struct BraidCrossing: Equatable, Sendable {
    struct Meeting: Equatable, Sendable {
        let width: Int
        let otherThread: Int
        /// Whether the other thread runs along the braid. Carried so the face can
        /// be read off without asking the derivation a second question.
        let otherRunsAlongTheBraid: Bool
        /// The side *this* thread takes: `over` when it was moved later in the
        /// cycle, because it was laid on what was already there.
        let layer: BraidCrossingLayer
    }

    let threadPosition: Int
    /// The step along the braid this crossing is laid at.
    let row: Int
    let fromWidth: Int
    let toWidth: Int
    /// The widths between the two ends, in the order they are passed.
    let passedWidths: [Int]
    let meetings: [Meeting]

    var meetingsWithThreadsRunningAlong: [Meeting] {
        meetings.filter(\.otherRunsAlongTheBraid)
    }

    /// The side taken against the threads that hold the columns — the one the
    /// face shows. `nil` when it meets none of them, or when it takes different
    /// sides against different ones, which would be worth knowing about.
    var layerAgainstThreadsRunningAlong: BraidCrossingLayer? {
        let layers = Set(meetingsWithThreadsRunningAlong.map(\.layer))
        return layers.count == 1 ? layers.first : nil
    }
}

/// One thread standing at one slot at one step along the braid.
struct BraidPatternCell: Equatable, Sendable {
    let row: Int
    let slot: Int
    let threadPosition: Int
    let layer: BraidCrossingLayer
}

/// Everything a stand and a sequence of moves say about the finished braid.
///
/// **No part of this knows the name of a braid.** It is given a stand, a table of
/// moves and the order the threads come in round the braid, and it works out the
/// courses, which threads run along and which are carried across, what passes
/// under what, where in a row each place takes its new appearance, and — when the
/// braid turns out to be flat — how the ring folds across a width.
///
/// **It is not given, and cannot be given, any measurement.** How far the braid
/// advances in one cycle, how high the ridges stand, how far the section is
/// squashed: none of that follows from the moves, so none of it appears here.
struct BraidDerivation: Equatable, Sendable {
    let stand: BraidStand
    let method: BraidMethod
    let crossSection: BraidCrossSection

    /// Cycles to one repeat. Worked out by braiding until the stand comes back to
    /// itself.
    let repeatCycleCount: Int

    /// Steps of one cycle plus the closing. A place that receives its thread at
    /// the third of them takes its new appearance three of these along the row.
    let instantsPerCycle: Int

    let courses: [BraidThreadCourse]
    let crossings: [BraidCrossing]
    let cells: [BraidPatternCell]

    /// How the ring folds across a width, when the braid turns out to be flat.
    /// `nil` for a tube — and a tube is what a braid is unless its own courses say
    /// otherwise.
    let fold: BraidFold?

    /// The columns the face of a tube shows, as slots, in the order they come
    /// round the braid.
    ///
    /// **Derived from the closing step.** When the closing moves each carry a
    /// thread one slot along the ring, and between them cover every slot, the
    /// braid's face is those pairs: one column for each, half as many columns as
    /// there are threads. `nil` when the closing does not do that — a flat braid's
    /// closing only tidies its edges, and its columns come from the fold instead.
    let faceColumns: [[Int]]?

    var faceColumnCount: Int? { faceColumns?.count }

    var threadCount: Int { stand.positionCount }

    var isFlat: Bool { fold != nil }

    func course(ofThread threadPosition: Int) -> BraidThreadCourse? {
        courses.first { $0.threadPosition == threadPosition }
    }

    var threadsRunningAlongTheBraid: [Int] {
        courses.filter(\.runsAlongTheBraid).map(\.threadPosition).sorted()
    }

    var threadsCarriedAcrossTheBraid: [Int] {
        courses.filter { !$0.runsAlongTheBraid }.map(\.threadPosition).sorted()
    }

    /// The columns a thread running along the braid holds. Empty for a tube.
    var columnsHeldLengthwise: Set<Int> {
        guard let fold else { return [] }
        return Set(courses.filter(\.runsAlongTheBraid).flatMap { course in
            course.slots.compactMap { fold.column(ofSlot: $0) }
        })
    }

    // MARK: - Where in a row a place takes its new appearance

    /// The instants within a cycle at which a thread arrives at a slot.
    ///
    /// **Counted as arrivals, not departures**: a place looks different from the
    /// moment the new thread reaches it. The closing counts as the last instant
    /// because for the outermost places it is the only one at which they receive a
    /// thread; without it they would have no arrival at all.
    func arrivalInstants(atSlot slot: Int) -> [Int] {
        guard let positionID = crossSection.positionID(atSlot: slot) else { return [] }
        guard let cycle = BraidWorking.cycle(
            of: method,
            from: BraidStandState.start(on: stand)
        ) else {
            return []
        }
        return cycle.instants.flatMap { instant in
            instant.step.moves.filter { $0.to == positionID }.map { _ in instant.ordinal }
        }
    }

    /// The instants at which a thread arrives anywhere across the width, both
    /// slots of an edge counted together. `nil` without a fold.
    func arrivalInstants(atWidth width: Int) -> [Int]? {
        guard let fold else { return nil }
        let slots = (0..<crossSection.slotCount).filter { fold.width(ofSlot: $0) == width }
        guard !slots.isEmpty else { return [] }
        return slots.flatMap { arrivalInstants(atSlot: $0) }.sorted()
    }

    /// How far along a row that place takes its new appearance, as a fraction of
    /// the row. **The number of instants divided by is a consequence of counting
    /// the closing, not an invariant of the braid.**
    func arrivalPhase(atWidth width: Int) -> Double? {
        guard let instants = arrivalInstants(atWidth: width), !instants.isEmpty else {
            return nil
        }
        let mean = Double(instants.reduce(0, +)) / Double(instants.count)
        return mean / Double(instantsPerCycle)
    }

    func arrivalPhase(atSlot slot: Int) -> Double? {
        let instants = arrivalInstants(atSlot: slot)
        guard !instants.isEmpty else { return nil }
        return Double(instants.reduce(0, +)) / Double(instants.count) / Double(instantsPerCycle)
    }

    // MARK: - Deriving

    /// `nil` when the stand and the table do not fit each other, when the table
    /// never returns the stand to itself, or when the cross-section does not cover
    /// the stand.
    static func derive(
        stand: BraidStand,
        method: BraidMethod,
        crossSection: BraidCrossSection? = nil,
        repeatLimit: Int = 64
    ) -> BraidDerivation? {
        let section = crossSection ?? .tube(of: stand)
        guard
            stand.isWellFormed,
            method.standID == stand.id,
            section.isWellFormed,
            Set(section.order) == Set(stand.positionIDs),
            let repeatCount = BraidWorking.repeatCycleCount(
                of: method, on: stand, limit: repeatLimit
            ),
            let cycles = BraidWorking.cycles(of: method, on: stand, count: repeatCount)
        else {
            return nil
        }

        // Where every thread stands at each cycle boundary, the closing one
        // included, so a course has one sample per step along the braid.
        var boundaries = cycles.compactMap(\.startState.positionByThread)
        if let last = cycles.last?.endState.positionByThread { boundaries.append(last) }
        guard boundaries.count == repeatCount + 1 else { return nil }

        // Which instant of each cycle moved each thread. A thread moved twice in
        // one cycle would make "the one moved later" ambiguous, so it is refused
        // rather than resolved by a rule nobody has checked.
        var layingByThread = [Int: [Int]](minimumCapacity: stand.positionCount)
        for cycle in cycles {
            var seen = Set<Int>()
            for carried in cycle.allCarried {
                guard seen.insert(carried.thread).inserted else { return nil }
                layingByThread[carried.thread, default: []].append(carried.instant)
            }
            guard seen.count == stand.positionCount else { return nil }
        }

        var courses = [BraidThreadCourse]()
        for thread in stand.positionIDs.sorted() {
            let slots = boundaries.compactMap { byThread in
                byThread[thread].flatMap { section.slotIndex(ofPositionID: $0) }
            }
            guard
                slots.count == boundaries.count,
                let laying = layingByThread[thread],
                laying.count == repeatCount
            else {
                return nil
            }
            courses.append(BraidThreadCourse(
                threadPosition: thread, slots: slots, layingInstants: laying
            ))
        }

        let fold = BraidFold.folding(
            slotCount: section.slotCount,
            throughThicknessPairs: Set(
                courses.filter(\.runsAlongTheBraid).map { Set($0.slots) }
            )
        )

        guard let crossings = crossings(courses: courses, fold: fold, rowCount: repeatCount)
        else {
            return nil
        }
        let cells = cells(courses: courses, crossings: crossings, rowCount: repeatCount)

        return BraidDerivation(
            stand: stand,
            method: method,
            crossSection: section,
            repeatCycleCount: repeatCount,
            instantsPerCycle: method.instantCount,
            courses: courses,
            crossings: crossings,
            cells: cells,
            fold: fold,
            faceColumns: faceColumns(method: method, crossSection: section)
        )
    }

    /// A step of one across the width is a turn at an edge; anything longer
    /// crosses the braid, passing the threads that hold the widths between.
    ///
    /// **Which side it takes comes from the order of the moves.** The crossing
    /// thread was moved at one instant of the cycle and each thread it meets at
    /// another; the one moved later was laid on top.
    ///
    /// `nil` when two threads that meet were moved at the same instant. The table
    /// then does not say which lies over, and inventing an answer is exactly the
    /// mistake this file exists to stop.
    private static func crossings(
        courses: [BraidThreadCourse],
        fold: BraidFold?,
        rowCount: Int
    ) -> [BraidCrossing]? {
        guard let fold else { return [] }
        var result = [BraidCrossing]()
        for course in courses {
            for row in 0..<rowCount {
                guard
                    let from = fold.width(ofSlot: course.slots[row]),
                    let to = fold.width(ofSlot: course.slots[row + 1]),
                    abs(to - from) > 1
                else {
                    continue
                }
                let step = to > from ? 1 : -1
                let passed = Array(stride(from: from + step, to: to, by: step))
                var meetings = [BraidCrossing.Meeting]()
                for other in courses where other.threadPosition != course.threadPosition {
                    guard
                        let width = fold.width(ofSlot: other.slots[row]),
                        passed.contains(width)
                    else {
                        continue
                    }
                    let mine = course.layingInstants[row]
                    let theirs = other.layingInstants[row]
                    guard mine != theirs else { return nil }
                    meetings.append(BraidCrossing.Meeting(
                        width: width,
                        otherThread: other.threadPosition,
                        otherRunsAlongTheBraid: other.runsAlongTheBraid,
                        layer: mine > theirs ? .over : .under
                    ))
                }
                result.append(BraidCrossing(
                    threadPosition: course.threadPosition,
                    row: row,
                    fromWidth: from,
                    toWidth: to,
                    passedWidths: passed,
                    meetings: meetings.sorted {
                        ($0.width, $0.otherThread) < ($1.width, $1.otherThread)
                    }
                ))
            }
        }
        return result.sorted { ($0.row, $0.threadPosition) < ($1.row, $1.threadPosition) }
    }

    /// The face's columns, when the closing step pairs the whole ring.
    ///
    /// On a round braid the closing takes each thread that has just arrived at the
    /// middle of a group and sets it one place along, beside the thread already
    /// there. Those two threads are the one column of the finished braid, which is
    /// why a sixteen-thread round braid shows eight columns and not sixteen.
    private static func faceColumns(
        method: BraidMethod,
        crossSection: BraidCrossSection
    ) -> [[Int]]? {
        let slotCount = crossSection.slotCount
        guard method.closing.moves.count * 2 == slotCount else { return nil }

        var pairs = [[Int]]()
        for move in method.closing.moves {
            guard
                let from = crossSection.slotIndex(ofPositionID: move.from),
                let to = crossSection.slotIndex(ofPositionID: move.to),
                (to + 1) % slotCount == from || (from + 1) % slotCount == to
            else {
                return nil
            }
            // The pair's place round the ring is the one of the two slots whose
            // neighbour behind it is not also in the pair.
            let leading = (to + 1) % slotCount == from ? to : from
            pairs.append([leading, (leading + 1) % slotCount])
        }
        guard Set(pairs.flatMap { $0 }).count == slotCount else { return nil }
        return pairs.sorted { $0[0] < $1[0] }
    }

    /// Every slot, at every step along the braid.
    ///
    /// A thread shows as `under` at a row when, at that row, it crosses the braid
    /// beneath the threads holding the columns. That is what keeps it out of the
    /// middle of the face: it is only seen where it turns.
    private static func cells(
        courses: [BraidThreadCourse],
        crossings: [BraidCrossing],
        rowCount: Int
    ) -> [BraidPatternCell] {
        let goesUnder = Set(
            crossings
                .filter { $0.layerAgainstThreadsRunningAlong == .under }
                .map { [$0.row, $0.threadPosition] }
        )
        var result = [BraidPatternCell]()
        for course in courses {
            for row in 0..<rowCount {
                result.append(BraidPatternCell(
                    row: row,
                    slot: course.slots[row],
                    threadPosition: course.threadPosition,
                    layer: goesUnder.contains([row, course.threadPosition]) ? .under : .over
                ))
            }
        }
        return result.sorted { ($0.row, $0.slot) < ($1.row, $1.slot) }
    }
}
