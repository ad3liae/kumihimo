import Foundation
import Testing
@testable import Kumihimo

struct MaruGenjiSurfacePatternTests {
    @Test func validAssignmentsProduceTheFixedSixtyFourPatchCorrespondence() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixture1)
        )

        #expect(pattern.patches.count == 64)
        #expect(pattern.patches.allSatisfy { $0.corners.count == 4 })
        #expect(pattern.patches.allSatisfy { patch in
            patch.corners.allSatisfy {
                (0...1).contains($0.x)
                    && (0...MaruGenjiSurfacePatternGenerator.maximumUnwrappedV).contains($0.y)
            }
        })
        #expect(pattern.patches.contains { patch in patch.corners.contains { $0.y > 1 } })
        for position in 1...16 {
            #expect(pattern.patches.count { $0.threadPosition == position } == 4)
            #expect(pattern.patches
                .filter { $0.threadPosition == position }
                .allSatisfy { $0.colorID == fixture1[position - 1].colorID })
        }
    }

    @Test func generationIsDeterministicIncludingPatchOrderAndCoordinates() throws {
        let first = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixture3)
        )
        let second = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: Array(fixture3.reversed()))
        )

        #expect(first == second)
    }

    @Test func flattenedFacesShareTheSameLongitudinalOrigin() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixture1)
        )

        let minimumVByFace = (0..<4).map { face in
            pattern.patches
                .filter { patch in
                    Int(min(center(of: patch).x * 4, 3)) == face
                }
                .flatMap(\.corners)
                .map(\.y)
                .min()
        }

        #expect(minimumVByFace.allSatisfy { $0 == 0 })
    }

    @Test func duplicateMissingOutOfRangeAndWrongCountsFailSafely() {
        let valid = fixture1
        let duplicate = Array(valid.dropLast()) + [
            ThreadAssignment(position: 15, colorID: blue),
        ]
        let outOfRange = Array(valid.dropLast()) + [
            ThreadAssignment(position: 17, colorID: blue),
        ]

        #expect(MaruGenjiSurfacePatternGenerator.generate(assignments: duplicate) == nil)
        #expect(MaruGenjiSurfacePatternGenerator.generate(assignments: outOfRange) == nil)
        #expect(MaruGenjiSurfacePatternGenerator.generate(assignments: Array(valid.dropLast())) == nil)
        #expect(
            MaruGenjiSurfacePatternGenerator.generate(
                assignments: valid + [ThreadAssignment(position: 17, colorID: blue)]
            ) == nil
        )
    }

    @Test func cyclicPositionShiftPreservesPatchAndColorCounts() throws {
        let original = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixture3)
        )
        let shiftedAssignments = fixture3.map { assignment in
            ThreadAssignment(
                position: assignment.position == 16 ? 1 : assignment.position + 1,
                colorID: assignment.colorID
            )
        }
        let shifted = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: shiftedAssignments)
        )

        #expect(original.patches.count == shifted.patches.count)
        #expect(colorCounts(in: original) == colorCounts(in: shifted))
        #expect(Set(original.patches.map(\.colorID)) == Set(shifted.patches.map(\.colorID)))
    }

    @Test func threeVerifiedFixturesKeepTheirFixedSpatialSignatures() throws {
        let first = try #require(MaruGenjiSurfacePatternGenerator.generate(assignments: fixture1))
        let second = try #require(MaruGenjiSurfacePatternGenerator.generate(assignments: fixture2))
        let third = try #require(MaruGenjiSurfacePatternGenerator.generate(assignments: fixture3))

        #expect(spatialSignature(first) ==
            "BBBBBBBBPPPPPPPPBBBBBBBBPPPPPPPPBBBBBBBBPPPPPPPPBBBBBBBBPPPPPPPP")
        #expect(spatialSignature(second) ==
            "BBPPBBPPBBPPBBPPBBPPBBPPBBPPBBPPBBPPBBPPBBPPBBPPBBPPBBPPBBPPBBPP")
        #expect(spatialSignature(third) ==
            "PBBPPBBPPBBPPBBPBPPBBPPBBPPBBPPBPBBPPBBPPBBPPBBPBPPBBPPBBPPBBPPB")
        #expect(Set([spatialSignature(first), spatialSignature(second), spatialSignature(third)]).count == 3)
    }

    @Test func fixturesExpressFineChevronSolidFacesAndPhaseShift() throws {
        let first = try #require(MaruGenjiSurfacePatternGenerator.generate(assignments: fixture1))
        let second = try #require(MaruGenjiSurfacePatternGenerator.generate(assignments: fixture2))
        let third = try #require(MaruGenjiSurfacePatternGenerator.generate(assignments: fixture3))

        let firstFaces = faceColorSequences(first)
        #expect(firstFaces.allSatisfy { Set($0).count == 2 })
        #expect(firstFaces.allSatisfy { transitionCount($0) >= 3 })

        let secondFaces = faceColorSequences(second)
        #expect(secondFaces.map { Set($0) } == [[blue], [pink], [blue], [pink]])

        let thirdFaces = faceColorSequences(third)
        #expect(thirdFaces.allSatisfy { Set($0).count == 2 })
        #expect(thirdFaces[0] != thirdFaces[1])
        #expect(spatialSignature(first) != spatialSignature(third))
    }

    @Test func colorChangeUpdatesThePatternConsumedByThumbnailAndSurfaceMesh() throws {
        let before = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixture2)
        )
        let beforeMesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: before))
        var changedAssignments = fixture2
        changedAssignments[0].colorID = pink
        let after = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: changedAssignments)
        )
        let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: after))

        #expect(before != after)
        #expect(after.patches.count { $0.colorID == pink } == 36)
        #expect(mesh.colorGroups[pink]?.isEmpty == false)
        #expect((mesh.colorGroups[pink]?.count ?? 0) > (beforeMesh.colorGroups[pink]?.count ?? 0))
        #expect((mesh.colorGroups[blue]?.count ?? 0) < (beforeMesh.colorGroups[blue]?.count ?? 0))
    }

    private let blue = ThreadColorID(rawValue: "blue")
    private let pink = ThreadColorID(rawValue: "pink")

    private var fixture1: [ThreadAssignment] {
        assignments([
            blue, pink, pink, blue,
            blue, pink, pink, blue,
            blue, pink, pink, blue,
            blue, pink, pink, blue,
        ])
    }

    private var fixture2: [ThreadAssignment] {
        assignments([
            blue, blue,
            pink, pink, pink, pink,
            blue, blue, blue, blue,
            pink, pink, pink, pink,
            blue, blue,
        ])
    }

    private var fixture3: [ThreadAssignment] {
        assignments([
            blue, blue, blue, blue,
            pink, pink, pink, pink,
            blue, blue, blue, blue,
            pink, pink, pink, pink,
        ])
    }

    private func assignments(_ colors: [ThreadColorID]) -> [ThreadAssignment] {
        colors.enumerated().map { index, colorID in
            ThreadAssignment(position: index + 1, colorID: colorID)
        }
    }

    private func colorCounts(in pattern: MaruGenjiSurfacePattern) -> [ThreadColorID: Int] {
        Dictionary(grouping: pattern.patches, by: \.colorID).mapValues(\.count)
    }

    private func spatialSignature(_ pattern: MaruGenjiSurfacePattern) -> String {
        pattern.patches.sorted { first, second in
            let firstCenter = center(of: first)
            let secondCenter = center(of: second)
            if firstCenter.y != secondCenter.y { return firstCenter.y < secondCenter.y }
            return firstCenter.x < secondCenter.x
        }
        .map { $0.colorID == blue ? "B" : "P" }
        .joined()
    }

    private func faceColorSequences(
        _ pattern: MaruGenjiSurfacePattern
    ) -> [[ThreadColorID]] {
        (0..<4).map { face in
            pattern.patches.filter { patch in
                Int(min(center(of: patch).x * 4, 3)) == face
            }
            .sorted { center(of: $0).y < center(of: $1).y }
            .map(\.colorID)
        }
    }

    private func center(of patch: MaruGenjiSurfacePatch) -> SIMD2<Float> {
        patch.corners.reduce(.zero, +) / Float(patch.corners.count)
    }

    private func transitionCount(_ colors: [ThreadColorID]) -> Int {
        zip(colors, colors.dropFirst()).count { pair in pair.0 != pair.1 }
    }
}
