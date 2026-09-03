import Foundation
import RealityKit
import simd
import Testing
@testable import Kumihimo

struct MaruGenjiSurfaceMeshTests {
    @Test func meshIsFiniteOpenGroupedAndNondegenerate() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        #expect(mesh.positions.count == mesh.normals.count)
        #expect(mesh.positions.count == mesh.textureCoordinates.count)
        #expect(mesh.positions.count == mesh.patchLocalCoordinates.count)
        #expect(mesh.positions.count == mesh.boundaryDistances.count)
        #expect(mesh.positions.count == mesh.surfaceVertexPatchIndices.count)
        #expect(mesh.positions.allSatisfy(isFinite))
        #expect(mesh.normals.allSatisfy(isFinite))
        #expect(mesh.normals.allSatisfy { abs(simd_length($0) - 1) < 0.001 })
        #expect(Set(mesh.colorGroups.keys).union(mesh.boundaryColorGroups.keys) == Set([blue, pink]))
        #expect(mesh.colorGroups.values.allSatisfy { !$0.isEmpty })
        #expect(mesh.boundaryColorGroups.values.allSatisfy { !$0.isEmpty })
        #expect(mesh.textureCoordinates.allSatisfy(isFiniteUnitCoordinate))
        #expect(mesh.patchLocalCoordinates.allSatisfy(isFiniteUnitCoordinate))
        #expect(mesh.boundaryDistances.allSatisfy { $0.isFinite && (0...0.5).contains($0) })
        #expect(mesh.surfaceVertexPatchIndices.allSatisfy { pattern.patches.indices.contains($0) })
        #expect(mesh.surfaceTrianglePatchIndices.count == mesh.triangleCount)

        let indices = mesh.allTriangleIndices
        #expect(indices.allSatisfy { Int($0) < mesh.positions.count })
        #expect(indices.count.isMultiple(of: 3))
        for offset in stride(from: 0, to: indices.count, by: 3) {
            let first = mesh.positions[Int(indices[offset])]
            let second = mesh.positions[Int(indices[offset + 1])]
            let third = mesh.positions[Int(indices[offset + 2])]
            #expect(simd_length_squared(simd_cross(second - first, third - first))
                > 0.000_000_000_001)
        }
    }

    @Test func meshContainsNoEndCapTriangles() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        let indices = mesh.allTriangleIndices

        for offset in stride(from: 0, to: indices.count, by: 3) {
            let triangle = (0..<3).map { mesh.positions[Int(indices[offset + $0])] }
            let hasConstantX = triangle.allSatisfy {
                abs($0.x - triangle[0].x) < 0.000_001
            }
            #expect(!hasConstantX)
        }
    }

    @Test func longitudinalTileBoundariesHaveMatchingGeometryAndSurfaceState() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        let halfLength = MaruGenjiSurfaceMeshGenerator.defaultLength / 2
        let start = mesh.positions.indices.filter { abs(mesh.positions[$0].x + halfLength) < 0.000_001 }
        let end = mesh.positions.indices.filter { abs(mesh.positions[$0].x - halfLength) < 0.000_001 }

        #expect(!start.isEmpty)
        #expect(boundariesMatch(start, end, in: mesh))
        let startGroups = groupBoundaryCounts(start, in: mesh)
        let endGroups = groupBoundaryCounts(end, in: mesh)
        #expect(startGroups["base"] == endGroups["base"])
        #expect(startGroups["boundary"] == endGroups["boundary"])
        #expect(edgeColorIDs(start, in: mesh) == edgeColorIDs(end, in: mesh))
    }

    @Test func circumferentialSeamVerticesMatchExactly() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))

        #expect(mesh.seamStartVertexIndices.count == mesh.seamEndVertexIndices.count)
        #expect(!mesh.seamStartVertexIndices.isEmpty)
        for (startIndex, endIndex) in zip(
            mesh.seamStartVertexIndices,
            mesh.seamEndVertexIndices
        ) {
            #expect(mesh.positions[startIndex] == mesh.positions[endIndex])
            #expect(mesh.normals[startIndex] == mesh.normals[endIndex])
        }
    }

    @Test func everySurfacePatchIsRepresentedOncePerGeneratedTriangle() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        #expect(mesh.surfaceTrianglePatchIndices.allSatisfy { pattern.patches.indices.contains($0) })
        for patchIndex in pattern.patches.indices {
            #expect(mesh.surfaceTrianglePatchIndices.contains(patchIndex))
        }
        #expect(mesh.surfaceTrianglePatchIndices.count == mesh.surfaceTriangleIsBoundary.count)
    }

    @Test func everyPatchHasNarrowBoundaryAndInteriorReliefData() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))

        #expect(mesh.surfaceTriangleIsBoundary.contains(true))
        #expect(mesh.surfaceTriangleIsBoundary.contains(false))
        for patchIndex in pattern.patches.indices {
            let vertexIndices = mesh.surfaceVertexPatchIndices.indices.filter {
                mesh.surfaceVertexPatchIndices[$0] == patchIndex
            }
            #expect(!vertexIndices.isEmpty)
            #expect(vertexIndices.contains { mesh.boundaryDistances[$0] < 0.000_001 })
            #expect(vertexIndices.contains {
                mesh.boundaryDistances[$0] >= MaruGenjiSurfaceMeshGenerator.boundaryWidth
            })
        }

        let baseIndices = Set(mesh.colorGroups.values.flatMap { $0 })
        let boundaryIndices = Set(mesh.boundaryColorGroups.values.flatMap { $0 })
        #expect(baseIndices.isDisjoint(with: boundaryIndices))
    }

    @Test func boundaryReliefStaysWithinTheConfiguredRadiusLimit() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        let surfaceRadii = mesh.positions.indices.compactMap { index -> Float? in
            guard mesh.surfaceVertexPatchIndices[index] >= 0 else { return nil }
            let position = mesh.positions[index]
            return hypot(position.y, position.z)
        }
        let radius = MaruGenjiSurfaceMeshGenerator.defaultRadius
        #expect(surfaceRadii.allSatisfy {
            $0 >= radius * (1 - MaruGenjiSurfaceMeshGenerator.boundaryDepthRatio - 0.000_1)
                && $0 <= radius * (1 + MaruGenjiSurfaceMeshGenerator.fiberReliefRatio + 0.000_1)
        })
    }

    @Test func fiberCoordinatesAreDeterministicAndFollowOnePatchAxis() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        let firstPatchVertices = mesh.surfaceVertexPatchIndices.indices.filter {
            mesh.surfaceVertexPatchIndices[$0] == 0
                && mesh.boundaryDistances[$0] >= MaruGenjiSurfaceMeshGenerator.boundaryWidth
        }
        let coordinates = firstPatchVertices.map { mesh.patchLocalCoordinates[$0] }

        #expect(MaruGenjiSurfaceMeshGenerator.fiberCount == 8)
        #expect(Set(coordinates.map(\.y)).count >= MaruGenjiSurfaceMeshGenerator.fiberCount * 2 - 2)
        #expect(Set(coordinates.map(\.x)).count > 2)
        #expect(firstPatchVertices.allSatisfy {
            mesh.textureCoordinates[$0] == mesh.patchLocalCoordinates[$0]
        })
    }

    @Test func meshGenerationIsDeterministic() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let first = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        let second = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))

        #expect(first.positions == second.positions)
        #expect(first.normals == second.normals)
        #expect(first.textureCoordinates == second.textureCoordinates)
        #expect(first.patchLocalCoordinates == second.patchLocalCoordinates)
        #expect(first.boundaryDistances == second.boundaryDistances)
        #expect(first.colorGroups == second.colorGroups)
        #expect(first.boundaryColorGroups == second.boundaryColorGroups)
        #expect(first.surfaceTrianglePatchIndices == second.surfaceTrianglePatchIndices)
        #expect(first.surfaceTriangleIsBoundary == second.surfaceTriangleIsBoundary)
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
            longitudinalSubdivisionsPerPatch: MaruGenjiSurfaceMeshGenerator.fiberCount * 2
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

            let groups = mesh.colorGroups.sorted { $0.key.rawValue < $1.key.rawValue }
                + mesh.boundaryColorGroups.sorted { $0.key.rawValue < $1.key.rawValue }
            var indices = [UInt32]()
            var materialIndices = [UInt32]()
            for (materialIndex, group) in groups.enumerated() {
                indices.append(contentsOf: group.value)
                materialIndices.append(
                    contentsOf: repeatElement(
                        UInt32(materialIndex),
                        count: group.value.count / 3
                    )
                )
            }
            var descriptor = MeshDescriptor(name: "maru-genji-surface")
            descriptor.positions = MeshBuffer(mesh.positions)
            descriptor.normals = MeshBuffer(mesh.normals)
            descriptor.textureCoordinates = MeshBuffer(mesh.textureCoordinates)
            descriptor.primitives = .triangles(indices)
            descriptor.materials = .perFace(materialIndices)
            _ = try MeshResource.generate(from: [descriptor])
        }
    }

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

    private func isFinite(_ vector: SIMD3<Float>) -> Bool {
        vector.x.isFinite && vector.y.isFinite && vector.z.isFinite
    }

    private func isFiniteUnitCoordinate(_ vector: SIMD2<Float>) -> Bool {
        vector.x.isFinite && vector.y.isFinite
            && (0...1).contains(vector.x)
            && (0...1).contains(vector.y)
    }

    private func boundariesMatch(
        _ startIndices: [Int],
        _ endIndices: [Int],
        in mesh: MaruGenjiSurfaceMeshData
    ) -> Bool {
        func hasMatch(for sourceIndex: Int, in candidates: [Int]) -> Bool {
            let sourcePosition = mesh.positions[sourceIndex]
            let sourceNormal = mesh.normals[sourceIndex]
            return candidates.contains { candidateIndex in
                let candidatePosition = mesh.positions[candidateIndex]
                return hypot(
                    sourcePosition.y - candidatePosition.y,
                    sourcePosition.z - candidatePosition.z
                ) < 0.000_2
                    && simd_distance(sourceNormal, mesh.normals[candidateIndex]) < 0.000_2
            }
        }

        return startIndices.allSatisfy { hasMatch(for: $0, in: endIndices) }
            && endIndices.allSatisfy { hasMatch(for: $0, in: startIndices) }
    }

    private func groupBoundaryCounts(
        _ boundaryIndices: [Int],
        in mesh: MaruGenjiSurfaceMeshData
    ) -> [String: Int] {
        let boundarySet = Set(boundaryIndices.map(UInt32.init))
        var result = [String: Int]()
        for indices in mesh.colorGroups.values {
            result["base", default: 0] += indices.filter { boundarySet.contains($0) }.count
        }
        for indices in mesh.boundaryColorGroups.values {
            result["boundary", default: 0] += indices.filter { boundarySet.contains($0) }.count
        }
        return result
    }

    private func edgeColorIDs(
        _ boundaryIndices: [Int],
        in mesh: MaruGenjiSurfaceMeshData
    ) -> Set<ThreadColorID> {
        let boundarySet = Set(boundaryIndices.map(UInt32.init))
        return Set((mesh.colorGroups.merging(mesh.boundaryColorGroups) { $0 + $1 }).compactMap {
            colorID, indices in
            indices.contains(where: boundarySet.contains) ? colorID : nil
        })
    }
}
