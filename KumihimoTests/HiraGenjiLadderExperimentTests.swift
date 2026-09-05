import Foundation
import Testing
@testable import Kumihimo

/// Book A p97's second sample, run as a controlled experiment.
///
/// The caption says: give the far group and the near group different colours and
/// the braid comes out with a ladder whose colours reverse between the two faces.
/// Far and near are faces 1 and 3 of the stand — the threads worked along the
/// braid — so the sample is a statement about their path and nothing else. The
/// prediction was not put into the model; it falls out of the move rules and the
/// cross-section read from p96.
///
/// This is the third such experiment. The first showed that colouring only the
/// threads carried across leaves the middle of the face plain (they never
/// surface there); the second was the arrow feather. Each one holds a different
/// part of the derivation still.
@MainActor
struct HiraGenjiLadderExperimentTests {
    private var pattern: HiraGenjiWeavePattern {
        get throws {
            try #require(HiraGenjiWeavePatternGenerator.generate(
                assignments: ProjectEditorPreviewData.hiraGenjiSurfaceLadder
            ))
        }
    }

    private func colours(
        _ pattern: HiraGenjiWeavePattern,
        _ face: HiraGenjiBraidFace,
        row: Int
    ) -> [String] {
        (0..<pattern.columnCount).map { column in
            pattern.patches.first {
                $0.face == face && $0.row == row && $0.column == column
            }?.colorID.rawValue ?? "?"
        }
    }

    /// A rung, not a stripe: one row of the face is all one colour across every
    /// column a lengthwise thread holds.
    @Test func eachRowOfTheFaceIsOneColourRightAcross() throws {
        let pattern = try pattern
        let middle = pattern.lengthwiseColumns.sorted()

        #expect(middle == [1, 2, 3, 4])
        for face in HiraGenjiBraidFace.allCases {
            for row in 0..<pattern.rowCount {
                let line = colours(pattern, face, row: row)
                let rung = middle.map { line[$0] }
                #expect(Set(rung).count == 1)
                #expect(rung[0] == "brown" || rung[0] == "yellow")
            }
        }
    }

    /// The rungs alternate along the braid, which is what makes it a ladder
    /// rather than one long band.
    @Test func theRungsAlternateAlongTheBraid() throws {
        let pattern = try pattern
        for face in HiraGenjiBraidFace.allCases {
            let rungs = (0..<pattern.rowCount).map { colours(pattern, face, row: $0)[2] }
            for (earlier, later) in zip(rungs, rungs.dropFirst()) {
                #expect(earlier != later)
            }
        }
    }

    /// **The claim the sample is for.** Every rung shows the other colour on the
    /// other face, at the same step along the braid.
    @Test func theColoursReverseBetweenTheTwoFaces() throws {
        let pattern = try pattern
        for row in 0..<pattern.rowCount {
            let front = colours(pattern, .front, row: row)
            let back = colours(pattern, .back, row: row)
            for column in pattern.lengthwiseColumns.sorted() {
                #expect(front[column] != back[column])
                #expect(Set([front[column], back[column]]) == ["brown", "yellow"])
            }
        }
    }

    /// The third colour never reaches the middle of a face. The threads carried
    /// across pass under every lengthwise thread, so the ladder cannot be coming
    /// from them — the experiment answers only the question asked.
    @Test func theThreadsCarriedAcrossStayOutOfTheMiddle() throws {
        let pattern = try pattern
        let middle = pattern.lengthwiseColumns
        #expect(pattern.patches.allSatisfy { patch in
            patch.colorID.rawValue != "white" || !middle.contains(patch.column)
        })
        // And they are the only thing at the two outer columns.
        for face in HiraGenjiBraidFace.allCases {
            for row in 0..<pattern.rowCount {
                let line = colours(pattern, face, row: row)
                #expect(line[0] == "white")
                #expect(line[pattern.columnCount - 1] == "white")
            }
        }
    }
}
