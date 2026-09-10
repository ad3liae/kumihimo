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
/// - **How far a cell leans**, from the move table: a thread ends the cycle at
///   another place, and the cell carries it there. **Read off the courses**, so an
///   S table leans one way and its mirror the other without either being told to.
/// - **Which thread is in a cell**, from the occupancy history, which is the
///   settled answer for what shows on a face (`docs/architecture.md`, 組み台の力学).
///
/// **Nothing here decides what passes over what, because on this braid nothing
/// crosses.** Every cell leans by the same amount, so the cells of one cycle lie
/// side by side and the cells of the next carry on where they left off: the
/// surface is a set of parallel helices and there is no crossing for an order to
/// settle. That is a finding, not an omission — see the note on
/// `columnsCarriedPerCycle`.
struct RoundTube8SurfacePattern: Equatable, Sendable {
    /// The cells, as strand segments in unwrapped surface coordinates: `x` runs
    /// round the braid in turns, `y` runs along it in cycles. `x` is allowed past
    /// 0 and 1 — the surface is a cylinder and wraps.
    let surface: BraidStrandSurface
    /// Cycles to one repeat: how many rows before the whole thing comes round
    /// again. **Worked out by braiding**, not counted here.
    let rowCount: Int
    /// One repeat along the braid divided by one turn around it, so that wrapping
    /// the drawing onto a braid of any radius keeps the cells the shape they were
    /// worked out to be.
    let aspectRatio: Float
    /// How many places round the braid a cell carries its thread, signed: negative
    /// runs against the ring. Kept so a drawing can say what it leaned on.
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
    /// **Not a number chosen here: it is read off the courses**, place by place,
    /// and this only says what to do when the courses disagree with themselves.
    /// It is stated as a constant so that the one thing the drawing's slant rests
    /// on has somewhere to be named.
    ///
    /// **The lean this produces does not match the photograph**, and Task 031 said
    /// to report that rather than to close it: three places is 1.18 diameters
    /// round for 0.40 along, which lays the ridges at about 19 degrees to the way
    /// across the braid, where the photographs measure 54 to 61. What does match
    /// is the drift of the *colour bands*, which is one place a cycle rather than
    /// three, because these colourings repeat every four places round the stand
    /// and three places on is one place back in four. **Whether the ridge a
    /// photograph shows is the thread or the colour is the author's to settle**;
    /// changing it is changing this one reading of the courses.
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

        // How far a cell leans: the same for every cell, read off the courses.
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
                // The cell spans one column at the row it starts on and the same
                // column carried round at the row it ends on, so the cells of one
                // row tile the ring and each row joins the next thread for thread.
                let start = Float(slot) * columnWidth
                let end = Float(slot + columnsCarried) * columnWidth
                segments.append(BraidStrandSegment(
                    threadPosition: course.threadPosition,
                    colorID: colour,
                    // **Nothing crosses**, so there is no side of a crossing to
                    // take. Every cell says the same thing rather than pretending
                    // to an order the surface does not have.
                    layer: .over,
                    centerlineStart: SIMD2(start + columnWidth / 2, Float(row) * rowHeight),
                    centerlineEnd: SIMD2(end + columnWidth / 2, Float(row + 1) * rowHeight),
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
