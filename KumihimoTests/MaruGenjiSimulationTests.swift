import Foundation
import Testing
@testable import Kumihimo

struct MaruGenjiSimulationTests {
    @Test func presetIsAvailableOnlyForSixteenThreads() {
        #expect(BraidPresetCatalog.availablePresets(threadCount: 4).isEmpty)
        #expect(BraidPresetCatalog.availablePresets(threadCount: 8).isEmpty)
        #expect(BraidPresetCatalog.availablePresets(threadCount: 12).isEmpty)
        #expect(
            BraidPresetCatalog.availablePresets(threadCount: 16)
                == [BraidPresetCatalog.maruGenji]
        )
    }

    @Test func oneCycleExchangesOuterPairsWhilePreservingAllThreads() {
        let next = MaruGenjiSimulation.nextCycle(from: .initial)

        #expect(next.north == [16, 10, 7, 1])
        #expect(next.east == [4, 14, 11, 5])
        #expect(next.south == [9, 15, 2, 8])
        #expect(next.west == [13, 3, 6, 12])
        #expect(next.threadPositions.sorted() == Array(1...16))
    }

    @Test func repeatedCyclesAreDeterministicAndKeepEveryThread() {
        let firstRun = MaruGenjiSimulation.boardStates(cycleCount: 12)
        let secondRun = MaruGenjiSimulation.boardStates(cycleCount: 12)

        #expect(firstRun == secondRun)
        #expect(firstRun.count == 13)
        #expect(firstRun.allSatisfy { $0.threadPositions.sorted() == Array(1...16) })
    }

    @Test func pathGeneratorKeepsAssignmentColorsAndProducesFinitePoints() throws {
        let assignments = (1...16).map { position in
            ThreadAssignment(
                position: position,
                colorID: ThreadColorCatalog.colors[(position - 1) % ThreadColorCatalog.colors.count].id
            )
        }

        let paths = MaruGenjiPathGenerator.generate(
            assignments: assignments,
            cycleCount: 3,
            samplesPerCycle: 4
        )

        #expect(paths.count == 16)
        #expect(paths.allSatisfy { $0.points.count == 13 })
        #expect(paths.allSatisfy { path in
            path.points.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }
        })
        for path in paths {
            let assignment = try #require(assignments.first { $0.position == path.threadPosition })
            #expect(path.colorID == assignment.colorID)
        }
    }

    @Test func tubeMeshHasExpectedVerticesNormalsAndTriangles() throws {
        let points = [
            SIMD3<Float>(-1, 0, 0),
            SIMD3<Float>(0, 0.2, 0),
            SIMD3<Float>(1, 0, 0),
        ]

        let mesh = try #require(
            MaruGenjiTubeMeshGenerator.generate(points: points, sideCount: 6)
        )

        #expect(mesh.positions.count == 18)
        #expect(mesh.normals.count == 18)
        #expect(mesh.triangleIndices.count == 72)
        #expect(mesh.normals.allSatisfy { abs(length($0) - 1) < 0.001 })
    }

    private func length(_ vector: SIMD3<Float>) -> Float {
        sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    }
}
