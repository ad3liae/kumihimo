import Foundation
import Testing
@testable import Kumihimo

/// Task 025-2's acceptance: **adding a braid costs a move table, a colouring and
/// the measured values, and nothing else.**
///
/// The table below is book C's Fig.32 turned a quarter of the way round the disk.
/// **It is not claimed to be a new braid** — turned back it is the same one. What
/// it is, is a table the code has never seen, added without touching the
/// working-out, the figure builder or the readings.
@MainActor
struct BraidRecipeIsThreeThingsTests {
    /// A quarter turn of the thirty-two notch disk. The sixteen resting notches
    /// land on resting notches, so the cycle still runs.
    private static func turned(_ notch: Int) -> Int { (notch - 1 + 8) % 32 + 1 }

    private static let recipe = BraidRecipe(
        id: "a-table-this-code-has-not-seen",
        name: "架空の紐",
        notation: BraidDiskNotation(
            source: "book C Fig.32, turned a quarter round the disk",
            notchCount: 32,
            standPositionByRestingNotch: BraidMethodCatalog.diskRestingNotches,
            moves: BraidMethodCatalog.maruGenjiDisk.moves.map {
                BraidMove(from: turned($0.from), to: turned($0.to))
            },
            threadsPerStep: 2
        ),
        colouring: BraidMethodCatalog.colouring(on: BraidMethodCatalog.stand16, [
            "north": Array(repeating: "red", count: 4),
            "east": Array(repeating: "white", count: 4),
            "south": Array(repeating: "blue", count: 4),
            "west": Array(repeating: "white", count: 4),
        ]),
        shape: BraidShapeValues(
            crestHeight: .observed(0.45, from: "carried over from a braid worked "
                                   + "with the same thread and the same weights")
        )
    )

    /// Three things went in. **Nothing declared a fourth**: a braid is a tube
    /// unless its own courses fold it, so the order round the braid comes from the
    /// stand's rim.
    @Test func nothingElseHadToBeDeclared() {
        #expect(Self.recipe.orderRoundTheBraid == nil)
        #expect(Self.recipe.crossSection(on: BraidMethodCatalog.stand16).source == .standRim)
    }

    @Test func theWorkingOutTakesItWithoutBeingTold() throws {
        let worked = try #require(Self.recipe.worked(on: BraidMethodCatalog.stand16))
        #expect(worked.derivation.threadCount == 16)
        #expect(worked.derivation.fold == nil)
        #expect(worked.method.instantCount == Self.recipe.notation.braidingMoves.count + 1)
    }

    @Test func aFigureComesOutOfIt() throws {
        let worked = try #require(Self.recipe.worked(on: BraidMethodCatalog.stand16))
        let figure = try #require(BraidFigureBuilder.tube(
            from: worked.derivation, assignments: Self.recipe.colouring
        ))
        #expect(figure.columns.count == 8)
        #expect(figure.rowCount == 4)
        for row in 0..<figure.rowCount {
            #expect(figure.row(row).count == 8)
        }
        // The colours are the ones handed in, and no others.
        let shown = Set(figure.shapes.map(\.colorID.rawValue))
        #expect(shown.isSubset(of: ["red", "white", "blue"]))
    }

    /// The stacking model counts k for it too, without being told anything.
    @Test func theLengthwiseGrowthIsCountedForItAsWell() throws {
        let worked = try #require(Self.recipe.worked(on: BraidMethodCatalog.stand16))
        let stacking = try #require(BraidStacking.stacking(
            of: worked.method, on: BraidMethodCatalog.stand16,
            crossSection: worked.section, fold: worked.derivation.fold, cycles: 5
        ))
        #expect(stacking.layersPerCycle == 3)
        #expect(stacking.pitchPerCycle.isDerived)
    }

    /// **The one thing a flat braid needs on top**: the order round the braid.
    /// Task 020's judgement 1 made that a declared input with a default, so it is
    /// not a fourth ingredient invented here — but it is more than three, and it is
    /// written down rather than glossed over.
    @Test func aFlatBraidDeclaresItsOrderRoundTheBraid() {
        #expect(BraidMethodCatalog.hiraGenji16Recipe.orderRoundTheBraid != nil)
        #expect(BraidMethodCatalog.hiraGenji16Recipe
            .crossSection(on: BraidMethodCatalog.stand16).isDeclared)
    }
}
