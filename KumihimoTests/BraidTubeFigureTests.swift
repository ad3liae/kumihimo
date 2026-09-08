import Foundation
import Testing
@testable import Kumihimo

/// Task 025-2: the round braid gets a figure at last.
///
/// There was none: the flat braid's builder returns `nil` for a tube, and rightly
/// so. This one comes out of the occupancy history, its columns stand at the slots
/// a hand lands on, and it is held against Task 004's transcription cell for cell.
@MainActor
struct BraidTubeFigureTests {
    private struct MaruFixture: Decodable {
        let columns: [Int]
        let columnAnglesDegrees: [Double]
        let grid: [[Int]]
        let task004: [[Int]]

        enum CodingKeys: String, CodingKey {
            case columns, grid, task004
            case columnAnglesDegrees = "column_angles_degrees"
        }
    }

    private var derivation: BraidDerivation {
        get throws {
            try #require(BraidDerivation.derive(
                stand: BraidMethodCatalog.stand16,
                method: BraidMethodCatalog.maruGenji16,
                crossSection: BraidMethodCatalog.maruGenji16CrossSection
            ))
        }
    }

    private var figure: BraidTubeFigure {
        get throws {
            try #require(BraidFigureBuilder.tube(
                from: try derivation,
                assignments: BraidMethodCatalog.maruGenji16Colouring
            ))
        }
    }

    @Test func aFlatBraidHasNoTubeFigure() throws {
        let flat = try #require(BraidDerivation.derive(
            stand: BraidMethodCatalog.stand16,
            method: BraidMethodCatalog.hiraGenji16,
            crossSection: BraidMethodCatalog.hiraGenji16CrossSection
        ))
        #expect(BraidFigureBuilder.tube(
            from: flat, assignments: BraidMethodCatalog.hiraGenji16Colouring
        ) == nil)
    }

    /// **Not every 45 degrees.** The sixteen slots stand 22.5 apart and the closing
    /// folds them in pairs, so the columns fall at 0, 67.5, 90, 157.5 and so on.
    @Test func theColumnsStandAtTheSlotsAHandLandsOn() throws {
        let fixture = try BraidFixtures.decode(MaruFixture.self, from: "maru-occupancy")
        let figure = try figure
        #expect(figure.columns.map(\.slot) == fixture.columns)
        for (column, degrees) in zip(figure.columns, fixture.columnAnglesDegrees) {
            #expect(abs(column.angleInTurns * 360 - degrees) < 1e-9)
        }
        let gaps = Set(zip(figure.columns, figure.columns.dropFirst()).map {
            ($1.angleInTurns - $0.angleInTurns) * 360
        })
        #expect(gaps.count > 1)     // evenly spaced views would be the old mistake
    }

    @Test func everyCellHoldsTheThreadThatIsRestingThere() throws {
        let fixture = try BraidFixtures.decode(MaruFixture.self, from: "maru-occupancy")
        let figure = try figure
        #expect(figure.rowCount == fixture.grid.count)
        for row in 0..<figure.rowCount {
            let line = try (0..<figure.columns.count).map { column in
                try #require(figure.appearance(atColumn: column, row: row)).threadPosition
            }
            #expect(line == fixture.grid[row])
        }
    }

    /// Thirty-two of thirty-two. **The mirror counts as agreement** and the E/W
    /// column order is still undecided; both are on the figure rather than in a
    /// comment.
    @Test func theFigureAgreesWithTaskZeroZeroFourCellForCell() throws {
        let fixture = try BraidFixtures.decode(MaruFixture.self, from: "maru-occupancy")
        let figure = try figure
        let grid = (0..<figure.rowCount).map { row in
            figure.row(row).map(\.threadPosition)
        }
        let best = try #require(BraidGridAgreement.best(of: grid, against: fixture.task004))
        #expect(best.same == 32)
        #expect(best.of == 32)
        #expect(best.mirrored)
    }

    @Test func theFigureCarriesWhatIsNotSettledAboutIt() throws {
        let figure = try figure
        #expect(figure.unsettled.contains { $0.contains("mirror") })
        #expect(figure.unsettled.contains { $0.contains("Task 004") })
    }

    /// The repeat is drawn as many times as asked, and every repeat is the same.
    @Test func theRepeatIsDrawnOverAndOver() throws {
        let figure = try figure
        #expect(figure.rowsDrawn == figure.rowCount * 3)
        for row in 0..<figure.rowCount {
            let first = figure.row(row).map(\.threadPosition)
            let again = figure.row(row + figure.rowCount).map(\.threadPosition)
            #expect(first == again)
        }
    }

    /// Draws the figure so the author can look at it. **Decides nothing.**
    @Test func theFigureIsDrawnForTheAuthorToLookAt() throws {
        let url = try BraidFigureDrawing.write(try figure, named: "maru-genji-16-figure")
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
