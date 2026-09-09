import Foundation

/// The flat braid's weave pattern, worked out from the general working-out.
///
/// **This is the path the tests proved before it shipped.** It was
/// `KumihimoTests/BraidPatternBridge`, which rebuilt this same object out of the
/// stand, the move table and the construction so the two could be compared object
/// for object; it matched the per-braid derivation patch for patch, edge for edge
/// and crossing for crossing on all four of the colourings the books set up
/// (`BraidDerivationHiraGenjiAgreementTests`). Task 025-4 moved it into the
/// product, and the comparison stayed where it was.
///
/// Every value here is one the working-out already has: the fold says which face
/// and which column, the courses say which thread goes where, the occupancy history
/// says which thread is resting at each place, and **the construction says which
/// side of a crossing a thread takes** — a carry that runs across the braid passes
/// the columns between its ends, and it passes them inside.
enum Flat16WeaveFromWorking {
    static func pattern(
        from derivation: BraidDerivation,
        construction: BraidConstruction,
        assignments: [ThreadAssignment]
    ) -> HiraGenjiWeavePattern? {
        guard
            let fold = derivation.fold,
            assignments.count == derivation.threadCount,
            Set(assignments.map(\.position)) == Set(derivation.stand.positionIDs)
        else {
            return nil
        }
        let colours = Dictionary(uniqueKeysWithValues: assignments.map { ($0.position, $0.colorID) })
        let rowCount = derivation.repeatCycleCount

        var patches = [HiraGenjiWeavePatch]()
        var edgePlaces = [HiraGenjiWeaveEdgePlace]()
        var crossings = [HiraGenjiWeftCrossing]()

        for course in derivation.courses {
            guard let colour = colours[course.threadPosition] else { return nil }
            let kind: HiraGenjiThreadCourseKind =
                course.runsAlongTheBraid ? .lengthwise : .carriedAcross
            guard let half = keptFace(of: course, fold: fold) else { return nil }

            for row in 0..<rowCount {
                let slot = course.slots[row]
                let nextSlot = course.slots[row + 1]
                guard
                    let width = fold.width(ofSlot: slot),
                    let nextWidth = fold.width(ofSlot: nextSlot)
                else {
                    return nil
                }
                guard let layer = construction.layer(
                    ofThread: course.threadPosition, atRow: row
                ) else { return nil }

                if let face = fold.face(ofSlot: slot), let column = fold.column(ofSlot: slot) {
                    patches.append(HiraGenjiWeavePatch(
                        column: column,
                        row: row,
                        face: face.asHiraFace,
                        threadPosition: course.threadPosition,
                        colorID: colour,
                        course: kind,
                        layer: layer,
                        nextWidthPosition: nextWidth
                    ))
                } else {
                    edgePlaces.append(HiraGenjiWeaveEdgePlace(
                        edge: width < 0 ? .left : .right,
                        row: row,
                        half: half.asHiraFace,
                        threadPosition: course.threadPosition,
                        colorID: colour
                    ))
                }
            }
        }

        // The shipped pattern records only the runs that cross the braid, and
        // measures them across the width, so the width is put back here.
        for course in derivation.courses {
            guard
                let colour = colours[course.threadPosition],
                let half = keptFace(of: course, fold: fold)
            else { continue }
            for row in 0..<rowCount {
                guard
                    let way = construction.steps[course.threadPosition], row + 1 < way.count,
                    let from = fold.width(ofSlot: way[row].slot),
                    let to = fold.width(ofSlot: way[row + 1].slot),
                    abs(to - from) > 1,
                    let layer = construction.layer(ofThread: course.threadPosition, atRow: row)
                else { continue }
                let step = to > from ? 1 : -1
                crossings.append(HiraGenjiWeftCrossing(
                    threadPosition: course.threadPosition,
                    colorID: colour,
                    row: row,
                    face: half.asHiraFace,
                    fromWidthPosition: from,
                    toWidthPosition: to,
                    passedColumns: Array(stride(from: from + step, to: to, by: step))
                        .filter { (0..<fold.columnCount).contains($0) },
                    layer: layer
                ))
            }
        }

        return HiraGenjiWeavePattern(
            patches: patches.sorted {
                ($0.row, $0.face.rawValue, $0.column) < ($1.row, $1.face.rawValue, $1.column)
            },
            edgePlaces: edgePlaces.sorted {
                ($0.row, $0.threadPosition) < ($1.row, $1.threadPosition)
            },
            weftCrossings: crossings.sorted {
                ($0.row, $0.face.rawValue, $0.threadPosition)
                    < ($1.row, $1.face.rawValue, $1.threadPosition)
            },
            columnCount: fold.columnCount,
            rowCount: rowCount
        )
    }

    /// The half of the braid a thread keeps to. A thread carried across stays on
    /// one side the whole way round its circuit; one running along visits both, and
    /// is named by where it starts, which is all the pattern uses it for.
    private static func keptFace(of course: BraidThreadCourse, fold: BraidFold) -> BraidFace? {
        let visited = Set(course.slots.compactMap { fold.face(ofSlot: $0) })
        if visited.count == 1 { return visited.first }
        return course.slots.first.flatMap { fold.face(ofSlot: $0) }
    }
}

private extension BraidFace {
    var asHiraFace: HiraGenjiBraidFace { self == .front ? .front : .back }
}
