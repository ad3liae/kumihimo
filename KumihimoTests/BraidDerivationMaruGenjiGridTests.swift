import Foundation
import Testing
@testable import Kumihimo

/// Task 020 stage 1, the round braid: what the move table says, held against the
/// sixty-four-cell correspondence Task 004 transcribed from a reference colouring
/// page.
///
/// **The table was never derived.** It was copied by hand, and what the
/// photographs checked was the finished look, not the table. So a disagreement
/// here does not by itself convict the derivation — it may convict the table. Both
/// are recorded, and which is right is settled by the photographs and the author's
/// own braids, not here.
@MainActor
struct BraidDerivationMaruGenjiGridTests {
    private var derivation: BraidDerivation {
        get throws {
            try #require(BraidDerivation.derive(
                stand: BraidMethodCatalog.stand16,
                method: BraidMethodCatalog.maruGenji16
            ))
        }
    }

    /// One cell of the transcribed table, recovered from the shipped patches.
    private struct TableCell {
        let column: Int
        let row: Int
        let threadPosition: Int
        let layer: BraidCrossingLayer
    }

    private var tableCells: [TableCell] {
        get throws {
            let plain = (1...16).map {
                ThreadAssignment(position: $0, colorID: ThreadColorID(rawValue: "white"))
            }
            let pattern = try #require(MaruGenjiSurfacePatternGenerator.generate(assignments: plain))
            return pattern.patches.map { patch in
                let rises = patch.corners[2].y > patch.corners[1].y
                return TableCell(
                    column: Int((patch.corners[0].x * 8).rounded()),
                    row: Int((patch.corners[0].y * 8).rounded()) + (rises ? 1 : 0),
                    threadPosition: patch.threadPosition,
                    layer: patch.layer
                )
            }
        }
    }

    /// Where a thread stands at each cycle boundary of one repeat.
    private func occupants(_ derivation: BraidDerivation) throws -> [[Int: Int]] {
        var state = BraidStandState.start(on: derivation.stand)
        var result = [[Int: Int]]()
        for _ in 0..<derivation.repeatCycleCount {
            result.append(try #require(state.threadByPosition))
            state = try #require(
                BraidWorking.cycle(of: derivation.method, from: state)
            ).endState
        }
        return result
    }

    @Test func theTranscribedTableIsEightColumnsAndFourRowsDrawnTwice() throws {
        let cells = try tableCells
        #expect(cells.count == 64)
        #expect(Set(cells.map(\.column)) == Set(0...7))
        #expect(Set(cells.map(\.row)) == Set(1...8))

        var byPlace = [String: Int]()
        for cell in cells { byPlace["\(cell.column),\(cell.row)"] = cell.threadPosition }
        #expect(byPlace.count == 64)
        // The second four rows are the first four again, so the table's own repeat
        // is four rows — the same as the four cycles the stand takes to come back.
        for column in 0...7 {
            for row in 1...4 {
                #expect(byPlace["\(column),\(row)"] == byPlace["\(column),\(row + 4)"])
            }
        }
    }

    /// **Agreement, cell by cell.** Each of the eight columns is one of the pairs
    /// the closing step joins, and what it shows at each row is the thread standing
    /// at that pair's closing-move source. All sixty-four.
    @Test func everyCellOfTheTableIsTheThreadTheMoveTablePutsThere() throws {
        let derivation = try derivation
        let occupants = try occupants(derivation)
        let cells = try tableCells

        // Which board position each table column watches, read off the table.
        var watched = [Int: Int]()
        for cell in cells where cell.row == 1 { watched[cell.column] = cell.threadPosition }
        #expect(watched.count == 8)

        // Those are exactly the sources of the closing step's moves.
        let closingSources = Set(BraidMethodCatalog.maruGenji16.closing.moves.map(\.from))
        #expect(Set(watched.values) == closingSources)

        var compared = 0
        var disagreements = [String]()
        for cell in cells {
            guard let position = watched[cell.column] else { continue }
            let boundary = ((1 - cell.row) % 4 + 4) % 4
            let expected = occupants[boundary][position]
            if expected != cell.threadPosition {
                disagreements.append(
                    "c\(cell.column) r\(cell.row): table \(cell.threadPosition), derived \(expected ?? -1)"
                )
            }
            compared += 1
        }
        #expect(compared == 64)
        #expect(disagreements.isEmpty, "\(disagreements)")
    }

    /// **The one disagreement, stated as a fact rather than repaired.**
    ///
    /// The eight columns the table watches are eight board positions, and their
    /// order across the drawing is not any rotation or reflection of the stand's
    /// ring: inside each of the four blocks the two columns run one way round the
    /// stand, and the four blocks run the other. No unrolling of a tube does that,
    /// so the drawing's blocks and its columns cannot both be right.
    @Test func theTablesColumnsAreNotInAnyOrderTheRingCanBe() throws {
        let cells = try tableCells
        var watched = [Int](repeating: 0, count: 8)
        for cell in cells where cell.row == 1 { watched[cell.column] = cell.threadPosition }
        #expect(watched == [16, 1, 12, 13, 8, 9, 4, 5])

        // Inside a block, the step round the ring is +1; between blocks it is -5.
        let steps = (0..<8).map { index -> Int in
            let step = (watched[(index + 1) % 8] - watched[index] + 16) % 16
            return step > 8 ? step - 16 : step
        }
        #expect(steps == [1, -5, 1, -5, 1, -5, 1, -5])

        // A rotation or a reflection of the ring keeps one step throughout.
        #expect(Set(steps).count > 1)
    }

    /// **Why the photographs could not catch it.** The disagreement is exactly the
    /// swap of the east and west blocks, and all three colourings Task 004 checked
    /// against real braids are unchanged by that swap. They are the wrong
    /// experiment for this question, so a new colouring is needed before anyone
    /// decides which of the two is right.
    @Test func taskZeroZeroFoursThreeColouringsCannotTellTheTwoOrdersApart() throws {
        // The swap: east positions 3, 4, 5, 6 against west positions 11, 12, 13, 14,
        // each keeping its place inside its block.
        func swapped(_ position: Int) -> Int {
            switch position {
            case 3...6: return position + 8
            case 11...14: return position - 8
            default: return position
            }
        }
        let fixtures: [(String, [ThreadAssignment])] = [
            ("fixture 1", ProjectEditorPreviewData.maruGenjiSurfaceFixture1),
            ("fixture 2", ProjectEditorPreviewData.maruGenjiSurfaceFixture2),
            ("fixture 3", ProjectEditorPreviewData.maruGenjiSurfaceFixture3),
        ]
        for (name, fixture) in fixtures {
            let byPosition = Dictionary(
                uniqueKeysWithValues: fixture.map { ($0.position, $0.colorID) }
            )
            let colourGroups = Set(byPosition.values)
            let swappedGrouping = Set(colourGroups.map { colour in
                Set(byPosition.filter { $0.value == colour }.keys.map(swapped))
            })
            let grouping = Set(colourGroups.map { colour in
                Set(byPosition.filter { $0.value == colour }.keys)
            })
            #expect(swappedGrouping == grouping, "\(name) tells the two orders apart")
        }
    }

    /// **What the derivation does not say.** Over and under on a round braid does
    /// not follow from the order of the moves the way it does on a flat one: the
    /// threads that meet there were moved in the same step, so the table is silent
    /// about which was laid on which. The shipped checkerboard is an invention, and
    /// its own comment says so.
    @Test func theMoveOrderDoesNotSettleOverAndUnderOnTheRoundBraid() throws {
        let derivation = try derivation
        #expect(derivation.crossings.isEmpty)

        // Both threads of every column-defining pair are moved at the same instant,
        // so "the one moved later lies over" has no answer for them.
        let closing = BraidMethodCatalog.maruGenji16.closing
        #expect(closing.moves.count == 8)
        let cells = try tableCells
        let layers = Set(cells.map(\.layer))
        #expect(layers == Set(BraidCrossingLayer.allCases))
    }
}
