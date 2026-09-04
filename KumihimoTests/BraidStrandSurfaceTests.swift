import Foundation
import simd
import Testing
@testable import Kumihimo

struct BraidStrandSurfaceTests {
    @Test func everyPatchCarriesACrossingLayer() throws {
        let pattern = try #require(MaruGenjiSurfacePatternGenerator.generate(assignments: fixture))

        #expect(pattern.patches.count == MaruGenjiSurfacePatternGenerator.patchCount)
        #expect(pattern.patches.contains { $0.layer == .over })
        #expect(pattern.patches.contains { $0.layer == .under })
        #expect(pattern.patches.count { $0.layer == .over } == pattern.patches.count / 2)
    }

    @Test func strandsMeetingAtACrossingTakeOppositeLayers() throws {
        let pattern = try #require(MaruGenjiSurfacePatternGenerator.generate(assignments: fixture))
        let leadingEdges = Dictionary(
            grouping: pattern.patches.indices,
            by: { edgeKey(of: pattern.patches[$0], leading: true) }
        )

        var crossingCount = 0
        for index in pattern.patches.indices {
            let patch = pattern.patches[index]
            let partners = leadingEdges[edgeKey(of: patch, leading: false)] ?? []
            #expect(partners.count == 1)
            for partner in partners {
                crossingCount += 1
                #expect(pattern.patches[partner].layer == patch.layer.opposite)
            }
        }
        #expect(crossingCount == pattern.patches.count)
    }

    @Test func oneThreadAlternatesOverAndUnderAlongItsLength() throws {
        let pattern = try #require(MaruGenjiSurfacePatternGenerator.generate(assignments: fixture))

        for position in 1...MaruGenjiSurfacePatternGenerator.requiredThreadCount {
            let layers = pattern.patches
                .filter { $0.threadPosition == position }
                .sorted { longitudinalCenter(of: $0) < longitudinalCenter(of: $1) }
                .map(\.layer)

            #expect(layers.count == 4)
            #expect(zip(layers, layers.dropFirst()).allSatisfy { $0 != $1 })
            // The pattern repeats, so the last run must also differ from the first.
            #expect(layers.first != layers.last)
        }
    }

    @Test func layerAssignmentIsDeterministicAndIndependentOfColour() throws {
        let first = try #require(MaruGenjiSurfacePatternGenerator.generate(assignments: fixture))
        let second = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: Array(fixture.reversed()))
        )
        let recoloured = try #require(
            MaruGenjiSurfacePatternGenerator.generate(
                assignments: fixture.map {
                    ThreadAssignment(position: $0.position, colorID: natural)
                }
            )
        )

        #expect(first.patches.map(\.layer) == second.patches.map(\.layer))
        #expect(first.patches.map(\.layer) == recoloured.patches.map(\.layer))
    }

    @Test func strandSegmentsReproduceTheirPatchCorners() throws {
        let pattern = try #require(MaruGenjiSurfacePatternGenerator.generate(assignments: fixture))
        let surface = BraidStrandSurfaceBuilder.surface(for: pattern)

        #expect(surface.segments.count == pattern.patches.count)
        for (segment, patch) in zip(surface.segments, pattern.patches) {
            #expect(segment.threadPosition == patch.threadPosition)
            #expect(segment.colorID == patch.colorID)
            #expect(segment.layer == patch.layer)
            let corners = [
                segment.surfacePoint(along: 0, across: -1),
                segment.surfacePoint(along: 0, across: 1),
                segment.surfacePoint(along: 1, across: 1),
                segment.surfacePoint(along: 1, across: -1),
            ]
            for (rebuilt, original) in zip(corners, patch.corners) {
                #expect(simd_distance(rebuilt, original) < 0.000_01)
            }
        }
    }

    @Test func centrelineRunsBetweenTheMidpointsOfTheTwoCrossingEdges() throws {
        let pattern = try #require(MaruGenjiSurfacePatternGenerator.generate(assignments: fixture))
        let surface = BraidStrandSurfaceBuilder.surface(for: pattern)

        for (segment, patch) in zip(surface.segments, pattern.patches) {
            #expect(simd_distance(
                segment.surfacePoint(along: 0, across: 0),
                (patch.corners[0] + patch.corners[1]) / 2
            ) < 0.000_01)
            #expect(simd_distance(
                segment.surfacePoint(along: 1, across: 0),
                (patch.corners[2] + patch.corners[3]) / 2
            ) < 0.000_01)
            #expect(simd_length(segment.centerlineDelta) > 0)
            #expect(simd_length(segment.meanHalfWidth) > 0)
        }
    }

    @Test func malformedPatchesProduceNoSegment() {
        let patch = MaruGenjiSurfacePatch(
            threadPosition: 1,
            colorID: blue,
            layer: .over,
            corners: [SIMD2<Float>(0, 0), SIMD2<Float>(0, 1)]
        )
        let infinite = MaruGenjiSurfacePatch(
            threadPosition: 1,
            colorID: blue,
            layer: .over,
            corners: [
                SIMD2<Float>(0, 0),
                SIMD2<Float>(0, .infinity),
                SIMD2<Float>(1, 1),
                SIMD2<Float>(1, 0),
            ]
        )

        #expect(BraidStrandSurfaceBuilder.segment(for: patch) == nil)
        #expect(BraidStrandSurfaceBuilder.segment(for: infinite) == nil)
    }

    // MARK: - Helpers

    private let blue = ThreadColorID(rawValue: "blue")
    private let pink = ThreadColorID(rawValue: "pink")
    private let natural = ThreadColorID(rawValue: "natural")

    private var fixture: [ThreadAssignment] {
        (1...16).map { position in
            ThreadAssignment(
                position: position,
                colorID: position.isMultiple(of: 2) ? pink : blue
            )
        }
    }

    /// Two strands cross where the trailing edge of one is the leading edge of the
    /// other. The braid closes on itself both ways, so wrap the key around the
    /// circumference and along one pattern repeat.
    private func edgeKey(of patch: MaruGenjiSurfacePatch, leading: Bool) -> String {
        let corners = leading
            ? [patch.corners[0], patch.corners[1]]
            : [patch.corners[3], patch.corners[2]]
        return corners
            .map { corner in
                let around = corner.x >= 1 - 0.000_1 ? 0 : corner.x
                let along = corner.y.truncatingRemainder(dividingBy: 1)
                let wrapped = along >= 1 - 0.000_1 ? 0 : along
                return String(format: "%.3f,%.3f", around, wrapped)
            }
            .sorted()
            .joined(separator: "|")
    }

    private func longitudinalCenter(of patch: MaruGenjiSurfacePatch) -> Float {
        let center = patch.corners.map(\.y).reduce(0, +) / Float(patch.corners.count)
        return center.truncatingRemainder(dividingBy: 1)
    }
}
