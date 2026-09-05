import Foundation
import Testing
@testable import Kumihimo

/// Stage C of Task 007F, second attempt: the surface built on the given
/// cross-section — six columns to a face, two threads at each edge — with the
/// move rules saying which thread stands where.
///
/// Two references check it, and both are controlled experiments the books set up
/// themselves. Book A p96 colours faces 1 and 3 in four colours and photographs
/// the result, which fixes the order of the columns across the face. Book A p97
/// colours everything worked lengthwise plain and everything worked sideways in
/// colour, which fixes which threads reach the face at all.
struct HiraGenjiWeavePatternTests {
    // MARK: - Shape

    @Test func theSurfaceIsSixColumnsTwoFacesTwoEdgesAndFourRows() throws {
        let pattern = try #require(HiraGenjiWeavePatternGenerator.generate(assignments: plain))

        #expect(pattern.columnCount == 6)
        // Rows to a repeat come from the move rules, not from the older pattern's
        // twelve.
        #expect(pattern.rowCount == 4)
        #expect(pattern.rowCount == HiraGenjiWeaveDerivation.repeatCycleCount())
        #expect(pattern.patches.count == 48)
        #expect(pattern.edgePlaces.count == 16)

        for row in 0..<pattern.rowCount {
            for face in HiraGenjiBraidFace.allCases {
                let line = pattern.row(row, face: face)
                #expect(line.count == 6)
                #expect(line.map(\.column) == Array(0..<6))
            }
            for edge in HiraGenjiBraidEdge.allCases {
                let atTheEdge = pattern.threadsAtEdge(row: row, edge: edge)
                #expect(atTheEdge.count == 2)
                #expect(Set(atTheEdge.map(\.half)) == Set(HiraGenjiBraidFace.allCases))
            }
            // All sixteen threads appear once in each row: twelve on the faces and
            // four at the edges.
            let onTheFaces = pattern.patches.filter { $0.row == row }.map(\.threadPosition)
            let atTheEdges = pattern.edgePlaces.filter { $0.row == row }.map(\.threadPosition)
            #expect(onTheFaces.count == 12)
            #expect(atTheEdges.count == 4)
            #expect(Set(onTheFaces + atTheEdges) == Set(1...16))
        }
    }

    @Test func generationIsDeterministicAndDrivenByPositionNotColour() throws {
        let first = try #require(HiraGenjiWeavePatternGenerator.generate(assignments: plain))
        let second = try #require(
            HiraGenjiWeavePatternGenerator.generate(assignments: Array(plain.reversed()))
        )
        #expect(first == second)

        let recoloured = try #require(HiraGenjiWeavePatternGenerator.generate(
            assignments: (1...16).map { ThreadAssignment(position: $0, colorID: white) }
        ))
        #expect(first.patches.map(\.threadPosition) == recoloured.patches.map(\.threadPosition))
        #expect(first.patches.map(\.column) == recoloured.patches.map(\.column))
        #expect(first.patches.map(\.layer) == recoloured.patches.map(\.layer))
    }

    // MARK: - Book A p96: the order of the columns across the face

    /// The finished braid photographed at the head of book A p96 is worked with
    /// face 1 as mauve, mauve, black, vermilion and everything else salmon. Across
    /// its width it reads salmon, mauve, mauve, vermilion, black, salmon, in bands
    /// measuring 16, 20, 20, 24, 24 and 16 pixels — six columns of one thread.
    ///
    /// This is the reading the whole map rests on, so it is asserted directly.
    @Test func theP96ColouringComesOutAsThePhotographedBraid() throws {
        let pattern = try #require(
            HiraGenjiWeavePatternGenerator.generate(assignments: bookAP96Colouring)
        )
        let expected = [salmon, mauve, mauve, vermilion, black, salmon]

        for row in 0..<pattern.rowCount {
            for face in HiraGenjiBraidFace.allCases {
                #expect(pattern.row(row, face: face).map(\.colorID) == expected)
            }
        }
        // The edges are salmon too, so the photograph shows no colour beyond the
        // six columns of the face.
        #expect(pattern.edgePlaces.allSatisfy { $0.colorID == salmon })
    }

    /// Turned round: black is outboard of vermilion in the braid, and inboard of it
    /// on the stand. Any map that carried the ring's order across would give the
    /// other answer, so this is the assertion that rules that map out.
    @Test func theBlackColumnIsOutboardOfTheVermilionOne() throws {
        let pattern = try #require(
            HiraGenjiWeavePatternGenerator.generate(assignments: bookAP96Colouring)
        )
        let front = pattern.row(0, face: .front)
        let blackColumn = try #require(front.first { $0.colorID == black }?.column)
        let vermilionColumn = try #require(front.first { $0.colorID == vermilion }?.column)

        #expect(blackColumn == 4)
        #expect(vermilionColumn == 3)
        // On the stand it is the other way about: board position 1 is black and 2
        // is vermilion, and 1 comes first going round.
        #expect(blackColumn > vermilionColumn)
    }

    // MARK: - What the courses put where

    @Test func lengthwiseThreadsHoldTheFourMiddleColumnsAndTurnOverEveryRow() throws {
        let pattern = try #require(HiraGenjiWeavePatternGenerator.generate(assignments: plain))
        let lengthwise = pattern.patches(ofCourse: .lengthwise)

        #expect(Set(lengthwise.map(\.threadPosition)).count == 8)
        #expect(pattern.lengthwiseColumns == [1, 2, 3, 4])
        #expect(lengthwise.allSatisfy { $0.column == $0.nextWidthPosition })

        for thread in Set(lengthwise.map(\.threadPosition)) {
            let course = lengthwise.filter { $0.threadPosition == thread }
                .sorted { $0.row < $1.row }
            #expect(course.count == 4)
            #expect(Set(course.map(\.column)).count == 1)
            #expect(zip(course, course.dropFirst()).allSatisfy { $0.face != $1.face })
        }
    }

    @Test func threadsCarriedAcrossShowOnlyInTheOutermostColumn() throws {
        let pattern = try #require(HiraGenjiWeavePatternGenerator.generate(assignments: plain))
        let carried = pattern.patches(ofCourse: .carriedAcross)
        let lastColumn = pattern.columnCount - 1

        #expect(Set(carried.map(\.threadPosition)).count == 8)
        #expect(pattern.carriedAcrossColumns == [0, lastColumn])

        for thread in Set(carried.map(\.threadPosition)) {
            let onTheFace = carried.filter { $0.threadPosition == thread }
                .sorted { $0.row < $1.row }
            // Two rows on the face and two at an edge, out of the four in a repeat.
            #expect(onTheFace.count == 2)
            #expect(Set(onTheFace.map(\.face)).count == 1)
            #expect(Set(onTheFace.map(\.column)) == [0, lastColumn])

            let atTheEdges = pattern.edgePlaces.filter { $0.threadPosition == thread }
            #expect(atTheEdges.count == 2)
            #expect(Set(atTheEdges.map(\.edge)) == Set(HiraGenjiBraidEdge.allCases))
            // A thread keeps to one half of the braid the whole way round.
            #expect(Set(atTheEdges.map(\.half)) == Set(onTheFace.map(\.face)))
        }
    }

    /// A thread carried across the braid does not stop at the outermost column: it
    /// runs the whole width to reach the other side. The grid of visible places
    /// cannot show that, so the crossings are carried separately.
    @Test func everyCrossingRunsTheWholeWidthOfTheBraid() throws {
        let pattern = try #require(HiraGenjiWeavePatternGenerator.generate(assignments: plain))
        let lastColumn = pattern.columnCount - 1

        // Four threads cross per row, two on each half of the braid, and they cross
        // in opposite directions.
        #expect(pattern.weftCrossings.count == 4 * pattern.rowCount)
        for row in 0..<pattern.rowCount {
            let inThisRow = pattern.weftCrossings.filter { $0.row == row }
            #expect(inThisRow.count == 4)
            for face in HiraGenjiBraidFace.allCases {
                let onThisFace = inThisRow.filter { $0.face == face }
                #expect(onThisFace.count == 2)
                #expect(onThisFace.count { $0.toWidthPosition < $0.fromWidthPosition } == 1)
                #expect(onThisFace.count { $0.toWidthPosition > $0.fromWidthPosition } == 1)
            }
        }

        for crossing in pattern.weftCrossings {
            // One side of the braid to the other. A crossing runs either from the
            // outermost column to the far edge or from an edge to the far
            // outermost column, because the thread turns at an edge in between.
            let ends = Set([crossing.fromWidthPosition, crossing.toWidthPosition])
            #expect([Set([lastColumn, -1]), Set([0, lastColumn + 1])].contains(ends))
            #expect(crossing.passedColumns.count == lastColumn)
            #expect(Set(crossing.passedColumns).isSuperset(of: pattern.lengthwiseColumns))
        }
    }

    /// Where a crossing meets the threads running along the braid, it goes under
    /// them. Book A p97's controlled sample is what settles this: colour every
    /// sideways thread, leave every lengthwise thread plain, and the middle of the
    /// braid comes out plain. A crossing running over the face would put colour
    /// across the middle.
    @Test func crossingsPassUnderTheThreadsRunningAlong() throws {
        let pattern = try #require(HiraGenjiWeavePatternGenerator.generate(assignments: plain))

        #expect(pattern.weftCrossings.allSatisfy { $0.layer == .under })
        #expect(pattern.patches(ofCourse: .carriedAcross).allSatisfy { $0.layer == .under })
        #expect(pattern.patches(ofCourse: .lengthwise).allSatisfy { $0.layer == .over })
    }

    // MARK: - Book A p97: which threads reach the face

    /// "配色を変えてみると", left sample: faces 1 and 3 — everything worked
    /// lengthwise — in a plain neutral, faces 2 and 4 — everything worked
    /// sideways — in colours. The braid it shows has a plain body and a coloured
    /// edging down both sides.
    ///
    /// If the board positions were mapped across the braid the wrong way, the
    /// colour would land in the middle instead.
    @Test func theReferenceColouringPutsThePlainThreadsOnTheFaceAndTheColoursAtBothSides() throws {
        let pattern = try #require(
            HiraGenjiWeavePatternGenerator.generate(assignments: referenceColourVariant)
        )
        let lastColumn = pattern.columnCount - 1

        for patch in pattern.patches {
            if patch.column == 0 || patch.column == lastColumn {
                #expect(patch.colorID != plainColour)
            } else {
                #expect(patch.colorID == plainColour)
            }
        }
        #expect(pattern.edgePlaces.allSatisfy { $0.colorID != plainColour })

        // Said the other way round: every row of both faces is a coloured edging,
        // four plain columns, and a coloured edging.
        for row in 0..<pattern.rowCount {
            for face in HiraGenjiBraidFace.allCases {
                let plainness = pattern.row(row, face: face).map { $0.colorID == plainColour }
                #expect(plainness == [false, true, true, true, true, false])
            }
        }

        // And the coloured threads do run right through the middle on their way
        // across — they simply pass under it, which is why none of that colour
        // reaches either face.
        #expect(pattern.weftCrossings.allSatisfy { $0.colorID != plainColour })
        #expect(pattern.weftCrossings.allSatisfy {
            Set($0.passedColumns).isSuperset(of: pattern.lengthwiseColumns)
        })
        #expect(pattern.weftCrossings.allSatisfy { $0.layer == .under })
    }

    /// Book A p97's second controlled experiment, and the one its caption spells
    /// out: "colour the middle two of faces 2 and 4 one way and the far and near
    /// two another, and the **edging** comes out in arrow-feather."
    ///
    /// Faces 2 and 4 are the threads carried across. The caption says their
    /// colour patterns the edging, not the body — so this checks the body stays
    /// plain, and that the edging alternates the two colours in a way that reads
    /// as a chevron. If a thread carried across ever reached the middle of the
    /// face, the body would come out coloured.
    @Test func theArrowFeatherColouringPatternsOnlyTheEdging() throws {
        let pattern = try #require(
            HiraGenjiWeavePatternGenerator.generate(assignments: arrowFeatherColouring)
        )
        let lastColumn = pattern.columnCount - 1

        // The body: every middle column, both faces, every row, stays plain.
        for patch in pattern.patches where patch.column != 0 && patch.column != lastColumn {
            #expect(patch.colorID == plainColour)
        }
        // And no plain thread ever reaches the edging.
        for patch in pattern.patches where patch.column == 0 || patch.column == lastColumn {
            #expect(patch.colorID != plainColour)
        }
        #expect(pattern.edgePlaces.allSatisfy { $0.colorID != plainColour })

        // The edging is two places deep on each side — the outermost column and
        // the edge itself — and the two carry opposite colours at every row.
        // That alternation down the braid is what draws the arrow-feather.
        for row in 0..<pattern.rowCount {
            for (edge, column) in [(HiraGenjiBraidEdge.left, 0),
                                   (HiraGenjiBraidEdge.right, lastColumn)] {
                let onTheFace = try #require(
                    pattern.patch(column: column, row: row, face: .front)?.colorID
                )
                let atTheEdge = try #require(
                    pattern.threadsAtEdge(row: row, edge: edge)
                        .first { $0.half == .front }?.colorID
                )
                #expect(onTheFace != atTheEdge)
                #expect([middleOfTheSides, farAndNear].contains(onTheFace))
                #expect([middleOfTheSides, farAndNear].contains(atTheEdge))
            }
            // Both sides carry the same pair, so the two edgings mirror.
            let left = try #require(pattern.patch(column: 0, row: row, face: .front)?.colorID)
            let right = try #require(
                pattern.patch(column: lastColumn, row: row, face: .front)?.colorID
            )
            #expect(left == right)
        }
        // Down the braid each place changes colour every row: an alternation, not
        // a stripe.
        for column in [0, lastColumn] {
            let downTheEdge = (0..<pattern.rowCount).compactMap {
                pattern.patch(column: column, row: $0, face: .front)?.colorID
            }
            #expect(zip(downTheEdge, downTheEdge.dropFirst()).allSatisfy { $0 != $1 })
        }
    }

    /// The edging is not one flat colour: the outermost column carries a different
    /// one of the sideways threads every row, which is the moving edge pattern the
    /// same caption describes.
    @Test func theEdgingChangesColourFromRowToRow() throws {
        let pattern = try #require(
            HiraGenjiWeavePatternGenerator.generate(assignments: referenceColourVariant)
        )

        for column in [0, pattern.columnCount - 1] {
            let downTheEdge = (0..<pattern.rowCount).compactMap {
                pattern.patch(column: column, row: $0, face: .front)?.colorID
            }
            #expect(downTheEdge.count == 4)
            #expect(Set(downTheEdge).count == 4)
        }
    }

    // MARK: - Failure

    @Test func malformedAssignmentsFailSafely() {
        let duplicate = Array(plain.dropLast()) + [plain[14]]
        let outOfRange = Array(plain.dropLast()) + [
            ThreadAssignment(position: 17, colorID: white),
        ]

        #expect(HiraGenjiWeavePatternGenerator.generate(assignments: duplicate) == nil)
        #expect(HiraGenjiWeavePatternGenerator.generate(assignments: outOfRange) == nil)
        #expect(HiraGenjiWeavePatternGenerator.generate(assignments: Array(plain.dropLast())) == nil)
        #expect(HiraGenjiWeavePatternGenerator.generate(assignments: []) == nil)
    }

    // MARK: - Fixtures

    private let white = ThreadColorID(rawValue: "white")
    private let plainColour = ThreadColorID(rawValue: "natural")
    private let mauve = ThreadColorID(rawValue: "mauve")
    private let black = ThreadColorID(rawValue: "black")
    private let vermilion = ThreadColorID(rawValue: "vermilion")
    private let salmon = ThreadColorID(rawValue: "salmon")
    private let middleOfTheSides = ThreadColorID(rawValue: "gold")
    private let farAndNear = ThreadColorID(rawValue: "rust")

    /// Book A p97's arrow-feather sample: the middle two of each side one colour,
    /// the far and near two another, everything worked lengthwise plain.
    private var arrowFeatherColouring: [ThreadAssignment] {
        var colours = [Int: ThreadColorID]()
        for position in HiraGenjiBoardState.initial.north + HiraGenjiBoardState.initial.south {
            colours[position] = plainColour
        }
        for side in [HiraGenjiBoardState.initial.east, HiraGenjiBoardState.initial.west] {
            colours[side[0]] = farAndNear
            colours[side[3]] = farAndNear
            colours[side[1]] = middleOfTheSides
            colours[side[2]] = middleOfTheSides
        }
        return (1...16).map {
            ThreadAssignment(position: $0, colorID: colours[$0] ?? plainColour)
        }
    }

    private var plain: [ThreadAssignment] {
        (1...16).map {
            ThreadAssignment(
                position: $0,
                colorID: ThreadColorCatalog.colors[$0 % ThreadColorCatalog.colors.count].id
            )
        }
    }

    /// The colouring drawn in book A p96's starting diagram, read off the dots:
    /// face 1 west to east is mauve, mauve, black, vermilion, face 3 the same, and
    /// faces 2 and 4 all salmon.
    private var bookAP96Colouring: [ThreadAssignment] {
        var colours = [Int: ThreadColorID]()
        for (position, colour) in zip(
            HiraGenjiBoardState.initial.north,
            [mauve, mauve, black, vermilion]
        ) {
            colours[position] = colour
        }
        for (position, colour) in zip(
            HiraGenjiBoardState.initial.south,
            [mauve, mauve, black, vermilion]
        ) {
            colours[position] = colour
        }
        return (1...16).map {
            ThreadAssignment(position: $0, colorID: colours[$0] ?? salmon)
        }
    }

    /// Faces 1 and 3 plain; face 2 dark at its far and near threads and light in
    /// the middle two; face 4 the same with another pair of colours. This is the
    /// layout book A prints beside the sample.
    private var referenceColourVariant: [ThreadAssignment] {
        var colours = [Int: ThreadColorID]()
        for position in HiraGenjiBoardState.initial.north + HiraGenjiBoardState.initial.south {
            colours[position] = plainColour
        }
        for (position, colour) in zip(
            HiraGenjiBoardState.initial.west,
            ["green", "light-blue", "light-blue", "green"]
        ) {
            colours[position] = ThreadColorID(rawValue: colour)
        }
        for (position, colour) in zip(
            HiraGenjiBoardState.initial.east,
            ["yellow", "red", "red", "yellow"]
        ) {
            colours[position] = ThreadColorID(rawValue: colour)
        }
        return (1...16).map {
            ThreadAssignment(position: $0, colorID: colours[$0] ?? plainColour)
        }
    }
}
