import Foundation
import RealityKit
import simd
import Testing
@testable import Kumihimo

struct MaruGenjiSurfaceMeshTests {
    @Test func meshIsFiniteClosedGroupedAndNondegenerate() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))

        #expect(mesh.positions.count == mesh.normals.count)
        #expect(mesh.positions.allSatisfy(isFinite))
        #expect(mesh.normals.allSatisfy(isFinite))
        #expect(mesh.normals.allSatisfy { abs(simd_length($0) - 1) < 0.001 })
        #expect(Set(mesh.colorGroups.keys) == Set([blue, pink]))
        #expect(mesh.colorGroups.values.allSatisfy { !$0.isEmpty })

        let indices = mesh.colorGroups.values.flatMap { $0 }
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
    }

    @Test func meshGenerationIsDeterministic() throws {
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let first = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        let second = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))

        #expect(first.positions == second.positions)
        #expect(first.normals == second.normals)
        #expect(first.colorGroups == second.colorGroups)
        #expect(first.surfaceTrianglePatchIndices == second.surfaceTrianglePatchIndices)
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
    }

    @Test @MainActor func everyColorGroupBuildsARealityKitMesh() throws {
        for assignments in [
            fixtureAssignments,
            verifiedFixture1,
            ProjectEditorPreviewData.maruGenjiSurfaceFixture1,
        ] {
            let pattern = try #require(
                MaruGenjiSurfacePatternGenerator.generate(assignments: assignments)
            )
            let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))

            for (colorID, indices) in mesh.colorGroups {
                var descriptor = MeshDescriptor(name: "surface-\(colorID.rawValue)")
                descriptor.positions = MeshBuffer(mesh.positions)
                descriptor.normals = MeshBuffer(mesh.normals)
                descriptor.primitives = .triangles(indices)
                descriptor.materials = .allFaces(0)
                _ = try MeshResource.generate(from: [descriptor])
            }
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
}
