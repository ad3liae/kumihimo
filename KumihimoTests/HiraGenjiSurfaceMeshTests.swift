import Foundation
import RealityKit
import simd
import Testing
@testable import Kumihimo

struct HiraGenjiSurfaceMeshTests {
    @Test func meshIsAnOpenRoundedFlatBraidWithEveryRegion() throws {
        let pattern = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: assignments))
        let mesh = try #require(HiraGenjiSurfaceMeshGenerator.generate(pattern: pattern))

        #expect(abs(HiraGenjiSurfaceMeshGenerator.widthToThicknessRatio - 6) < 0.000_01)
        #expect((4...8).contains(HiraGenjiSurfaceMeshGenerator.widthToThicknessRatio))
        #expect(Set(mesh.surfaceVertexRegions) == Set(HiraGenjiSurfaceRegion.allCases))
        #expect(mesh.positions.count == mesh.normals.count)
        #expect(mesh.positions.count == mesh.textureCoordinates.count)
        #expect(mesh.positions.count == mesh.boundaryDistances.count)
        #expect(mesh.positions.count == mesh.surfaceVertexPatchIndices.count)
        #expect(mesh.surfaceVertexPatchIndices.allSatisfy { pattern.patches.indices.contains($0) })
        #expect(mesh.normals.allSatisfy { abs(simd_length($0) - 1) < 0.001 })
        #expect(mesh.colorGroups.values.allSatisfy { !$0.isEmpty })
        #expect(mesh.boundaryColorGroups.values.allSatisfy { !$0.isEmpty })

        let yExtent = extent(mesh.positions.map(\.y))
        let zExtent = extent(mesh.positions.map(\.z))
        #expect(yExtent / zExtent >= 4)
        #expect(yExtent / zExtent <= 8)
    }

    @Test func longitudinalStitchesStayNearYarnWidthInsteadOfBecomingPanels() {
        let yarnWidth = 2 * HiraGenjiSurfaceMeshGenerator.defaultHalfWidth
            / Float(HiraGenjiSurfacePatternGenerator.broadFaceColumnCount)
        let stitchLength = HiraGenjiSurfaceMeshGenerator.defaultLength
            / Float(HiraGenjiSurfaceMeshGenerator.defaultPatternRepeatCount)
            / Float(HiraGenjiSurfacePatternGenerator.stitchPhaseCount)

        #expect((0.45...1.0).contains(stitchLength / yarnWidth))
        #expect(HiraGenjiSurfaceMeshGenerator.defaultPatternRepeatCount >= 10)
    }

    @Test func meshHasNoEndCapTriangles() throws {
        let pattern = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: assignments))
        let mesh = try #require(HiraGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        let indices = mesh.allTriangleIndices

        let containsEndCap = stride(from: 0, to: indices.count, by: 3).contains { offset in
            let firstX = mesh.positions[Int(indices[offset])].x
            return abs(mesh.positions[Int(indices[offset + 1])].x - firstX) < 0.000_001
                && abs(mesh.positions[Int(indices[offset + 2])].x - firstX) < 0.000_001
        }
        #expect(!containsEndCap)
    }

    @Test func everySurfaceTriangleHasArea() throws {
        let pattern = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: assignments))
        let mesh = try #require(HiraGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        let indices = mesh.allTriangleIndices
        let containsDegenerateTriangle = stride(from: 0, to: indices.count, by: 3).contains { offset in
            let a = mesh.positions[Int(indices[offset])]
            let b = mesh.positions[Int(indices[offset + 1])]
            let c = mesh.positions[Int(indices[offset + 2])]
            return simd_length_squared(simd_cross(b - a, c - a))
                <= 0.000_000_000_001
        }

        #expect(!containsDegenerateTriangle)
    }

    @Test func repeatedTileGeometryNormalsBoundaryAndFiberPhaseMatch() throws {
        let pattern = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: assignments))
        let mesh = try #require(HiraGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        let length = HiraGenjiSurfaceMeshGenerator.defaultLength
        let start = mesh.positions.indices.filter { abs(mesh.positions[$0].x + length / 2) < 0.000_001 }
        let end = mesh.positions.indices.filter { abs(mesh.positions[$0].x - length / 2) < 0.000_001 }

        #expect(!start.isEmpty)
        #expect(boundarySignature(start, mesh: mesh) == boundarySignature(end, mesh: mesh))
        #expect(fiberPhaseSignature(start, mesh: mesh) == fiberPhaseSignature(end, mesh: mesh))
    }

    @Test func consecutivePatternRepeatsKeepColorAndBoundaryMaterialPhase() throws {
        let pattern = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: assignments))
        let mesh = try #require(HiraGenjiSurfaceMeshGenerator.generate(
            pattern: pattern,
            patternRepeatCount: 2
        ))

        var firstRepeat = [String: Int]()
        var secondRepeat = [String: Int]()
        for (isBoundary, groups) in [
            (false, mesh.colorGroups),
            (true, mesh.boundaryColorGroups),
        ] {
            for (colorID, indices) in groups {
                for offset in stride(from: 0, to: indices.count, by: 3) {
                    let vertexIndices = (0..<3).map { Int(indices[offset + $0]) }
                    let centerX = vertexIndices.reduce(Float.zero) {
                        $0 + mesh.positions[$1].x
                    } / 3
                    let centerUV = vertexIndices.reduce(SIMD2<Float>.zero) {
                        $0 + mesh.textureCoordinates[$1]
                    } / 3
                    let patchIndex = mesh.surfaceVertexPatchIndices[vertexIndices[0]]
                    let region = mesh.surfaceVertexRegions[vertexIndices[0]]
                    let signature = [
                        colorID.rawValue,
                        String(describing: region),
                        String(patchIndex),
                        String(Int((centerUV.x * 1_000_000).rounded())),
                        String(Int((centerUV.y * 1_000_000).rounded())),
                        String(isBoundary),
                    ].joined(separator: ":")
                    if centerX < 0 {
                        firstRepeat[signature, default: 0] += 1
                    } else {
                        secondRepeat[signature, default: 0] += 1
                    }
                }
            }
        }

        #expect(firstRepeat == secondRepeat)
    }

    @Test @MainActor func allMaterialGroupsBuildOneRealityKitMesh() throws {
        let pattern = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: assignments))
        let mesh = try #require(HiraGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        let groups = mesh.colorGroups.sorted { $0.key.rawValue < $1.key.rawValue }
            + mesh.boundaryColorGroups.sorted { $0.key.rawValue < $1.key.rawValue }
        var indices = [UInt32]()
        var materials = [UInt32]()
        for (materialIndex, group) in groups.enumerated() {
            indices.append(contentsOf: group.value)
            materials.append(contentsOf: repeatElement(
                UInt32(materialIndex),
                count: group.value.count / 3
            ))
        }
        var descriptor = MeshDescriptor(name: "hira-genji-surface-test")
        descriptor.positions = MeshBuffer(mesh.positions)
        descriptor.normals = MeshBuffer(mesh.normals)
        descriptor.textureCoordinates = MeshBuffer(mesh.textureCoordinates)
        descriptor.primitives = .triangles(indices)
        descriptor.materials = .perFace(materials)
        _ = try MeshResource.generate(from: [descriptor])
    }

    @Test func malformedInputsFailSafely() throws {
        let pattern = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: assignments))
        #expect(HiraGenjiSurfaceMeshGenerator.generate(
            pattern: HiraGenjiSurfacePattern(patches: Array(pattern.patches.dropLast()))
        ) == nil)
        #expect(HiraGenjiSurfaceMeshGenerator.generate(pattern: pattern, halfWidth: .nan) == nil)
        #expect(HiraGenjiSurfaceMeshGenerator.generate(pattern: pattern, halfThickness: 0) == nil)
        #expect(HiraGenjiSurfaceMeshGenerator.generate(pattern: pattern, halfThickness: 0.5) == nil)
        #expect(HiraGenjiSurfaceMeshGenerator.generate(pattern: pattern, patternRepeatCount: 0) == nil)
    }

    private var assignments: [ThreadAssignment] {
        (1...16).map {
            ThreadAssignment(
                position: $0,
                colorID: ThreadColorCatalog.colors[$0 % ThreadColorCatalog.colors.count].id
            )
        }
    }

    private func extent(_ values: [Float]) -> Float {
        (values.max() ?? 0) - (values.min() ?? 0)
    }

    private func boundarySignature(
        _ indices: [Int],
        mesh: HiraGenjiSurfaceMeshData
    ) -> [String] {
        indices.map { index in
            let point = mesh.positions[index]
            let normal = mesh.normals[index]
            return [point.y, point.z, normal.y, normal.z, mesh.boundaryDistances[index]]
                .map { String(Int(($0 * 1_000_000).rounded())) }
                .joined(separator: ":")
        }
        .sorted()
    }

    private func fiberPhaseSignature(
        _ indices: [Int],
        mesh: HiraGenjiSurfaceMeshData
    ) -> [Int] {
        indices.map {
            Int((cos(
                2 * .pi * Float(HiraGenjiSurfaceMeshGenerator.fiberCount)
                    * mesh.textureCoordinates[$0].y
            ) * 1_000_000).rounded())
        }
        .sorted()
    }
}
