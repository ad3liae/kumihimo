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
                method: BraidMethodCatalog.maruGenji16,
                crossSection: BraidMethodCatalog.maruGenji16CrossSection
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

    /// **The chord model against the shipped checkerboard.** Reported, not
    /// repaired.
    ///
    /// Each pair of neighbouring columns at one step along the braid is two
    /// threads that the drawing puts side by side, and the checkerboard makes
    /// their layers opposite. Where the chord model says those two threads have to
    /// pass each other, it also says which is on top; the two answers are compared
    /// here.
    ///
    /// The counts are the finding. They are pinned so that a change to either side
    /// shows up rather than passing quietly.
    @Test func theChordModelAndTheCheckerboardDisagreeOnHalfOfWhatTheyBothDecide() throws {
        let derivation = try derivation
        let cells = try tableCells
        let occupants = try occupants(derivation)

        var layerOfThread = [[Int]: BraidCrossingLayer]()
        var watched = [Int](repeating: 0, count: 8)
        for cell in cells {
            layerOfThread[[cell.threadPosition, cell.row]] = cell.layer
            if cell.row == 1 { watched[cell.column] = cell.threadPosition }
        }

        var over = [[Int]: Int]()
        for crossing in derivation.crossings {
            for meeting in crossing.meetings where meeting.layer == .over {
                over[[crossing.row, min(crossing.threadPosition, meeting.otherThread),
                      max(crossing.threadPosition, meeting.otherThread)]] =
                    crossing.threadPosition
            }
        }

        // Both the order the table was transcribed in and the order the derivation
        // gives, so the disagreement cannot be blamed on the column order.
        let ringOrder = [1, 4, 5, 8, 9, 12, 13, 16]
        for order in [watched, ringOrder] {
            var agree = 0
            var disagree = 0
            var neverMeet = 0
            for row in 1...8 {
                let boundary = ((1 - row) % 4 + 4) % 4
                let cycle = ((boundary - 1) % 4 + 4) % 4
                for column in 0..<8 {
                    let next = (column + 1) % 8
                    guard
                        let one = occupants[boundary][order[column]],
                        let other = occupants[boundary][order[next]],
                        let oneLayer = layerOfThread[[one, row]]
                    else {
                        continue
                    }
                    let tableSaysOver = oneLayer == .over ? one : other
                    let key = [cycle, min(one, other), max(one, other)]
                    guard let modelSaysOver = over[key] else { neverMeet += 1; continue }
                    if modelSaysOver == tableSaysOver { agree += 1 } else { disagree += 1 }
                }
            }
            #expect(agree == 16)
            #expect(disagree == 16)
            #expect(neverMeet == 32)
        }
    }

    /// **The check that comes before any photograph.** Followed along its own
    /// length, does each model give a thread a sequence a braid could have?
    ///
    /// The checkerboard does: every thread goes over, then under, then over. The
    /// chord model does not: it splits the sixteen threads into a group that is on
    /// top of nine of the ten crossings it makes in a repeat and a group that is
    /// underneath nine of ten, and the two groups never change places, because the
    /// east and west threads are moved at the third and fourth steps of every
    /// cycle and the north and south ones at the first and second.
    @Test func theCheckerboardAlternatesAlongEachThreadAndTheChordModelDoesNot() throws {
        let derivation = try derivation

        var overCount = [Int: Int]()
        var underCount = [Int: Int]()
        for crossing in derivation.crossings {
            for meeting in crossing.meetings {
                if meeting.layer == .over {
                    overCount[crossing.threadPosition, default: 0] += 1
                } else {
                    underCount[crossing.threadPosition, default: 0] += 1
                }
            }
        }
        for thread in 1...16 {
            let over = overCount[thread] ?? 0
            let under = underCount[thread] ?? 0
            #expect(over + under == 10, "thread \(thread)")
            #expect(min(over, under) == 1, "thread \(thread) is \(over)/\(under)")
        }
        // The lopsided group is exactly the east and west threads.
        let mostlyOver = Set((1...16).filter { (overCount[$0] ?? 0) > (underCount[$0] ?? 0) })
        #expect(mostlyOver == [3, 4, 5, 6, 11, 12, 13, 14])

        // The checkerboard, by contrast, turns every thread over and back.
        let cells = try tableCells
        for thread in 1...16 {
            let along = cells.filter { $0.threadPosition == thread }
                .sorted { $0.row < $1.row }
                .map(\.layer)
            #expect(along.count == 4, "thread \(thread)")
            #expect(zip(along, along.dropFirst()).allSatisfy { $0 != $1 }, "thread \(thread)")
        }
    }

    // MARK: - What the books can and cannot settle about the column order

    /// **Why no photograph in the books settles which way the eight columns run.**
    ///
    /// A colouring shows lengthwise stripes only when it gives one colour to each
    /// of the four courses a thread takes round the braid. The east-against-west
    /// difference between the two orders swaps two of those four and leaves the
    /// other two alone, so a colouring can only tell them apart when those two
    /// have different colours — and even then the two answers come out mirror
    /// images of each other, which a photograph reads the same way from either
    /// end.
    ///
    /// Every colouring the books print is checked here. Only one of them can
    /// distinguish the two orders at all, and it needs the direction along the
    /// braid; its photograph shows no end.
    @Test func onlyOneReferenceColouringCanTellTheTwoColumnOrdersApart() throws {
        let derivation = try derivation
        let occupants = try occupants(derivation)
        let ringOrder = [1, 4, 5, 8, 9, 12, 13, 16]
        let tableOrder = [16, 1, 12, 13, 8, 9, 4, 5]

        func grid(_ order: [Int], _ colours: [Int: ThreadColorID]) -> [[String]] {
            (1...4).map { row in
                let boundary = ((1 - row) % 4 + 4) % 4
                return order.map { position in
                    occupants[boundary][position].flatMap { colours[$0]?.rawValue } ?? "?"
                }
            }
        }
        func turned(_ g: [[String]], columns: Int, rows: Int) -> [[String]] {
            let byColumn = g.map { Array($0[columns...] + $0[..<columns]) }
            return Array(byColumn[rows...] + byColumn[..<rows])
        }
        func fromTheOtherEnd(_ g: [[String]]) -> [[String]] {
            g.reversed().map { $0.reversed() }
        }

        let samples: [(String, [ThreadAssignment], String)] = [
            ("book A p94", BraidReferenceColourings.bookAP94MaruGenji, "cannot"),
            ("book A p95 arrow feather", BraidReferenceColourings.bookAP95ArrowFeather, "cannot"),
            ("book A p95 vertical stripe", BraidReferenceColourings.bookAP95VerticalStripe,
             "needs the end"),
            ("book B a", BraidReferenceColourings.bookBMaruGenjiA, "cannot"),
            ("book B b", BraidReferenceColourings.bookBMaruGenjiB, "cannot"),
        ]
        for (name, assignments, expected) in samples {
            let colours = Dictionary(
                uniqueKeysWithValues: assignments.map { ($0.position, $0.colorID) }
            )
            let ring = grid(ringOrder, colours)
            let table = grid(tableOrder, colours)
            let sameWay = (0..<8).contains { c in
                (0..<4).contains { r in turned(ring, columns: c, rows: r) == table }
            }
            let otherEnd = (0..<8).contains { c in
                (0..<4).contains { r in
                    turned(fromTheOtherEnd(ring), columns: c, rows: r) == table
                }
            }
            let verdict = sameWay ? "cannot" : (otherEnd ? "needs the end" : "distinguishes")
            #expect(verdict == expected, "\(name): \(verdict)")
        }
    }

    /// A tube has no thread running along it to measure a face against, so the
    /// derivation says nothing about how a cell shows. **`nil`, not a default.**
    @Test func theDerivationDoesNotYetSayHowACellOfATubeShows() throws {
        let derivation = try derivation
        #expect(derivation.fold == nil)
        #expect(!derivation.cells.isEmpty)
        #expect(derivation.cells.allSatisfy { $0.layer == nil })
    }
}
