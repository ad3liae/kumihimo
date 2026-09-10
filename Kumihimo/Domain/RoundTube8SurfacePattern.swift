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
/// **What slants on the finished braid is the colour, not the geometry.** A place
/// holds a different thread every cycle, and with these colourings the pattern
/// walks one place round the braid each cycle, which is the diagonal a photograph
/// shows. Nothing here draws that: it falls out of the occupancy history and the
/// pitch.
///
/// **Nothing here decides what passes over what, because nothing crosses.** Cells
/// stand side by side round a ring and end to end along the braid; there is no
/// crossing for an order to settle.
struct RoundTube8SurfacePattern: Equatable, Sendable {
    /// The cells, as strand segments in unwrapped surface coordinates: `x` runs
    /// round the braid in turns, `y` runs along it in cycles. `x` is allowed past
    /// 0 and 1 — the surface is a cylinder — though a cell stands still and so
    /// never reaches past its own column.
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
}

enum RoundTube8SurfacePatternGenerator {
    static let requiredThreadCount = 8

    /// One cycle's growth as a fraction of the braid's own diameter.
    ///
    /// **Measured, on book A p.8-9** — `Scripts/task031/measure_photographs.py`,
    /// and the procedure is written out in Task 031's stage 1. The braid is cut
    /// from its background, a strip down its middle is sheared until the colour
    /// bands lie flat, and the first peak of that strip's autocorrelation is one
    /// turn of the colour; the colouring turns once in four cycles.
    ///
    /// **The three braids photographed do not agree**, and the value shipped is
    /// the S braid's, which is the cleanest signal of the three and the one this
    /// recipe draws. See the measurement's `unsettled` note on
    /// `RoundTube8SurfaceMesh.shape`.
    static let pitchOverDiameter: Float = 0.403

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
    /// of the stand, or when the courses do not all carry their threads the same
    /// distance — the last of which would mean the cells cannot all lean alike and
    /// is worth stopping over rather than drawing something arbitrary.
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

        let columnWidth = Float(1) / Float(requiredThreadCount)
        let rowHeight = Float(1) / Float(rows)

        var segments = [BraidStrandSegment]()
        for row in 0..<rows {
            for course in derivation.courses {
                guard let colour = colours[course.threadPosition] else { return nil }
                let slot = course.slots[row]
                // **The thread stands here for this cycle**, so the cell runs
                // along the braid at this one place: one column wide, one cycle
                // long, and square to the braid. The cells of a row tile the ring
                // and the next row stands on top of them.
                let middle = (Float(slot) + 0.5) * columnWidth
                segments.append(BraidStrandSegment(
                    threadPosition: course.threadPosition,
                    colorID: colour,
                    // **Nothing crosses**, so there is no side of a crossing to
                    // take. Every cell says the same thing rather than pretending
                    // to an order the surface does not have.
                    layer: .over,
                    centerlineStart: SIMD2(middle, Float(row) * rowHeight),
                    centerlineEnd: SIMD2(middle, Float(row + 1) * rowHeight),
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
            columnsCarried: columnsCarried
        )
    }

    /// The way round the ring from one slot to another, signed, taking whichever
    /// way is shorter. A half turn has no shorter way and comes back positive.
    static func shortestWayRound(from: Int, to: Int, around count: Int) -> Int {
        let forward = ((to - from) % count + count) % count
        return forward * 2 > count ? forward - count : forward
    }
}
