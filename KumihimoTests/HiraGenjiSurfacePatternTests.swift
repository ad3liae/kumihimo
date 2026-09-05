import Foundation
import simd
import Testing
@testable import Kumihimo

/// The surface layout: where each place on the braid is. Which thread stands
/// there is `HiraGenjiWeavePattern`'s answer, tested in its own file; what is
/// tested here is that the layout puts the weave's places where they belong on
/// the cross-section, and that the lane geometry is what the mesh expects.
struct HiraGenjiSurfacePatternTests {
    @Test func patternHasTwoSixLaneFacesTwoEdgesAndFourStepsToARepeat() throws {
        let pattern = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: fixtureA))
        let rowCount = try #require(HiraGenjiSurfacePatternGenerator.rowCount)

        #expect(rowCount == 4)
        #expect(pattern.patches.count == 64)
        #expect(pattern.patches(in: .front).count == 24)
        #expect(pattern.patches(in: .back).count == 24)
        #expect(pattern.patches(in: .leftEdge).count == 8)
        #expect(pattern.patches(in: .rightEdge).count == 8)
        #expect(Set(pattern.patches(in: .front).map(\.widthColumn)) == Set(0..<6))
        #expect(Set(pattern.patches(in: .leftEdge).map(\.widthColumn)) == Set(0..<2))
        #expect(Set(pattern.patches(in: .front).map(\.row)) == Set(0..<rowCount))
        // Every place is filled once.
        let places = pattern.patches.map { [$0.region.hashValue, $0.widthColumn, $0.row] }
        #expect(Set(places.map(\.description)).count == pattern.patches.count)
        #expect(pattern.patches.contains { $0.threadRole == .inner })
        #expect(pattern.patches.contains { $0.threadRole == .outer })
    }

    /// The check that the two faces are laid out consistently. A column of the
    /// braid is one column, so the thread on the front of it and the thread on
    /// the back of it have to come out at the same place across the width — the
    /// front region runs one way round the cross-section and the back runs the
    /// other, so one of the two lane orders has to be reversed.
    @Test func aWeaveColumnComesOutAtTheSamePlaceOnBothFaces() throws {
        let pattern = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: fixtureA))
        let weave = try #require(HiraGenjiWeavePatternGenerator.generate(assignments: fixtureA))
        let rowCount = try #require(HiraGenjiSurfacePatternGenerator.rowCount)

        for row in 0..<rowCount {
            for weaveColumn in 0..<weave.columnCount {
                let front = try #require(
                    weave.patch(column: weaveColumn, row: row, face: .front)
                )
                let back = try #require(
                    weave.patch(column: weaveColumn, row: row, face: .back)
                )
                let frontPatch = try #require(pattern.patches(in: .front).first {
                    $0.row == row && $0.threadPosition == front.threadPosition
                })
                let backPatch = try #require(pattern.patches(in: .back).first {
                    $0.row == row && $0.threadPosition == back.threadPosition
                })
                #expect(abs(widthCentre(frontPatch) - widthCentre(backPatch)) < 0.01)
            }
        }
    }

    /// Book A p96's braid, read across the front: salmon, mauve, mauve,
    /// vermilion, black, salmon. The mesh reads the front region from `+x` to
    /// `-x`, so the lanes are put in the order the width itself runs in.
    @Test func theP96ColouringLandsAcrossTheFaceInThePhotographedOrder() throws {
        let pattern = try #require(
            HiraGenjiSurfacePatternGenerator.generate(assignments: bookAP96Colouring)
        )
        let expected = [salmon, mauve, mauve, vermilion, black, salmon]

        for row in 0..<4 {
            let acrossTheWidth = pattern.patches(in: .front)
                .filter { $0.row == row }
                .sorted { widthCentre($0) < widthCentre($1) }
            #expect(acrossTheWidth.map(\.colorID) == expected)
        }
        #expect(pattern.patches(in: .leftEdge).allSatisfy { $0.colorID == salmon })
        #expect(pattern.patches(in: .rightEdge).allSatisfy { $0.colorID == salmon })
    }

    /// The four middle lanes of each face are the threads that run along the
    /// braid; the two outermost lanes and both edges are threads carried across.
    @Test func theOutermostLanesAndBothEdgesAreThreadsCarriedAcross() throws {
        let pattern = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: fixtureA))

        for region in [HiraGenjiSurfaceRegion.front, .back] {
            for row in 0..<4 {
                let ordered = pattern.patches(in: region)
                    .filter { $0.row == row }
                    .sorted { $0.widthColumn < $1.widthColumn }
                #expect(ordered.count == 6)
                #expect(ordered[0].threadRole == .outer)
                #expect(ordered[5].threadRole == .outer)
                #expect(ordered[1...4].allSatisfy { $0.threadRole == .inner })
            }
        }
        #expect(pattern.patches(in: .leftEdge).allSatisfy { $0.threadRole == .outer })
        #expect(pattern.patches(in: .rightEdge).allSatisfy { $0.threadRole == .outer })
    }

    /// The lane geometry the mesh reads. Every stitch join runs straight across
    /// its lane: the lean was 0.4 of a step, measured from nothing, and the
    /// references do not settle a value to put in its place — see
    /// `faceStitchLean`. The machinery that leans a join is still here, wired to
    /// zero, because stage 3 may yet show the braid needs one.
    @Test func everyStitchJoinRunsStraightAcrossItsLane() throws {
        let pattern = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: fixtureA))
        let rowCount = try #require(HiraGenjiSurfacePatternGenerator.rowCount)
        let front = pattern.patches(in: .front)

        for patch in front {
            #expect(patch.corners.count == 4)
            #expect(patch.corners.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
        }
        // The first row starts flat and the last row finishes flat.
        for patch in front where patch.row == 0 {
            #expect(patch.corners[0].y == 0)
            #expect(patch.corners[3].y == 0)
        }
        for patch in front where patch.row == rowCount - 1 {
            #expect(patch.corners[1].y == 1)
            #expect(patch.corners[2].y == 1)
        }
        // No join leans, and every row is exactly one step of the repeat.
        let step = 1 / Float(rowCount)
        #expect(HiraGenjiSurfacePatternGenerator.faceStitchLean == 0)
        for patch in front {
            #expect(patch.corners[0].y == patch.corners[3].y)
            #expect(patch.corners[1].y == patch.corners[2].y)
            #expect(abs((patch.corners[1].y - patch.corners[0].y) - step) < 0.000_1)
        }
        // The lean still reaches the corners, so stage 3 can turn it back on.
        let leaned = HiraGenjiSurfacePatternGenerator.corners(
            column: 1, row: 1, rowCount: rowCount, columnCount: 6, lean: 0.4
        )
        #expect(leaned[1].y != leaned[2].y)
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

    // MARK: - Helpers

    /// Where a patch sits across the braid, on the axis the mesh draws it on.
    private func widthCentre(_ patch: HiraGenjiSurfacePatch) -> Float {
        let columnCount = HiraGenjiSurfacePatternGenerator.columnCount(in: patch.region)
        let regionU = (Float(patch.widthColumn) + 0.5) / Float(columnCount)
        return HiraGenjiSurfaceMeshGenerator.crossSectionPoint(
            region: patch.region,
            regionU: regionU,
            halfWidth: HiraGenjiSurfaceMeshGenerator.defaultHalfWidth,
            halfThickness: HiraGenjiSurfaceMeshGenerator.defaultHalfThickness
        ).x
    }

    private let blue = ThreadColorID(rawValue: "blue")
    private let pink = ThreadColorID(rawValue: "pink")
    private let white = ThreadColorID(rawValue: "white")
    private let black = ThreadColorID(rawValue: "black")
    private let lightBlue = ThreadColorID(rawValue: "light-blue")
    private let mauve = ThreadColorID(rawValue: "mauve")
    private let vermilion = ThreadColorID(rawValue: "vermilion")
    private let salmon = ThreadColorID(rawValue: "salmon")

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

    private var bookAP96Colouring: [ThreadAssignment] {
        var colours = [Int: ThreadColorID]()
        for group in [HiraGenjiBoardState.initial.north, HiraGenjiBoardState.initial.south] {
            for (position, colour) in zip(group, [mauve, mauve, black, vermilion]) {
                colours[position] = colour
            }
        }
        return (1...16).map {
            ThreadAssignment(position: $0, colorID: colours[$0] ?? salmon)
        }
    }

    private func assignments(_ color: (Int) -> ThreadColorID) -> [ThreadAssignment] {
        (1...16).map { ThreadAssignment(position: $0, colorID: color($0)) }
    }
}
