import Foundation

struct HiraGenjiBoardState: Equatable, Sendable {
    var north: [Int]
    var east: [Int]
    var south: [Int]
    var west: [Int]

    static let initial = HiraGenjiBoardState(
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

    var threadPositions: [Int] { north + east + south + west }

    var boardPositionsByThread: [Int: Int] {
        var result = [Int: Int]()
        for (group, slots) in zip([north, east, south, west], Self.boardSlots) {
            for (threadPosition, boardPosition) in zip(group, slots) {
                result[threadPosition] = boardPosition
            }
        }
        return result
    }
}

enum HiraGenjiMoveKind: Int, CaseIterable, Equatable, Sendable {
    case eastOuterToWestCenter = 1
    case westOuterToEastCenter
    case southInnerToNorthCenter
    case northInnerToSouthCenter
    case southOuterToNorthOuter
    case northOuterToSouthOuter
}

struct HiraGenjiThreadMove: Equatable, Sendable {
    let threadPosition: Int
    let sourceBoardPosition: Int
    let destinationBoardPosition: Int
}

struct HiraGenjiMoveEvent: Equatable, Sendable {
    let kind: HiraGenjiMoveKind
    let moves: [HiraGenjiThreadMove]

    var movingThreadPositions: [Int] { moves.map(\.threadPosition) }
}

struct HiraGenjiEndRepositioning: Equatable, Sendable {
    let moves: [HiraGenjiThreadMove]
}

struct HiraGenjiCycle: Equatable, Sendable {
    let startState: HiraGenjiBoardState
    let moveEvents: [HiraGenjiMoveEvent]
    let endRepositioning: HiraGenjiEndRepositioning
    let endState: HiraGenjiBoardState
}

enum HiraGenjiSimulation {
    static let requiredThreadCount = 16

    static func cycle(from state: HiraGenjiBoardState) -> HiraGenjiCycle? {
        guard isValid(state) else { return nil }

        let moveEvents = [
            event(.eastOuterToWestCenter, state.east, [0, 3], [3, 6], [13, 12]),
            event(.westOuterToEastCenter, state.west, [0, 3], [14, 11], [4, 5]),
            event(.southInnerToNorthCenter, state.south, [1, 2], [9, 8], [16, 1]),
            event(.northInnerToSouthCenter, state.north, [1, 2], [16, 1], [9, 8]),
            event(.southOuterToNorthOuter, state.south, [0, 3], [10, 7], [15, 2]),
            event(.northOuterToSouthOuter, state.north, [0, 3], [15, 2], [10, 7]),
        ]

        let endRepositioning = HiraGenjiEndRepositioning(moves: [
            move(state.east[1], from: 4, to: 3),
            move(state.east[2], from: 5, to: 6),
            move(state.west[1], from: 13, to: 14),
            move(state.west[2], from: 12, to: 11),
        ])

        return HiraGenjiCycle(
            startState: state,
            moveEvents: moveEvents,
            endRepositioning: endRepositioning,
            endState: HiraGenjiBoardState(
                north: state.south,
                east: [state.east[1], state.west[0], state.west[3], state.east[2]],
                south: state.north,
                west: [state.west[1], state.east[0], state.east[3], state.west[2]]
            )
        )
    }

    static func cycles(cycleCount: Int) -> [HiraGenjiCycle] {
        guard cycleCount > 0 else { return [] }
        var state = HiraGenjiBoardState.initial
        var result = [HiraGenjiCycle]()
        result.reserveCapacity(cycleCount)
        for _ in 0..<cycleCount {
            guard let cycle = cycle(from: state) else { break }
            result.append(cycle)
            state = cycle.endState
        }
        return result
    }

    static func boardStates(cycleCount: Int) -> [HiraGenjiBoardState] {
        [.initial] + cycles(cycleCount: cycleCount).map(\.endState)
    }

    private static func isValid(_ state: HiraGenjiBoardState) -> Bool {
        let groups = [state.north, state.east, state.south, state.west]
        return groups.allSatisfy { $0.count == 4 }
            && state.threadPositions.sorted() == Array(1...requiredThreadCount)
    }

    private static func event(
        _ kind: HiraGenjiMoveKind,
        _ group: [Int],
        _ indices: [Int],
        _ sources: [Int],
        _ destinations: [Int]
    ) -> HiraGenjiMoveEvent {
        HiraGenjiMoveEvent(
            kind: kind,
            moves: zip(zip(indices, sources), destinations).map { pair, destination in
                move(group[pair.0], from: pair.1, to: destination)
            }
        )
    }

    private static func move(
        _ threadPosition: Int,
        from source: Int,
        to destination: Int
    ) -> HiraGenjiThreadMove {
        HiraGenjiThreadMove(
            threadPosition: threadPosition,
            sourceBoardPosition: source,
            destinationBoardPosition: destination
        )
    }
}
