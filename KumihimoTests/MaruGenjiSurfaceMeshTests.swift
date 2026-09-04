import Foundation
import RealityKit
import simd
import Testing
@testable import Kumihimo

struct MaruGenjiSurfaceMeshTests {
    @Test func meshIsFiniteGroupedAndNondegenerate() throws {
        let mesh = try makeMesh()

        #expect(mesh.positions.count == mesh.normals.count)
        #expect(mesh.positions.count == mesh.tangents.count)
        #expect(mesh.positions.count == mesh.bitangents.count)
        #expect(mesh.positions.count == mesh.textureCoordinates.count)
        #expect(mesh.positions.count == mesh.strandCoordinates.count)
        #expect(mesh.positions.count == mesh.twistPhases.count)
        #expect(mesh.positions.count == mesh.vertexSegmentIndices.count)
        #expect(mesh.positions.count == mesh.vertexIsCrossingWall.count)
        #expect(mesh.positions.allSatisfy(isFinite))
        #expect(mesh.normals.allSatisfy(isUnit))
        #expect(mesh.tangents.allSatisfy(isUnit))
        #expect(mesh.bitangents.allSatisfy(isUnit))
        #expect(mesh.textureCoordinates.allSatisfy(isFiniteUnitCoordinate))
        #expect(mesh.strandCoordinates.allSatisfy { $0.x.isFinite && (-1.001...1.001).contains($0.y) })
        #expect(mesh.twistPhases.allSatisfy { $0.isFinite })
        #expect(Set(mesh.colorGroups.keys) == Set([blue, pink]))
        #expect(mesh.colorGroups.values.allSatisfy { !$0.isEmpty })
        #expect(mesh.triangleSegmentIndices.count == mesh.triangleCount)
        #expect(mesh.triangleSegmentIndices.count == mesh.triangleIsCrossingWall.count)

        let indices = mesh.allTriangleIndices
        #expect(indices.count.isMultiple(of: 3))
        #expect(indices.allSatisfy { Int($0) < mesh.positions.count })
        for offset in stride(from: 0, to: indices.count, by: 3) {
            let first = mesh.positions[Int(indices[offset])]
            let second = mesh.positions[Int(indices[offset + 1])]
            let third = mesh.positions[Int(indices[offset + 2])]
            #expect(simd_length_squared(simd_cross(second - first, third - first))
                > 0.000_000_000_001)
        }
    }

    @Test func meshContainsNoEndCapTriangles() throws {
        let mesh = try makeMesh()
        let indices = mesh.allTriangleIndices

        for offset in stride(from: 0, to: indices.count, by: 3) {
            let triangle = (0..<3).map { mesh.positions[Int(indices[offset + $0])] }
            let hasConstantX = triangle.allSatisfy { abs($0.x - triangle[0].x) < 0.000_001 }
            #expect(!hasConstantX)
        }
    }

    @Test func everySurfacePatchReachesTheMesh() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))

        #expect(mesh.triangleSegmentIndices.allSatisfy { pattern.patches.indices.contains($0) })
        for index in pattern.patches.indices {
            #expect(mesh.triangleSegmentIndices.contains(index))
        }
    }

    // MARK: - Round strands

    @Test func everyStrandIsARidgeWithItsEdgesInTheSharedValley() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        let base = MaruGenjiSurfaceMeshGenerator.defaultRadius
        let tolerance: Float = 0.000_1

        for index in pattern.patches.indices {
            // Excludes the walls sealing a crossing and the lap past a strand's own
            // ends, which both sit at or below the valley floor by design.
            let vertices = mesh.positions.indices.filter {
                mesh.vertexSegmentIndices[$0] == index
                    && !mesh.vertexIsCrossingWall[$0]
                    && (0...1).contains(mesh.strandCoordinates[$0].x)
            }
            #expect(!vertices.isEmpty)

            let crest = vertices.filter { abs(mesh.strandCoordinates[$0].y) < 0.000_1 }
            let edges = vertices.filter { abs(mesh.strandCoordinates[$0].y) > 1 - 0.000_1 }
            #expect(!crest.isEmpty)
            #expect(!edges.isEmpty)
            #expect(crest.allSatisfy { radius(of: mesh, at: $0) > base + tolerance })
            #expect(edges.allSatisfy { radius(of: mesh, at: $0) <= base + tolerance })
            #expect(edges.allSatisfy {
                abs(radius(of: mesh, at: $0) - mesh.valleyFloorRadius) < tolerance
            })
        }
    }

    @Test func radiusStaysInsideTheConfiguredReliefRange() throws {
        let mesh = try makeMesh()
        let base = MaruGenjiSurfaceMeshGenerator.defaultRadius
        let highest = base * (
            1 - MaruGenjiSurfaceMeshGenerator.valleyDepthRatio
                + MaruGenjiSurfaceMeshGenerator.crestHeightRatio
                * (1 + MaruGenjiSurfaceMeshGenerator.overCrossingLift)
        )
        let radii = mesh.positions.indices.map { radius(of: mesh, at: $0) }

        let lowest = mesh.valleyFloorRadius
            - base * MaruGenjiSurfaceMeshGenerator.overCrossingLapSink
        #expect(radii.allSatisfy { $0 >= lowest - 0.000_1 })
        #expect(radii.allSatisfy { $0 <= highest + 0.000_1 })
        // The silhouette has to undulate rather than trace a circle.
        #expect((radii.max() ?? 0) - (radii.min() ?? 0) > base * 0.08)
    }

    @Test func theStrandPassingOverACrossingCoversTheStepBelowIt() {
        let radius = MaruGenjiSurfaceMeshGenerator.defaultRadius
        let floor = radius * (1 - MaruGenjiSurfaceMeshGenerator.valleyDepthRatio)

        for step in 0...20 {
            let across = Float(step) / 10 - 1
            for along in [Float(0), Float(1)] {
                let over = MaruGenjiSurfaceMeshGenerator.strandRadius(
                    layer: .over, along: along, across: across, radius: radius
                )
                let under = MaruGenjiSurfaceMeshGenerator.strandRadius(
                    layer: .under, along: along, across: across, radius: radius
                )
                #expect(over >= under)
                #expect(under >= floor - 0.000_1)
            }
        }

        // Both layers meet exactly in the valley, so neighbouring strands never
        // leave a gap however differently their crests are scaled.
        for along in [Float(0), Float(0.5), Float(1)] {
            for across in [Float(-1), Float(1)] {
                #expect(abs(MaruGenjiSurfaceMeshGenerator.strandRadius(
                    layer: .over, along: along, across: across, radius: radius
                ) - floor) < 0.000_01)
                #expect(abs(MaruGenjiSurfaceMeshGenerator.strandRadius(
                    layer: .under, along: along, across: across, radius: radius
                ) - floor) < 0.000_01)
            }
        }
    }

    @Test func onlyTheOverStrandSealsACrossingSoTheWallsNeverOverlap() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))

        #expect(mesh.triangleIsCrossingWall.contains(true))
        #expect(mesh.triangleIsCrossingWall.contains(false))
        for (index, isWall) in zip(mesh.triangleSegmentIndices, mesh.triangleIsCrossingWall)
        where isWall {
            #expect(pattern.patches[index].layer == .over)
        }
        for index in pattern.patches.indices where pattern.patches[index].layer == .over {
            #expect(zip(mesh.triangleSegmentIndices, mesh.triangleIsCrossingWall)
                .contains { $0 == index && $1 })
        }
    }

    // MARK: - Seams

    @Test func longitudinalTileBoundariesHaveMatchingGeometry() throws {
        let mesh = try makeMesh()
        let halfLength = MaruGenjiSurfaceMeshGenerator.defaultLength / 2
        // The visible skin has to present the same ring at both ends so tiles can be
        // repeated. The walls sealing a crossing are excluded: one of them may begin
        // exactly on a repeat boundary, and the adjoining tile carries its
        // continuation.
        let surface = mesh.positions.indices.filter { !mesh.vertexIsCrossingWall[$0] }
        let start = surface.filter { abs(mesh.positions[$0].x + halfLength) < 0.000_001 }
        let end = surface.filter { abs(mesh.positions[$0].x - halfLength) < 0.000_001 }

        #expect(!start.isEmpty)
        #expect(boundariesMatch(start, end, in: mesh))
        #expect(edgeColorIDs(start, in: mesh) == edgeColorIDs(end, in: mesh))
    }

    @Test func circumferentialSeamIsSealedAtEveryLongitudinalPosition() throws {
        let mesh = try makeMesh()

        #expect(!mesh.seamStartVertexIndices.isEmpty)
        #expect(!mesh.seamEndVertexIndices.isEmpty)

        let start = radiiByLongitudinalPosition(mesh.seamStartVertexIndices, in: mesh)
        let end = radiiByLongitudinalPosition(mesh.seamEndVertexIndices, in: mesh)
        #expect(Set(start.keys) == Set(end.keys))

        for (key, startRadii) in start {
            let endRadii = try #require(end[key])
            let startRange = (startRadii.min() ?? 0)...(startRadii.max() ?? 0)
            let endRange = (endRadii.min() ?? 0)...(endRadii.max() ?? 0)
            // Both sides of the seam reach the shared valley floor, and the wall on
            // the over side spans the step, so the tube stays closed.
            #expect(startRange.overlaps(endRange))
            #expect(min(startRange.lowerBound, endRange.lowerBound)
                <= mesh.valleyFloorRadius + 0.000_1)
        }
    }

    // MARK: - Twist

    @Test func twistPhaseIsAffineAndThereforeContinuousInsideAStrand() throws {
        let mesh = try makeMesh()
        let twist = MaruGenjiSurfaceMeshGenerator.twistCoefficients(
            for: BraidStrandSurfaceBuilder.surface(
                for: try #require(
                    MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
                )
            ),
            radius: MaruGenjiSurfaceMeshGenerator.defaultRadius,
            length: MaruGenjiSurfaceMeshGenerator.defaultLength,
            repeatCount: MaruGenjiSurfaceMeshGenerator.defaultPatternRepeatCount
        )

        #expect(twist.phasePerAlong.isFinite)
        #expect(twist.phasePerAcross.isFinite)
        #expect(abs(twist.phasePerAlong) > 0)
        #expect(abs(twist.phasePerAcross) > 0)
        #expect(abs(twist.phasePerAlong)
            == 2 * .pi * Float(MaruGenjiSurfaceMeshGenerator.fiberCount))

        for index in mesh.positions.indices {
            let expected = twist.phase(
                along: mesh.strandCoordinates[index].x,
                across: mesh.strandCoordinates[index].y
            )
            #expect(abs(mesh.twistPhases[index] - expected) < 0.000_5)
        }
    }

    @Test func twistRunsAtTheSameAngleAndHandAcrossEveryStrand() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let surface = BraidStrandSurfaceBuilder.surface(for: pattern)
        let radius = MaruGenjiSurfaceMeshGenerator.defaultRadius
        let length = MaruGenjiSurfaceMeshGenerator.defaultLength
        let repeatCount = MaruGenjiSurfaceMeshGenerator.defaultPatternRepeatCount
        let twist = MaruGenjiSurfaceMeshGenerator.twistCoefficients(
            for: surface, radius: radius, length: length, repeatCount: repeatCount
        )

        let angles = surface.segments.map { segment -> Float in
            let along = MaruGenjiSurfaceMeshGenerator.worldOffset(
                segment.centerlineDelta, radius: radius, length: length, repeatCount: repeatCount
            )
            let across = MaruGenjiSurfaceMeshGenerator.worldOffset(
                segment.meanHalfWidth, radius: radius, length: length, repeatCount: repeatCount
            )
            // Direction along a stripe: the world direction the phase is constant in.
            let stripe = along * twist.phasePerAcross - across * twist.phasePerAlong
            return signedAngle(from: along, to: stripe)
        }

        #expect(angles.count == MaruGenjiSurfacePatternGenerator.patchCount)
        #expect(angles.allSatisfy { $0 > 0 })
        #expect(angles.allSatisfy { (20...40).contains($0) })
        #expect(abs((angles.max() ?? 0) - (angles.min() ?? 0)) < 12)
        #expect(abs(
            angles.reduce(0, +) / Float(angles.count)
                - MaruGenjiSurfaceMeshGenerator.twistAngleDegrees
        ) < 3)
    }

    // MARK: - Regression

    @Test func meshGenerationIsDeterministic() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let first = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        let second = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))

        #expect(first.positions == second.positions)
        #expect(first.normals == second.normals)
        #expect(first.tangents == second.tangents)
        #expect(first.bitangents == second.bitangents)
        #expect(first.textureCoordinates == second.textureCoordinates)
        #expect(first.strandCoordinates == second.strandCoordinates)
        #expect(first.twistPhases == second.twistPhases)
        #expect(first.colorGroups == second.colorGroups)
        #expect(first.triangleSegmentIndices == second.triangleSegmentIndices)
        #expect(first.triangleIsCrossingWall == second.triangleIsCrossingWall)
        #expect(first.triangleCount == second.triangleCount)
    }

    @Test func malformedPatternAndParametersFailSafely() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )

        #expect(MaruGenjiSurfaceMeshGenerator.generate(
            pattern: MaruGenjiSurfacePattern(patches: Array(pattern.patches.dropLast()))
        ) == nil)
        #expect(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern, radius: .nan) == nil)
        #expect(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern, length: 0) == nil)
        #expect(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern, patternRepeatCount: 0) == nil)
        #expect(MaruGenjiSurfaceMeshGenerator.generate(
            pattern: pattern,
            alongStrandSubdivisions: MaruGenjiSurfaceMeshGenerator.minimumAlongStrandSubdivisions - 1
        ) == nil)
        #expect(MaruGenjiSurfaceMeshGenerator.generate(
            pattern: pattern,
            acrossStrandSubdivisions: MaruGenjiSurfaceMeshGenerator.minimumAcrossStrandSubdivisions - 1
        ) == nil)
    }

    @Test @MainActor func allMaterialGroupsBuildOneRealityKitMesh() throws {
        for assignments in [
            fixtureAssignments,
            verifiedFixture1,
            ProjectEditorPreviewData.maruGenjiSurfaceFixture1,
        ] {
            let pattern = try #require(
                MaruGenjiSurfacePatternGenerator.generate(assignments: assignments)
            )
            let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))

            var indices = [UInt32]()
            var materialIndices = [UInt32]()
            for (materialIndex, group) in mesh.colorGroups
                .sorted(by: { $0.key.rawValue < $1.key.rawValue })
                .enumerated() {
                indices.append(contentsOf: group.value)
                materialIndices.append(
                    contentsOf: repeatElement(UInt32(materialIndex), count: group.value.count / 3)
                )
            }
            var descriptor = MeshDescriptor(name: "maru-genji-surface")
            descriptor.positions = MeshBuffer(mesh.positions)
            descriptor.normals = MeshBuffer(mesh.normals)
            descriptor.tangents = MeshBuffer(mesh.tangents)
            descriptor.bitangents = MeshBuffer(mesh.bitangents)
            descriptor.textureCoordinates = MeshBuffer(mesh.textureCoordinates)
            descriptor.primitives = .triangles(indices)
            descriptor.materials = .perFace(materialIndices)
            _ = try MeshResource.generate(from: [descriptor])
        }
    }

    // MARK: - Helpers

    private let blue = ThreadColorID(rawValue: "blue")
    private let pink = ThreadColorID(rawValue: "pink")

    private var fixtureAssignments: [ThreadAssignment] {
        (1...16).map { position in
            ThreadAssignment(
                position: position,
                colorID: position.isMultiple(of: 2) ? pink : blue
            )
        }
    }

    private var verifiedFixture1: [ThreadAssignment] {
        let colors = [
            blue, pink, pink, blue,
            blue, pink, pink, blue,
            blue, pink, pink, blue,
            blue, pink, pink, blue,
        ]
        return colors.enumerated().map { index, colorID in
            ThreadAssignment(position: index + 1, colorID: colorID)
        }
    }

    private func makeMesh() throws -> MaruGenjiSurfaceMeshData {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        return try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))
    }

    private func radius(of mesh: MaruGenjiSurfaceMeshData, at index: Int) -> Float {
        let position = mesh.positions[index]
        return hypot(position.y, position.z)
    }

    private func radiiByLongitudinalPosition(
        _ indices: [Int],
        in mesh: MaruGenjiSurfaceMeshData
    ) -> [Int: [Float]] {
        var result = [Int: [Float]]()
        for index in indices {
            let key = Int((mesh.positions[index].x * 10_000).rounded())
            result[key, default: []].append(radius(of: mesh, at: index))
        }
        return result
    }

    private func signedAngle(from first: SIMD2<Float>, to second: SIMD2<Float>) -> Float {
        let cross = first.x * second.y - first.y * second.x
        let dot = simd_dot(first, second)
        return atan2(cross, dot) * 180 / .pi
    }

    private func isFinite(_ vector: SIMD3<Float>) -> Bool {
        vector.x.isFinite && vector.y.isFinite && vector.z.isFinite
    }

    private func isUnit(_ vector: SIMD3<Float>) -> Bool {
        isFinite(vector) && abs(simd_length(vector) - 1) < 0.001
    }

    private func isFiniteUnitCoordinate(_ vector: SIMD2<Float>) -> Bool {
        vector.x.isFinite && vector.y.isFinite
            && (0...1).contains(vector.x)
            && (0...1).contains(vector.y)
    }

    /// A tile end must present the same ring of geometry at both ends so instances
    /// can be repeated. Strand surfaces and the walls sealing a crossing are matched
    /// separately: they can share a position on the valley line while facing apart.
    private func boundariesMatch(
        _ startIndices: [Int],
        _ endIndices: [Int],
        in mesh: MaruGenjiSurfaceMeshData
    ) -> Bool {
        func hasMatch(for sourceIndex: Int, in candidates: [Int]) -> Bool {
            let sourcePosition = mesh.positions[sourceIndex]
            let sourceNormal = mesh.normals[sourceIndex]
            let sourceIsWall = mesh.vertexIsCrossingWall[sourceIndex]
            return candidates.contains { candidateIndex in
                guard mesh.vertexIsCrossingWall[candidateIndex] == sourceIsWall else { return false }
                let candidatePosition = mesh.positions[candidateIndex]
                return hypot(
                    sourcePosition.y - candidatePosition.y,
                    sourcePosition.z - candidatePosition.z
                ) < 0.000_2
                    && simd_distance(sourceNormal, mesh.normals[candidateIndex]) < 0.002
            }
        }

        return startIndices.allSatisfy { hasMatch(for: $0, in: endIndices) }
            && endIndices.allSatisfy { hasMatch(for: $0, in: startIndices) }
    }

    private func edgeColorIDs(
        _ boundaryIndices: [Int],
        in mesh: MaruGenjiSurfaceMeshData
    ) -> Set<ThreadColorID> {
        let boundarySet = Set(boundaryIndices.map(UInt32.init))
        return Set(mesh.colorGroups.compactMap { colorID, indices in
            indices.contains(where: boundarySet.contains) ? colorID : nil
        })
    }
}
