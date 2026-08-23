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

    private static let boardSlots = [
        [15, 16, 1, 2],
        [3, 4, 5, 6],
        [10, 9, 8, 7],
        [14, 13, 12, 11],
    ]

    var threadPositions: [Int] {
        north + east + south + west
    }

    var boardPositionsByThread: [Int: Int] {
        var result = [Int: Int]()
        for (group, slots) in zip([north, east, south, west], Self.boardSlots) {
            for (threadPosition, boardPosition) in zip(group, slots) {
                result[threadPosition] = boardPosition
            }
        }
        return result
    }

    func boardPosition(for threadPosition: Int) -> Int? {
        boardPositionsByThread[threadPosition]
    }
}

enum MaruGenjiMoveKind: CaseIterable, Equatable, Sendable {
    case southToNorth
    case northToSouth
    case eastToWest
    case westToEast
}

struct MaruGenjiThreadMove: Equatable, Sendable {
    let threadPosition: Int
    let sourceBoardPosition: Int
    let destinationBoardPosition: Int
}

struct MaruGenjiMoveEvent: Equatable, Sendable {
    let kind: MaruGenjiMoveKind
    let moves: [MaruGenjiThreadMove]

    var movingThreadPositions: [Int] {
        moves.map(\.threadPosition)
    }
}

struct MaruGenjiEndRepositioning: Equatable, Sendable {
    let moves: [MaruGenjiThreadMove]
}

struct MaruGenjiCycle: Equatable, Sendable {
    let startState: MaruGenjiBoardState
    let moveEvents: [MaruGenjiMoveEvent]
    let endRepositioning: MaruGenjiEndRepositioning
    let endState: MaruGenjiBoardState
}

enum MaruGenjiSimulation {
    static let requiredThreadCount = 16

    static func cycle(from state: MaruGenjiBoardState) -> MaruGenjiCycle? {
        guard [state.north, state.east, state.south, state.west].allSatisfy({ $0.count == 4 }) else {
            return nil
        }

        let moveEvents = [
            event(
                kind: .southToNorth,
                threads: [state.south[0], state.south[3]],
                sources: [10, 7],
                destinations: [16, 1]
            ),
            event(
                kind: .northToSouth,
                threads: [state.north[0], state.north[3]],
                sources: [15, 2],
                destinations: [9, 8]
            ),
            event(
                kind: .eastToWest,
                threads: [state.east[0], state.east[3]],
                sources: [3, 6],
                destinations: [13, 12]
            ),
            event(
                kind: .westToEast,
                threads: [state.west[0], state.west[3]],
                sources: [14, 11],
                destinations: [4, 5]
            ),
        ]

        let endRepositioning = MaruGenjiEndRepositioning(moves: [
            threadMove(state.north[1], from: 16, to: 15),
            threadMove(state.north[2], from: 1, to: 2),
            threadMove(state.east[1], from: 4, to: 3),
            threadMove(state.east[2], from: 5, to: 6),
            threadMove(state.south[1], from: 9, to: 10),
            threadMove(state.south[2], from: 8, to: 7),
            threadMove(state.west[1], from: 13, to: 14),
            threadMove(state.west[2], from: 12, to: 11),
        ])

        return MaruGenjiCycle(
            startState: state,
            moveEvents: moveEvents,
            endRepositioning: endRepositioning,
            endState: MaruGenjiBoardState(
                north: exchangedGroup(keepingInnerOf: state.north, receivingOuterOf: state.south),
                east: exchangedGroup(keepingInnerOf: state.east, receivingOuterOf: state.west),
                south: exchangedGroup(keepingInnerOf: state.south, receivingOuterOf: state.north),
                west: exchangedGroup(keepingInnerOf: state.west, receivingOuterOf: state.east)
            )
        )
    }

    static func nextCycle(from state: MaruGenjiBoardState) -> MaruGenjiBoardState {
        cycle(from: state)?.endState ?? state
    }

    static func cycles(cycleCount: Int) -> [MaruGenjiCycle] {
        guard cycleCount > 0 else { return [] }
        var state = MaruGenjiBoardState.initial
        var result = [MaruGenjiCycle]()
        result.reserveCapacity(cycleCount)

        for _ in 0..<cycleCount {
            guard let cycle = cycle(from: state) else { break }
            result.append(cycle)
            state = cycle.endState
        }
        return result
    }

    static func boardStates(cycleCount: Int) -> [MaruGenjiBoardState] {
        [.initial] + cycles(cycleCount: cycleCount).map(\.endState)
    }

    private static func event(
        kind: MaruGenjiMoveKind,
        threads: [Int],
        sources: [Int],
        destinations: [Int]
    ) -> MaruGenjiMoveEvent {
        MaruGenjiMoveEvent(
            kind: kind,
            moves: zip(zip(threads, sources), destinations).map { pair, destination in
                threadMove(pair.0, from: pair.1, to: destination)
            }
        )
    }

    private static func threadMove(
        _ threadPosition: Int,
        from source: Int,
        to destination: Int
    ) -> MaruGenjiThreadMove {
        MaruGenjiThreadMove(
            threadPosition: threadPosition,
            sourceBoardPosition: source,
            destinationBoardPosition: destination
        )
    }

    private static func exchangedGroup(
        keepingInnerOf destination: [Int],
        receivingOuterOf source: [Int]
    ) -> [Int] {
        [destination[1], source[0], source[3], destination[2]]
    }
}

struct BraidStrandPath: Equatable, Sendable {
    let threadPosition: Int
    let colorID: ThreadColorID
    let points: [SIMD3<Float>]
}

enum MaruGenjiPathKeyframePhase: Equatable, Sendable {
    case cycleStart
    case move(MaruGenjiMoveKind)
    case endRepositioning
}

struct MaruGenjiPathKeyframe: Equatable, Sendable {
    let cycleIndex: Int
    let phase: MaruGenjiPathKeyframePhase
    let boardPositionsByThread: [Int: Int]
}

enum MaruGenjiPathGenerator {
    static func generate(
        assignments: [ThreadAssignment],
        cycleCount: Int = 10,
        samplesPerCycle: Int = 18
    ) -> [BraidStrandPath] {
        let expectedPositions = Set(1...MaruGenjiSimulation.requiredThreadCount)
        let suppliedPositions = Set(assignments.map(\.position))
        guard
            assignments.count == MaruGenjiSimulation.requiredThreadCount,
            suppliedPositions.count == MaruGenjiSimulation.requiredThreadCount,
            suppliedPositions == expectedPositions,
            cycleCount > 0,
            samplesPerCycle > 1
        else {
            return []
        }

        // The uniqueness and exact range checks above make this construction safe.
        let assignmentsByPosition = Dictionary(
            uniqueKeysWithValues: assignments.map { ($0.position, $0.colorID) }
        )
        let keyframes = keyframes(cycleCount: cycleCount)
        guard keyframes.count > 1 else { return [] }

        let length: Float = 3.4
        let baseRadius: Float = 0.28
        let weaveOffset: Float = 0.018

        return (1...MaruGenjiSimulation.requiredThreadCount).compactMap { threadPosition in
            guard let colorID = assignmentsByPosition[threadPosition] else { return nil }
            var unwrappedAngles = [Float]()

            for keyframe in keyframes {
                guard let position = keyframe.boardPositionsByThread[threadPosition] else {
                    return nil
                }
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
            let segmentCount = keyframes.count - 1
            let points = (0..<pointCount).map { sample -> SIMD3<Float> in
                let progress = Float(sample) / Float(pointCount - 1)
                let keyframeProgress = progress * Float(segmentCount)
                let segment = min(Int(keyframeProgress), segmentCount - 1)
                let segmentProgress = min(keyframeProgress - Float(segment), 1)
                let easedProgress = segmentProgress * segmentProgress * (3 - 2 * segmentProgress)
                let angle = unwrappedAngles[segment]
                    + (unwrappedAngles[segment + 1] - unwrappedAngles[segment]) * easedProgress
                let cycleProgress = progress * Float(cycleCount)
                let cycle = min(Int(cycleProgress), cycleCount - 1)
                let localCycleProgress = min(cycleProgress - Float(cycle), 1)
                let overUnder = (threadPosition + cycle).isMultiple(of: 2) ? Float(1) : -1
                let radius = baseRadius
                    + overUnder * weaveOffset * sin(.pi * localCycleProgress)
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

    static func keyframes(cycleCount: Int) -> [MaruGenjiPathKeyframe] {
        let cycles = MaruGenjiSimulation.cycles(cycleCount: cycleCount)
        guard let firstCycle = cycles.first else { return [] }
        var result = [MaruGenjiPathKeyframe(
            cycleIndex: 0,
            phase: .cycleStart,
            boardPositionsByThread: firstCycle.startState.boardPositionsByThread
        )]

        for (cycleIndex, cycle) in cycles.enumerated() {
            var positions = cycle.startState.boardPositionsByThread
            for event in cycle.moveEvents {
                apply(event.moves, to: &positions)
                result.append(MaruGenjiPathKeyframe(
                    cycleIndex: cycleIndex,
                    phase: .move(event.kind),
                    boardPositionsByThread: positions
                ))
            }
            apply(cycle.endRepositioning.moves, to: &positions)
            result.append(MaruGenjiPathKeyframe(
                cycleIndex: cycleIndex,
                phase: .endRepositioning,
                boardPositionsByThread: positions
            ))
        }
        return result
    }

    private static func apply(
        _ moves: [MaruGenjiThreadMove],
        to positions: inout [Int: Int]
    ) {
        for move in moves {
            positions[move.threadPosition] = move.destinationBoardPosition
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
}
