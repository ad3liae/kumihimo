import Foundation
import simd

/// The surface of a tube of four threads, **worked out rather than transcribed**
/// (Task 054).
///
/// **Made the way `RoundTube8SurfacePattern` is, and kept apart from it** (the
/// author, 2026-09-22): a drawer belongs to a family and so do its shape values,
/// so the four-thread tube has a drawer of its own rather than a wider eight.
/// What it takes over is the eight-thread tube's reading, which Tasks 045-053
/// settled:
///
/// - **A cell is a thread standing still at a place**, one column wide, from its
///   arrival to the next thread's arrival there. The carry across the braid is
///   buried in the bundle and does not show.
/// - **The columns come from the ring**: four places, a quarter of the turn
///   each. **Which thread is in a cell** comes from the occupancy history.
/// - **A dan is one layer, half a cycle**: a table's braiding moves make its dan
///   two at a time, one pair (book A p.56: the upright pair, then the flat
///   pair). Every place takes its thread in one half of the cycle or the other,
///   neighbouring places in opposite halves, so **the columns stand half a pitch
///   apart** — read off the table, not laid down.
/// - **How a thread shows on its cell** — a run that leans the stitch's way, a
///   blunt head on top, a tail that keeps its width and goes on beneath the runs
///   laid after it — is `RoundTube4Bundle`, a drawing approximation laid over
///   the cells, and it moves no cell.
///
/// **Nothing here decides what passes over what.** The two threads of a pair
/// go to each other's places at one instant (book A prints no order between the
/// hands), and cells stand side by side round the ring and end to end along the
/// braid, so there is no crossing for an order to settle.
struct RoundTube4SurfacePattern: Equatable, Sendable {
    /// The cells, as strand segments in unwrapped surface coordinates: `x` runs
    /// round the braid in turns, `y` along it in repeats. `y` goes below 0 for
    /// the first row's cells, which begin in the repeat before.
    let surface: BraidStrandSurface
    /// Cycles to one repeat. **Worked out by braiding**, not counted here.
    let rowCount: Int
    /// One repeat along the braid divided by one turn around it.
    let aspectRatio: Float
    /// How many places round the braid one cycle carries a thread, signed. **Not
    /// the cell's shape**: it decides which thread is where next cycle.
    let columnsCarried: Int
    /// When each place takes its new thread, as a share of the cycle, by slot.
    let arrivalPhaseBySlot: [Float]
    /// Where each column's cells begin, as a share of the cycle: 0.5 or 1, the
    /// half of the cycle its place takes its thread in.
    let drawnPhaseByColumn: [Float]
    /// Which way each cell's run leans, by segment: **the stitch's own
    /// direction, the same for every cell** (`RoundTube4SurfacePatternGenerator
    /// .stitchLean`). It is not the carry's sign.
    let leanBySegment: [Float]

    /// One cycle along the braid, in repeats.
    var cycleInRepeats: Float { 1 / Float(rowCount) }

    /// A run's length in cycles is measured against its own cell.
    func runCycle(of segment: BraidStrandSegment) -> Float {
        segment.centerlineEnd.y - segment.centerlineStart.y
    }
}

/// **What a thread's visible run looks like on the four-thread tube**: the
/// eight-thread tube's bundle (Task 051) with figures of its own.
///
/// **A drawing approximation calibrated against a photograph, not a
/// derivation** (book A p.10's b). The cell a thread holds is still what the
/// occupancy history gives; this is how the thread *shows* on it:
///
/// - **it leans** the stitch's way, the same for every run — **never the way
///   the carry goes** (Task 053: the spiral turns, the stitch does not);
/// - **its head is blunt**, full width a short rounding after its arrival, and
///   it lies on top of what was laid before it (後に置いた糸が上);
/// - **its tail keeps its width until it is covered**: past the middle of the
///   run it bends further the way it leans, into the next lane, goes on under
///   the side of the run laid half a cycle after it and under the next thread's
///   head at its own place, and only then narrows.
///
/// **What shows at a place is the run standing highest there**, by run and
/// thread and never by colour (`RoundTube4SurfacePattern.runsStanding`). The
/// solid and the card both read that one rule.
struct RoundTube4Bundle: Equatable, Sendable {
    /// How far the run's centreline moves round the braid over one cycle along
    /// it, **in columns per cycle**. Unsigned; the stitch gives the sign.
    let leanColumnsPerCycle: Float
    /// How far the run goes on past the next thread's arrival, **in cycles**.
    let tuckedCycles: Float
    /// How far past its arrival the head is rounded to its full width, **in
    /// cycles**.
    let headRoundingCycles: Float
    /// Over how much of the run the height's arc stands, from the arrival, **in
    /// cycles**.
    let arcSpanCycles: Float
    /// How far the tail's centreline bends round the braid, beyond the lean, by
    /// the run's end, **in columns**.
    let tailBendColumns: Float
    /// Where the bend begins, **in cycles past the arrival**.
    let tailBendFromCycles: Float
    /// Where the tail begins to narrow, **in cycles past the arrival**.
    let tailNarrowsFromCycles: Float
    /// Half the run's width, **in columns**.
    let widestHalfWidthInColumns: Float

    /// **Set against book A p.10's photograph b by eye** (Task 054), side by
    /// side with the solid at the same braid width. How far the tail goes
    /// under, the arc, and where the tail bends are the eight-thread tube's
    /// (Task 051), counted in cycles: on both braids a place takes a new thread
    /// every cycle, half a cycle from its neighbours. **The rest is this
    /// braid's own**, because photograph b's bundles are not the eight-thread
    /// tube's beans:
    ///
    /// - they are **domed ovals that taper to the head** rather than blunt
    ///   pillows — the eight-thread head rounding of 0.12 cycles drew them as
    ///   gnocchi (the author, 2026-09-22: 「ニョッキみたい」), so the head is
    ///   rounded over 0.35;
    /// - they **come to a point at the right end** while it still shows, so the
    ///   tail narrows from 0.7 of a cycle, not from the next thread's arrival;
    /// - they **lean hard**, and their tails go up under the lane beside them
    ///   (the author asked for both, 2026-09-22);
    /// - they are **fat and packed**, about six tenths of the braid's width, with
    ///   no floor showing between the columns.
    static let standard = RoundTube4Bundle(
        leanColumnsPerCycle: 0.6,
        tuckedCycles: 0.55,
        headRoundingCycles: 0.35,
        arcSpanCycles: 1.2,
        tailBendColumns: 0.6,
        tailBendFromCycles: 0.5,
        tailNarrowsFromCycles: 0.7,
        widestHalfWidthInColumns: 0.64
    )

    /// From the arrival to the end of the run, in cycles.
    var lengthInCycles: Float { 1 + tuckedCycles }

    /// A thread is one column wide: the half-width the thread count gives.
    static let oneThreadHalfWidthInColumns: Float = 0.5

    /// Half the run's width at `cycles` past its arrival, in columns: rounded
    /// over `headRoundingCycles` at the head, full through the run, and
    /// narrowing from `tailNarrowsFromCycles` to nothing at the end.
    func halfWidthInColumns(atCycles cycles: Float) -> Float {
        guard cycles >= 0, cycles <= lengthInCycles else { return 0 }
        var fraction: Float = 1
        if headRoundingCycles > 0, cycles < headRoundingCycles {
            let toGo = 1 - cycles / headRoundingCycles
            fraction = max(0, 1 - toGo * toGo).squareRoot()
        }
        let tail = lengthInCycles - tailNarrowsFromCycles
        if tail > 0, cycles > tailNarrowsFromCycles {
            fraction *= cos(.pi / 2 * min((cycles - tailNarrowsFromCycles) / tail, 1))
        }
        return widestHalfWidthInColumns * fraction
    }

    /// Where the run stands highest, **in cycles past its arrival**: the middle
    /// of the arc. It follows from the form.
    var crestAtCycles: Float { arcSpanCycles / 2 }

    /// How tall the run stands at `cycles` past its arrival, 0...1 of the ridge:
    /// **a circular arc over `arcSpanCycles`**, even about its middle (the
    /// author's ruling on the eight-thread tube, Task 049). Past the span the run
    /// lies on the floor, under the runs laid after it.
    func heightFraction(atCycles cycles: Float) -> Float {
        guard cycles >= 0, cycles <= lengthInCycles, arcSpanCycles > 0 else { return 0 }
        let fromTheMiddle = 2 * cycles / arcSpanCycles - 1
        return max(0, 1 - fromTheMiddle * fromTheMiddle).squareRoot()
    }

    /// How far round the braid the centreline has moved from the middle of the
    /// thread's own cell, in columns, signed by `direction`: the lean, and past
    /// `tailBendFromCycles` the tail's bend, growing as the square of the way to
    /// the end so it leaves the lean without a kink.
    func leanInColumns(atCycles cycles: Float, direction: Float) -> Float {
        let reach = lengthInCycles - tailBendFromCycles
        let bent = reach > 0 ? max(0, cycles - tailBendFromCycles) / reach : 0
        return direction * (leanColumnsPerCycle * (cycles - 0.5) + tailBendColumns * bent * bent)
    }

    /// How far the run stands at `cycles` past its arrival and `across` its
    /// width (-1...1), as a fraction of the ridge: its height across a
    /// semi-elliptical section.
    func standingFraction(atCycles cycles: Float, across: Float) -> Float {
        let clamped = min(max(across, -1), 1)
        return heightFraction(atCycles: cycles) * max(0, 1 - clamped * clamped).squareRoot()
    }
}

enum RoundTube4SurfacePatternGenerator {
    static let requiredThreadCount = 4

    /// **Which way every run leans round the braid**: the stitch's direction,
    /// set against book A p.10's photograph b (Task 054) and **not taken from the
    /// sign of the carry** — a pair's two threads are carried the same way round
    /// by the ring's reckoning (a half turn has no shorter way), and that sign
    /// says nothing about the stitch (Task 053).
    ///
    /// **+1: on the solid, with the braid lying across the view and the braiding
    /// point to the right, a run rises to the right and its tail goes up under
    /// the lane above**, as photograph b's bundles do (their tails go under the
    /// white lane above the purple one). **The eight-thread tube's sign is the
    /// other**, −1, set against book A p.8; a rotation of the photograph does
    /// not change which way a bundle leans, so the two are read independently.
    /// Which end of p.10's braid is the braiding point is not known, and neither
    /// is whether the drawing's mirror question (Task 049 2.3) reaches here.
    static let stitchLean: Float = 1

    /// One cycle's growth as a fraction of the braid's own diameter.
    ///
    /// **Measured on book A p.10's photograph b** (`Scripts/task054
    /// /measure_photograph.py`): the surface comes round every 47.3 px along a
    /// braid 59 px across. **The stitch's period, not the colour's**: with this
    /// colouring a place keeps its colour for ever, so the colour runs straight
    /// along the braid and measuring procedure 6's colour period does not exist
    /// here. Each place takes a new thread every cycle, so one bundle along a
    /// column is one cycle.
    static let pitchOverDiameter: Float = 0.80

    /// How many places round the braid one cycle carries a thread: **two of
    /// four**, the pair swapped across the braid. A fact about the table.
    static let columnsCarriedPerCycle = 2

    /// The pattern for a braid, from its table and its colouring.
    static func generate(
        stand: BraidStand,
        method: BraidMethod,
        crossSection: BraidCrossSection,
        assignments: [ThreadAssignment]
    ) -> RoundTube4SurfacePattern? {
        generate(stand: stand, rounds: [method], crossSection: crossSection, assignments: assignments)
    }

    /// The pattern for a braid worked with one table or several in turn.
    ///
    /// **A cell is a thread standing at a place, from its arrival to the next
    /// thread's arrival there.** The time is counted in dan: a table's braiding
    /// moves make its dan two at a time, and a place's thread arrives at the end
    /// of its dan.
    ///
    /// `nil` when the braid is not a tube of four, when a table's braiding moves
    /// are not a whole number of dan, when a place receives twice in one dan,
    /// when a cycle of two dan does not put every other place in each (the half
    /// pitch), when the first table does not carry every thread the same
    /// distance, or when a repeat is not a whole number of cycles long.
    static func generate(
        stand: BraidStand,
        rounds: [BraidMethod],
        crossSection: BraidCrossSection,
        assignments: [ThreadAssignment]
    ) -> RoundTube4SurfacePattern? {
        let count = requiredThreadCount
        guard
            stand.positionCount == count,
            assignments.count == count,
            let derivation = BraidDerivation.derive(
                stand: stand, rounds: rounds, crossSection: crossSection
            ),
            derivation.fold == nil,
            crossSection.slotCount == count,
            let cycles = BraidWorking.cycles(
                ofRounds: rounds, on: stand, count: derivation.repeatCycleCount
            )
        else { return nil }

        let colours = Dictionary(uniqueKeysWithValues: assignments.map { ($0.position, $0.colorID) })
        guard Set(colours.keys) == Set(stand.positionIDs) else { return nil }

        struct Arrival { let time: Float; let thread: Int }
        let perDan = count / 2
        var arrivalsBySlot = [[Arrival]](repeating: [], count: count)
        var time: Float = 0
        var firstCarry: Int?
        var firstPhases = [Float?](repeating: nil, count: count)

        for (index, cycle) in cycles.enumerated() {
            let round = rounds[index % rounds.count]
            // The closing lays nothing, and is left out of the count; a thread
            // it moves still arrives, in the table's last dan.
            let braiding = cycle.allCarried.filter { $0.instant <= round.steps.count }
            let closing = cycle.allCarried.filter { $0.instant > round.steps.count }
            guard !braiding.isEmpty, braiding.count % perDan == 0 else { return nil }
            let dans = braiding.count / perDan
            var slotsByDan = [Set<Int>](repeating: [], count: dans)
            for (order, carried) in (braiding + closing).enumerated() {
                let dan = min(order / perDan, dans - 1)
                guard
                    let from = crossSection.slotIndex(ofPositionID: carried.move.from),
                    let to = crossSection.slotIndex(ofPositionID: carried.move.to)
                else { return nil }
                let step = shortestWayRound(from: from, to: to, around: count)
                guard step != 0, !slotsByDan[dan].contains(to) else { return nil }
                slotsByDan[dan].insert(to)
                arrivalsBySlot[to].append(Arrival(
                    time: time + Float(dan + 1) * 0.5, thread: carried.thread
                ))
                if index == 0, order < braiding.count {
                    if let firstCarry, firstCarry != step { return nil }
                    firstCarry = step
                    firstPhases[to] = Float(carried.instant) / Float(round.steps.count)
                }
            }
            // **Half a pitch**: in a cycle of two dan, every other place takes
            // its thread in each.
            if dans == 2 {
                for slot in 0..<count where slotsByDan[0].contains(slot)
                    == slotsByDan[0].contains((slot + 1) % count) {
                    return nil
                }
            }
            time += Float(dans) * 0.5
        }

        guard time > 0, abs(time - time.rounded()) < 1e-4 else { return nil }
        let rows = Int(time.rounded())
        let repeatLength = Float(rows)
        guard let columnsCarried = firstCarry else { return nil }
        let arrivalPhases = firstPhases.compactMap { $0 }
        guard arrivalPhases.count == count else { return nil }

        let columnWidth = Float(1) / Float(count)
        struct Cell { let start: Float; let end: Float; let slot: Int; let thread: Int }
        var cells = [Cell]()
        for slot in 0..<count {
            let arrivals = arrivalsBySlot[slot].sorted { $0.time < $1.time }
            guard !arrivals.isEmpty else { return nil }
            for (index, arrival) in arrivals.enumerated() {
                var start = arrival.time
                var end = index + 1 < arrivals.count
                    ? arrivals[index + 1].time : arrivals[0].time + repeatLength
                guard end > start else { return nil }
                // The last cycle's cells begin in the repeat before and are
                // drawn from there, so nothing is cut at the tile's edge (Task
                // 033's line down the card).
                if start > repeatLength - 1 + 1e-4 {
                    start -= repeatLength
                    end -= repeatLength
                }
                cells.append(Cell(start: start, end: end, slot: slot, thread: arrival.thread))
            }
        }
        func row(_ cell: Cell) -> Int { Int((cell.start - 1e-4).rounded(.up)) }
        cells.sort { row($0) != row($1) ? row($0) < row($1) : $0.thread < $1.thread }

        var segments = [BraidStrandSegment]()
        for cell in cells {
            guard let colour = colours[cell.thread] else { return nil }
            let middle = (Float(cell.slot) + 0.5) * columnWidth
            segments.append(BraidStrandSegment(
                threadPosition: cell.thread,
                colorID: colour,
                layer: .over,
                centerlineStart: SIMD2(middle, cell.start / repeatLength),
                centerlineEnd: SIMD2(middle, cell.end / repeatLength),
                startHalfWidth: SIMD2(columnWidth / 2, 0),
                endHalfWidth: SIMD2(columnWidth / 2, 0)
            ))
        }

        return RoundTube4SurfacePattern(
            surface: BraidStrandSurface(segments: segments),
            rowCount: rows,
            // `rows` cycles of `pitchOverDiameter` diameters, over pi diameters.
            aspectRatio: Float(rows) * pitchOverDiameter / .pi,
            columnsCarried: columnsCarried,
            arrivalPhaseBySlot: arrivalPhases,
            drawnPhaseByColumn: arrivalPhases.map(drawnPhase(ofArrival:)),
            leanBySegment: Array(repeating: stitchLean, count: segments.count)
        )
    }

    /// Where a place's cells begin, as a share of the cycle: the half of the
    /// cycle its thread arrives in — 0.5 for the first dan, 1 for the second.
    static func drawnPhase(ofArrival arrival: Float) -> Float {
        arrival <= 0.5 + 1e-4 ? 0.5 : 1
    }

    /// The way round the ring from one slot to another, signed, the shorter
    /// way. **A half turn has no shorter way and comes back positive** — which
    /// is every carry of this braid, so the sign says nothing about the stitch.
    static func shortestWayRound(from: Int, to: Int, around count: Int) -> Int {
        let forward = ((to - from) % count + count) % count
        return forward * 2 > count ? forward - count : forward
    }
}

/// One thread's run where it stands at a place on the braid.
struct RoundTube4StandingRun: Equatable, Sendable {
    let repeatOffset: Int
    /// The run's cell, as an index into the pattern's `surface.segments`.
    let segment: Int
    /// How far it stands there, 0...1 of the ridge.
    let height: Float
}

extension RoundTube4SurfacePattern {
    /// Every run that reaches a place, highest first: `turns` round the braid
    /// and `along` in repeats. **The rule for what shows**: the first of these,
    /// and the cell beneath where there is none.
    func runsStanding(
        atTurns turns: Float,
        along: Float,
        bundle: RoundTube4Bundle = .standard
    ) -> [RoundTube4StandingRun] {
        var found = [RoundTube4StandingRun]()
        for index in surface.segments.indices {
            for repeatOffset in -1...1 {
                if let height = standing(
                    segment: index, repeatOffset: repeatOffset,
                    atTurns: turns, along: along, bundle: bundle
                ) {
                    found.append(RoundTube4StandingRun(
                        repeatOffset: repeatOffset, segment: index, height: height
                    ))
                }
            }
        }
        return found.sorted { $0.height > $1.height }
    }

    /// How far one run stands at a place, or `nil` where it does not reach.
    func standing(
        segment index: Int,
        repeatOffset: Int,
        atTurns turns: Float,
        along: Float,
        bundle: RoundTube4Bundle = .standard
    ) -> Float? {
        let segment = surface.segments[index]
        let cycles = (along - Float(repeatOffset) - segment.centerlineStart.y) / runCycle(of: segment)
        guard cycles >= 0, cycles <= bundle.lengthInCycles else { return nil }
        let halfWidth = bundle.halfWidthInColumns(atCycles: cycles)
        guard halfWidth > 0 else { return nil }
        let columns = Float(RoundTube4SurfacePatternGenerator.requiredThreadCount)
        let centre = segment.centerlineStart.x * columns
            + bundle.leanInColumns(atCycles: cycles, direction: leanBySegment[index])
        var offset = (turns * columns - centre).truncatingRemainder(dividingBy: columns)
        if offset > columns / 2 { offset -= columns }
        if offset < -columns / 2 { offset += columns }
        let across = offset / halfWidth
        guard abs(across) <= 1 else { return nil }
        return bundle.standingFraction(atCycles: cycles, across: across)
    }

    /// The cell lying beneath a place: the thread standing at that place in the
    /// occupancy history.
    func cellBeneath(atTurns turns: Float, along: Float) -> (repeatOffset: Int, segment: Int)? {
        let columns = Float(RoundTube4SurfacePatternGenerator.requiredThreadCount)
        var wrapped = turns.truncatingRemainder(dividingBy: 1)
        if wrapped < 0 { wrapped += 1 }
        let lane = min(Int(wrapped * columns), Int(columns) - 1)
        for (index, segment) in surface.segments.enumerated()
        where Int((segment.centerlineStart.x * columns).rounded(.down)) == lane {
            for repeatOffset in -1...1 {
                let start = segment.centerlineStart.y + Float(repeatOffset)
                let end = segment.centerlineEnd.y + Float(repeatOffset)
                if along >= start, along < end { return (repeatOffset, index) }
            }
        }
        return nil
    }
}
