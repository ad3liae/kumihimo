import CoreGraphics
import Foundation
import Testing
@testable import Kumihimo

/// Task 066: **the step animation's stand is laid out as the book's disk is** —
/// the eight-bobbin braids two by two, north, east, south and west, with place
/// 1・2's pair at the top (「金剛は2本ずつ東西南北よせる」). Drawing only: the
/// script's hands are the ones Task 062 left.
@MainActor
struct BraidStepLayoutTests {
    private func layout(_ recipe: BraidRecipe) throws -> BraidStepLayout {
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        return BraidStepLayout(stand: stand, startingSlits: recipe.startingSlits)
    }

    private func script(_ recipe: BraidRecipe) throws -> BraidStepScript {
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        return try #require(BraidStepScript(
            recipe: recipe, stand: stand,
            colours: Dictionary(uniqueKeysWithValues: recipe.colouring.map { ($0.position, $0.colorID) })
        ))
    }

    /// The short way round from one angle to another, in turns, signed.
    private func between(_ from: Double, _ to: Double) -> Double {
        var value = (to - from).truncatingRemainder(dividingBy: 1)
        if value > 0.5 { value -= 1 }
        if value < -0.5 { value += 1 }
        return value
    }

    private func middle(of island: [Int], in layout: BraidStepLayout) -> Double {
        let first = layout.turn(of: island[0])
        let span = between(first, layout.turn(of: island[island.count - 1]))
        let value = (first + span / 2).truncatingRemainder(dividingBy: 1)
        return value < 0 ? value + 1 : value
    }

    // MARK: 1. The eight-bobbin braids

    /// **Places 1・2, 3・4, 5・6, 7・8 are islands, their middles north, east,
    /// south and west**, and the two of an island nearer each other than the
    /// islands are — but not so near that the bobbins touch.
    @Test(arguments: [
        BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe,
        BraidMethodCatalog.yatsuKongoGaeshi8Recipe, BraidMethodCatalog.edoYatsu8Recipe,
    ])
    func theEightStandTwoByTwoNorthEastSouthWest(recipe: BraidRecipe) throws {
        let layout = try layout(recipe)
        #expect(layout.islands == [[1, 2], [3, 4], [5, 6], [7, 8]], "\(recipe.id)")
        for (island, wanted) in zip(layout.islands, [0.0, 0.25, 0.5, 0.75]) {
            #expect(abs(between(wanted, middle(of: island, in: layout))) < 1e-9, "\(recipe.id) \(island)")
        }
        let inside = between(layout.turn(of: 1), layout.turn(of: 2))
        let across = between(layout.turn(of: 2), layout.turn(of: 3))
        #expect(inside > 0 && inside < across)
        for island in layout.islands {
            #expect(abs(between(layout.turn(of: island[0]), layout.turn(of: island[1])) - inside) < 1e-9)
        }
        // Spread from the book's one notch just far enough to part the bobbins.
        #expect(2 * sin(.pi * inside) >= 2 * layout.ballRadius)
        #expect(inside > 1.0 / 32)
    }

    // MARK: 2. The others

    /// **丸四つ組 has no islands**: its four stand evenly, place 1 at the top, as
    /// they did before Task 066.
    @Test func maruYotsuStandsEvenlyAsBefore() throws {
        let recipe = BraidMethodCatalog.maruYotsu4Recipe
        let layout = try layout(recipe)
        #expect(layout.islands == [[1], [2], [3], [4]])
        for position in layout.stand.positions {
            #expect(abs(between(position.rim, layout.turn(of: position.id))) < 1e-12)
        }
        #expect(layout.turn(of: 1) == 0)
    }

    /// **丸源氏・平源氏 stand in eight pairs, evenly round**, as book C's disk has
    /// them; the book's notch apart already parts their bobbins.
    @Test(arguments: [BraidMethodCatalog.maruGenji16Recipe, BraidMethodCatalog.hiraGenji16Recipe])
    func theSixteenStandInEightPairs(recipe: BraidRecipe) throws {
        let layout = try layout(recipe)
        #expect(layout.islands == stride(from: 1, through: 15, by: 2).map { [$0, $0 + 1] }, "\(recipe.id)")
        for (index, island) in layout.islands.enumerated() {
            #expect(abs(between(Double(index) / 8, middle(of: island, in: layout))) < 1e-9)
            #expect(abs(between(layout.turn(of: island[0]), layout.turn(of: island[1])) - 1.0 / 32) < 1e-12)
        }
    }

    /// **A recipe with no starting diagram is drawn evenly**, on the stand's rim.
    @Test func aRecipeWithNoDiagramStandsEvenly() throws {
        let kongo = BraidMethodCatalog.yatsuKongoS8Recipe
        let bare = BraidRecipe(
            id: "no-diagram", name: "図の無い組み方", rounds: kongo.rounds,
            colouring: kongo.colouring, shape: kongo.shape
        )
        #expect(bare.startingSlits == nil)
        let layout = try layout(bare)
        #expect(layout.islands == (1...8).map { [$0] })
        for position in layout.stand.positions {
            #expect(layout.turn(of: position.id) == position.rim)
        }
    }

    /// Book C's table, turned round the other way: place *p* at a notch.
    @Test func theSlitsAreTheCataloguesOwn() throws {
        let maru = try #require(BraidMethodCatalog.maruGenji16Recipe.startingSlits)
        #expect(maru.notchCount == 32)
        #expect(maru.placeOneOnward == [5, 6, 9, 10, 13, 14, 17, 18, 21, 22, 25, 26, 29, 30, 1, 2])
        #expect(BraidMethodCatalog.maruYotsu4Recipe.startingSlits?.placeOneOnward == [1, 9, 17, 25])
        #expect(BraidMethodCatalog.yatsuKongoS8Recipe.startingSlits?.placeOneOnward
                == BraidMethodCatalog.yatsuKongoStartingSlits)
        #expect(BraidMethodCatalog.edoYatsu8Recipe.startingSlits?.placeOneOnward
                == BraidMethodCatalog.edoYatsuStartingSlits)
        #expect(BraidMethodCatalog.yatsuKongoGaeshi8Recipe.startingSlits?.placeOneOnward
                == BraidMethodCatalog.yatsuKongoGaeshiStartingSlits)
        #expect(BraidMethodCatalog.recipes.allSatisfy { $0.startingSlits != nil })
    }

    // MARK: 3. No two bobbins on top of each other

    /// **At no moment of any hand do two bobbins overlap**, but for a carried one
    /// passing over the threads it goes by, which it is drawn over on purpose,
    /// and a thread the settle moves on purpose. At the start and the end of
    /// every hand, when everything stands still, none at all overlap. On the
    /// stand as the screen draws it: from the book's disk where there is one.
    @Test(arguments: BraidMethodCatalog.recipes.map(\.id))
    func noTwoBobbinsOverlap(recipeID: String) throws {
        let recipe = try #require(BraidMethodCatalog.recipes.first { $0.id == recipeID })
        let script = try script(recipe)
        let stage = BraidStepStage(script: script, recipe: recipe, layout: try layout(recipe))
        let least = 2 * stage.layout.ballRadius
        func check(_ balls: [BraidStepFrame.Ball], _ label: String) {
            for (index, one) in balls.enumerated() {
                for other in balls[(index + 1)...] {
                    let distance = hypot(one.point.x - other.point.x, one.point.y - other.point.y)
                    #expect(distance >= least - 1e-9, "\(recipeID) \(label): threads \(one.thread) and \(other.thread)")
                }
            }
        }
        for (number, hand) in script.hands.enumerated() {
            let stations = stage.stations(ofHand: number)
            let carried = stations.carried
            for reduceMotion in [false, true] {
                for time in stride(from: 0.0, through: BraidStepTiming.hand, by: 0.05) {
                    let frame = BraidStepFrame.at(time, of: stations, carried: carried, reduceMotion: reduceMotion)
                    check(frame.balls.filter { !$0.isCarried }, "hand \(number + 1) at \(time)")
                }
            }
            for time in [0, BraidStepTiming.hand] {
                let frame = BraidStepFrame.at(time, of: stations, carried: carried, reduceMotion: false)
                check(frame.balls, "hand \(number + 1) standing at \(time)")
            }
        }
    }

    /// **On the stand's places — the drawing for a braid with no book disk — a
    /// thread waiting beside a place stands on the side it came from, out by
    /// the rim where there is room**: 江戸八つ組's hand 1 as the script has it.
    @Test func aWaitingThreadStandsClearOnTheStandsPlaces() throws {
        let recipe = BraidMethodCatalog.edoYatsu8Recipe
        let script = try script(recipe)
        let layout = try layout(recipe)
        let waiting = try #require(script.hands[0].afterCarrying[1])
        #expect(waiting.place == 3 && waiting.rank == 1 && waiting.cameBy == .clockwise)
        let point = BraidStepFrame.polarPoint(of: waiting, on: layout)
        #expect(between(layout.turn(of: 3), point.turn) < 0)          // anticlockwise of place 3
        #expect(between(layout.turn(of: 2), point.turn) > 0)          // clockwise of place 2
        #expect(point.radius > 0.8)                                   // out by the rim, where there is room
    }

    // MARK: 4. The script is Task 062's

    /// **The hands do not read the layout**: the same recipe without its
    /// starting slits gives the same script, hand for hand.
    @Test(arguments: BraidMethodCatalog.recipes.map(\.id))
    func theScriptDoesNotReadTheStartingSlits(recipeID: String) throws {
        let recipe = try #require(BraidMethodCatalog.recipes.first { $0.id == recipeID })
        let bare = BraidRecipe(
            id: recipe.id, name: recipe.name, rounds: recipe.rounds, colouring: recipe.colouring,
            shape: recipe.shape, orderRoundTheBraid: recipe.orderRoundTheBraid
        )
        #expect(try script(bare) == script(recipe))
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        #expect(bare.methods(on: stand) == recipe.methods(on: stand))
    }
}
