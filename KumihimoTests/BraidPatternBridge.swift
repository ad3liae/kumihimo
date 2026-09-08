import Foundation
@testable import Kumihimo

/// Rebuilds the shipped flat-braid surface out of the general working-out, so the
/// two can be compared object for object.
///
/// **This exists to make a difference visible, not to ship.** Every value it fills
/// in is one the working-out already has — the fold says which face and which
/// column, the courses say which thread, and **which side of a crossing a thread
/// takes comes from the construction**: a carry that runs across the braid passes
/// the columns between its ends, and it passes them inside.
///
/// It used to take that last one from the chord model. The author's ruling of
/// 2026-09-09 made the construction the source, and the two agree cell for cell
/// (`BraidLayerFromConstructionTests`), so nothing about this comparison moved.
enum BraidPatternBridge {
    static func hiraStylePattern(
        from derivation: BraidDerivation,
        assignments: [ThreadAssignment]
    ) -> HiraGenjiWeavePattern? {
        guard let construction = BraidConstruction.construct(
            of: derivation.method, on: derivation.stand,
            crossSection: derivation.crossSection, fold: derivation.fold,
            cycles: derivation.repeatCycleCount + 1
        ) else { return nil }
        return hiraStylePattern(from: derivation, construction: construction,
                                assignments: assignments)
    }

    static func hiraStylePattern(
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

/// The colourings the books set up as controlled experiments, written the way the
/// books write them: by group of the stand.
@MainActor
enum HiraGenjiReferenceColourings {
    /// Book A p97, left: everything worked lengthwise plain, everything worked
    /// sideways in colour.
    static var weftOnly: [ThreadAssignment] {
        colouring(north: .init(repeating: "white", count: 4),
                  south: .init(repeating: "white", count: 4),
                  east: ["yellow", "red", "red", "yellow"],
                  west: ["green", "light-blue", "light-blue", "green"])
    }

    /// Book A p97's arrow feather: the middle two of each side one colour, the far
    /// and near two another.
    static var arrowFeather: [ThreadAssignment] {
        ProjectEditorPreviewData.hiraGenjiSurfaceArrowFeather
    }

    /// Book A p97's ladder: the far group and the near group in two colours.
    static var ladder: [ThreadAssignment] {
        ProjectEditorPreviewData.hiraGenjiSurfaceLadder
    }

    /// The colouring drawn in book A p96's starting diagram, whose finished braid
    /// is the photograph the cross-section's order is read from.
    static var bookAP96: [ThreadAssignment] {
        colouring(north: ["purple", "purple", "black", "orange"],
                  south: ["purple", "purple", "black", "orange"],
                  east: .init(repeating: "pink", count: 4),
                  west: .init(repeating: "pink", count: 4))
    }

    static var all: [(String, [ThreadAssignment])] {
        [("weft only", weftOnly), ("arrow feather", arrowFeather),
         ("ladder", ladder), ("book A p96", bookAP96)]
    }

    private static func colouring(
        north: [String], south: [String], east: [String], west: [String]
    ) -> [ThreadAssignment] {
        var colours = [Int: String]()
        for (group, names) in [
            (HiraGenjiBoardState.initial.north, north),
            (HiraGenjiBoardState.initial.east, east),
            (HiraGenjiBoardState.initial.south, south),
            (HiraGenjiBoardState.initial.west, west),
        ] {
            for (position, name) in zip(group, names) { colours[position] = name }
        }
        return (1...16).map {
            ThreadAssignment(position: $0, colorID: ThreadColorID(rawValue: colours[$0] ?? "white"))
        }
    }
}
