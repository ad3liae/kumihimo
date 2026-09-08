import Foundation

/// One thread's run through the braid over a whole repeat.
struct BraidThreadCourse: Equatable, Sendable {
    let threadPosition: Int

    /// The slot the thread stands at, at each cycle boundary. `repeatCycleCount + 1`
    /// long, the last equal to the first.
    let slots: [Int]

    /// The instant of each cycle at which this thread was moved, or 0 for a cycle
    /// that left it alone. **This is what decides over and under**: where two
    /// threads cross, the one moved later in the cycle was laid on top of the
    /// other, and a thread nobody touched was already lying there.
    let layingInstants: [Int]

    var visitedSlots: Set<Int> { Set(slots) }

    /// A thread that keeps to two slots for the whole repeat runs along the braid,
    /// turning over from one face to the other; anything else is carried across
    /// it. **Read off the course**, with no appeal to which group of the stand the
    /// thread started in.
    var runsAlongTheBraid: Bool { visitedSlots.count == 2 }
}

/// One carry of one thread, at one instant of one cycle.
///
/// **This is the whole of the braiding motion.** A thread is lifted from one place
/// on the ring and set down at another; across the top of the stand it takes the
/// straight way, so the carry is a chord. A thread carried twice in a cycle has
/// two chords.
struct BraidChord: Equatable, Sendable {
    /// The step along the braid, one per worked cycle.
    let row: Int
    /// Which instant of that cycle. **Later means laid on top.**
    let instant: Int
    let threadPosition: Int
    let fromSlot: Int
    let toSlot: Int

    var run: (from: Int, to: Int) { (fromSlot, toSlot) }
}

/// One carry, and which side it takes of every thread it has to pass.
///
/// **One rule decides all of it, and it is the stand's own motion**: where two
/// carries cross, the one made later in the cycle was laid on what was already
/// there. Nothing here asks whether the braid is flat or round.
///
/// **A carry does not have one side.** A thread carried across a flat braid goes
/// under the threads running along it and over another thread carried the other
/// way at the same row, because the second was moved before it and the first
/// after. So the sides are kept per meeting, and the summary the face uses is the
/// side taken against the threads that hold the columns.
struct BraidCrossing: Equatable, Sendable {
    struct Meeting: Equatable, Sendable {
        let otherThread: Int
        let otherInstant: Int
        /// Whether the other thread runs along the braid. Carried so the face can
        /// be read off without asking the derivation a second question.
        let otherRunsAlongTheBraid: Bool
        /// The side *this* thread takes: `over` when it was carried later.
        let layer: BraidCrossingLayer
    }

    let threadPosition: Int
    let row: Int
    let instant: Int
    let fromSlot: Int
    let toSlot: Int
    let meetings: [Meeting]

    var meetingsWithThreadsRunningAlong: [Meeting] {
        meetings.filter(\.otherRunsAlongTheBraid)
    }

    /// The side taken against the threads that hold the columns — the one the face
    /// shows. `nil` when it meets none of them, or when it takes different sides
    /// against different ones, which would be worth knowing about.
    var layerAgainstThreadsRunningAlong: BraidCrossingLayer? {
        let layers = Set(meetingsWithThreadsRunningAlong.map(\.layer))
        return layers.count == 1 ? layers.first : nil
    }
}

/// One thread standing at one slot at one step along the braid.
///
/// **Retired from the product (Task 025-2, 2026-09-09).** What shows on a face is
/// whatever is resting there, and `BraidOccupancy` is the record of that; nothing
/// the app draws asks the chord model any more. It is still here because the tests
/// that hold this working-out against the two book-checked per-braid ones read
/// `cells` and `crossings` for over and under, and the occupancy history does not
/// answer that question — the construction of Task 024 does, and porting it is
/// Task 025-3. **Do not reach for this from new product code.**
struct BraidPatternCell: Equatable, Sendable {
    let row: Int
    let slot: Int
    let threadPosition: Int
    /// How the thread shows there. `nil` when the derivation cannot yet say —
    /// which is the case wherever no thread runs along the braid to be measured
    /// against, as on a tube. **Not a default; an admission.**
    let layer: BraidCrossingLayer?
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
    /// Every carry of every thread, in working order.
    let chords: [BraidChord]
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

    /// Threads moved at the same instant that have to pass each other.
    ///
    /// **Where such a pair exists, the move table cannot say which lies over.**
    /// Both were laid at once, so "the one moved later" has no answer, and the
    /// order inside the step would have to come from somewhere else.
    ///
    /// **It is empty for a method whose steps carry one move each**, which is what
    /// a source that moves one thread at a time generates. Both known methods are
    /// like that. The closing is the one instant that carries several, and its
    /// shifts never pass each other: each goes one place into a slot just vacated.
    ///
    /// It stays because a method somebody invents on the stand may well declare two
    /// threads to move together, and then the table really does not say.
    var passingsWithinOneInstant: [(row: Int, instant: Int, threads: (Int, Int))] {
        var result = [(row: Int, instant: Int, threads: (Int, Int))]()
        for row in 0..<repeatCycleCount {
            for (index, one) in courses.enumerated() {
                for other in courses[(index + 1)...]
                where one.layingInstants[row] == other.layingInstants[row] {
                    let mine = (from: one.slots[row], to: one.slots[row + 1])
                    let theirs = (from: other.slots[row], to: other.slots[row + 1])
                    guard crossSection.runsMustPassEachOther(mine, theirs) else { continue }
                    result.append((
                        row: row,
                        instant: one.layingInstants[row],
                        threads: (one.threadPosition, other.threadPosition)
                    ))
                }
            }
        }
        return result
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

        // Which instant of each cycle moved each thread. A thread left alone for a
        // whole cycle is laid at instant 0: it was already lying there, so
        // anything moved during the cycle is laid on top of it. A thread moved
        // twice in one cycle would make "the one moved later" ambiguous, so that
        // is refused rather than resolved by a rule nobody has checked.
        var layingByThread = [Int: [Int]](minimumCapacity: stand.positionCount)
        for cycle in cycles {
            var thisCycle = [Int: Int]()
            for carried in cycle.allCarried {
                guard thisCycle[carried.thread] == nil else { return nil }
                thisCycle[carried.thread] = carried.instant
            }
            for thread in stand.positionIDs {
                layingByThread[thread, default: []].append(thisCycle[thread] ?? 0)
            }
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

        var chords = [BraidChord]()
        for (row, cycle) in cycles.enumerated() {
            for carried in cycle.allCarried {
                guard
                    let from = section.slotIndex(ofPositionID: carried.move.from),
                    let to = section.slotIndex(ofPositionID: carried.move.to)
                else {
                    return nil
                }
                chords.append(BraidChord(
                    row: row,
                    instant: carried.instant,
                    threadPosition: carried.thread,
                    fromSlot: from,
                    toSlot: to
                ))
            }
        }

        let crossings = crossings(
            chords: chords, courses: courses, crossSection: section
        )
        let cells = cells(courses: courses, crossings: crossings, rowCount: repeatCount)

        return BraidDerivation(
            stand: stand,
            method: method,
            crossSection: section,
            repeatCycleCount: repeatCount,
            instantsPerCycle: method.instantCount,
            courses: courses,
            chords: chords,
            crossings: crossings,
            cells: cells,
            fold: fold,
            faceColumns: faceColumns(method: method, crossSection: section)
        )
    }

    /// Which carries have to pass which, and which side each takes.
    ///
    /// **One rule, and no branch on the shape of the braid.** Two carries made in
    /// the same cycle cross when their chords' ends alternate round the ring; the
    /// one made at the later instant was laid on the other. Carries made in
    /// different cycles lie at different steps along the braid and are stacked,
    /// not crossed.
    ///
    /// This replaces an earlier reading that worked only on a folded braid, and
    /// measured a crossing by the places it passed across the width. That counted
    /// two threads as meeting whenever they stood at the same place across the
    /// width — even when one kept to the front of the braid and the other to the
    /// back, where they never meet at all.
    private static func crossings(
        chords: [BraidChord],
        courses: [BraidThreadCourse],
        crossSection: BraidCrossSection
    ) -> [BraidCrossing] {
        let runsAlong = Dictionary(
            uniqueKeysWithValues: courses.map { ($0.threadPosition, $0.runsAlongTheBraid) }
        )
        var result = [BraidCrossing]()
        for chord in chords {
            var meetings = [BraidCrossing.Meeting]()
            for other in chords
            where other.row == chord.row
                && other.threadPosition != chord.threadPosition
                && other.instant != chord.instant
                && crossSection.runsMustPassEachOther(chord.run, other.run) {
                meetings.append(BraidCrossing.Meeting(
                    otherThread: other.threadPosition,
                    otherInstant: other.instant,
                    otherRunsAlongTheBraid: runsAlong[other.threadPosition] ?? false,
                    layer: chord.instant > other.instant ? .over : .under
                ))
            }
            guard !meetings.isEmpty else { continue }
            result.append(BraidCrossing(
                threadPosition: chord.threadPosition,
                row: chord.row,
                instant: chord.instant,
                fromSlot: chord.fromSlot,
                toSlot: chord.toSlot,
                meetings: meetings.sorted { $0.otherThread < $1.otherThread }
            ))
        }
        return result.sorted {
            ($0.row, $0.instant, $0.threadPosition) < ($1.row, $1.instant, $1.threadPosition)
        }
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
    /// A thread shows as `under` at a row when, at that row, it is carried beneath
    /// the threads holding the columns. That is what keeps it out of the middle of
    /// the face: it is only seen where it turns. **`nil` where there are no such
    /// threads to be measured against** — a tube has none, and the derivation does
    /// not yet say which of two threads of a tube shows on the outside.
    private static func cells(
        courses: [BraidThreadCourse],
        crossings: [BraidCrossing],
        rowCount: Int
    ) -> [BraidPatternCell] {
        var layers = [[Int]: BraidCrossingLayer]()
        for crossing in crossings {
            guard let layer = crossing.layerAgainstThreadsRunningAlong else { continue }
            layers[[crossing.row, crossing.threadPosition]] = layer
        }
        let anyRunsAlong = courses.contains(where: \.runsAlongTheBraid)
        var result = [BraidPatternCell]()
        for course in courses {
            for row in 0..<rowCount {
                let key = [row, course.threadPosition]
                result.append(BraidPatternCell(
                    row: row,
                    slot: course.slots[row],
                    threadPosition: course.threadPosition,
                    layer: anyRunsAlong ? (layers[key] ?? .over) : nil
                ))
            }
        }
        return result.sorted { ($0.row, $0.slot) < ($1.row, $1.slot) }
    }
}
