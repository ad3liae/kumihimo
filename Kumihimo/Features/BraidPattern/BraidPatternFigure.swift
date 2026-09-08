import Foundation
import simd

/// The braid drawn flat, from the derivation and nothing else.
///
/// **This is the drawing that answers a braid nobody has made yet.** It shows
/// which thread goes where, what passes under what, and what colour it all comes
/// out — and none of that needs a measurement. How far the braid advances in one
/// worked cycle, how high the ridges stand, how far the section is squashed: none
/// of it is here, so nothing here can be wrong about a braid that has never been
/// photographed.
///
/// One face at a time, with the two edges. A flat braid reads front and back
/// differently, and both are wanted — book A p97's ladder is a statement about
/// the two faces together.
struct BraidFigure: Equatable, Sendable {
    /// One place on the drawing: across the width, and along the braid.
    struct Place: Equatable, Sendable {
        /// The edges are one step outside the columns, as everywhere else.
        let width: Int
        let row: Int
    }

    struct Shape: Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            /// Where the thread shows: one place on the face, or at an edge.
            case appearance
            /// Where the thread runs between two appearances. Beneath the face
            /// when it crosses the braid or turns over to the other side.
            case passage
        }

        let kind: Kind
        let threadPosition: Int
        let colorID: ThreadColorID
        /// A closed quadrilateral for an appearance, an open polyline for a
        /// passage. In column widths across and worked rows along.
        let points: [SIMD2<Double>]
        /// **Whether this part of the thread can be seen.** A passage under the
        /// face is drawn, because the whole point of the figure is to show where
        /// a thread goes when it is not on top.
        let isOnTheFace: Bool
        /// Where an appearance sits. `nil` for a passage, which spans two places.
        let place: Place?
    }

    func appearance(atWidth width: Int, row: Int) -> Shape? {
        shapes.first { $0.kind == .appearance && $0.place == Place(width: width, row: row) }
    }

    /// One row across the face, left edge to right edge.
    func row(_ row: Int) -> [Shape] {
        (-1...columnCount).compactMap { appearance(atWidth: $0, row: row) }
    }

    /// In drawing order: what the face shows, then the hidden runs, then the runs
    /// that stay on the face.
    ///
    /// **The hidden runs are drawn last but thin and broken, over the face rather
    /// than under it.** Hiding them under the face would be truer to the braid and
    /// useless as a drawing: the reader could no longer follow a thread from where
    /// it dives to where it comes back. A technical drawing shows hidden work as a
    /// broken line; so does this.
    let shapes: [Shape]
    let face: BraidFace
    let columnCount: Int
    /// Rows to one repeat.
    let rowCount: Int
    /// Rows actually drawn, a whole number of repeats.
    let rowsDrawn: Int
    /// In the same units as the points: columns plus an edge on each side, by
    /// rows drawn.
    let size: SIMD2<Double>
}

enum BraidFigureBuilder {
    /// `nil` for a braid the derivation has not folded flat — a tube has no face
    /// to draw this way, and pretending otherwise would be the whole mistake this
    /// task exists to stop.
    static func figure(
        from derivation: BraidDerivation,
        assignments: [ThreadAssignment],
        face: BraidFace,
        repeats: Int = 3
    ) -> BraidFigure? {
        guard
            let fold = derivation.fold,
            repeats > 0,
            assignments.count == derivation.threadCount,
            Set(assignments.map(\.position)) == Set(derivation.stand.positionIDs)
        else {
            return nil
        }
        let colours = Dictionary(uniqueKeysWithValues: assignments.map { ($0.position, $0.colorID) })
        let rowCount = derivation.repeatCycleCount

        // **What shows on the face is what is resting there**, and the occupancy
        // history is the record of that (`docs/architecture.md`, 組み台の力学).
        // It is asked here rather than worked out again from the courses, so the
        // figure and the readings answer out of one object.
        guard let occupancy = BraidOccupancy.history(
            of: derivation.method, on: derivation.stand,
            crossSection: derivation.crossSection, cycles: rowCount
        ) else { return nil }
        var slotOfThread = [[Int: Int]]()
        for boundary in 0...rowCount {
            guard let at = occupancy.slotByThread(atBoundary: boundary) else { return nil }
            slotOfThread.append(at)
        }
        func slot(ofThread thread: Int, at row: Int) -> Int? {
            slotOfThread[row % rowCount][thread]
        }
        let rowsDrawn = rowCount * repeats
        let phases = longitudinalPhases(of: derivation, fold: fold)

        // Half a column of margin, then the edge, then the columns.
        func x(_ width: Int) -> Double { Double(width) + 1.5 }
        func y(_ row: Int, _ width: Int) -> Double {
            Double(row) + 0.5 + (phases[width] ?? 0)
        }

        // Where each thread shows on this face at each row, if it shows at all.
        // A thread on the other face, or crossing beneath, has no place here.
        func place(of course: BraidThreadCourse, at row: Int) -> Int? {
            guard
                let slot = slot(ofThread: course.threadPosition, at: row),
                let width = fold.width(ofSlot: slot)
            else { return nil }
            if let slotFace = fold.face(ofSlot: slot) {
                return slotFace == face ? width : nil
            }
            // An edge holds one thread from each half of the braid.
            return keptFace(of: course, fold: fold) == face ? width : nil
        }

        var appearances = [BraidFigure.Shape]()
        var hidden = [BraidFigure.Shape]()
        var seenRuns = [BraidFigure.Shape]()

        for course in derivation.courses {
            guard let colour = colours[course.threadPosition] else { return nil }

            for row in 0..<rowsDrawn {
                if let width = place(of: course, at: row) {
                    let centre = SIMD2(x(width), y(row, width))
                    // An edge is not a column: it holds two threads through the
                    // thickness, so it is drawn narrow.
                    let halfWidth = (0..<fold.columnCount).contains(width) ? 0.46 : 0.26
                    let halfHeight = 0.46
                    appearances.append(BraidFigure.Shape(
                        kind: .appearance,
                        threadPosition: course.threadPosition,
                        colorID: colour,
                        points: [
                            centre + SIMD2(-halfWidth, -halfHeight),
                            centre + SIMD2(halfWidth, -halfHeight),
                            centre + SIMD2(halfWidth, halfHeight),
                            centre + SIMD2(-halfWidth, halfHeight),
                        ],
                        isOnTheFace: true,
                        place: BraidFigure.Place(width: width, row: row)
                    ))
                }

                guard row + 1 < rowsDrawn else { continue }
                let here = place(of: course, at: row)
                let next = place(of: course, at: row + 1)
                let hereWidth = slot(ofThread: course.threadPosition, at: row)
                    .flatMap { fold.width(ofSlot: $0) }
                let nextWidth = slot(ofThread: course.threadPosition, at: row + 1)
                    .flatMap { fold.width(ofSlot: $0) }
                guard let from = hereWidth, let to = nextWidth else { continue }

                // Seen only when the thread is on this face at both ends and stays
                // where it is. Anything else — a turn over to the other face, a run
                // across the braid — goes beneath.
                let seen = here != nil && next != nil && abs(to - from) <= 1
                let segment = BraidFigure.Shape(
                    kind: .passage,
                    threadPosition: course.threadPosition,
                    colorID: colour,
                    points: [
                        SIMD2(x(from), y(row, from)),
                        SIMD2(x(to), y(row + 1, to)),
                    ],
                    isOnTheFace: seen,
                    place: nil
                )
                if seen { seenRuns.append(segment) } else { hidden.append(segment) }
            }
        }

        return BraidFigure(
            shapes: appearances + hidden + seenRuns,
            face: face,
            columnCount: fold.columnCount,
            rowCount: rowCount,
            rowsDrawn: rowsDrawn,
            size: SIMD2(Double(fold.columnCount) + 3, Double(rowsDrawn))
        )
    }

    /// How far along a row each place across the width takes its new appearance.
    ///
    /// **Derived, from the order of the moves** — see
    /// `BraidDerivation.arrivalPhase(atWidth:)` and Task 007G. Measured from the
    /// body, so the braid as a whole does not slide along its length.
    ///
    /// The places a thread runs along are held level with each other. They are not
    /// quite in step — on hira-genji two of them take their appearance a third of
    /// a row before the others — but drawing that would put a chevron across the
    /// face, and book A p97's ladder sample shows the face flat. **Reported by the
    /// derivation, not drawn here**, the same standing Task 007G gave it.
    static func longitudinalPhases(
        of derivation: BraidDerivation,
        fold: BraidFold
    ) -> [Int: Double] {
        let body = derivation.columnsHeldLengthwise
        let bodyPhases = body.compactMap { derivation.arrivalPhase(atWidth: $0) }
        let bodyPhase = bodyPhases.isEmpty
            ? 0
            : bodyPhases.reduce(0, +) / Double(bodyPhases.count)

        var result = [Int: Double]()
        for width in -1...fold.columnCount {
            let raw = body.contains(width)
                ? bodyPhase
                : (derivation.arrivalPhase(atWidth: width) ?? bodyPhase)
            var centred = raw - bodyPhase
            while centred > 0.5 { centred -= 1 }
            while centred < -0.5 { centred += 1 }
            result[width] = centred
        }
        return result
    }

    /// The half of the braid a thread keeps to: the faces its course visits, or
    /// where it starts when it visits both.
    private static func keptFace(of course: BraidThreadCourse, fold: BraidFold) -> BraidFace? {
        let visited = Set(course.slots.compactMap { fold.face(ofSlot: $0) })
        if visited.count == 1 { return visited.first }
        return course.slots.first.flatMap { fold.face(ofSlot: $0) }
    }
}

/// The face of a braid that is a tube, unrolled.
///
/// **A tube has no fold, so it has no faces and no edges** — it has one surface,
/// and the occupancy history folds its slots into columns, a closing pair each.
/// The columns stand at the angles of the slots a hand lands on, which are not
/// evenly spaced: the two slots of a pair are half a column apart, and a figure
/// drawn on the halfway angles reads the seam between two threads rather than
/// either of them.
struct BraidTubeFigure: Equatable, Sendable {
    struct Column: Equatable, Sendable {
        /// The slot of the cross-section this column is read at: the one a hand
        /// lands on.
        let slot: Int
        /// Where that slot stands round the braid, in turns from the first slot.
        let angleInTurns: Double
    }

    let columns: [Column]
    let shapes: [BraidFigure.Shape]
    /// Cycles to one repeat.
    let rowCount: Int
    let rowsDrawn: Int
    let size: SIMD2<Double>

    /// **Shown, not hidden.** A tube has no origin and no printed direction, so a
    /// figure of one agrees with a transcription up to a rotation, a mirror, the
    /// way up and where the transcription started. Anything the cross-section
    /// itself is unsure of is carried here too.
    let unsettled: [String]

    func appearance(atColumn column: Int, row: Int) -> BraidFigure.Shape? {
        shapes.first { $0.place?.width == column && $0.place?.row == row && $0.isOnTheFace }
    }

    func row(_ row: Int) -> [BraidFigure.Shape] {
        (0..<columns.count).compactMap { appearance(atColumn: $0, row: row) }
    }
}

extension BraidFigureBuilder {
    /// `nil` for a braid the derivation has folded flat — that one has faces, and
    /// `figure(from:assignments:face:repeats:)` draws them.
    static func tube(
        from derivation: BraidDerivation,
        assignments: [ThreadAssignment],
        repeats: Int = 3
    ) -> BraidTubeFigure? {
        guard
            derivation.fold == nil,
            repeats > 0,
            assignments.count == derivation.threadCount,
            Set(assignments.map(\.position)) == Set(derivation.stand.positionIDs)
        else {
            return nil
        }
        let colours = Dictionary(uniqueKeysWithValues: assignments.map { ($0.position, $0.colorID) })
        let rowCount = derivation.repeatCycleCount
        let rowsDrawn = rowCount * repeats
        let slotCount = derivation.crossSection.slotCount

        guard
            let occupancy = BraidOccupancy.history(
                of: derivation.method, on: derivation.stand,
                crossSection: derivation.crossSection, cycles: rowCount
            ),
            let slots = occupancy.columns(.landing),
            let grid = occupancy.grid(atColumns: slots, rows: rowCount)
        else { return nil }

        let columns = slots.map {
            BraidTubeFigure.Column(slot: $0,
                                   angleInTurns: Double($0) / Double(slotCount))
        }

        var shapes = [BraidFigure.Shape]()
        for row in 0..<rowsDrawn {
            for (column, thread) in grid[row % rowCount].enumerated() {
                guard let colour = colours[thread] else { return nil }
                let centre = SIMD2(Double(column) + 0.5, Double(row) + 0.5)
                let half = 0.46
                shapes.append(BraidFigure.Shape(
                    kind: .appearance,
                    threadPosition: thread,
                    colorID: colour,
                    points: [
                        centre + SIMD2(-half, -half), centre + SIMD2(half, -half),
                        centre + SIMD2(half, half), centre + SIMD2(-half, half),
                    ],
                    isOnTheFace: true,
                    place: BraidFigure.Place(width: column, row: row)
                ))
            }
        }

        var unsettled = ["a tube has no origin and no printed direction, so this "
                         + "agrees with a transcription up to a rotation, a mirror, "
                         + "the way up and where the transcription started"]
        if let note = derivation.crossSection.unsettled { unsettled.append(note) }

        return BraidTubeFigure(
            columns: columns, shapes: shapes, rowCount: rowCount, rowsDrawn: rowsDrawn,
            size: SIMD2(Double(columns.count), Double(rowsDrawn)),
            unsettled: unsettled
        )
    }
}
