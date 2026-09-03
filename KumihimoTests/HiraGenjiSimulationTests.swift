import Testing
@testable import Kumihimo

struct HiraGenjiSimulationTests {
    @Test func presetDescribesItsFlatProfileAndVerificationState() throws {
        #expect(BraidPresetCatalog.hiraGenji.verificationLevel == .referenceSurface)
        guard case .flat(let ratio) = BraidPresetCatalog.hiraGenji.crossSectionProfile else {
            Issue.record("平源氏には平紐の断面プロファイルが必要です")
            return
        }
        #expect((4...8).contains(ratio))
        #expect(BraidPresetCatalog.availablePresets(threadCount: 8).contains(
            BraidPresetCatalog.hiraGenji
        ) == false)
        #expect(BraidPresetCatalog.availablePresets(threadCount: 16).contains(
            BraidPresetCatalog.hiraGenji
        ))
    }

    @Test func sixDocumentedMovesUseTheNormalizedBoardPositions() throws {
        let cycle = try #require(HiraGenjiSimulation.cycle(from: .initial))

        #expect(cycle.moveEvents.map(\.kind) == HiraGenjiMoveKind.allCases)
        #expect(cycle.moveEvents.map(\.movingThreadPositions) == [
            [3, 6], [14, 11], [9, 8], [16, 1], [10, 7], [15, 2],
        ])
        #expect(cycle.moveEvents.map { $0.moves.map(\.sourceBoardPosition) } == [
            [3, 6], [14, 11], [9, 8], [16, 1], [10, 7], [15, 2],
        ])
        #expect(cycle.moveEvents.map { $0.moves.map(\.destinationBoardPosition) } == [
            [13, 12], [4, 5], [16, 1], [9, 8], [15, 2], [10, 7],
        ])
    }

    @Test func stepSevenIsSeparateAndProducesTheDocumentedEndState() throws {
        let cycle = try #require(HiraGenjiSimulation.cycle(from: .initial))

        #expect(cycle.moveEvents.count == 6)
        #expect(cycle.endRepositioning.moves.map(\.threadPosition) == [4, 5, 13, 12])
        #expect(cycle.endRepositioning.moves.map(\.sourceBoardPosition) == [4, 5, 13, 12])
        #expect(cycle.endRepositioning.moves.map(\.destinationBoardPosition) == [3, 6, 14, 11])
        #expect(cycle.endState.north == [10, 9, 8, 7])
        #expect(cycle.endState.south == [15, 16, 1, 2])
        #expect(cycle.endState.east == [4, 14, 11, 5])
        #expect(cycle.endState.west == [13, 3, 6, 12])
    }

    @Test func oneAndManyCyclesPreserveEveryThreadDeterministically() {
        let first = HiraGenjiSimulation.boardStates(cycleCount: 20)
        let second = HiraGenjiSimulation.boardStates(cycleCount: 20)

        #expect(first == second)
        #expect(first.count == 21)
        #expect(first.allSatisfy { $0.threadPositions.sorted() == Array(1...16) })
    }

    @Test func malformedBoardStateFailsSafely() {
        var duplicate = HiraGenjiBoardState.initial
        duplicate.north[0] = duplicate.north[1]
        var missingSlot = HiraGenjiBoardState.initial
        missingSlot.west.removeLast()

        #expect(HiraGenjiSimulation.cycle(from: duplicate) == nil)
        #expect(HiraGenjiSimulation.cycle(from: missingSlot) == nil)
    }
}
