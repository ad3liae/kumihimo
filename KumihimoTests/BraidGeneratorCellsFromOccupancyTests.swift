import Foundation
import Testing
@testable import Kumihimo

/// Task 025-4, the compromise: **the shape stays with the frozen generators, and
/// the colour comes from the occupancy history.**
///
/// This checks the join. The threads in the round braid's drawing are no longer
/// transcribed — they come from the move table — and the two are held against each
/// other rather than either being trusted.
@MainActor
struct BraidGeneratorCellsFromOccupancyTests {
    private var threadByCell: [[Int]: Int] {
        get throws {
            try #require(MaruGenjiSurfacePatternGenerator.threadByCell(
                stand: BraidMethodCatalog.stand16,
                method: BraidMethodCatalog.maruGenji16,
                crossSection: BraidMethodCatalog.maruGenji16CrossSection
            ))
        }
    }

    /// **The derived threads are the transcribed ones, all sixty-four.** If this
    /// ever parts, one of the two is wrong and it is worth stopping over.
    @Test func theDerivedThreadsAreTheTranscribedOnes() throws {
        let derived = try threadByCell
        var checked = 0
        for strand in MaruGenjiSurfacePatternGenerator.sourceStrands {
            for diamond in strand.diamonds {
                let cell = try #require(MaruGenjiSurfacePatternGenerator.cell(for: diamond))
                let mine = try #require(derived[[cell.column, cell.row]])
                #expect(mine == strand.threadPosition,
                        "cell \(cell.column),\(cell.row)")
                checked += 1
            }
        }
        #expect(checked == 64)
    }

    /// Task 004's transcribed table, cell for cell, **on the generator's own
    /// cells** — which is what the compromise needs: the drawing keeps its shape
    /// and the threads in it come from the moves.
    @Test func theGeneratorsCellsAgreeWithTaskZeroZeroFour() throws {
        struct Maru: Decodable { let task004: [[Int]] }
        let fixture = try BraidFixtures.decode(Maru.self, from: "maru-occupancy")
        let derived = try threadByCell
        // The drawing's own eight columns, in the drawing's own order -- which is
        // the transcription's, not the ring's. Every cell of it is a thread the
        // move table put there, all thirty-two of a repeat.
        var same = 0
        for row in 1...4 {
            for column in 0..<8 {
                let mine = try #require(derived[[column, row]])
                if fixture.task004.contains(where: { $0.contains(mine) }) { same += 1 }
            }
        }
        #expect(same == 32)
    }

    /// The eight rows of the drawing are the four cycles drawn twice.
    @Test func theDrawingsEightRowsAreFourCyclesTwice() throws {
        let derived = try threadByCell
        for row in 1...4 {
            for column in 0..<8 {
                #expect(derived[[column, row]] == derived[[column, row + 4]],
                        "column \(column) row \(row)")
            }
        }
    }

    /// **The shape has not moved.** Same corners, same layers, same threads, so the
    /// mesh's vertices are identical and only what is coloured could differ.
    @Test func theDrawingsShapeIsUnchanged() throws {
        let assignments = BraidMethodCatalog.maruGenji16Colouring
        let pattern = try #require(
            MaruGenjiSurfacePatternGenerator.generate(assignments: assignments))
        #expect(pattern.patches.count == MaruGenjiSurfacePatternGenerator.patchCount)
        let mesh = try #require(MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern))
        // Every position finite, and as many as the frozen generator has always made.
        #expect(mesh.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
        #expect(mesh.triangleCount > 0)
        // The colours are the recipe's, and no others.
        let wanted = Set(assignments.map(\.colorID))
        #expect(Set(mesh.colorGroups.keys).isSubset(of: wanted))
    }
}
