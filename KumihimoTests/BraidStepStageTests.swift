import CoreGraphics
import Foundation
import Testing
@testable import Kumihimo

/// Task 066: **the step animation draws the eight-bobbin braids as the book's
/// disk works them** — a thread carried round to beside the pair across the
/// stand, the pairs drawn back to north, east, south and west whenever they
/// stand in pairs again — and **the places are numbered as the book's figure
/// is**, places 1・2 at slits 4・5.
@MainActor
struct BraidStepStageTests {
    private func stage(_ recipe: BraidRecipe, colours: [ThreadAssignment]? = nil) throws -> BraidStepStage {
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        let colouring = colours ?? recipe.colouring
        let script = try #require(BraidStepScript(
            recipe: recipe, stand: stand,
            colours: Dictionary(uniqueKeysWithValues: colouring.map { ($0.position, $0.colorID) })
        ))
        return BraidStepStage(
            script: script, recipe: recipe,
            layout: BraidStepLayout(stand: stand, startingSlits: recipe.startingSlits)
        )
    }

    private func between(_ from: Double, _ to: Double) -> Double {
        var value = (to - from).truncatingRemainder(dividingBy: 1)
        if value > 0.5 { value -= 1 }
        if value < -0.5 { value += 1 }
        return value
    }

    /// The place a turn is drawn at, if it is one.
    private func place(at turn: Double, in layout: BraidStepLayout) -> Int? {
        layout.stand.positionIDs.first { abs(between(layout.turn(of: $0), turn)) < 1e-9 }
    }

    nonisolated private static let kongo = [
        BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe,
        BraidMethodCatalog.yatsuKongoGaeshi8Recipe, BraidMethodCatalog.edoYatsu8Recipe,
    ]

    // MARK: 1. The book's disk behind the drawing

    /// **Every table of the four braids off the book's disk carries the book's
    /// moves, a hand's worth to each of the script's hands**, and the stand is
    /// drawn from them. The others are drawn on the stand's places.
    @Test(arguments: BraidMethodCatalog.recipes.map(\.id))
    func theBooksDisksAreDrawnFromTheBook(recipeID: String) throws {
        let recipe = try #require(BraidMethodCatalog.recipes.first { $0.id == recipeID })
        let fromTheBook = Self.kongo.contains { $0.id == recipeID }
        #expect(try stage(recipe).isDrawnFromTheBook == fromTheBook)
        #expect(recipe.rounds.allSatisfy { !$0.bookHands.isEmpty } == fromTheBook)
    }

    /// **The derivation does not read the book's moves**: the tables without
    /// them give the same method and the same script.
    @Test(arguments: Self.kongo)
    func theDerivationDoesNotReadTheBooksMoves(recipe: BraidRecipe) throws {
        let bare = recipe.rounds.map {
            BraidDiskNotation(
                source: $0.source, notchCount: $0.notchCount,
                standPositionByRestingNotch: $0.standPositionByRestingNotch, moves: $0.moves,
                threadsPerStep: $0.threadsPerStep, stepReading: $0.stepReading, name: $0.name,
                handOvers: $0.handOvers, handOverName: $0.handOverName
            )
        }
        let stripped = BraidRecipe(
            id: recipe.id, name: recipe.name, rounds: bare, colouring: recipe.colouring,
            shape: recipe.shape, orderRoundTheBraid: recipe.orderRoundTheBraid,
            startingSlits: recipe.startingSlits
        )
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        #expect(stripped.methods(on: stand) == recipe.methods(on: stand))
        #expect(try stage(stripped).script == stage(recipe).script)
        #expect(try !stage(stripped).isDrawnFromTheBook)
    }

    // MARK: 2. 八つ金剛 S, hand by hand

    /// **Hand 1 takes the south pair's right-hand thread round outside the east
    /// pair to beside the north pair's right-hand one** (the book's p.37
    /// figure 1, slit 20 to slit 6), and says so.
    @Test func kongoSsFirstHandCrossesToBesideTheNorthPair() throws {
        let stage = try stage(BraidMethodCatalog.yatsuKongoS8Recipe)
        let layout = stage.layout
        let stations = stage.stations(ofHand: 0)
        #expect(stage.script.hands[0].carries.map(\.thread) == [5])
        #expect(stage.script.hands[0].carries.first?.way == .anticlockwise)
        let before = try #require(stations.before[5])
        #expect(abs(between(layout.turn(of: 5), before.turn)) < 1e-9)
        let landing = try #require(stations.afterCarrying[5])
        let notch = try #require(layout.notchTurn)
        #expect(abs(between(layout.turn(of: 2) + notch, landing.turn)) < 1e-9)
        // Round the east pair: half way, it is at the east.
        let middle = BraidStepFrame.slide(from: before, to: landing, way: .anticlockwise, share: 0.5, lift: 0)
        #expect(abs(between(0.25, middle.turn)) < 0.05)
        #expect(stations.sentence == "場所5の糸を、左回りに場所2の隣へ")
    }

    /// **After every second hand the threads stand in pairs again, and are drawn
    /// back to north, east, south and west**, every place taken once; after the
    /// others, three stand together on one side. Hand 2 takes the north pair's
    /// left-hand thread to beside the south pair's left-hand one.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func thePairsAreDrawnBackEverySecondHand(recipe: BraidRecipe) throws {
        let stage = try stage(recipe)
        let layout = stage.layout
        for index in stage.script.hands.indices {
            let after = stage.stations(ofHand: index).after
            let places = after.values.map { place(at: $0.turn, in: layout) }
            if index % 2 == 1 {
                #expect(Set(places.compactMap { $0 }) == Set(1...8), "\(recipe.id) hand \(index + 1)")
            } else {
                #expect(places.contains { $0 == nil }, "\(recipe.id) hand \(index + 1)")
            }
        }
        if recipe.id == BraidMethodCatalog.yatsuKongoS8Recipe.id {
            #expect(stage.stations(ofHand: 1).sentence == "場所1の糸を、左回りに場所6の隣へ")
        }
    }

    /// **Every dan is the book's printed one**: the same four hands, in the same
    /// order, every time round — the book's slits drift, and the pairs are
    /// drawn back to the compass points, so the dan reads the same.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func everyDanIsThePrintedOne(recipe: BraidRecipe) throws {
        let stage = try stage(recipe)
        let sentences = stage.script.hands.indices.map { stage.stations(ofHand: $0).sentence ?? "" }
        #expect(sentences.count % 4 == 0)
        for dan in stride(from: 4, to: sentences.count, by: 4) {
            #expect(Array(sentences[dan..<(dan + 4)]) == Array(sentences[0..<4]), "\(recipe.id) from hand \(dan + 1)")
        }
        // Lit is the thread the book lifts.
        for index in stage.script.hands.indices {
            #expect(stage.stations(ofHand: index).carried.count == 1)
        }
    }

    /// 8Z's hand 1 is S's mirror: the north pair's right-hand thread clockwise to
    /// beside the south pair's right-hand one (p.36 figure 1, slit 5 to 19).
    @Test func kongoZsFirstHandIsSsMirror() throws {
        let stage = try stage(BraidMethodCatalog.yatsuKongoZ8Recipe)
        #expect(stage.stations(ofHand: 0).sentence == "場所2の糸を、右回りに場所5の隣へ")
    }

    // MARK: 3. 江戸八つ組 and 返し組

    /// **江戸八つ組's hand 1 sets place 1's thread down in slit 11, beside place
    /// 3** (the textbook's figure 1), and **hand 4 carries place 3's thread off
    /// and then lays it on into place 3** (figures 4 and 5) as the hand settles.
    @Test func edoYatsuIsTheTextbooksDisk() throws {
        let stage = try stage(BraidMethodCatalog.edoYatsu8Recipe)
        let layout = stage.layout
        let first = stage.stations(ofHand: 0)
        #expect(first.sentence == "場所1の糸を、右回りに場所3の隣へ")
        let landing = try #require(first.afterCarrying[1])
        #expect(between(layout.turn(of: 2), landing.turn) > 0 && between(landing.turn, layout.turn(of: 3)) > 0)
        #expect(landing.radius == 1)
        let fourth = stage.stations(ofHand: 3)
        #expect(fourth.settled == [1])
        #expect(abs(between(layout.turn(of: 3), try #require(fourth.after[1]).turn)) < 1e-9)
    }

    /// 返し組's hand-overs are hands of their own here too, said as hand-overs.
    @Test func gaeshisHandOversAreDrawnFromTheBook() throws {
        let stage = try stage(BraidMethodCatalog.yatsuKongoGaeshi8Recipe)
        let overs = stage.script.hands.indices.filter { stage.script.hands[$0].isHandOver }
        #expect(!overs.isEmpty)
        for index in overs {
            #expect(stage.stations(ofHand: index).sentence?.contains("隣の糸を越えて") == true)
        }
    }

    // MARK: 4. A time round

    /// **A time round ends as it began**: every place shows the colour it
    /// began with, the threads in pairs at the compass points — under the
    /// recipe's own colouring, and under eight colours all different.
    @Test(arguments: Self.kongo)
    func aTimeRoundEndsAsItBegan(recipe: BraidRecipe) throws {
        let eight = (1...8).map {
            ThreadAssignment(position: $0, colorID: ThreadColorCatalog.colors[$0 * 3].id)
        }
        for colouring in [recipe.colouring, eight] {
            let colours = Dictionary(uniqueKeysWithValues: colouring.map { ($0.position, $0.colorID) })
            let stage = try stage(recipe, colours: colouring)
            let layout = stage.layout
            let first = stage.stations(ofHand: 0).before
            let last = try #require(stage.stations(ofHand: stage.script.hands.count - 1).after as [Int: BraidStepFrame.Polar]?)
            func colourAtPlaces(_ stations: [Int: BraidStepFrame.Polar]) -> [Int: ThreadColorID] {
                var out = [Int: ThreadColorID]()
                for (thread, polar) in stations {
                    if let place = place(at: polar.turn, in: layout) { out[place] = colours[thread] }
                }
                return out
            }
            #expect(colourAtPlaces(last).count == 8, "\(recipe.id)")
            #expect(colourAtPlaces(last) == colourAtPlaces(first), "\(recipe.id)")
        }
    }
}
