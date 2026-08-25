import Foundation
import simd
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

    @Test func oneCycleKeepsTheFourOrderedMoveEvents() throws {
        let cycle = try #require(MaruGenjiSimulation.cycle(from: .initial))

        #expect(cycle.moveEvents.map(\.kind) == [
            .southToNorth,
            .northToSouth,
            .eastToWest,
            .westToEast,
        ])
        #expect(cycle.moveEvents.map(\.movingThreadPositions) == [
            [10, 7],
            [15, 2],
            [3, 6],
            [14, 11],
        ])
        #expect(cycle.moveEvents.map { $0.moves.map(\.sourceBoardPosition) } == [
            [10, 7],
            [15, 2],
            [3, 6],
            [14, 11],
        ])
        #expect(cycle.moveEvents.map { $0.moves.map(\.destinationBoardPosition) } == [
            [16, 1],
            [9, 8],
            [13, 12],
            [4, 5],
        ])
        #expect(cycle.moveEvents.allSatisfy { event in
            event.moves.count == 2 && Set(event.movingThreadPositions).count == 2
        })
        #expect(Set(cycle.moveEvents.flatMap(\.movingThreadPositions)).count == 8)
    }

    @Test func oneCycleRepositionsAtTheEndAndPreservesAllThreads() throws {
        let cycle = try #require(MaruGenjiSimulation.cycle(from: .initial))
        let next = cycle.endState

        #expect(cycle.endRepositioning.moves.count == 8)
        #expect(next.north == [16, 10, 7, 1])
        #expect(next.east == [4, 14, 11, 5])
        #expect(next.south == [9, 15, 2, 8])
        #expect(next.west == [13, 3, 6, 12])
        #expect(next.threadPositions.sorted() == Array(1...16))
    }

    @Test func pathKeyframesApplyOnlyEachOrderedMoveBeforeEndRepositioning() throws {
        let keyframes = MaruGenjiPathGenerator.keyframes(cycleCount: 1)

        #expect(keyframes.map(\.phase) == [
            .cycleStart,
            .move(.southToNorth),
            .move(.northToSouth),
            .move(.eastToWest),
            .move(.westToEast),
            .endRepositioning,
        ])

        let expectedChangedThreads: [Set<Int>] = [
            [10, 7],
            [15, 2],
            [3, 6],
            [14, 11],
            [16, 1, 4, 5, 9, 8, 13, 12],
        ]
        for index in 1..<keyframes.count {
            let previous = keyframes[index - 1].boardPositionsByThread
            let current = keyframes[index].boardPositionsByThread
            let changed = Set((1...16).filter { previous[$0] != current[$0] })
            #expect(changed == expectedChangedThreads[index - 1])
        }

        let finalPositions = try #require(keyframes.last?.boardPositionsByThread)
        let cycle = try #require(MaruGenjiSimulation.cycle(from: .initial))
        #expect(finalPositions == cycle.endState.boardPositionsByThread)
    }

    @Test func repeatedCyclesAndKeyframesAreDeterministicAndKeepEveryThread() {
        let firstRun = MaruGenjiSimulation.boardStates(cycleCount: 12)
        let secondRun = MaruGenjiSimulation.boardStates(cycleCount: 12)
        let firstKeyframes = MaruGenjiPathGenerator.keyframes(cycleCount: 12)
        let secondKeyframes = MaruGenjiPathGenerator.keyframes(cycleCount: 12)

        #expect(firstRun == secondRun)
        #expect(firstRun.count == 13)
        #expect(firstRun.allSatisfy { $0.threadPositions.sorted() == Array(1...16) })
        #expect(firstKeyframes == secondKeyframes)
        #expect(firstKeyframes.count == 61)
        #expect(firstKeyframes.allSatisfy { Set($0.boardPositionsByThread.keys) == Set(1...16) })
    }

    @Test func pathGeneratorKeepsAssignmentColorsAndProducesFinitePoints() throws {
        let assignments = validAssignments()

        let paths = MaruGenjiPathGenerator.generate(
            assignments: assignments,
            cycleCount: 3,
            samplesPerCycle: 10
        )

        #expect(paths.count == 16)
        #expect(paths.allSatisfy { $0.points.count == 31 })
        #expect(paths.allSatisfy { path in
            path.points.allSatisfy(isFinite)
        })
        for path in paths {
            let assignment = try #require(assignments.first { $0.position == path.threadPosition })
            #expect(path.colorID == assignment.colorID)
        }
    }

    @Test func pathGeneratorRejectsDuplicateMissingAndOutOfRangePositions() {
        let assignments = validAssignments()
        let duplicate = Array(assignments.dropLast()) + [
            ThreadAssignment(position: 15, colorID: ThreadColorCatalog.defaultColor.id),
        ]
        let outOfRange = Array(assignments.dropLast()) + [
            ThreadAssignment(position: 17, colorID: ThreadColorCatalog.defaultColor.id),
        ]
        let tooFew = Array(assignments.dropLast())
        let tooMany = assignments + [
            ThreadAssignment(position: 17, colorID: ThreadColorCatalog.defaultColor.id),
        ]

        #expect(MaruGenjiPathGenerator.generate(assignments: duplicate).isEmpty)
        #expect(MaruGenjiPathGenerator.generate(assignments: outOfRange).isEmpty)
        #expect(MaruGenjiPathGenerator.generate(assignments: tooFew).isEmpty)
        #expect(MaruGenjiPathGenerator.generate(assignments: tooMany).isEmpty)
        #expect(MaruGenjiPathGenerator.generate(assignments: assignments).count == 16)
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
        expectValidMesh(mesh)
    }

    @Test func tubeMeshTransportsFrameAcrossFormerReferenceAxisThreshold() throws {
        let points = [
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(0.05, 0, 1),
            SIMD3<Float>(0.2, 0.03, 2),
            SIMD3<Float>(0.7, 0.08, 3),
            SIMD3<Float>(1.5, 0.15, 4),
        ]
        let sideCount = 8
        let mesh = try #require(
            MaruGenjiTubeMeshGenerator.generate(points: points, sideCount: sideCount)
        )

        for ring in 0..<(points.count - 1) {
            for side in 0..<sideCount {
                let current = mesh.normals[ring * sideCount + side]
                let next = mesh.normals[(ring + 1) * sideCount + side]
                #expect(simd_dot(current, next) > 0)
            }
        }
        expectValidMesh(mesh)
    }

    private func validAssignments() -> [ThreadAssignment] {
        (1...16).map { position in
            ThreadAssignment(
                position: position,
                colorID: ThreadColorCatalog.colors[(position - 1) % ThreadColorCatalog.colors.count].id
            )
        }
    }

    private func expectValidMesh(_ mesh: TubeMeshData) {
        #expect(mesh.positions.allSatisfy(isFinite))
        #expect(mesh.normals.allSatisfy(isFinite))
        #expect(mesh.normals.allSatisfy { abs(simd_length($0) - 1) < 0.001 })
        #expect(mesh.triangleIndices.allSatisfy { Int($0) < mesh.positions.count })
        #expect(mesh.triangleIndices.count.isMultiple(of: 3))

        for triangle in stride(from: 0, to: mesh.triangleIndices.count, by: 3) {
            let first = mesh.positions[Int(mesh.triangleIndices[triangle])]
            let second = mesh.positions[Int(mesh.triangleIndices[triangle + 1])]
            let third = mesh.positions[Int(mesh.triangleIndices[triangle + 2])]
            #expect(simd_length_squared(simd_cross(second - first, third - first)) > 0.000_000_000_001)
        }
    }

    private func isFinite(_ vector: SIMD3<Float>) -> Bool {
        vector.x.isFinite && vector.y.isFinite && vector.z.isFinite
    }
}
