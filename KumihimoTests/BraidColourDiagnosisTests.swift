import Foundation
import Testing
@testable import Kumihimo

/// Task 025-4: **why did the two paths show different colours from the same
/// colouring?** Recorded before the pictures are made again, so the answer is on
/// the record rather than fixed quietly.
@MainActor
struct BraidColourDiagnosisTests {
    @Test func whatEachPathDoesWithTheSameColouring() throws {
        let assignments = BraidMethodCatalog.hiraGenji16Colouring
        var lines = [String]()
        lines.append("colouring handed to both (position: colour)")
        for assignment in assignments.sorted(by: { $0.position < $1.position }) {
            lines.append("  \(assignment.position): \(assignment.colorID.rawValue)")
        }

        // The frozen generator.
        let pattern = try #require(HiraGenjiSurfacePatternGenerator.generate(assignments: assignments))
        let mesh = try #require(HiraGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        lines.append("")
        lines.append("frozen generator, triangles by colour:")
        for (colour, indices) in mesh.colorGroups.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            lines.append("  \(colour.rawValue): \(indices.count / 3)")
        }
        lines.append("frozen generator, boundary triangles by colour:")
        for (colour, indices) in mesh.boundaryColorGroups
            .sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            lines.append("  \(colour.rawValue): \(indices.count / 3)")
        }

        // The new path.
        let built = try #require(BraidFromRecipe.build(
            BraidMethodCatalog.hiraGenji16Recipe, on: BraidMethodCatalog.stand16
        ))
        let picture = BraidPicture.paint(built.lines, looking: SIMD3(0, -1, 0))
        var tally = [String: Int]()
        var colourOf = [Int: String]()
        for assignment in assignments { colourOf[assignment.position] = assignment.colorID.rawValue }
        for row in 0..<picture.height {
            for column in 0..<picture.width {
                guard let thread = picture.thread(atPixel: column, row: row) else { continue }
                tally[colourOf[thread] ?? "?", default: 0] += 1
            }
        }
        lines.append("")
        lines.append("new path, painted pixels by colour, straight on:")
        for (colour, count) in tally.sorted(by: { $0.key < $1.key }) {
            lines.append("  \(colour): \(count)")
        }
        func extents(_ points: [SIMD3<Float>]) -> String {
            let xs = points.map(\.x), ys = points.map(\.y), zs = points.map(\.z)
            return String(format: "x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f",
                          xs.min() ?? 0, xs.max() ?? 0, ys.min() ?? 0, ys.max() ?? 0,
                          zs.min() ?? 0, zs.max() ?? 0)
        }
        lines.append("")
        lines.append("frozen generator, mesh extents: " + extents(mesh.positions))
        var newPoints = [SIMD3<Float>]()
        for thread in built.lines.threads {
            for point in built.lines.points[thread]! {
                newPoints.append(SIMD3(Float(point.x), Float(point.y), Float(point.z)))
            }
        }
        lines.append("new path, extents: " + extents(newPoints))
        let maruPattern = try #require(MaruGenjiSurfacePatternGenerator.generate(
            assignments: BraidMethodCatalog.maruGenji16Colouring))
        let maruMesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: maruPattern))
        lines.append("frozen tube generator, mesh extents: " + extents(maruMesh.positions))

        try BraidSideBySideTests.record(lines.joined(separator: "\n"),
                                        named: "colour-diagnosis-hira")
        #expect(!mesh.colorGroups.isEmpty)
    }
}
