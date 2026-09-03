import Foundation
import Testing
@testable import Kumihimo

struct HiraGenjiSurfacePatternTests {
    @Test func patternHasTwoSixColumnBroadFacesAndBothEdges() throws {
        let pattern = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: fixtureA))

        #expect(pattern.patches.count == 32)
        #expect(pattern.patches(in: .front).count == 12)
        #expect(pattern.patches(in: .back).count == 12)
        #expect(pattern.patches(in: .leftEdge).count == 4)
        #expect(pattern.patches(in: .rightEdge).count == 4)
        #expect(Set(pattern.patches(in: .front).map(\.widthColumn)) == Set(0..<6))
        #expect(Set(pattern.patches(in: .front).map(\.stitchPhase)) == [0, 1])
        #expect(pattern.patches.contains { $0.threadRole == .inner })
        #expect(pattern.patches.contains { $0.threadRole == .outer })
    }

    @Test func frontSixByTwoCorrespondenceUsesPhysicalLaneOrder() throws {
        let cycle = try #require(HiraGenjiSimulation.cycle(from: .initial))
        let pattern = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: fixtureA))
        let front = pattern.patches(in: .front)
        let laneEventOrder = [0, 4, 2, 3, 5, 1]

        for (column, eventIndex) in laneEventOrder.enumerated() {
            for phase in 0..<2 {
                let patch = try #require(front.first {
                    $0.widthColumn == column && $0.stitchPhase == phase
                })
                #expect(patch.threadPosition == cycle.moveEvents[eventIndex].moves[phase].threadPosition)
            }
        }
    }

    @Test func fixtureAPlacesOuterColorsAtBothEdgesAndInnerColorsInFourCenterLanes() throws {
        let pattern = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: fixtureA))
        let front = pattern.patches(in: .front)

        for phase in 0..<2 {
            let ordered = front.filter { $0.stitchPhase == phase }
                .sorted { $0.widthColumn < $1.widthColumn }
            #expect(ordered.count == 6)
            #expect(ordered[0].threadRole == .outer)
            #expect(ordered[5].threadRole == .outer)
            #expect(ordered[1...4].allSatisfy { $0.threadRole == .inner })
        }
    }

    @Test func frontAndBackAreIndependentAndFixtureCReversesOuterColorRoles() throws {
        let pattern = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: fixtureC))
        let frontOuter = outerColorSignature(pattern.patches(in: .front))
        let backOuter = outerColorSignature(pattern.patches(in: .back))

        #expect(frontOuter == "BBPP")
        #expect(backOuter == "PPBB")
        #expect(frontOuter != backOuter)
    }

    @Test func fixturesAreDeterministicAndPositionDriven() throws {
        for fixture in [fixtureA, fixtureB, fixtureC] {
            let first = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: fixture))
            let second = try #require(
                HiraGenjiSurfacePatternGenerator.generate(assignments: Array(fixture.reversed()))
            )
            #expect(first == second)
        }

        var changed = fixtureA
        changed[0].colorID = ThreadColorID(rawValue: "red")
        let before = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: fixtureA))
        let after = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: changed))
        #expect(before != after)
        #expect(after.patches.filter { $0.threadPosition == 1 }.allSatisfy {
            $0.colorID == ThreadColorID(rawValue: "red")
        })
        #expect(zip(before.patches, after.patches).allSatisfy { old, new in
            old.threadPosition == 1 || old == new
        })
    }

    @Test func invalidAssignmentPositionsFailSafely() {
        let duplicate = Array(fixtureA.dropLast()) + [fixtureA[14]]
        let outOfRange = Array(fixtureA.dropLast()) + [
            ThreadAssignment(position: 17, colorID: blue),
        ]

        #expect(HiraGenjiSurfacePatternGenerator.generate(assignments: duplicate) == nil)
        #expect(HiraGenjiSurfacePatternGenerator.generate(assignments: outOfRange) == nil)
        #expect(HiraGenjiSurfacePatternGenerator.generate(assignments: Array(fixtureA.dropLast())) == nil)
    }

    private let blue = ThreadColorID(rawValue: "blue")
    private let pink = ThreadColorID(rawValue: "pink")
    private let white = ThreadColorID(rawValue: "white")
    private let black = ThreadColorID(rawValue: "black")
    private let lightBlue = ThreadColorID(rawValue: "light-blue")

    private var fixtureA: [ThreadAssignment] {
        assignments { position in
            let inner = Set([15, 16, 1, 2, 10, 9, 8, 7])
            if inner.contains(position) { return position.isMultiple(of: 2) ? blue : lightBlue }
            return position.isMultiple(of: 2) ? white : black
        }
    }

    private var fixtureB: [ThreadAssignment] {
        assignments { position in
            Set([4, 5, 13, 12]).contains(position) ? blue : pink
        }
    }

    private var fixtureC: [ThreadAssignment] {
        assignments { position in
            if Set([3, 4, 14, 13]).contains(position) { return blue }
            if Set([5, 6, 12, 11]).contains(position) { return pink }
            return white
        }
    }

    private func assignments(_ color: (Int) -> ThreadColorID) -> [ThreadAssignment] {
        (1...16).map { ThreadAssignment(position: $0, colorID: color($0)) }
    }

    private func outerColorSignature(_ patches: [HiraGenjiSurfacePatch]) -> String {
        patches.filter { $0.threadRole == .outer }
            .sorted {
                ($0.stitchPhase, $0.widthColumn) < ($1.stitchPhase, $1.widthColumn)
            }
            .map { $0.colorID == blue ? "B" : "P" }
            .joined()
    }
}
