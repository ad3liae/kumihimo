import Foundation
import Testing
@testable import Kumihimo

/// The three published descriptions of 十六平源氏組, normalized and compared move
/// for move.
///
/// `HiraGenjiSimulation` was written from book A and checked against book C in
/// Task 005H. Book B had never been checked. Each source is read here on its own
/// terms — book B as a sequence of hand movements between the four faces of the
/// stand, book C as twenty-four numbered moves round a thirty-two slot disk — and
/// then reduced to the one thing they can be compared on: where each of the
/// sixteen threads ends up after one repeat.
struct HiraGenjiMoveRuleSourcesTests {
    // MARK: - Book B, read off the six diagrams on p72

    /// One cycle of book B, worked the way the diagrams show it: a face is a row
    /// of threads, a move lifts one or two of them out and puts them back
    /// somewhere else in another row.
    ///
    /// Nothing here consults `HiraGenjiSimulation`; that is the point.
    @Test func bookBWorkedByHandGivesTheSamePlacementAsTheImplementation() throws {
        let worked = Self.bookBCycle(from: .initial)
        let cycle = try #require(HiraGenjiSimulation.cycle(from: .initial))

        #expect(worked.north == cycle.endState.north)
        #expect(worked.east == cycle.endState.east)
        #expect(worked.south == cycle.endState.south)
        #expect(worked.west == cycle.endState.west)
    }

    /// Book B prints six steps and no repositioning; book A prints the same six
    /// and then a seventh that tidies every thread back onto its standard place.
    /// The tidy renames positions and moves no thread past another, so the two
    /// books describe one braid.
    @Test func bookBsSixStepsAreBookAsSixStepsInTheSameOrder() throws {
        let cycle = try #require(HiraGenjiSimulation.cycle(from: .initial))
        let kinds = cycle.moveEvents.map(\.kind)

        #expect(kinds == [
            .eastOuterToWestCenter,
            .westOuterToEastCenter,
            .southInnerToNorthCenter,
            .northInnerToSouthCenter,
            .southOuterToNorthOuter,
            .northOuterToSouthOuter,
        ])
        // What book B's arrows pick up, step by step: the two ends of a side, the
        // two ends of the other side, then the second-in threads and finally the
        // end threads of the near and far faces.
        let sources = cycle.moveEvents.map { $0.moves.map(\.sourceBoardPosition).sorted() }
        #expect(sources == [[3, 6], [11, 14], [8, 9], [1, 16], [7, 10], [2, 15]])
    }

    // MARK: - Book C, Fig.20

    /// The twenty-four moves run without ever sending a thread to an occupied
    /// slot, and they finish on the sixteen slots they started from. A misreading
    /// of the handwriting would almost certainly break one or the other.
    @Test func bookCsTwentyFourMovesRunCleanlyAndCloseOnThemselves() throws {
        let (occupied, faults) = Self.bookCCycle()

        #expect(faults.isEmpty)
        #expect(Set(occupied.keys) == Set(Self.diskToApp.keys))
    }

    /// Where each thread ends up, compared thread by thread. This is the check
    /// Task 005H made; it is repeated here so the three-way comparison stands in
    /// one place.
    @Test func bookCAgreesWithTheImplementationOnEveryThread() throws {
        let cycle = try #require(HiraGenjiSimulation.cycle(from: .initial))
        let implementation = Self.permutation(of: cycle.endState)
        let bookC = try Self.bookCPermutation()

        #expect(implementation.count == 16)
        #expect(bookC == implementation)
    }

    /// The twelve braiding moves, one at a time. Book C works both sides of a pair
    /// in one printed row, so its first three rows are book A and book B's six
    /// steps; its last three rows are the tidy book A prints as step 7.
    @Test func theTwelveBraidingMovesLineUpOneForOne() throws {
        let cycle = try #require(HiraGenjiSimulation.cycle(from: .initial))
        let landing = Self.landingSlots(of: cycle.endState)
        let bookC = try Self.bookCPermutation()

        var checked = 0
        for (row, moves) in Self.bookCMethod.prefix(3).enumerated() {
            let expectedKinds = [
                [HiraGenjiMoveKind.eastOuterToWestCenter, .westOuterToEastCenter],
                [.southInnerToNorthCenter, .northInnerToSouthCenter],
                [.southOuterToNorthOuter, .northOuterToSouthOuter],
            ][row]
            let sourcesInThisRow = Set(moves.compactMap { Self.diskToApp[$0.from] })
            let sourcesInThoseSteps = Set(cycle.moveEvents
                .filter { expectedKinds.contains($0.kind) }
                .flatMap { $0.moves.map(\.sourceBoardPosition) })
            #expect(sourcesInThisRow == sourcesInThoseSteps)

            for move in moves {
                let source = try #require(Self.diskToApp[move.from])
                #expect(bookC[source] == landing[source])
                checked += 1
            }
        }
        #expect(checked == 12)
    }

    // MARK: - Book B worked by hand

    private static func bookBCycle(from state: HiraGenjiBoardState) -> HiraGenjiBoardState {
        var north = state.north
        var east = state.east
        var south = state.south
        var west = state.west

        // 1  The far and near threads of the right-hand side, into the middle of
        //    the left-hand side. The far one stays the far one.
        let (eastWithoutEnds, eastFar, eastNear) = takingBothEnds(east)
        east = eastWithoutEnds
        west = insertingIntoTheMiddle(west, eastFar, eastNear)

        // 2  The same the other way.
        let (westWithoutEnds, westFar, westNear) = takingBothEnds(west)
        west = westWithoutEnds
        east = insertingIntoTheMiddle(east, westFar, westNear)

        // 3  The second thread in from each end of the near face, into the middle
        //    of the far face.
        let (southWithoutInner, southLeft, southRight) = takingBothSecondIn(south)
        south = southWithoutInner
        north = insertingIntoTheMiddle(north, southLeft, southRight)

        // 4  The same the other way.
        let (northWithoutInner, northLeft, northRight) = takingBothSecondIn(north)
        north = northWithoutInner
        south = insertingIntoTheMiddle(south, northLeft, northRight)

        // 5  The end threads of the near face, to just inside the end threads of
        //    the far face.
        let (southWithoutEnds, southFarLeft, southFarRight) = takingBothEnds(south)
        south = southWithoutEnds
        north = insertingJustInsideTheEnds(north, southFarLeft, southFarRight)

        // 6  The end threads of the far face, to the ends of the near face.
        let (northWithoutEnds, northFarLeft, northFarRight) = takingBothEnds(north)
        north = northWithoutEnds
        south = insertingAtTheEnds(south, northFarLeft, northFarRight)

        return HiraGenjiBoardState(north: north, east: east, south: south, west: west)
    }

    private static func takingBothEnds(_ face: [Int]) -> ([Int], Int, Int) {
        (Array(face.dropFirst().dropLast()), face[0], face[face.count - 1])
    }

    private static func takingBothSecondIn(_ face: [Int]) -> ([Int], Int, Int) {
        var remaining = face
        let right = remaining.remove(at: remaining.count - 2)
        let left = remaining.remove(at: 1)
        return (remaining, left, right)
    }

    private static func insertingIntoTheMiddle(_ face: [Int], _ first: Int, _ second: Int) -> [Int] {
        let middle = face.count / 2
        return Array(face[..<middle]) + [first, second] + Array(face[middle...])
    }

    private static func insertingJustInsideTheEnds(
        _ face: [Int], _ first: Int, _ second: Int
    ) -> [Int] {
        [face[0], first] + face.dropFirst().dropLast() + [second, face[face.count - 1]]
    }

    private static func insertingAtTheEnds(_ face: [Int], _ first: Int, _ second: Int) -> [Int] {
        [first] + face + [second]
    }

    // MARK: - Book C worked as printed

    /// Fig.20's `method`, read left to right and top to bottom. Slots are the
    /// disk's own thirty-two, so a move may park a thread on a slot no thread
    /// starts on; the last three rows walk them all back.
    private static let bookCMethod: [[(from: Int, to: Int)]] = [
        [(9, 28), (14, 27), (30, 11), (25, 12)],
        [(18, 4), (21, 3), (5, 18), (2, 21)],
        [(17, 5), (22, 2), (6, 17), (1, 22)],
        [(29, 30), (28, 29), (26, 25), (27, 26)],
        [(10, 9), (11, 10), (13, 14), (12, 13)],
        [(2, 1), (3, 2), (5, 6), (4, 5)],
    ]

    /// The sixteen disk slots that carry a thread, and the app board position each
    /// stands for. From the Task 005H reading of Fig.20's starting diagram.
    private static let diskToApp: [Int: Int] = [
        1: 15, 2: 16, 5: 1, 6: 2, 9: 3, 10: 4, 13: 5, 14: 6,
        17: 7, 18: 8, 21: 9, 22: 10, 25: 11, 26: 12, 29: 13, 30: 14,
    ]

    /// Runs the twenty-four moves. Returns which thread sits on which disk slot at
    /// the end, and anything that went wrong on the way.
    private static func bookCCycle() -> (occupied: [Int: Int], faults: [String]) {
        var occupied = Dictionary(uniqueKeysWithValues: diskToApp.keys.map { ($0, $0) })
        var faults = [String]()

        for (row, moves) in bookCMethod.enumerated() {
            for move in moves {
                guard let thread = occupied[move.from] else {
                    faults.append("row \(row + 1): nothing on slot \(move.from)")
                    continue
                }
                guard occupied[move.to] == nil else {
                    faults.append("row \(row + 1): slot \(move.to) already taken")
                    continue
                }
                occupied[move.from] = nil
                occupied[move.to] = thread
            }
        }
        return (occupied, faults)
    }

    /// Book C's cycle as a map from starting board position to finishing board
    /// position, in the app's own numbering.
    private static func bookCPermutation() throws -> [Int: Int] {
        let (occupied, faults) = bookCCycle()
        #expect(faults.isEmpty)
        var permutation = [Int: Int]()
        for (slot, startedOn) in occupied {
            let from = try #require(diskToApp[startedOn])
            let to = try #require(diskToApp[slot])
            permutation[from] = to
        }
        return permutation
    }

    // MARK: - Shared

    private static func permutation(of endState: HiraGenjiBoardState) -> [Int: Int] {
        let before = HiraGenjiBoardState.initial.boardPositionsByThread
        let after = endState.boardPositionsByThread
        return before.reduce(into: [Int: Int]()) { result, entry in
            result[entry.value] = after[entry.key]
        }
    }

    private static func landingSlots(of endState: HiraGenjiBoardState) -> [Int: Int] {
        permutation(of: endState)
    }
}
