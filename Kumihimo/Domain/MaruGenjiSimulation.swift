import Foundation
import simd

struct MaruGenjiBoardState: Equatable, Sendable {
    var north: [Int]
    var east: [Int]
    var south: [Int]
    var west: [Int]

    static let initial = MaruGenjiBoardState(
        north: [15, 16, 1, 2],
        east: [3, 4, 5, 6],
        south: [10, 9, 8, 7],
        west: [14, 13, 12, 11]
    )

    var threadPositions: [Int] {
        north + east + south + west
    }

    func boardPosition(for threadPosition: Int) -> Int? {
        let groups = [north, east, south, west]
        let boardSlots = [
            [15, 16, 1, 2],
            [3, 4, 5, 6],
            [10, 9, 8, 7],
            [14, 13, 12, 11],
        ]

        for (group, slots) in zip(groups, boardSlots) {
            if let index = group.firstIndex(of: threadPosition) {
                return slots[index]
            }
        }
        return nil
    }
}

enum MaruGenjiSimulation {
    static let requiredThreadCount = 16

    static func nextCycle(from state: MaruGenjiBoardState) -> MaruGenjiBoardState {
        MaruGenjiBoardState(
            north: exchangedGroup(keepingInnerOf: state.north, receivingOuterOf: state.south),
            east: exchangedGroup(keepingInnerOf: state.east, receivingOuterOf: state.west),
            south: exchangedGroup(keepingInnerOf: state.south, receivingOuterOf: state.north),
            west: exchangedGroup(keepingInnerOf: state.west, receivingOuterOf: state.east)
        )
    }

    static func boardStates(cycleCount: Int) -> [MaruGenjiBoardState] {
        guard cycleCount > 0 else { return [.initial] }
        return (0..<cycleCount).reduce(into: [.initial]) { states, _ in
            states.append(nextCycle(from: states[states.count - 1]))
        }
    }

    private static func exchangedGroup(
        keepingInnerOf destination: [Int],
        receivingOuterOf source: [Int]
    ) -> [Int] {
        guard destination.count == 4, source.count == 4 else { return destination }
        return [destination[1], source[0], source[3], destination[2]]
    }
}

struct BraidStrandPath: Equatable, Sendable {
    let threadPosition: Int
    let colorID: ThreadColorID
    let points: [SIMD3<Float>]
}

enum MaruGenjiPathGenerator {
    static func generate(
        assignments: [ThreadAssignment],
        cycleCount: Int = 10,
        samplesPerCycle: Int = 18
    ) -> [BraidStrandPath] {
        guard
            assignments.count == MaruGenjiSimulation.requiredThreadCount,
            cycleCount > 0,
            samplesPerCycle > 1
        else {
            return []
        }

        let assignmentsByPosition = Dictionary(
            uniqueKeysWithValues: assignments.map { ($0.position, $0.colorID) }
        )
        guard assignmentsByPosition.count == MaruGenjiSimulation.requiredThreadCount else {
            return []
        }

        let states = MaruGenjiSimulation.boardStates(cycleCount: cycleCount)
        let length: Float = 3.4
        let baseRadius: Float = 0.28
        let weaveOffset: Float = 0.018

        return (1...MaruGenjiSimulation.requiredThreadCount).compactMap { threadPosition in
            guard let colorID = assignmentsByPosition[threadPosition] else { return nil }
            var unwrappedAngles = [Float]()

            for state in states {
                guard let position = state.boardPosition(for: threadPosition) else { return nil }
                let target = angle(forBoardPosition: position)
                if let previous = unwrappedAngles.last {
                    unwrappedAngles.append(
                        unwrappedAngle(target, nearestTo: previous, threadPosition: threadPosition)
                    )
                } else {
                    unwrappedAngles.append(target)
                }
            }

            let pointCount = cycleCount * samplesPerCycle + 1
            let points = (0..<pointCount).map { sample -> SIMD3<Float> in
                let progress = Float(sample) / Float(pointCount - 1)
                let cycleProgress = progress * Float(cycleCount)
                let cycle = min(Int(cycleProgress), cycleCount - 1)
                let localProgress = min(cycleProgress - Float(cycle), 1)
                let angle = interpolatedAngle(
                    angles: unwrappedAngles,
                    cycle: cycle,
                    progress: localProgress
                )
                let overUnder = (threadPosition + cycle).isMultiple(of: 2) ? Float(1) : -1
                let radius = baseRadius
                    + overUnder * weaveOffset * sin(.pi * localProgress)
                let x = -length / 2 + length * progress

                return SIMD3<Float>(
                    x,
                    radius * cos(angle),
                    radius * sin(angle)
                )
            }

            return BraidStrandPath(
                threadPosition: threadPosition,
                colorID: colorID,
                points: points
            )
        }
    }

    private static func angle(forBoardPosition position: Int) -> Float {
        2 * .pi * Float(position - 1) / Float(MaruGenjiSimulation.requiredThreadCount)
    }

    private static func unwrappedAngle(
        _ target: Float,
        nearestTo previous: Float,
        threadPosition: Int
    ) -> Float {
        var difference = target - previous.truncatingRemainder(dividingBy: 2 * .pi)
        while difference > .pi { difference -= 2 * .pi }
        while difference < -.pi { difference += 2 * .pi }
        if abs(abs(difference) - .pi) < 0.0001, threadPosition.isMultiple(of: 2) {
            difference = -difference
        }
        return previous + difference
    }

    private static func interpolatedAngle(
        angles: [Float],
        cycle: Int,
        progress: Float
    ) -> Float {
        let current = angles[cycle]
        let next = angles[cycle + 1]
        let previous = cycle > 0 ? angles[cycle - 1] : current - (next - current)
        let following = cycle + 2 < angles.count
            ? angles[cycle + 2]
            : next + (next - current)
        let squared = progress * progress
        let cubed = squared * progress
        return 0.5 * (
            2 * current
                + (-previous + next) * progress
                + (2 * previous - 5 * current + 4 * next - following) * squared
                + (-previous + 3 * current - 3 * next + following) * cubed
        )
    }
}
