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
/// **The columns are half a pitch apart because the table says so** (Task 053).
/// The disk book braids a cycle as two dan (段), each moving four threads, one
/// from each pair; so every place takes its new thread in one half of the cycle
/// or the other, and neighbouring places in opposite halves. **A dan is drawn as
/// one layer**: a place's cells begin half a cycle or a whole cycle into the row
/// (`drawnPhase(ofArrival:)`), which is the brickwork the author asked for in
/// Task 048 — now read off the table instead of laid down by a parity rule.
///
/// **Task 048 drew the finished braid turning a column a cycle and chose the
/// stagger's parity by hand.** Both were for book A p.54's table, under which a
/// place held the same colour for two cycles running (the author,
/// 2026-09-20). The disk book's table puts a different colour at a place every
/// cycle by itself, and its places keep their halves of the cycle, so both are
/// gone: a column is a place on the stand, for ever.
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
    /// How many places round the braid the first table's cycle carried the
    /// thread each place takes, signed, by slot: negative runs against the ring.
    ///
    /// **This is not the cell's shape.** The carry is buried and does not show; it
    /// is kept because it is what decides which thread is at which place next
    /// cycle, and so what the colour does.
    ///
    /// **By slot since Task 009**: 江戸八つ組 carries its even places two on
    /// and its odd places two back. Until then the carry was one number and a
    /// table whose threads went different ways was refused — a leftover from
    /// before Task 053, when a run leaned the way it was carried.
    let columnsCarriedBySlot: [Int]

    /// When each place takes its new thread in the braiding, as a share of the
    /// cycle, by slot: **the braiding's own record**, one thread an instant.
    let arrivalPhaseBySlot: [Float]
    /// Where each column's cells begin, as a share of the cycle: the half of
    /// the cycle its place takes its thread in, 0.5 or 1 (`drawnPhase
    /// (ofArrival:)`). **Half a pitch apart from one column to the next** (the
    /// author's condition, Task 048), from the table (Task 053). A column is a
    /// place on the stand.
    let drawnPhaseByColumn: [Float]
    /// Which way each cell's run leans, by segment, `+1` or `-1`: **the
    /// stitch's own direction, the same for every cell of every eight-thread
    /// braid** (`RoundTube8SurfacePatternGenerator.stitchLean`, the author,
    /// 2026-09-22). Kept per segment so a drawing reads it where it reads the
    /// cell.
    let leanBySegment: [Float]

    /// The carry as one number, **when every place is carried the same way** —
    /// yatsu-kongo's spiral — and `nil` when not (江戸八つ組).
    var columnsCarried: Int? {
        guard let first = columnsCarriedBySlot.first,
              columnsCarriedBySlot.allSatisfy({ $0 == first }) else { return nil }
        return first
    }

    /// One cycle along the braid, in repeats.
    var cycleInRepeats: Float { 1 / Float(rowCount) }

    /// **What a run's length in cycles is measured against: its own cell**, the
    /// time its thread stands at its place. A cycle, for a braid of one table;
    /// where a braid turns its spiral round, a cell of half a cycle draws a run
    /// half as long and one of a cycle and a half a run half as long again
    /// (Task 053) — the thread shows for as long as it stands there. Measured
    /// against a whole cycle instead, the long cells' runs ran out before the
    /// next thread came and the floor showed at every turn.
    func runCycle(of segment: BraidStrandSegment) -> Float {
        segment.centerlineEnd.y - segment.centerlineStart.y
    }
}

/// **What a thread's visible run looks like on the eight-thread tube: a bundle
/// with a blunt head that lies on top, and a tail that keeps its width and goes
/// on under the runs that come after it** (Task 045, reshaped by Task 051).
///
/// **A drawing approximation calibrated against a photograph, not a derivation.**
/// The cell a thread holds — one column wide, from its arrival to the next
/// thread's arrival at the same place — is still what the occupancy history
/// gives, and it is still the pattern's `surface`: which thread is at which place
/// and when does not move. What this adds is how that thread *shows*:
///
/// - **it leans.** Its centreline moves round the braid as it goes along it,
///   **the same way for S, Z and S&Z** (`RoundTube8SurfacePatternGenerator
///   .stitchLean`): the stitch comes from how the braid is built up, and only
///   the colour's spiral turns (the author, 2026-09-22). Until then it leaned
///   the way the carry goes, and Z's stitches were drawn as S's mirror;
/// - **its head is blunt**: full width a short rounding after the arrival. The
///   head is where the thread was laid last, so it lies on top of what was laid
///   before it (`docs/architecture.md`, 組み台の力学: 後に置いた糸が上), and
///   its own outline is what shows there;
/// - **its tail keeps its width until it is covered.** From the middle of the
///   run on, the centreline bends further the way it leans, into the next lane,
///   where the run laid half a cycle after it is at its belly; the tail goes on
///   under that run's side and under the next thread's head at its own place,
///   and only narrows once it is under them. **The line where it stops showing
///   is the covering run's own side**, not the tail's outline (Task 051: 幅の
///   ある端が隣の下へ続く).
///
/// Until Task 051 a run was a lens — pointed at both ends, widest across a belly
/// — under a height that closed to nothing at both ends, and every run read as
/// a closed oval, one after another (the author, 2026-09-21: 「楕円の丸いもの
/// が何個も繋がってるだけに見える」).
///
/// **What shows at a place is the run standing highest there** — nothing else
/// decides it (`RoundTube8SurfacePattern.runsStanding`). The line where two runs
/// meet is a drawing approximation, not a settled order of the real braid. **The
/// solid and the card both read this one rule.**
///
/// **Nothing is decided by colour.** Every run of every thread has the same
/// shape, and which one shows is decided by where they stand, by run and thread,
/// never by what colour they are. The bend is the same for every run; it does
/// not look for a neighbour, let alone one of the same colour.
///
/// **The figures, each with a unit, are set by eye against book A p.8's zoom.**
/// The height is still **a circular arc, even about its middle** (the author on
/// Task 049: 「偏りのある膨らみではない。円弧というか半円状で良い」), with a
/// half-ellipse across the run; since Task 051 it is set over its own span and
/// no longer over the run's whole length, so how long a run goes on under the
/// others no longer moves its crest.
struct RoundTube8Bundle: Equatable, Sendable {
    /// How far the run's centreline moves round the braid over one cycle along
    /// it, **in columns per cycle**. Unsigned; the table gives the sign.
    let leanColumnsPerCycle: Float
    /// How far the run goes on past the next thread's arrival, **in cycles**:
    /// the tail under the runs laid after it.
    let tuckedCycles: Float
    /// How far past its arrival the head is rounded to its full width, **in
    /// cycles**: short, so the head is blunt.
    let headRoundingCycles: Float
    /// Over how much of the run the height's arc stands, from the arrival, **in
    /// cycles**. Past it the run lies on the valley floor.
    let arcSpanCycles: Float
    /// How far the tail's centreline bends round the braid, beyond the lean, by
    /// the run's end, **in columns**, the way the run leans.
    let tailBendColumns: Float
    /// Where the bend begins, **in cycles past the arrival**.
    let tailBendFromCycles: Float
    /// Where the tail begins to narrow, **in cycles past the arrival**: the next
    /// thread's arrival, so the tail is as wide as the run where it goes under.
    let tailNarrowsFromCycles: Float
    /// Half the run's width, **in columns**.
    let widestHalfWidthInColumns: Float

    /// **Set against the photograph by eye** (Task 051), keeping Task 049's lean
    /// and width. The arc's span and the tail were set so that a run's head
    /// shows blunt and its tail goes under the next lane's run with its width;
    /// on the real mesh the floor shows at none of 16,384 places over a repeat,
    /// S and Z (`RoundTube8CardAgreesWithSolidTests.theFloorHardlyShows`).
    static let standard = RoundTube8Bundle(
        leanColumnsPerCycle: 0.2,
        tuckedCycles: 0.55,
        headRoundingCycles: 0.12,
        arcSpanCycles: 1.2,
        tailBendColumns: 0.55,
        tailBendFromCycles: 0.5,
        tailNarrowsFromCycles: 1,
        widestHalfWidthInColumns: 0.6
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
    /// of the arc. **Not a figure set by eye** — it follows from the form.
    var crestAtCycles: Float { arcSpanCycles / 2 }

    /// How tall the run stands at `cycles` past its arrival, 0...1 of the ridge:
    /// **a circular arc over `arcSpanCycles`** — zero at the arrival and at the
    /// end of the span, one in the middle, even about it (the author's ruling,
    /// Task 049's second rework). Past the span the run lies on the floor, under
    /// the runs laid after it.
    ///
    /// Two shapes were tried before the arc and both were wrong: the width's
    /// plateau at one height, which read as flat tiles, and a hump with its
    /// crest before the middle, which read as a lopsided swelling. **The run is
    /// even end to end in height**; what makes its ends differ is the width and
    /// where the other runs cover it.
    ///
    /// Across the run it is a half-ellipse as well (`standingFraction`), so a
    /// run domes both ways.
    func heightFraction(atCycles cycles: Float) -> Float {
        guard cycles >= 0, cycles <= lengthInCycles, arcSpanCycles > 0 else { return 0 }
        let fromTheMiddle = 2 * cycles / arcSpanCycles - 1
        return max(0, 1 - fromTheMiddle * fromTheMiddle).squareRoot()
    }

    /// How far round the braid the centreline has moved from the middle of the
    /// thread's own cell, in columns, signed by `direction`: the lean, and past
    /// `tailBendFromCycles` the tail's bend, growing as the square of the way
    /// to the end so it leaves the lean without a kink.
    func leanInColumns(atCycles cycles: Float, direction: Float) -> Float {
        let reach = lengthInCycles - tailBendFromCycles
        let bent = reach > 0 ? max(0, cycles - tailBendFromCycles) / reach : 0
        return direction * (leanColumnsPerCycle * (cycles - 0.5) + tailBendColumns * bent * bent)
    }

    /// How far the run stands at `cycles` past its arrival and `across` its
    /// width (-1...1), as a fraction of the ridge: its height there across a
    /// semi-elliptical section (the crest's own, `RoundTube8SurfaceMesh
    /// .crestProfile`). 0 at its edges, which lie on the valley floor.
    func standingFraction(atCycles cycles: Float, across: Float) -> Float {
        let clamped = min(max(across, -1), 1)
        return heightFraction(atCycles: cycles) * max(0, 1 - clamped * clamped).squareRoot()
    }
}

enum RoundTube8SurfacePatternGenerator {
    static let requiredThreadCount = 8

    /// **Which way every run leans round the braid, for S, Z and S&Z alike**
    /// (the author, 2026-09-22): the stitch comes from the way the braid is built
    /// up, which does not change when the spiral turns the other way. The sign is
    /// S's, whose stitch the author accepted in Task 051; Z and 返し組 now draw the
    /// same stitch, and only their colour turns the other way.
    static let stitchLean: Float = -1

    /// One cycle's growth as a fraction of the braid's own diameter.
    ///
    /// **Read from the colour's period, once the drawing's cycle is fixed**
    /// (Task 048's rework). Task 031 measured the colour coming round again
    /// every 1.614 braid widths on S (book A p.8-9, the zoom;
    /// `Scripts/task031/measure_photographs.py`), and divided it by four, on the
    /// reading that the colouring — which repeats every four places round the
    /// stand — takes four cycles to come back. **With the finished braid's
    /// places turning one column a cycle** (Task 048), this colouring's
    /// two colours alternate cell by cell along a column and come back every
    /// **two** drawn cycles, so the same measurement gives 1.614 / 2.
    ///
    /// **The disk book's table (Task 053) gives the same two cycles by itself**:
    /// it carries a thread two places a cycle, and these colourings repeat every
    /// four, so a place changes colour every cycle and has it back every second.
    /// The figure stands, on the same measurement, without the turn.
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
    /// **Two since Task 053**: the disk book carries every thread two places a
    /// cycle, back for S and on for Z (`BookDiskKongo`). Book A p.54's reading,
    /// shipped until then, carried three.
    static let columnsCarriedPerCycle = 2

    /// The pattern for a braid, from its table and its colouring.
    static func generate(
        stand: BraidStand,
        method: BraidMethod,
        crossSection: BraidCrossSection,
        assignments: [ThreadAssignment]
    ) -> RoundTube8SurfacePattern? {
        generate(stand: stand, rounds: [method], crossSection: crossSection, assignments: assignments)
    }

    /// The pattern for a braid worked with one table or several in turn
    /// (Task 053), from its tables and its colouring.
    ///
    /// **A cell is a thread standing at a place, from its arrival to the next
    /// thread's arrival there** — whatever table brought either. The time is
    /// counted in dan (段): **a dan is one layer, half a cycle**, and a table's
    /// braiding moves make its dan four at a time — one thread from each pair of
    /// the eight (the disk book: 1段 = four figures). A cycle is two dan, for S,
    /// Z and 返し組 alike (its hand-overs are part of the dan before them,
    /// `BookDiskKongo.rounds`). A place's thread arrives at the end of its dan.
    ///
    /// Every place receives one thread a cycle, in one dan or the other, so its
    /// cells are a cycle long and half a pitch from the next place's
    /// (`drawnPhaseByColumn`). A table that gave a place two threads running, or
    /// none, would draw cells of other lengths — **the table's, not a shape
    /// drawn in** — and the shipped tables do not.
    ///
    /// **Every cell leans the stitch's way, `stitchLean`**, whichever table
    /// carried its thread (the author, 2026-09-22): the spiral turns, the stitch
    /// does not.
    ///
    /// `nil` when the braid is not a tube of eight, when a table's braiding moves
    /// are not a whole number of dan, when a place receives twice in one dan, when
    /// a cycle of two dan does not put every other place in each (the half
    /// pitch), when the first table does not give every place a thread, or
    /// when a repeat is not a whole number of cycles long — then "where its cell
    /// begins" has no single answer, and that is worth stopping over rather than
    /// drawing something arbitrary.
    ///
    /// **Threads carried different ways are drawn** (Task 009): until then a
    /// table was refused unless it carried every thread the same way, which
    /// kept only the carry's record to one number — the cell's shape has not
    /// read the carry since Task 053.
    static func generate(
        stand: BraidStand,
        rounds: [BraidMethod],
        crossSection: BraidCrossSection,
        assignments: [ThreadAssignment]
    ) -> RoundTube8SurfacePattern? {
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

        struct Arrival { let time: Float; let thread: Int; let lean: Float }
        let perDan = count / 2
        var arrivalsBySlot = [[Arrival]](repeating: [], count: count)
        var time: Float = 0
        // The first table's own record: how far it carries, and when in its
        // cycle each place takes its thread.
        var firstCarries = [Int?](repeating: nil, count: count)
        var firstPhases = [Float?](repeating: nil, count: count)

        for (index, cycle) in cycles.enumerated() {
            let round = rounds[index % rounds.count]
            // **The braiding moves, the closing left out of the count** (Task
            // 007G's "the denominator is 6, not 7"): the closing lays nothing.
            // A thread the closing moves still arrives, in the table's last dan.
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
                    time: time + Float(dan + 1) * 0.5,
                    thread: carried.thread,
                    lean: stitchLean
                ))
                if index == 0, order < braiding.count {
                    firstCarries[to] = step
                    firstPhases[to] = Float(carried.instant) / Float(round.steps.count)
                }
            }
            // **Half a pitch** (the author's condition, Task 048): in a cycle of
            // two dan, every other place takes its thread in each.
            if dans == 2 {
                for slot in 0..<count where slotsByDan[0].contains(slot)
                    == slotsByDan[0].contains((slot + 1) % count) {
                    return nil
                }
            }
            time += Float(dans) * 0.5
        }

        // One repeat, in cycles: a whole number of them.
        guard time > 0, abs(time - time.rounded()) < 1e-4 else { return nil }
        let rows = Int(time.rounded())
        let repeatLength = Float(rows)
        let columnsCarried = firstCarries.compactMap { $0 }
        guard columnsCarried.count == count else { return nil }
        let arrivalPhases = firstPhases.compactMap { $0 }
        guard arrivalPhases.count == count else { return nil }

        let columnWidth = Float(1) / Float(count)
        struct Cell { let start: Float; let end: Float; let slot: Int; let thread: Int; let lean: Float }
        var cells = [Cell]()
        for slot in 0..<count {
            let arrivals = arrivalsBySlot[slot].sorted { $0.time < $1.time }
            guard !arrivals.isEmpty else { return nil }
            for (index, arrival) in arrivals.enumerated() {
                var start = arrival.time
                var end = index + 1 < arrivals.count
                    ? arrivals[index + 1].time : arrivals[0].time + repeatLength
                guard end > start else { return nil }
                // **The last cycle's cells begin in the repeat before this one,
                // and are drawn from there** — nothing is cut at the tile's edge,
                // and a lane's cells run end to end over exactly one repeat. What
                // hangs past an end is the frame's to crop, or the next tile's to
                // meet. Cutting it at the edge instead put a cell boundary in
                // every lane at the same place, once a repeat: a line down the
                // card (Task 033), the same mistake Task 030 found in the flat
                // braid.
                if start > repeatLength - 1 + 1e-4 {
                    start -= repeatLength
                    end -= repeatLength
                }
                cells.append(Cell(start: start, end: end, slot: slot, thread: arrival.thread, lean: arrival.lean))
            }
        }
        // Row by row — the cycle whose start a cell stands across — and thread
        // by thread within a row.
        func row(_ cell: Cell) -> Int { Int((cell.start - 1e-4).rounded(.up)) }
        cells.sort { row($0) != row($1) ? row($0) < row($1) : $0.thread < $1.thread }

        var segments = [BraidStrandSegment]()
        for cell in cells {
            guard let colour = colours[cell.thread] else { return nil }
            // **The thread stands here from its arrival to the next**, so the
            // cell runs along the braid at this one place: one column wide,
            // square to the braid.
            let middle = (Float(cell.slot) + 0.5) * columnWidth
            segments.append(BraidStrandSegment(
                threadPosition: cell.thread,
                colorID: colour,
                // **Nothing crosses**, so there is no side of a crossing to
                // take. Every cell says the same thing rather than pretending
                // to an order the surface does not have.
                layer: .over,
                centerlineStart: SIMD2(middle, cell.start / repeatLength),
                centerlineEnd: SIMD2(middle, cell.end / repeatLength),
                startHalfWidth: SIMD2(columnWidth / 2, 0),
                endHalfWidth: SIMD2(columnWidth / 2, 0)
            ))
        }

        return RoundTube8SurfacePattern(
            surface: BraidStrandSurface(segments: segments),
            rowCount: rows,
            // One repeat is `rows` cycles of `pitchOverDiameter` diameters each,
            // and one turn is pi diameters.
            aspectRatio: Float(rows) * pitchOverDiameter / .pi,
            columnsCarriedBySlot: columnsCarried,
            arrivalPhaseBySlot: arrivalPhases,
            drawnPhaseByColumn: arrivalPhases.map(drawnPhase(ofArrival:)),
            leanBySegment: cells.map(\.lean)
        )
    }

    /// Where a place's cells begin, as a share of the cycle, from when its
    /// thread arrives: **the half of the cycle it arrives in** — 0.5 for the
    /// first dan, 1 for the second (Task 053). In (0, 1], so a cell still stands
    /// across the boundary of the row it belongs to.
    static func drawnPhase(ofArrival arrival: Float) -> Float {
        arrival <= 0.5 + 1e-4 ? 0.5 : 1
    }

    /// The way round the ring from one slot to another, signed, taking whichever
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
        for index in surface.segments.indices {
            for repeatOffset in -1...1 {
                if let height = standing(
                    segment: index, repeatOffset: repeatOffset,
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
        segment index: Int,
        repeatOffset: Int,
        atTurns turns: Float,
        along: Float,
        bundle: RoundTube8Bundle = .standard
    ) -> Float? {
        let segment = surface.segments[index]
        let cycles = (along - Float(repeatOffset) - segment.centerlineStart.y) / runCycle(of: segment)
        guard cycles >= 0, cycles <= bundle.lengthInCycles else { return nil }
        let halfWidth = bundle.halfWidthInColumns(atCycles: cycles)
        guard halfWidth > 0 else { return nil }
        let columns = Float(RoundTube8SurfacePatternGenerator.requiredThreadCount)
        let centre = segment.centerlineStart.x * columns
            + bundle.leanInColumns(atCycles: cycles, direction: leanBySegment[index])
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
