import Foundation
import Testing
@testable import Kumihimo

/// Task 025-2: a recipe is a move table, a colouring and the measured values.
@MainActor
struct BraidRecipeTests {
    /// **The stand comes out of the table**, so this asks the catalogue rather than
    /// naming one -- a recipe worked on the eight-place stand goes through here the
    /// same way as one worked on the sixteen.
    @Test(arguments: BraidMethodCatalog.recipes)
    func aRecipeWorksOutOnTheStandItNames(recipe: BraidRecipe) throws {
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        let worked = try #require(recipe.worked(on: stand))
        // One step a braiding move -- the source of record moves one thread at a
        // time -- and the closing is one more instant.
        #expect(worked.method.instantCount == recipe.notation.braidingMoves.count + 1)
        #expect(worked.derivation.threadCount == stand.positionCount)
    }

    @Test(arguments: BraidMethodCatalog.recipes)
    func aRecipeColoursEveryPosition(recipe: BraidRecipe) throws {
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        #expect(recipe.colouring.count == stand.positionCount)
        #expect(Set(recipe.colouring.map(\.position)) == Set(stand.positionIDs))
    }

    /// **Only measurements live in a recipe.** What the working-out works out for
    /// itself is somewhere else and says `.derived` when it gets there.
    @Test(arguments: BraidMethodCatalog.recipes)
    func everyShapeValueIsMeasuredAndSaysFromWhere(recipe: BraidRecipe) {
        #expect(recipe.shape.everythingIsObserved)
        #expect(recipe.shape.all.allSatisfy { !$0.source.origin.isEmpty })
        #expect(recipe.shape.all.allSatisfy { $0.agreesWithItsSpread })
    }

    /// The values are the ones `observed.json` records, and nothing has drifted.
    @Test func theMeasuredValuesAreTheOnesTheFixtureRecords() throws {
        struct Observed: Decodable {
            struct Value: Decodable {
                let braid: String
                let quantity: String
                let value: Double?
                let range: [Double]?
            }
            let values: [Value]
        }
        let fixture = try BraidFixtures.decode(Observed.self, from: "observed")
        func value(_ braid: String, _ quantity: String) -> Observed.Value? {
            fixture.values.first { $0.braid == braid && $0.quantity == quantity }
        }
        let hira = BraidMethodCatalog.hiraGenji16Shape
        let ratio = try #require(hira.widthOverThickness)
        let pitch = try #require(hira.pitchPerBraidWidth)
        let crest = try #require(hira.crestHeight)
        #expect(ratio.value == value("hira-genji-16", "section width over thickness")?.value)
        #expect(pitch.value == value("hira-genji-16", "pitch of one step over braid width")?.value)
        #expect(crest.value == value("hira-genji-16", "crest height over half thickness")?.value)
        let band = try #require(BraidMethodCatalog.maruGenji16Shape.chevronsPerBraidWidth)
        let spread = try #require(band.spread)
        let recorded = try #require(value("maru-genji-16", "chevrons a braid width")?.range)
        #expect(spread.lowerBound == recorded[0])
        #expect(spread.upperBound == recorded[1])
    }

    /// The round braid's crest height carries what is unsettled about it, on the
    /// value rather than in a comment.
    @Test func aValueHeldOnlyAsAProductSaysSo() throws {
        let crest = try #require(BraidMethodCatalog.maruGenji16Shape.crestHeight)
        #expect(!crest.isSettled)
        #expect(BraidMethodCatalog.maruGenji16Shape.unsettled.count == 1)
    }
}

extension BraidRecipe: @retroactive CustomTestStringConvertible {
    public var testDescription: String { id }
}
