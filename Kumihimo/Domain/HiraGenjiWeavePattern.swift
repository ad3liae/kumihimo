import Foundation

/// Which side of the flat braid a thread is on at one step along it.
enum HiraGenjiBraidFace: String, Equatable, Sendable, CaseIterable {
    case front
    case back

    var opposite: HiraGenjiBraidFace { self == .front ? .back : .front }
}

/// What a thread does over the length of the braid.
enum HiraGenjiThreadCourseKind: Equatable, Sendable, CaseIterable {
    /// Holds one column and turns over from one face to the other. Worked between
    /// the near and far faces of the stand.
    case lengthwise
    /// Runs from one edge of the braid to the other and turns back. Worked between
    /// the two sides of the stand.
    case carriedAcross
}

/// One place on the braid's surface: one column across the width, one step along
/// the length, one face.
struct HiraGenjiWeavePatch: Equatable, Sendable {
    /// 0 at the left edge of the face, `columnCount - 1` at the right.
    let column: Int
    /// 0..<`rowCount` along the braid. One row is one worked cycle.
    let row: Int
    let face: HiraGenjiBraidFace
    let threadPosition: Int
    let colorID: ThreadColorID
    let course: HiraGenjiThreadCourseKind
    /// Which side of a crossing this thread takes where it meets a thread going
    /// the other way.
    ///
    /// A thread carried across the braid passes under the threads running along
    /// it. Book A p97's own controlled sample settles this: colour every sideways
    /// thread and leave every lengthwise thread plain, and the braid comes out
    /// plain in the middle with the colour only at the two edges. A sideways
    /// thread crossing over the face would put colour across the middle.
    let layer: BraidCrossingLayer
    /// Where across the width this thread is one step further along, on the axis
    /// that counts the edges as one step outside the columns.
    let nextWidthPosition: Int
}

/// One of the two threads lying at an edge of the braid at one step along it.
///
/// An edge is not a column: it holds two threads through the thickness, one
/// keeping to the front half of the braid and one to the back. Neither is on
/// either face, so they have no patch.
struct HiraGenjiWeaveEdgePlace: Equatable, Sendable {
    let edge: HiraGenjiBraidEdge
    let row: Int
    /// The half of the braid this thread keeps to. Derived: a thread carried
    /// across stays on one side of the braid the whole way round its circuit.
    let half: HiraGenjiBraidFace
    let threadPosition: Int
    let colorID: ThreadColorID
}

/// One run of a thread from one edge of the braid to the other.
///
/// A thread carried across is seen on the face only in the outermost column and
/// at the edge, so the grid of visible places says nothing about the part in
/// between — and that part is most of the thread. It is recorded here: which
/// columns it passes, and that it goes under the threads running along the braid
/// while it does.
struct HiraGenjiWeftCrossing: Equatable, Sendable {
    let threadPosition: Int
    let colorID: ThreadColorID
    /// The step along the braid this crossing is laid at.
    let row: Int
    /// Which half of the braid the thread keeps to.
    let face: HiraGenjiBraidFace
    /// On the axis that counts the edges as one step outside the columns.
    let fromWidthPosition: Int
    let toWidthPosition: Int
    /// The face columns between the two ends, in the order they are passed.
    let passedColumns: [Int]
    /// Under the threads running along the braid, which is why the crossing is
    /// not seen on either face where they hold the column.
    let layer: BraidCrossingLayer
}

struct HiraGenjiWeavePattern: Equatable, Sendable {
    let patches: [HiraGenjiWeavePatch]
    /// The two threads at each edge, for every row.
    let edgePlaces: [HiraGenjiWeaveEdgePlace]
    /// Every run of a thread from one edge to the other, in row order.
    let weftCrossings: [HiraGenjiWeftCrossing]
    let columnCount: Int
    let rowCount: Int

    /// The columns a thread running along the braid holds. A crossing passes under
    /// every one of them.
    var lengthwiseColumns: Set<Int> {
        Set(patches.filter { $0.course == .lengthwise }.map(\.column))
    }

    /// The columns the face shows a thread carried across in. These sit outside
    /// the lengthwise columns, at the two sides of the face.
    var carriedAcrossColumns: Set<Int> {
        Set(patches.filter { $0.course == .carriedAcross }.map(\.column))
    }

    func patch(column: Int, row: Int, face: HiraGenjiBraidFace) -> HiraGenjiWeavePatch? {
        patches.first { $0.column == column && $0.row == row && $0.face == face }
    }

    /// One row of one face, left edge to right edge.
    func row(_ row: Int, face: HiraGenjiBraidFace) -> [HiraGenjiWeavePatch] {
        patches.filter { $0.row == row && $0.face == face }.sorted { $0.column < $1.column }
    }

    func threadsAtEdge(row: Int, edge: HiraGenjiBraidEdge) -> [HiraGenjiWeaveEdgePlace] {
        edgePlaces.filter { $0.row == row && $0.edge == edge }
    }

    func patches(ofCourse course: HiraGenjiThreadCourseKind) -> [HiraGenjiWeavePatch] {
        patches.filter { $0.course == course }
    }
}

/// Builds the flat braid's surface from the thread courses.
///
/// The cross-section — six columns to a face and two threads at each edge — is
/// given, from the author's account and from the finished braid in book A p96.
/// Which thread stands at which of those places, at each step along the braid,
/// comes from the move rules by way of `HiraGenjiWeaveDerivation`. The crossing
/// layer comes from book A p97's own controlled sample. The repeat is however
/// many cycles the stand takes to come back to itself.
enum HiraGenjiWeavePatternGenerator {
    static let requiredThreadCount = HiraGenjiWeaveDerivation.threadCount
    static let columnCount = HiraGenjiWeaveDerivation.columnCount

    /// Rows to one repeat. Derived by running the move rules until the stand is
    /// back where it started, not carried over from the older pattern.
    static var rowCount: Int? { HiraGenjiWeaveDerivation.repeatCycleCount() }

    /// Every column, on both faces, for every row of one repeat.
    static var patchCount: Int? {
        rowCount.map { columnCount * $0 * HiraGenjiBraidFace.allCases.count }
    }

    /// Both threads at both edges, for every row.
    static var edgePlaceCount: Int? {
        rowCount.map {
            $0 * HiraGenjiBraidEdge.allCases.count * HiraGenjiWeaveDerivation.edgeThreadCount
        }
    }

    static func generate(assignments: [ThreadAssignment]) -> HiraGenjiWeavePattern? {
        let expected = Set(1...requiredThreadCount)
        let supplied = Set(assignments.map(\.position))
        guard
            assignments.count == requiredThreadCount,
            supplied == expected
        else {
            return nil
        }
        let colorsByPosition = Dictionary(
            uniqueKeysWithValues: assignments.map { ($0.position, $0.colorID) }
        )

        guard
            let rowCount,
            let courses = HiraGenjiWeaveDerivation.courses(cycleCount: rowCount),
            courses.count == requiredThreadCount
        else {
            return nil
        }

        var patches = [HiraGenjiWeavePatch]()
        var edgePlaces = [HiraGenjiWeaveEdgePlace]()
        var crossings = [HiraGenjiWeftCrossing]()

        for course in courses {
            guard
                let colorID = colorsByPosition[course.threadPosition],
                let half = keptFace(of: course)
            else {
                return nil
            }
            let kind: HiraGenjiThreadCourseKind = course.runsAlongTheBraid
                ? .lengthwise
                : .carriedAcross

            for row in 0..<rowCount {
                guard
                    course.samples.indices.contains(row),
                    course.samples.indices.contains(row + 1)
                else {
                    return nil
                }
                let sample = course.samples[row]
                let next = course.samples[row + 1]

                switch sample.place {
                case .face(let face, let column):
                    guard (0..<columnCount).contains(column) else { return nil }
                    patches.append(HiraGenjiWeavePatch(
                        column: column,
                        row: row,
                        face: face,
                        threadPosition: course.threadPosition,
                        colorID: colorID,
                        course: kind,
                        layer: kind == .carriedAcross ? .under : .over,
                        nextWidthPosition: next.widthPosition
                    ))
                case .edge(let edge):
                    edgePlaces.append(HiraGenjiWeaveEdgePlace(
                        edge: edge,
                        row: row,
                        half: half,
                        threadPosition: course.threadPosition,
                        colorID: colorID
                    ))
                }

                // A step of one is a turn at an edge. Anything longer crosses the
                // braid, passing under every column on the way.
                let from = sample.widthPosition
                let to = next.widthPosition
                guard abs(to - from) > 1 else { continue }
                let step = to > from ? 1 : -1
                let passed = stride(from: from + step, to: to, by: step)
                    .filter { (0..<columnCount).contains($0) }
                crossings.append(HiraGenjiWeftCrossing(
                    threadPosition: course.threadPosition,
                    colorID: colorID,
                    row: row,
                    face: half,
                    fromWidthPosition: from,
                    toWidthPosition: to,
                    passedColumns: Array(passed),
                    layer: .under
                ))
            }
        }

        let pattern = HiraGenjiWeavePattern(
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
            columnCount: columnCount,
            rowCount: rowCount
        )
        return isComplete(pattern) ? pattern : nil
    }

    /// The half of the braid a thread keeps to. A thread running along the braid
    /// turns over every cycle and keeps to neither, so this is only asked of the
    /// ones carried across — but it is derived the same way for both: the faces
    /// the course actually visits.
    private static func keptFace(of course: HiraGenjiThreadCourse) -> HiraGenjiBraidFace? {
        let faces = Set(course.samples.compactMap(\.face))
        if faces.count == 1 { return faces.first }
        // A thread running along the braid visits both faces; name it by where it
        // starts, which is all the pattern needs it for.
        return course.samples.first?.face
    }

    /// Every place on the surface carries exactly one thread, every edge carries
    /// two, and every thread is somewhere in every row.
    private static func isComplete(_ pattern: HiraGenjiWeavePattern) -> Bool {
        guard
            pattern.patches.count == patchCount,
            pattern.edgePlaces.count == edgePlaceCount
        else {
            return false
        }
        let places = Set(pattern.patches.map { [$0.row, $0.column, $0.face == .front ? 1 : 0] })
        guard places.count == pattern.patches.count else { return false }

        let everyThread = Set(1...requiredThreadCount)
        guard (0..<pattern.rowCount).allSatisfy({ row in
            let onTheFaces = pattern.patches.filter { $0.row == row }.map(\.threadPosition)
            let atTheEdges = pattern.edgePlaces.filter { $0.row == row }.map(\.threadPosition)
            return Set(onTheFaces + atTheEdges) == everyThread
                && onTheFaces.count + atTheEdges.count == requiredThreadCount
        }) else {
            return false
        }
        // Each edge holds one thread from each half, at every row.
        guard (0..<pattern.rowCount).allSatisfy({ row in
            HiraGenjiBraidEdge.allCases.allSatisfy { edge in
                Set(pattern.threadsAtEdge(row: row, edge: edge).map(\.half))
                    == Set(HiraGenjiBraidFace.allCases)
            }
        }) else {
            return false
        }
        // Every crossing really does cross: it passes every column a lengthwise
        // thread holds, which is the whole middle of the braid.
        let middle = pattern.lengthwiseColumns
        return !pattern.weftCrossings.isEmpty
            && pattern.weftCrossings.allSatisfy { middle.isSubset(of: Set($0.passedColumns)) }
    }
}
