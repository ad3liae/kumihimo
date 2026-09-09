import Foundation
import Testing
@testable import Kumihimo

/// Task 027-3: **the figure comes from the recipe**, and a braid no drawer will
/// take still has a figure — a figure needs no drawer.
@MainActor
struct BraidPatternForRecipeTests {
    /// The flat braid gets two faces, and **they are the figures the existing
    /// expectations pin** — same columns, same rows, same cells.
    @Test func theFlatBraidGetsItsTwoFacesUnchanged() throws {
        let drawing = BraidPatternForRecipe.figure(
            for: BraidMethodCatalog.hiraGenji16Recipe,
            assignments: BraidMethodCatalog.hiraGenji16Colouring
        )
        guard case let .faces(faces) = drawing else {
            Issue.record("the flat braid should have faces")
            return
        }
        #expect(faces.count == 2)
        #expect(faces.map(\.name) == [BraidPatternStrings.frontFace,
                                      BraidPatternStrings.backFace])
        for pair in faces {
            #expect(pair.figure.columnCount == 6)
            #expect(pair.figure.rowCount == 4)
            #expect(pair.figure.rowsDrawn == 12)
            #expect(pair.figure.size == SIMD2<Double>(9, 12))
        }
    }

    /// The tube gets one figure, and **it is the fixture's eight by four**.
    @Test func theTubeGetsTheFigureTheFixtureRecords() throws {
        struct Maru: Decodable { let grid: [[Int]]; let columns: [Int] }
        let fixture = try BraidFixtures.decode(Maru.self, from: "maru-occupancy")
        let drawing = BraidPatternForRecipe.figure(
            for: BraidMethodCatalog.maruGenji16Recipe,
            assignments: BraidMethodCatalog.maruGenji16Colouring
        )
        guard case let .tube(figure) = drawing else {
            Issue.record("the tube should have a tube figure")
            return
        }
        #expect(figure.columns.map(\.slot) == fixture.columns)
        #expect(figure.rowCount == 4)
        for row in 0..<figure.rowCount {
            #expect(figure.row(row).map(\.threadPosition) == fixture.grid[row])
        }
        // **The unsettled things are on the figure**, to be shown where it is read.
        #expect(figure.unsettled.contains { $0.contains("mirror") })
        #expect(figure.unsettled.contains { $0.contains("Task 004") })
    }

    /// **A figure needs no drawer.** The second flat braid has no drawer, and still
    /// has a figure.
    @Test func abraidWithNoDrawerStillHasAFigure() throws {
        let secondFlat = BraidRecipe(
            id: "another-flat-braid", name: "別の平らな紐",
            notation: BraidMethodCatalog.hiraGenjiDisk,
            colouring: BraidMethodCatalog.hiraGenji16Colouring,
            shape: BraidMethodCatalog.hiraGenji16Shape,
            orderRoundTheBraid: BraidMethodCatalog.hiraGenji16CrossSection
        )
        #expect(BraidFamilyDrawing.drawer(for: secondFlat, on: BraidMethodCatalog.stand16) == nil)
        guard case let .faces(faces) = BraidPatternForRecipe.figure(
            for: secondFlat, assignments: BraidMethodCatalog.hiraGenji16Colouring
        ) else {
            Issue.record("a braid with no drawer should still have a figure")
            return
        }
        #expect(faces.count == 2)
    }

    /// A colouring that does not fit the braid gets nothing, rather than a figure
    /// built out of guesses.
    @Test func aColouringThatDoesNotFitGetsNothing() {
        let drawing = BraidPatternForRecipe.figure(
            for: BraidMethodCatalog.hiraGenji16Recipe,
            assignments: Array(BraidMethodCatalog.hiraGenji16Colouring.prefix(8))
        )
        guard case .nothing = drawing else {
            Issue.record("a colouring of the wrong size should give nothing")
            return
        }
    }
}
