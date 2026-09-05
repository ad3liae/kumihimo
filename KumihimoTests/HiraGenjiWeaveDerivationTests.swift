import Foundation
import Testing
@testable import Kumihimo

/// Stage A of Task 007F, second attempt.
///
/// The cross-section is given: six threads across each face and two at each edge.
/// The move rules say which thread stands at which of those places at each step.
/// The map between board position and place is read off book A p96's finished
/// braid; the tests here pin down what was read, show it is consistent with both
/// of the braid's mirrors, and record that the stand's ring order — what the
/// first attempt used — is refuted by the same photograph.
struct HiraGenjiWeaveDerivationTests {
    // MARK: - The cross-section

    @Test func theCrossSectionIsSixToAFaceAndTwoAtEachEdge() throws {
        let places = try (1...16).map {
            try #require(HiraGenjiWeaveDerivation.crossSectionPlace(ofBoardPosition: $0))
        }

        #expect(HiraGenjiWeaveDerivation.columnCount == 6)
        #expect(HiraGenjiWeaveDerivation.edgeThreadCount == 2)

        var faceColumns = [HiraGenjiBraidFace: [Int]]()
        var edgeCounts = [HiraGenjiBraidEdge: Int]()
        for place in places {
            switch place {
            case .face(let face, let column):
                faceColumns[face, default: []].append(column)
            case .edge(let edge):
                edgeCounts[edge, default: 0] += 1
            }
        }

        // Every place is filled exactly once: six columns front, six back, two at
        // each edge, sixteen in all.
        #expect(faceColumns[.front]?.sorted() == Array(0..<6))
        #expect(faceColumns[.back]?.sorted() == Array(0..<6))
        #expect(edgeCounts == [.left: 2, .right: 2])
        #expect(HiraGenjiWeaveDerivation.crossSectionPlace(ofBoardPosition: 0) == nil)
        #expect(HiraGenjiWeaveDerivation.crossSectionPlace(ofBoardPosition: 17) == nil)
    }

    /// What was read off the photograph, written out. Book A p96 starts face 1 as
    /// mauve, mauve, black, vermilion — board positions 15, 16, 1, 2 — and the
    /// finished braid on the same page reads salmon, mauve, mauve, vermilion,
    /// black, salmon across its width.
    @Test func theFaceIsLaidOutAsTheFinishedBraidInBookAP96ShowsIt() {
        func column(_ boardPosition: Int) -> Int? {
            guard
                case .face(.front, let column)? = HiraGenjiWeaveDerivation
                    .crossSectionPlace(ofBoardPosition: boardPosition)
            else {
                return nil
            }
            return column
        }

        #expect(column(16) == 1)   // mauve
        #expect(column(15) == 2)   // mauve
        #expect(column(2) == 3)    // vermilion
        #expect(column(1) == 4)    // black
        // The two outermost columns of the face are held by threads from the sides
        // of the stand, which is why the photographed braid is salmon at both.
        #expect(column(14) == 0)
        #expect(column(3) == 5)
    }

    /// The correspondence the first attempt used, and why this photograph rules it
    /// out. Board positions 1 and 2 are neighbours on the stand's ring, in that
    /// order; any map that carries the ring round the cross-section as an order
    /// keeps them neighbours in that order, so it puts black inboard of vermilion.
    /// The braid has them the other way about.
    @Test func theStandsRingOrderIsNotCarriedIntoTheCrossSection() throws {
        func widthPosition(_ boardPosition: Int) throws -> Int {
            try #require(HiraGenjiWeaveDerivation.widthPosition(ofBoardPosition: boardPosition))
        }

        // Neighbours on the ring, and the braid puts them the other way round.
        #expect(try widthPosition(1) > widthPosition(2))
        #expect(try widthPosition(16) < widthPosition(15))

        // Said generally. Going round the cross-section is front left to right,
        // the right edge, back right to left, the left edge — sixteen places in a
        // ring. Carrying the stand's ring across as an order means consecutive
        // board positions land on consecutive places all the way round. The two
        // threads at each edge can be taken in either order, so all four ways are
        // tried; none of them is consecutive.
        for leftInOrder in [true, false] {
            for rightInOrder in [true, false] {
                let perimeter = try (1...16).map { boardPosition -> Int in
                    let place = try #require(
                        HiraGenjiWeaveDerivation.crossSectionPlace(ofBoardPosition: boardPosition)
                    )
                    switch place {
                    case .face(.front, let column):
                        return column
                    case .edge(.right):
                        return rightInOrder == (boardPosition == 4) ? 6 : 7
                    case .face(.back, let column):
                        return 13 - column
                    case .edge(.left):
                        return leftInOrder == (boardPosition == 13) ? 14 : 15
                    }
                }
                #expect(Set(perimeter) == Set(0..<16))
                let steps = zip(perimeter, perimeter.dropFirst() + [perimeter[0]])
                    .map { ($1 - $0 + 16) % 16 }
                #expect(!steps.allSatisfy { $0 == 1 })
                #expect(!steps.allSatisfy { $0 == 15 })
            }
        }
    }

    /// Both of the braid's mirrors hold. Through the thickness, a pair shares a
    /// column and lies on opposite faces — or shares an edge. Across the width, a
    /// pair sits in mirrored columns on the same face, or at opposite edges.
    @Test func theMapRespectsBothOfTheBraidsMirrors() throws {
        let lastColumn = HiraGenjiWeaveDerivation.columnCount - 1

        for boardPosition in 1...16 {
            let place = try #require(
                HiraGenjiWeaveDerivation.crossSectionPlace(ofBoardPosition: boardPosition)
            )
            let through = try #require(HiraGenjiWeaveDerivation.crossSectionPlace(
                ofBoardPosition: HiraGenjiWeaveDerivation.positionThroughTheBraid(
                    from: boardPosition
                )
            ))
            switch (place, through) {
            case (.face(let face, let column), .face(let otherFace, let otherColumn)):
                #expect(column == otherColumn)
                #expect(face == otherFace.opposite)
            case (.edge(let edge), .edge(let otherEdge)):
                #expect(edge == otherEdge)
            default:
                Issue.record("through-braid pair changed kind of place")
            }

            let across = try #require(HiraGenjiWeaveDerivation.crossSectionPlace(
                ofBoardPosition: HiraGenjiWeaveDerivation.positionAcrossTheBraid(
                    from: boardPosition
                )
            ))
            switch (place, across) {
            case (.face(let face, let column), .face(let otherFace, let otherColumn)):
                #expect(column + otherColumn == lastColumn)
                #expect(face == otherFace)
            case (.edge(let edge), .edge(let otherEdge)):
                #expect(edge != otherEdge)
            default:
                Issue.record("across-braid pair changed kind of place")
            }
        }
    }

    /// The one assumption: the north side of the stand is the front of the braid.
    /// Everything else about the map is read or forced.
    @Test func theNorthGroupIsTheFrontAndTheSouthGroupIsTheBack() throws {
        let initial = HiraGenjiBoardState.initial

        for boardPosition in initial.north {
            #expect(HiraGenjiWeaveDerivation.isOnTheFront(boardPosition: boardPosition) == true)
        }
        for boardPosition in initial.south {
            #expect(HiraGenjiWeaveDerivation.isOnTheFront(boardPosition: boardPosition) == false)
        }
        // The sides start with one thread on each face and one at each edge.
        for group in [initial.east, initial.west] {
            let places = try group.map {
                try #require(HiraGenjiWeaveDerivation.crossSectionPlace(ofBoardPosition: $0))
            }
            #expect(places.count { if case .edge = $0 { return true } else { return false } } == 2)
            #expect(places.count { if case .face = $0 { return true } else { return false } } == 2)
        }
    }

    // MARK: - The courses

    @Test func theBraidComesBackToItsStartAfterFourCycles() throws {
        let cycles = try #require(HiraGenjiWeaveDerivation.repeatCycleCount())

        #expect(cycles == 4)
        // Four cycles of six worked moves and a repositioning is the twenty-four
        // move table Fig.20 prints, which is what Task 005H checked.
        let states = HiraGenjiSimulation.boardStates(cycleCount: cycles)
        #expect(states.first == .initial)
        #expect(states.last == .initial)
        #expect(states.dropFirst().dropLast().allSatisfy { $0 != .initial })
    }

    @Test func everyThreadHasACourseAndNoneIsLostOrDoubled() throws {
        let courses = try #require(HiraGenjiWeaveDerivation.courses(cycleCount: 4))

        #expect(courses.count == 16)
        #expect(courses.map(\.threadPosition) == Array(1...16))
        #expect(courses.allSatisfy { $0.samples.count == 5 })
        for cycle in 0...4 {
            let occupied = courses.map { $0.samples[cycle].boardPosition }
            #expect(Set(occupied) == Set(1...16))
            // Every column carries one thread on each face, and each edge two.
            let onTheFaces = courses.compactMap { course -> String? in
                let sample = course.samples[cycle]
                guard let face = sample.face, let column = sample.column else { return nil }
                return "\(face.rawValue):\(column)"
            }
            #expect(Set(onTheFaces).count == 12)
            #expect(onTheFaces.count == 12)
            let atTheEdges = courses.compactMap { $0.samples[cycle].edge }
            #expect(atTheEdges.count { $0 == .left } == 2)
            #expect(atTheEdges.count { $0 == .right } == 2)
        }
        #expect(courses.allSatisfy { $0.samples.first?.boardPosition
            == $0.samples.last?.boardPosition })
    }

    @Test func theCourseDerivationIsDeterministic() throws {
        let first = try #require(HiraGenjiWeaveDerivation.courses(cycleCount: 4))
        let second = try #require(HiraGenjiWeaveDerivation.courses(cycleCount: 4))

        #expect(first == second)
    }

    /// Classified by the course, then compared with the role the existing pattern
    /// carries. They agree, which is the point of the check.
    @Test func theCourseTellsThreadsRunningAlongFromThreadsCarriedAcross() throws {
        let courses = try #require(HiraGenjiWeaveDerivation.courses(cycleCount: 4))
        let along = courses.filter(\.runsAlongTheBraid)
        let across = courses.filter { !$0.runsAlongTheBraid }

        #expect(along.count == 8)
        #expect(across.count == 8)
        #expect(along.allSatisfy { $0.role == .inner })
        #expect(across.allSatisfy { $0.role == .outer })
        #expect(Set(along.map(\.threadPosition)) == [1, 2, 7, 8, 9, 10, 15, 16])
        #expect(Set(across.map(\.threadPosition)) == [3, 4, 5, 6, 11, 12, 13, 14])
    }

    /// The threads running along the braid are straight. Their column never moves
    /// and their face turns over at every cycle, which is a thread lying under one
    /// pick and over the next. They hold the four middle columns; the outermost
    /// column of each face belongs to the threads carried across.
    @Test func threadsRunningAlongHoldTheFourMiddleColumns() throws {
        let courses = try #require(HiraGenjiWeaveDerivation.courses(cycleCount: 4))
        let along = courses.filter(\.runsAlongTheBraid)

        #expect(along.allSatisfy { $0.widthTravel == 0 })
        #expect(along.allSatisfy { $0.alternatesFace })

        // Two threads to a column, front and back, never on the same face at once.
        let byColumn = Dictionary(grouping: along) { $0.widthPositions[0] }
        #expect(Set(byColumn.keys) == [1, 2, 3, 4])
        #expect(byColumn.values.allSatisfy { $0.count == 2 })
        for (_, pair) in byColumn {
            let first = try #require(pair.first)
            let second = try #require(pair.last)
            let firstFaces = first.samples.map(\.face)
            let secondFaces = second.samples.map(\.face)
            #expect(zip(firstFaces, secondFaces).allSatisfy { $0 != $1 })
        }
    }

    /// The threads carried across fall into two closed orbits of four, one keeping
    /// to the front of the braid and one to the back, and each is a serpentine:
    /// right across, turn at the edge, back across, turn at the other edge.
    @Test func theThreadsCarriedAcrossFormTwoSerpentinesOneOnEachFace() throws {
        let courses = try #require(HiraGenjiWeaveDerivation.courses(cycleCount: 4))
        let across = courses.filter { !$0.runsAlongTheBraid }
        let orbits = Dictionary(grouping: across) { Set($0.boardPositions) }

        #expect(orbits.count == 2)
        #expect(orbits.values.allSatisfy { $0.count == 4 })
        #expect(Set(orbits.keys) == [[3, 4, 13, 14], [5, 6, 11, 12]])

        let front = try #require(orbits[[3, 4, 13, 14]])
        let back = try #require(orbits[[5, 6, 11, 12]])
        #expect(front.allSatisfy { course in course.samples.compactMap(\.face).allSatisfy { $0 == .front } })
        #expect(back.allSatisfy { course in course.samples.compactMap(\.face).allSatisfy { $0 == .back } })

        let lastColumn = HiraGenjiWeaveDerivation.columnCount - 1
        for course in across {
            // Both edges and both outermost columns, reached by crossing rather
            // than by drifting one column at a time.
            #expect(Set(course.widthPositions) == [-1, 0, lastColumn, lastColumn + 1])
            #expect(course.widthTravel == 2 * (lastColumn + 1) + 2)
        }
    }

    /// At every cycle one thread turns at the left of the braid and one at the
    /// right, on each face. So wherever you cut the braid there is a thread that
    /// came from the left and one that came from the right.
    @Test func carriedThreadsTurnAtBothEdgesAtOnce() throws {
        let courses = try #require(HiraGenjiWeaveDerivation.courses(cycleCount: 4))
        let across = courses.filter { !$0.runsAlongTheBraid }

        for cycle in 0..<4 {
            for half in HiraGenjiBraidFace.allCases {
                let onThisHalf = across.filter { course in
                    Set(course.samples.compactMap(\.face)) == [half]
                }
                let turns = onThisHalf.compactMap { $0.turnEdge(afterCycle: cycle) }
                #expect(turns.count { $0 == .left } == 1)
                #expect(turns.count { $0 == .right } == 1)
            }
        }
    }

    /// And the other two of each half cross the whole braid at that same step, one
    /// going each way. That is what makes the braid a weave rather than four
    /// stripes: every row has a thread laid right across it in each direction.
    @Test func atEveryRowTwoThreadsCrossEachHalfOneEachWay() throws {
        let courses = try #require(HiraGenjiWeaveDerivation.courses(cycleCount: 4))
        let across = courses.filter { !$0.runsAlongTheBraid }

        for cycle in 0..<4 {
            for half in HiraGenjiBraidFace.allCases {
                let steps = across
                    .filter { course in Set(course.samples.compactMap(\.face)) == [half] }
                    .map { $0.widthPositions[cycle + 1] - $0.widthPositions[cycle] }
                #expect(steps.count { $0 > 1 } == 1)
                #expect(steps.count { $0 < -1 } == 1)
            }
        }
    }

    /// The threads carried across travel further, which is why Fig.20 says to cut
    /// them longer. The travel across is free of any choice about how fast the
    /// braid advances; the length is quoted at a few advances for comparison.
    @Test func threadsCarriedAcrossTravelFurtherThanThoseRunningAlong() throws {
        let courses = try #require(HiraGenjiWeaveDerivation.courses(cycleCount: 4))
        let across = courses.filter { !$0.runsAlongTheBraid }
        let along = courses.filter(\.runsAlongTheBraid)

        #expect(across.allSatisfy { $0.widthTravel == 14 })
        #expect(along.allSatisfy { $0.widthTravel == 0 })

        for advance in [Float(1), 2, 4] {
            let carried = across.map { $0.length(advancePerCycle: advance) }
                .reduce(0, +) / Float(across.count)
            let straight = along.map { $0.length(advancePerCycle: advance) }
                .reduce(0, +) / Float(along.count)
            // Longer at any advance, and by more than the thirty per cent the
            // reference tells the braider to allow for.
            #expect(carried / straight > 1.3)
        }
    }

    // MARK: - Two at a time

    /// "Two to a set; nothing in this braid shifts one thread on its own." Read
    /// off the move rules: every worked move takes a pair, and so does each half
    /// of the end repositioning.
    @Test func everyMoveTakesTwoThreadsAtOnce() throws {
        let cycle = try #require(HiraGenjiSimulation.cycle(from: .initial))
        let moves = HiraGenjiWeaveDerivation.allMoves(in: cycle)

        #expect(cycle.moveEvents.count == 6)
        #expect(cycle.moveEvents.allSatisfy { $0.moves.count == 2 })
        #expect(cycle.endRepositioning.moves.count == 4)
        #expect(moves.count == 16)
        // Sixteen moves, sixteen threads: every thread moves once, none twice.
        #expect(Set(moves.map(\.threadPosition)) == Set(1...16))
        #expect(Set(moves.map(\.sourceBoardPosition)) == Set(1...16))
        #expect(Set(moves.map(\.destinationBoardPosition)) == Set(1...16))
    }

    /// The two threads of a pair are always mirror images, but the mirror depends
    /// on which way the pair is worked. A move between the sides takes the two
    /// threads stacked at one edge, front and back. A move between the front and
    /// the back takes the two threads facing each other across the width.
    @Test func thePairsOfAMoveAreMirrorImagesOfEachOther() throws {
        let cycle = try #require(HiraGenjiSimulation.cycle(from: .initial))
        let sideways: Set<HiraGenjiMoveKind> = [.eastOuterToWestCenter, .westOuterToEastCenter]

        for event in cycle.moveEvents {
            let sources = event.moves.map(\.sourceBoardPosition)
            let destinations = event.moves.map(\.destinationBoardPosition)
            let reflect = sideways.contains(event.kind)
                ? HiraGenjiWeaveDerivation.positionThroughTheBraid(from:)
                : HiraGenjiWeaveDerivation.positionAcrossTheBraid(from:)
            #expect(reflect(sources[0]) == sources[1])
            #expect(reflect(destinations[0]) == destinations[1])
        }

        let repositioning = cycle.endRepositioning.moves
        for move in repositioning {
            let partner = repositioning.first {
                $0.sourceBoardPosition
                    == HiraGenjiWeaveDerivation.positionThroughTheBraid(from: move.sourceBoardPosition)
            }
            let found = try #require(partner)
            #expect(found.destinationBoardPosition
                == HiraGenjiWeaveDerivation.positionThroughTheBraid(from: move.destinationBoardPosition))
        }
    }

    /// Taken as one cycle rather than event by event, all sixteen moves pair off
    /// through the thickness of the braid: eight pairs, each of two threads in one
    /// column exchanging faces or crossing together.
    @Test func theWholeCyclePairsOffThroughTheThicknessOfTheBraid() throws {
        let cycle = try #require(HiraGenjiSimulation.cycle(from: .initial))
        let pairs = try #require(HiraGenjiWeaveDerivation.movePairs(
            in: cycle,
            underReflection: HiraGenjiWeaveDerivation.positionThroughTheBraid(from:)
        ))

        #expect(pairs.count == 8)
        for (first, second) in pairs {
            #expect(HiraGenjiWeaveDerivation
                .positionThroughTheBraid(from: first.sourceBoardPosition)
                == second.sourceBoardPosition)
            #expect(HiraGenjiWeaveDerivation
                .positionThroughTheBraid(from: first.destinationBoardPosition)
                == second.destinationBoardPosition)
        }
        // No position is its own mirror either way, so no move can stand alone.
        #expect((1...16).allSatisfy {
            HiraGenjiWeaveDerivation.positionThroughTheBraid(from: $0) != $0
                && HiraGenjiWeaveDerivation.positionAcrossTheBraid(from: $0) != $0
        })
    }

    /// The mirror through the thickness is the same one that pairs the lengthwise
    /// threads: each of them swaps with the thread lying under it, and stays where
    /// it is across the width.
    @Test func theMirrorThroughTheBraidPairsTheLengthwiseThreads() throws {
        let courses = try #require(HiraGenjiWeaveDerivation.courses(cycleCount: 4))
        let along = courses.filter(\.runsAlongTheBraid)

        for course in along {
            let start = try #require(course.samples.first?.boardPosition)
            let next = try #require(course.samples.dropFirst().first?.boardPosition)
            #expect(HiraGenjiWeaveDerivation.positionThroughTheBraid(from: start) == next)
            #expect(HiraGenjiWeaveDerivation.widthPosition(ofBoardPosition: start)
                == HiraGenjiWeaveDerivation.widthPosition(ofBoardPosition: next))
        }
    }

    // MARK: - What the side threads do

    /// Every thread that starts on the east or the west of the stand reaches the
    /// other side within one repeat. None of them holds a width position, so the
    /// braid has eight threads carried across, not four — the twelve and four the
    /// author quotes are the cross-section's count, not a count of threads.
    @Test func noSideThreadStaysOnItsOwnSideOfTheBraid() throws {
        let east = Set(HiraGenjiBoardState.initial.east)
        let west = Set(HiraGenjiBoardState.initial.west)

        for thread in east.union(west) {
            let orbit = try #require(
                HiraGenjiWeaveDerivation.orbit(ofThread: thread, cycleCount: 4)
            )
            #expect(!orbit.intersection(east).isEmpty)
            #expect(!orbit.intersection(west).isEmpty)
            #expect(orbit.count == 4)
        }

        // And the lengthwise threads never leave their own half.
        let north = Set(HiraGenjiBoardState.initial.north)
        let south = Set(HiraGenjiBoardState.initial.south)
        for thread in north.union(south) {
            let orbit = try #require(
                HiraGenjiWeaveDerivation.orbit(ofThread: thread, cycleCount: 4)
            )
            #expect(orbit.count == 2)
            #expect(orbit.intersection(east).isEmpty)
            #expect(orbit.intersection(west).isEmpty)
        }
    }

    /// Twelve threads stand in the middle of the braid and four at its edges at
    /// every step, which is the count the author gives. It is a count of places,
    /// not of threads: the four at the edges are different threads each cycle.
    @Test func twelveThreadsStandInTheMiddleAndFourAtTheEdgesAtEveryStep() throws {
        let courses = try #require(HiraGenjiWeaveDerivation.courses(cycleCount: 4))

        for cycle in 0...4 {
            let atTheEdges = courses.filter { $0.samples[cycle].edge != nil }
            #expect(atTheEdges.count == 4)
            #expect(courses.count - atTheEdges.count == 12)
        }

        // The threads at the edges are not the same four from one row to the next.
        let firstRow = Set(courses.filter { $0.samples[0].edge != nil }.map(\.threadPosition))
        let secondRow = Set(courses.filter { $0.samples[1].edge != nil }.map(\.threadPosition))
        #expect(firstRow != secondRow)
    }

    @Test func malformedInputsFailSafely() {
        #expect(HiraGenjiWeaveDerivation.courses(cycleCount: 0) == nil)
        #expect(HiraGenjiWeaveDerivation.courses(cycleCount: -3) == nil)
        #expect(HiraGenjiWeaveDerivation.repeatCycleCount(limit: 2) == nil)
        #expect(HiraGenjiWeaveDerivation.widthPosition(ofBoardPosition: 0) == nil)
        #expect(HiraGenjiWeaveDerivation.isOnTheFront(boardPosition: 99) == nil)
    }
}
