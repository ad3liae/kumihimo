import Foundation
import Testing
@testable import Kumihimo

/// Task 020 stage 1: what a stand and a table of moves say about the braid, with
/// nothing in the working-out that knows the name of a braid.
///
/// The two Genji braids are inputs here, not subjects. Everything asserted is
/// either a figure an earlier task measured or derived and wrote down, or a
/// structural claim that holds for any braid.
struct BraidDerivationTests {
    private var stand: BraidStand { BraidMethodCatalog.stand16 }

    private var hira: BraidDerivation {
        get throws {
            try #require(BraidDerivation.derive(
                stand: stand,
                method: BraidMethodCatalog.hiraGenji16,
                crossSection: BraidMethodCatalog.hiraGenji16CrossSection
            ))
        }
    }

    private var maru: BraidDerivation {
        get throws {
            try #require(BraidDerivation.derive(
                stand: stand,
                method: BraidMethodCatalog.maruGenji16,
                crossSection: BraidMethodCatalog.maruGenji16CrossSection
            ))
        }
    }

    // MARK: - The stand and the tables

    @Test func theStandIsARingOfSixteenPositionsAndNothingElseIsUsed() {
        #expect(stand.isWellFormed)
        #expect(stand.positionCount == 16)
        #expect(stand.positionIDs == Array(1...16))
        // A position's number is its place round the rim, which is what the two
        // move tables are written against.
        for id in 1...16 {
            #expect(stand.rimIndex(ofPositionID: id) == id - 1)
        }
    }

    /// **The end of a cycle is worked out, never written down.** Both older
    /// per-braid tables wrote it by hand beside the moves, so the same fact had two
    /// sources and nothing checked they agreed. These assert the worked answer
    /// against the hand-written one.
    @Test func theWorkedEndOfACycleIsTheOneTheOlderTableWroteByHand() throws {
        var hiraState = HiraGenjiBoardState.initial
        var maruState = MaruGenjiBoardState.initial
        var generalHira = BraidStandState.start(on: stand)
        var generalMaru = BraidStandState.start(on: stand)

        for _ in 0..<4 {
            let hiraCycle = try #require(HiraGenjiSimulation.cycle(from: hiraState))
            let maruCycle = try #require(MaruGenjiSimulation.cycle(from: maruState))
            hiraState = hiraCycle.endState
            maruState = maruCycle.endState

            generalHira = try #require(
                BraidWorking.cycle(of: BraidMethodCatalog.hiraGenji16, from: generalHira)
            ).endState
            generalMaru = try #require(
                BraidWorking.cycle(of: BraidMethodCatalog.maruGenji16, from: generalMaru)
            ).endState

            #expect(generalHira.threadByPosition == hiraState.boardPositionsByThread.inverted)
            #expect(generalMaru.threadByPosition == maruState.boardPositionsByThread.inverted)
        }
    }

    @Test func bothBraidsComeBackToTheirStartAfterFourCycles() throws {
        #expect(try hira.repeatCycleCount == 4)
        #expect(try maru.repeatCycleCount == 4)
        #expect(try hira.instantsPerCycle == 7)
        #expect(try maru.instantsPerCycle == 5)
    }

    @Test func everyThreadIsMovedExactlyOnceInEveryCycle() throws {
        for method in [BraidMethodCatalog.hiraGenji16, BraidMethodCatalog.maruGenji16] {
            let cycles = try #require(BraidWorking.cycles(of: method, on: stand, count: 4))
            for cycle in cycles {
                #expect(Set(cycle.allCarried.map(\.thread)) == Set(1...16))
                #expect(cycle.allCarried.count == 16)
            }
        }
    }

    // MARK: - Hira-genji: eight along, eight across

    @Test func hiraGenjiHasEightThreadsRunningAlongAndEightCarriedAcross() throws {
        let derivation = try hira
        #expect(derivation.threadsRunningAlongTheBraid == [1, 2, 7, 8, 9, 10, 15, 16])
        #expect(derivation.threadsCarriedAcrossTheBraid == [3, 4, 5, 6, 11, 12, 13, 14])
    }

    /// The ring folds, and where it folds is worked out rather than declared: the
    /// threads running along the braid pair the slots through its thickness, those
    /// pairs are a reflection of the ring, and the reflection's axis is the edge.
    @Test func hiraGenjiFoldsIntoSixColumnsWithTwoThreadsAtEachEdge() throws {
        let derivation = try hira
        let fold = try #require(derivation.fold)
        #expect(fold.columnCount == 6)
        #expect(fold.turningSlots.count == 4)

        let turningPositions = fold.turningSlots
            .compactMap { derivation.crossSection.positionID(atSlot: $0) }
            .sorted()
        #expect(turningPositions == [4, 5, 12, 13])
    }

    /// A thread carried across never surfaces in the middle of a face: it passes
    /// under every column a lengthwise thread holds. Book A p97's own sample is
    /// what this reproduces — colour the sideways threads and the body stays plain.
    @Test func nothingCarriedAcrossShowsInTheMiddleOfTheFace() throws {
        let derivation = try hira
        #expect(derivation.columnsHeldLengthwise == [1, 2, 3, 4])
        #expect(derivation.crossings.count == 16)
        for crossing in derivation.crossings {
            #expect(Set(crossing.passedWidths).isSuperset(of: [1, 2, 3, 4]))
            #expect(crossing.layerAgainstThreadsRunningAlong == .under)
        }
    }

    /// **The side taken at a crossing comes out of the order of the moves.** The
    /// threads carried across are moved at the first and second steps and the ones
    /// running along at the third to the sixth, so the second group is laid on the
    /// first.
    @Test func theSideTakenAtACrossingComesFromTheOrderOfTheMoves() throws {
        let derivation = try hira
        for crossing in derivation.crossings {
            let course = try #require(derivation.course(ofThread: crossing.threadPosition))
            #expect(course.layingInstants[crossing.row] <= 2)
            for meeting in crossing.meetingsWithThreadsRunningAlong {
                let other = try #require(derivation.course(ofThread: meeting.otherThread))
                #expect(other.layingInstants[crossing.row] >= 3)
                #expect(meeting.layer == .under)
            }
        }
    }

    /// The figures Task 007G derived from the move order, reproduced by code that
    /// does not know which braid it is looking at.
    @Test func theArrivalPhasesAreTheOnesTaskZeroZeroSevenGDerived() throws {
        let derivation = try hira
        let seventh = 1.0 / 7
        #expect(derivation.arrivalPhase(atWidth: -1) == 1 * seventh)
        #expect(derivation.arrivalPhase(atWidth: 6) == 2 * seventh)
        #expect(derivation.arrivalPhase(atWidth: 1) == 3.5 * seventh)
        #expect(derivation.arrivalPhase(atWidth: 4) == 3.5 * seventh)
        #expect(derivation.arrivalPhase(atWidth: 2) == 5.5 * seventh)
        #expect(derivation.arrivalPhase(atWidth: 3) == 5.5 * seventh)
        #expect(derivation.arrivalPhase(atWidth: 0) == 7 * seventh)
        #expect(derivation.arrivalPhase(atWidth: 5) == 7 * seventh)
    }

    // MARK: - Maru-genji: a tube

    /// No thread keeps to one place across the width, so nothing pairs the slots
    /// through a thickness, so there is no fold. **A tube is what the derivation
    /// says, and it says it by finding nothing rather than by being told.**
    @Test func maruGenjiHasNoThreadRunningAlongAndSoStaysATube() throws {
        let derivation = try maru
        #expect(derivation.threadsRunningAlongTheBraid.isEmpty)
        #expect(derivation.threadsCarriedAcrossTheBraid == Array(1...16))
        #expect(derivation.fold == nil)
        #expect(derivation.isFlat == false)
        #expect(derivation.crossSection.source == .standRim)
        #expect(derivation.crossSection.isDeclared == false)
        // The ring is the working answer, and it says so: which way round the
        // eight columns go is still open against Task 004's transcribed table.
        #expect(derivation.crossSection.isSettled == false)
        #expect(BraidMethodCatalog.hiraGenji16CrossSection.isSettled)
    }

    /// **Eight, derived.** The closing step carries each of eight threads one slot
    /// along the ring, and between them the eight moves cover all sixteen slots.
    /// Each of those pairs is one column of the finished braid.
    @Test func maruGenjiShowsEightColumnsAndTheyComeOutOfTheClosingStep() throws {
        let derivation = try maru
        #expect(derivation.faceColumnCount == 8)
        let columns = try #require(derivation.faceColumns)
        let positions = columns.map { slots in
            slots.compactMap { derivation.crossSection.positionID(atSlot: $0) }
        }
        #expect(positions == [
            [1, 2], [3, 4], [5, 6], [7, 8],
            [9, 10], [11, 12], [13, 14], [15, 16],
        ])
    }

    /// A flat braid's closing only tidies its edges, so it says nothing about
    /// columns; those come from the fold instead. The two routes do not collide.
    @Test func hiraGenjiTakesItsColumnsFromTheFoldAndNotFromTheClosing() throws {
        #expect(try hira.faceColumns == nil)
        #expect(try hira.fold?.columnCount == 6)
    }

    // MARK: - Refusing rather than guessing

    @Test func malformedInputsFailSafely() {
        let otherStand = BraidStands.round(id: "round-8", positionCount: 8)
        #expect(BraidDerivation.derive(
            stand: otherStand, method: BraidMethodCatalog.hiraGenji16
        ) == nil)

        let neverReturns = BraidMethod(
            id: "never", standID: BraidMethodCatalog.stand16.id,
            steps: [BraidStep(name: "one", moves: [BraidMove(from: 1, to: 2)])],
            closing: BraidStep(name: "closing", moves: [])
        )
        #expect(BraidDerivation.derive(
            stand: BraidMethodCatalog.stand16, method: neverReturns
        ) == nil)
    }
}

private extension [Int: Int] {
    var inverted: [Int: Int] {
        Dictionary(uniqueKeysWithValues: map { ($0.value, $0.key) })
    }
}
