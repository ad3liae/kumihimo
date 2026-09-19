import Foundation
import simd

/// The surface of a tube of eight threads, **worked out rather than transcribed.**
///
/// The sixteen-thread tube's drawing keeps the shape of every cell copied from
/// book A's sixty-four-cell figure and derives only which thread is in it. **There
/// is no such figure for the eight-bobbin braids** (`docs/tasks/031-round-tube-8-drawer.md`),
/// so here the cells' shape comes from rules and nothing is copied:
///
/// - **How many columns, and where they stand**, from the cross-section: eight
///   places round the ring, each an eighth of the turn. The braid does not fold,
///   so it is a tube and the ring is all there is to say.
/// - **How long a cell is**, from the measured pitch: one cycle's growth.
/// - **Which thread is in a cell**, from the occupancy history, which is the
///   settled answer for what shows on a face (`docs/architecture.md`, 組み台の力学).
///
/// **A cell is a thread standing still, not a thread being carried** (the author,
/// 2026-09-10). The same premise that says the occupancy history is the face says
/// what a cell looks like: a thread held at a place by its own weight runs *along*
/// the braid there, from the height it arrived at to the height it leaves — and
/// the carry that takes it three places on is pressed into the bundle and buried,
/// so it never shows. **So a cell is one column wide and one cycle long, and it
/// does not lean.** It was drawn stretched across the three places of the carry
/// until this was put right, which laid the ridges some thirty-five degrees away
/// from where the photographs have them.
///
/// **A cell begins where its thread arrives** (the author, 2026-09-11). The
/// premise says a thread standing at a place runs from the height it arrived at;
/// the threads of a cycle arrive a printed pair at a time, at different places,
/// so the cells of one row do not start level. A cell runs from its own thread's
/// arrival to the next one's at the same place — one cycle — and the rows stand
/// staggered, like brickwork. **This is the premise used, not a change to it**:
/// the arrival is what `BraidDerivation.arrivalInstants(atSlot:)` has always
/// counted, and the drawing had been leaving it out.
///
/// **Since Task 048 the finished braid is drawn turning as it is made.** A cell
/// is still the thread standing at a place in a cycle, but the column of the
/// finished braid it is drawn in turns one column a cycle
/// (`RoundTube8SurfacePatternGenerator.drawnColumn`), and the columns are
/// staggered half a pitch from their neighbours
/// (`drawnPhase(ofColumn:wholeCycleOnEvenColumns:)`) — the author's condition
/// for a clean spiral. Holding a place at one angle for ever drew each colour
/// two cells at a time down a column, which is not what the braid does (the
/// author, 2026-09-20). The arrivals are still recorded
/// (`arrivalPhaseBySlot`), and no cell changes its thread.
///
/// **It rests only on the order of the printed steps**, never on which thread of
/// a pair goes first: a printed step is one instant (`BraidDiskNotation
/// .StepReading`), so the two threads of a pair arrive together.
///
/// **The colour diagonal is the cells', not a slant drawn in.** A place holds a
/// different thread every cycle, and with these colourings the pattern walks one
/// place round the braid each cycle, which is the diagonal a photograph shows. It
/// falls out of the occupancy history and the pitch. **The cells themselves do
/// not lean**; how a thread *shows* on its cell — a run that leans and goes on
/// beneath the next thread — is `RoundTube8Bundle`, a drawing approximation laid
/// over them (Task 045), and it moves no cell.
///
/// **Nothing here decides what passes over what, because nothing crosses.** Cells
/// stand side by side round a ring and end to end along the braid; there is no
/// crossing for an order to settle.
struct RoundTube8SurfacePattern: Equatable, Sendable {
    /// The cells, as strand segments in unwrapped surface coordinates: `x` runs
    /// round the braid in turns, `y` runs along it in cycles. `x` is allowed past
    /// 0 and 1 — the surface is a cylinder — though a cell stands still and so
    /// never reaches past its own column. `y` goes below 0 for the first row's
    /// cells, which begin in the repeat before.
    let surface: BraidStrandSurface
    /// Cycles to one repeat: how many rows before the whole thing comes round
    /// again. **Worked out by braiding**, not counted here.
    let rowCount: Int
    /// One repeat along the braid divided by one turn around it, so that wrapping
    /// the drawing onto a braid of any radius keeps the cells the shape they were
    /// worked out to be.
    let aspectRatio: Float
    /// How many places round the braid one cycle carries a thread, signed:
    /// negative runs against the ring.
    ///
    /// **This is not the cell's shape.** The carry is buried and does not show; it
    /// is kept because it is what decides which thread is at which place next
    /// cycle, and so what the colour does.
    let columnsCarried: Int

    /// When each place takes its new thread in the braiding, as a share of the
    /// cycle, by slot: **the braiding's own record**, kept as it was worked out
    /// (Task 032). Since Task 048 it is not where the cell is drawn.
    let arrivalPhaseBySlot: [Float]
    /// Where each **drawn column's** cells begin, as a share of the cycle:
    /// **half a pitch apart from one column to the next** (the author, Task
    /// 048). In (0, 1]. Indexed by the finished braid's column, which a place on
    /// the stand moves through as the braid turns
    /// (`RoundTube8SurfacePatternGenerator.drawnColumn`).
    let drawnPhaseByColumn: [Float]

    /// Which way round the braid a thread's visible run leans as it goes along
    /// it, and which way the finished braid turns as it is made: the sign of
    /// the carry, `+1` or `-1`.
    ///
    /// **Only the sign is the table's.** A thread arrives from the place it was
    /// carried from and leaves towards the place it is carried to, so its run
    /// tilts from the one towards the other (Task 033 §4.2, Task 045). How far it
    /// tilts is `RoundTube8Bundle.leanColumnsPerCycle`, a drawing figure.
    var leanDirection: Float { columnsCarried < 0 ? -1 : 1 }
}

/// **What a thread's visible run looks like on the eight-thread tube: a bundle
/// that lies at a slant and sinks under the next one** (Task 045).
///
/// **A drawing approximation calibrated against a photograph, not a derivation.**
/// The cell a thread holds — one column wide, from its arrival to the next
/// thread's arrival at the same place — is still what the occupancy history
/// gives, and it is still the pattern's `surface`: which thread is at which place
/// and when does not move. What this adds is how that thread *shows*:
///
/// - **it leans.** Its centreline moves round the braid as it goes along it, the
///   way the carry goes (`RoundTube8SurfacePattern.leanDirection`) — so S and Z
///   are mirrors because their tables are;
/// - **it is a lens with a belly** (Task 046): pointed where it arrives, widening
///   to a belly that it holds for a while, and narrowing to a point again. The
///   belly is what lies between its neighbours and keeps the floor from showing;
///   the pointed ends are what slide in beside the runs around it;
/// - **it goes on past the next arrival and ends beneath another run**. Because
///   runs lean, a run's tail and the head of the next thread at its place lie
///   side by side for a while; then the later one, grown to its belly, stands
///   higher over the earlier one's tail, which sinks a little sooner than a head
///   rises, and ends there. The later thread is laid on the earlier one and
///   pressed down onto it (`docs/architecture.md`, 組み台の力学); this is how
///   the drawing shows that, not a derivation of it. The end is where the run
///   stops *showing*, not where the thread is cut.
///
/// **What shows at a place is the run standing highest there** — nothing else
/// decides it (`RoundTube8SurfacePattern.runsStanding`). That is not "the later
/// is on top everywhere": where a tail and the next head lie side by side, and
/// on the flanks of a run, the earlier can stand higher and show (Task 045
/// review). The line where two runs meet is a drawing approximation, not a
/// settled order of the real braid. **The solid and the card both read this one
/// rule.**
///
/// **Nothing is decided by colour.** Every run of every thread has the same
/// shape, and which one shows is decided by where they stand, by run and thread,
/// never by what colour they are.
///
/// **The figures, each with a unit, are all set by eye against book A p.8's
/// zoom**, and so is the form: a quarter sine up to the belly and a quarter
/// cosine down from it, the height rising as the square root of that and falling
/// with it. The run's widest half-width is `widestHalfWidthInColumns`: half a
/// column is what the thread count gives (a thread is one column wide, the
/// relation `crestHeightRatio` rests on); **a run is allowed to show wider than
/// the column its thread holds**, keeping the thread it belongs to.
struct RoundTube8Bundle: Equatable, Sendable {
    /// How far the run's centreline moves round the braid over one cycle along
    /// it, **in columns per cycle**. Unsigned; the table gives the sign.
    let leanColumnsPerCycle: Float
    /// How far the run goes on past the next thread's arrival, **in cycles**.
    let tuckedCycles: Float
    /// Where the run's belly begins and ends, **in cycles past its arrival**.
    let bellyStartCycles: Float
    let bellyEndCycles: Float
    /// Half the run's width across its belly, **in columns**.
    let widestHalfWidthInColumns: Float

    /// **Set against the photograph with a cycle of `pitchOverDiameter`**, so
    /// the figures moved when the cycle did (Task 048's rework doubled it): a
    /// run is about one cycle long and a little wider than its column, which is
    /// the size of a bean on book A p.8's zoom.
    ///
    /// **Measured again on the finished drawing** (Task 049): a bean on the
    /// photograph shows 0.67 of the braid's width long and 0.30 across, its long
    /// axis within a few degrees of the braid's own. The belly was widened along
    /// the run (0.25 to 0.75 of a cycle) and the tail shortened so that a run
    /// shows for most of a cycle instead of two thirds of one, and the lean was
    /// taken from 0.35 to 0.2 columns a cycle, which is where the photograph's
    /// beans lie.
    static let standard = RoundTube8Bundle(
        leanColumnsPerCycle: 0.2,
        tuckedCycles: 0.35,
        bellyStartCycles: 0.25,
        bellyEndCycles: 0.75,
        widestHalfWidthInColumns: 0.6
    )

    /// From the arrival to the end of the run, in cycles.
    var lengthInCycles: Float { 1 + tuckedCycles }

    /// A thread is one column wide: the half-width the thread count gives.
    static let oneThreadHalfWidthInColumns: Float = 0.5

    /// Half the run's width at `cycles` past its arrival, in columns.
    func halfWidthInColumns(atCycles cycles: Float) -> Float {
        widestHalfWidthInColumns * lens(atCycles: cycles).rising
            * lens(atCycles: cycles).falling
    }

    /// How tall the run stands at `cycles` past its arrival, 0...1 of the ridge:
    /// rising as the square root of the width's rise, so a head stands up
    /// quickly, and falling with the width's fall, so a tail sinks a little
    /// sooner than a head rises.
    func heightFraction(atCycles cycles: Float) -> Float {
        let shape = lens(atCycles: cycles)
        return shape.rising.squareRoot() * shape.falling
    }

    /// How far round the braid the centreline has moved from the middle of the
    /// thread's own cell, in columns, signed by `direction`.
    func leanInColumns(atCycles cycles: Float, direction: Float) -> Float {
        direction * leanColumnsPerCycle * (cycles - 0.5)
    }

    /// How far the run stands at `cycles` past its arrival and `across` its
    /// width (-1...1), as a fraction of the ridge: its height there across a
    /// semi-elliptical section (the crest's own, `RoundTube8SurfaceMesh
    /// .crestProfile`). 0 at its edges, which lie on the valley floor.
    func standingFraction(atCycles cycles: Float, across: Float) -> Float {
        let clamped = min(max(across, -1), 1)
        return heightFraction(atCycles: cycles) * max(0, 1 - clamped * clamped).squareRoot()
    }

    /// The lens: 0 at both ends and 1 across the belly, as a rising part before
    /// the belly and a falling part after it (each 1 elsewhere).
    private func lens(atCycles cycles: Float) -> (rising: Float, falling: Float) {
        guard cycles >= 0, cycles <= lengthInCycles else { return (0, 0) }
        let rising = bellyStartCycles > 0
            ? sin(.pi / 2 * min(cycles / bellyStartCycles, 1)) : 1
        let tail = lengthInCycles - bellyEndCycles
        let falling = tail > 0
            ? cos(.pi / 2 * min(max((cycles - bellyEndCycles) / tail, 0), 1)) : 1
        return (rising, falling)
    }
}

enum RoundTube8SurfacePatternGenerator {
    static let requiredThreadCount = 8

    /// One cycle's growth as a fraction of the braid's own diameter.
    ///
    /// **Read from the colour's period, once the drawing's cycle is fixed**
    /// (Task 048's rework). Task 031 measured the colour coming round again
    /// every 1.614 braid widths on S (book A p.8-9, the zoom;
    /// `Scripts/task031/measure_photographs.py`), and divided it by four, on the
    /// reading that the colouring — which repeats every four places round the
    /// stand — takes four cycles to come back. **With the finished braid's
    /// places turning one column a cycle** (`drawnColumn`), this colouring's
    /// two colours alternate cell by cell along a column and come back every
    /// **two** drawn cycles, so the same measurement gives 1.614 / 2.
    ///
    /// **This is the measurement divided under a different reading, not a new
    /// observation**: nothing was measured again, and the photograph's 1.614 is
    /// unchanged. It replaces 0.403, which drew a braid whose two colours ran
    /// two cells at a time (the author, 2026-09-20: 「2ピッチずつ色が入れ替わって
    /// いるが金剛組ではこのようにはならない」).
    static let pitchOverDiameter: Float = 0.807

    /// How many places round the braid one cycle carries a thread.
    ///
    /// **A fact about the table, not a number chosen to make a picture.** It is
    /// read off the courses place by place, and this states what they should agree
    /// on. **It is not the slant of a cell** — the carry is buried in the bundle
    /// and never shows on the face (`docs/architecture.md`, 組み台の力学), so what
    /// it decides is which thread stands where next cycle, and through that what
    /// the colour does.
    ///
    /// Because these colourings repeat every four places round the stand and three
    /// places on is one place back in four, **the colour walks one place a cycle**,
    /// and that is the diagonal the finished braid shows.
    static let columnsCarriedPerCycle = 3

    /// The pattern for a braid, from its table and its colouring.
    ///
    /// `nil` when the braid is not a tube of eight, when the table is not a cycle
    /// of the stand, when the courses do not all carry their threads the same
    /// distance, or when a place does not receive exactly one thread a cycle —
    /// then "where its cell begins" has no single answer, and that is worth
    /// stopping over rather than drawing something arbitrary.
    static func generate(
        stand: BraidStand,
        method: BraidMethod,
        crossSection: BraidCrossSection,
        assignments: [ThreadAssignment]
    ) -> RoundTube8SurfacePattern? {
        guard
            stand.positionCount == requiredThreadCount,
            assignments.count == requiredThreadCount,
            let derivation = BraidDerivation.derive(
                stand: stand, method: method, crossSection: crossSection
            ),
            derivation.fold == nil,
            crossSection.slotCount == requiredThreadCount
        else { return nil }

        let colours = Dictionary(uniqueKeysWithValues: assignments.map { ($0.position, $0.colorID) })
        guard Set(colours.keys) == Set(stand.positionIDs) else { return nil }

        let rows = derivation.repeatCycleCount
        guard rows > 0 else { return nil }

        // How far one cycle carries a thread: the same for every thread, read off
        // the courses. **Not the cell's shape** -- the carry is buried -- but it is
        // what sends the colour round, so a table that does not agree with itself
        // about it is one this cannot draw.
        var carried: Int?
        for course in derivation.courses {
            for row in 0..<rows {
                let step = shortestWayRound(
                    from: course.slots[row], to: course.slots[row + 1],
                    around: requiredThreadCount
                )
                if let carried, carried != step { return nil }
                carried = step
            }
        }
        guard let columnsCarried = carried, columnsCarried != 0 else { return nil }

        // Where in a cycle each place takes its new thread, as a share of the
        // cycle. **Counted in braiding instants, the closing left out**: the
        // stacking model lays the braid one layer a hand and the closing not at
        // all (`docs/architecture.md`, 積み重ねの模型), and on these braids the
        // closing carries nothing. **Not a new rule**: it is the one recorded for
        // Task 007G, "the denominator is 6, not 7, because the tidying is not
        // counted", applied here. One arrival a place, or there is no one place
        // for a cell to begin.
        let braidingInstants = method.steps.count
        guard braidingInstants > 0 else { return nil }
        var phaseOfSlot = [Int: Float]()
        for slot in 0..<requiredThreadCount {
            let arrivals = derivation.arrivalInstants(atSlot: slot)
            guard arrivals.count == 1, let instant = arrivals.first,
                  (1...braidingInstants).contains(instant) else { return nil }
            phaseOfSlot[slot] = Float(instant) / Float(braidingInstants)
        }

        let arrivalPhases = (0..<requiredThreadCount).compactMap { phaseOfSlot[$0] }
        guard arrivalPhases.count == requiredThreadCount else { return nil }
        // **The finished braid turns under the mirror as it is braided** (book A
        // p.54's note), so a place on the stand is not one column of the finished
        // braid for ever: `drawnColumn` turns it one column a cycle. The
        // half-pitch stagger belongs to the drawn columns, not to the stand's
        // places, and which columns take the whole cycle is
        // `wholeCycleOnEvenColumns`.
        let lean: Int = columnsCarried < 0 ? -1 : 1
        guard let evenIsWhole = wholeCycleOnEvenColumns(
            derivation: derivation, rows: rows, lean: lean
        ) else { return nil }
        let drawnPhases = (0..<requiredThreadCount).map { column in
            drawnPhase(ofColumn: column, wholeCycleOnEvenColumns: evenIsWhole)
        }

        let columnWidth = Float(1) / Float(requiredThreadCount)
        let rowHeight = Float(1) / Float(rows)

        var segments = [BraidStrandSegment]()
        for row in 0..<rows {
            for course in derivation.courses {
                guard let colour = colours[course.threadPosition] else { return nil }
                let slot = course.slots[row]
                let column = drawnColumn(ofSlot: slot, cycle: row, lean: lean)
                // **Drawn in the column the finished braid has turned this
                // place to, half a pitch from the columns beside it** (Task
                // 048's rework), not at the place's own angle and arrival. The
                // cell is still the thread standing here in cycle `row`.
                let phase = drawnPhases[column]
                // **The thread stands here for one cycle**, so the cell runs along
                // the braid at this one place: one column wide, one cycle long,
                // square to the braid. It is the thread that is here at the start
                // of cycle `row`, so it arrived during the cycle before, and it
                // stays until the next thread arrives: from `row - 1 + phase` to
                // `row + phase`.
                let middle = (Float(column) + 0.5) * columnWidth
                let start = Float(row) - 1 + phase
                let end = Float(row) + phase
                // **The first row's cells begin in the repeat before this one, and
                // are drawn from there** — nothing is cut at the tile's edge. The
                // phase is one constant added to a whole lane, so the lane stays
                // exactly one repeat long and its last cell ends where the next
                // repeat's first begins; what hangs past an end is the frame's to
                // crop, or the next tile's to meet. Cutting it at the edge instead
                // put a cell boundary in every lane at the same place, once a
                // repeat: a line down the card (Task 033), the same mistake Task
                // 030 found in the flat braid.
                segments.append(BraidStrandSegment(
                    threadPosition: course.threadPosition,
                    colorID: colour,
                    // **Nothing crosses**, so there is no side of a crossing to
                    // take. Every cell says the same thing rather than pretending
                    // to an order the surface does not have.
                    layer: .over,
                    centerlineStart: SIMD2(middle, start * rowHeight),
                    centerlineEnd: SIMD2(middle, end * rowHeight),
                    startHalfWidth: SIMD2(columnWidth / 2, 0),
                    endHalfWidth: SIMD2(columnWidth / 2, 0)
                ))
            }
        }

        return RoundTube8SurfacePattern(
            surface: BraidStrandSurface(segments: segments),
            rowCount: rows,
            // One repeat is `rows` cycles of `pitchOverDiameter` diameters each,
            // and one turn is pi diameters.
            aspectRatio: Float(rows) * pitchOverDiameter / .pi,
            columnsCarried: columnsCarried,
            arrivalPhaseBySlot: arrivalPhases,
            drawnPhaseByColumn: drawnPhases
        )
    }

    /// **Which column of the finished braid a place on the stand makes, in a
    /// given cycle** (Task 048's rework): `(slot - lean * cycle) mod 8`, so the
    /// braid turns one column a cycle against the lean.
    ///
    /// Book A p.54's note on these braids says the braid **turns under the
    /// mirror as it is made**. The drawing used to hold a place on the stand at
    /// one angle of the finished braid for ever, and that is what drew each
    /// colour two cells at a time down a column (the author, 2026-09-20). **One
    /// column a cycle is the smallest turn that puts a colouring of four places
    /// back to one cell at a time; the note does not give the amount, and this
    /// is a drawing choice, not a rate read off the braiding.**
    ///
    /// Which thread is in which cell does not change: the cell is still the
    /// thread standing at `slot` in cycle `cycle`, and only the column it is
    /// drawn in moves.
    static func drawnColumn(ofSlot slot: Int, cycle: Int, lean: Int) -> Int {
        let count = requiredThreadCount
        return ((slot - lean * cycle) % count + count) % count
    }

    /// Where a drawn column's cells begin, as a share of the cycle: **half a
    /// pitch from the columns either side** (the author, Task 048), a whole
    /// cycle on one parity and a half on the other. In (0, 1], so a cell still
    /// stands across the boundary of the row it belongs to.
    static func drawnPhase(ofColumn column: Int, wholeCycleOnEvenColumns: Bool) -> Float {
        let even = column.isMultiple(of: 2)
        return even == wholeCycleOnEvenColumns ? 1 : 0.5
    }

    /// **Which parity of column takes the whole cycle**, decided from the table
    /// alone — never from the colours.
    ///
    /// Half a pitch a column can be laid down two ways, and the two put the
    /// braid's colour bands on opposite diagonals. The one taken is the one
    /// where **the step half a pitch on, round the braid the way the runs lean,
    /// joins the threads that begin at places 1 and 2, 3 and 4, 5 and 6, 7 and
    /// 8** — the pairs the stand's numbering makes, which a mirror carries onto
    /// each other, so S and Z are chosen alike.
    ///
    /// **Held against the photograph** (book A p.8-9's S, its own colouring):
    /// this way round puts the colour band on the diagonal the photograph has
    /// (measured +38 degrees by Task 031's `colour_angle` against the
    /// photograph's +53; the other way round gives -27). `nil` if neither way
    /// gives those pairs, which would mean this reading does not fit the table.
    static func wholeCycleOnEvenColumns(
        derivation: BraidDerivation, rows: Int, lean: Int
    ) -> Bool? {
        // Where each thread starts, and where it stands in each cycle.
        var startingSlot = [Int: Int]()
        for course in derivation.courses { startingSlot[course.threadPosition] = course.slots[0] }
        for evenIsWhole in [true, false] {
            var joinsItsPairs = true
            for course in derivation.courses {
                guard let mine = startingSlot[course.threadPosition] else { return nil }
                let column = drawnColumn(ofSlot: course.slots[0], cycle: 0, lean: lean)
                let start = drawnPhase(ofColumn: column, wholeCycleOnEvenColumns: evenIsWhole) - 1
                // Half a pitch on, in the column the runs lean towards.
                let nextColumn = ((column + lean) % requiredThreadCount + requiredThreadCount)
                    % requiredThreadCount
                let wanted = start + 0.5
                var found: Int?
                for cycle in 0...rows {
                    for other in derivation.courses where
                        drawnColumn(ofSlot: other.slots[cycle], cycle: cycle, lean: lean) == nextColumn {
                        let begins = Float(cycle) - 1
                            + drawnPhase(ofColumn: nextColumn, wholeCycleOnEvenColumns: evenIsWhole)
                        if abs(begins - wanted) < 1e-4 { found = startingSlot[other.threadPosition] }
                    }
                }
                // The pairs the numbering makes: places 1 and 2, 3 and 4, ...
                if found != mine ^ 1 { joinsItsPairs = false }
            }
            if joinsItsPairs { return evenIsWhole }
        }
        return nil
    }

    /// The way round the ring from one slot to another, signed, taking whichever    /// The way round the ring from one slot to another, signed, taking whichever
    /// way is shorter. A half turn has no shorter way and comes back positive.
    static func shortestWayRound(from: Int, to: Int, around count: Int) -> Int {
        let forward = ((to - from) % count + count) % count
        return forward * 2 > count ? forward - count : forward
    }
}

/// One thread's run where it stands at a place on the braid.
struct RoundTube8StandingRun: Equatable, Sendable {
    /// Which repeat the run belongs to, counted from the one the place is
    /// counted in: a run can reach into the next repeat and the one before.
    let repeatOffset: Int
    /// The run's cell, as an index into the pattern's `surface.segments`.
    let segment: Int
    /// How far it stands there, 0...1 of the ridge.
    let height: Float
}

extension RoundTube8SurfacePattern {
    /// Every run that reaches a place on the braid, highest first: `turns` round
    /// it and `along` in repeats (0...1 is one repeat).
    ///
    /// **The rule for what shows** (Task 045 review): the first of these, and the
    /// cell beneath (`cellBeneath`) where there is none. It is the surface the
    /// solid's mesh samples, run by run, so the card and the solid show the same
    /// thread at the same place. Found by run and thread; colour never enters.
    func runsStanding(
        atTurns turns: Float,
        along: Float,
        bundle: RoundTube8Bundle = .standard
    ) -> [RoundTube8StandingRun] {
        var found = [RoundTube8StandingRun]()
        for (index, segment) in surface.segments.enumerated() {
            for repeatOffset in -1...1 {
                if let height = standing(
                    segment, repeatOffset: repeatOffset,
                    atTurns: turns, along: along, bundle: bundle
                ) {
                    found.append(RoundTube8StandingRun(
                        repeatOffset: repeatOffset, segment: index, height: height
                    ))
                }
            }
        }
        return found.sorted { $0.height > $1.height }
    }

    /// How far one run stands at a place, or `nil` where it does not reach.
    /// `repeatOffset` moves the run that many repeats along.
    func standing(
        _ segment: BraidStrandSegment,
        repeatOffset: Int,
        atTurns turns: Float,
        along: Float,
        bundle: RoundTube8Bundle = .standard
    ) -> Float? {
        let cycle = segment.centerlineEnd.y - segment.centerlineStart.y
        guard cycle > 0 else { return nil }
        let cycles = (along - Float(repeatOffset) - segment.centerlineStart.y) / cycle
        guard cycles >= 0, cycles <= bundle.lengthInCycles else { return nil }
        let halfWidth = bundle.halfWidthInColumns(atCycles: cycles)
        guard halfWidth > 0 else { return nil }
        let columns = Float(RoundTube8SurfacePatternGenerator.requiredThreadCount)
        let centre = segment.centerlineStart.x * columns
            + bundle.leanInColumns(atCycles: cycles, direction: leanDirection)
        // Round the ring: the nearest way to the run's centreline.
        var offset = (turns * columns - centre).truncatingRemainder(dividingBy: columns)
        if offset > columns / 2 { offset -= columns }
        if offset < -columns / 2 { offset += columns }
        let across = offset / halfWidth
        guard abs(across) <= 1 else { return nil }
        return bundle.standingFraction(atCycles: cycles, across: across)
    }

    /// The cell lying beneath a place: the thread standing at that place in the
    /// occupancy history, as `(repeatOffset, segment)`.
    func cellBeneath(atTurns turns: Float, along: Float) -> (repeatOffset: Int, segment: Int)? {
        let columns = Float(RoundTube8SurfacePatternGenerator.requiredThreadCount)
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
