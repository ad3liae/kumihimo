import Foundation
import Testing
@testable import Kumihimo

/// Task 071: **十二金剛組 and 十六金剛組, S and Z, from the textbook's p.40–41
/// and p.44–45** — yatsu-kongo's braid with twelve and sixteen threads, drawn by
/// yatsu-kongo's drawer read for the thread count.
@MainActor
struct KongoTwelveAndSixteenTests {
    /// (recipe, threads, numbers a dan, drift per dan, the way a move goes: +1 clockwise)
    nonisolated static let braids: [(String, Int, Int, Int, Int)] = [
        ("juni-kongo-s-12", 12, 3, 1, -1), ("juni-kongo-z-12", 12, 3, -1, 1),
        ("juroku-kongo-s-16", 16, 4, 1, -1), ("juroku-kongo-z-16", 16, 4, -1, 1),
    ]
    nonisolated static let ids = braids.map(\.0)

    private func recipe(_ id: String) throws -> BraidRecipe {
        try #require(BraidMethodCatalog.recipes.first { $0.id == id })
    }

    private func facts(_ id: String) throws -> (threads: Int, numbers: Int, drift: Int, way: Int) {
        let found = try #require(Self.braids.first { $0.0 == id })
        return (found.1, found.2, found.3, found.4)
    }

    // MARK: 1. The tables

    /// **The printed dan, and the next one the drift moves round**: a number
    /// is two moves, each **fourteen notches** round the book's disk — Z
    /// clockwise, S anticlockwise — **always into an empty slit**, and after a
    /// dan the threads stand in the starting slits moved one notch round (Z
    /// anticlockwise, S clockwise: 「スリット番号は【組みはじめ】から反時計回り
    /// （時計回り）に一つずれます」).
    @Test(arguments: ids)
    func theBooksDanIsPrintedAndDrifts(recipeID: String) throws {
        let recipe = try recipe(recipeID)
        let facts = try facts(recipeID)
        let slits = try #require(recipe.startingSlits)
        #expect(slits.placeOneOnward.count == facts.threads)
        let steps = recipe.notation.bookSteps
        #expect(steps.count == 2 * facts.numbers)
        var occupied = Set(slits.placeOneOnward)
        for (index, step) in steps.enumerated() {
            #expect(step.moves.count == 2 && !step.isHandOver)
            for move in step.moves {
                #expect(occupied.contains(move.from) && !occupied.contains(move.to), "\(recipeID) \(move)")
                let forward = ((move.to - move.from) % 32 + 32) % 32
                #expect(forward == (facts.way > 0 ? 14 : 18), "\(recipeID) \(move)")
                occupied.remove(move.from)
                occupied.insert(move.to)
            }
            if (index + 1) % facts.numbers == 0 {
                let dan = (index + 1) / facts.numbers
                let drifted = Set(slits.placeOneOnward.map { (($0 - 1 + facts.drift * dan) % 32 + 32) % 32 + 1 })
                #expect(occupied == drifted, "\(recipeID) dan \(dan)")
            }
        }
    }

    /// **Each carry goes over four threads on twelve and six on sixteen**, as
    /// the step animation works the book's disk.
    @Test(arguments: ids)
    func aCarryGoesOverFourOrSix(recipeID: String) throws {
        let recipe = try recipe(recipeID)
        let facts = try facts(recipeID)
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        let working = try #require(BraidBookWorking(recipe: recipe, stand: stand))
        #expect(working.hands.count == 2 * facts.numbers)
        for hand in working.hands {
            #expect(hand.carries.count == 2)
            #expect(hand.adjustments.isEmpty)
            for carry in hand.carries {
                #expect(carry.over.count == facts.threads / 2 - 2, "\(recipeID)")
                #expect(carry.way == (facts.way > 0 ? .clockwise : .anticlockwise), "\(recipeID)")
            }
        }
    }

    /// **The table is one cycle of the stand, every thread braided once**, and
    /// read on the stand's evenly spaced places every thread goes **four places
    /// a cycle on twelve and six on sixteen**, on for Z and back for S —
    /// across the stand less two, as yatsu-kongo's two. A number is one
    /// instant, two threads.
    @Test(arguments: ids)
    func theTableIsOneCycleOfTheStand(recipeID: String) throws {
        let recipe = try recipe(recipeID)
        let facts = try facts(recipeID)
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        #expect(stand.positionCount == facts.threads)
        let worked = try #require(recipe.worked(on: stand))
        #expect(worked.method.steps.count == facts.threads / 2)
        #expect(worked.method.steps.allSatisfy { $0.moves.count == 2 })
        let moves = worked.method.steps.flatMap(\.moves) + worked.method.closing.moves
        #expect(Set(moves.map(\.from)).count == facts.threads)
        let carry = facts.threads / 2 - 2
        for move in moves {
            let forward = ((move.to - move.from) % facts.threads + facts.threads) % facts.threads
            #expect(forward == (facts.way > 0 ? carry : facts.threads - carry), "\(recipeID) \(move)")
        }
        // Round again once every thread is back: 12 / gcd(12, 4) and 16 / gcd(16, 6).
        #expect(worked.derivation.repeatCycleCount == (facts.threads == 12 ? 3 : 8))
    }

    /// **The eight-thread stand's disk is the one the tables were always
    /// written on**: four notches a place, thirty-two for eight.
    @Test func eightThreadsRestWhereTheyDid() {
        #expect(BookDiskKongo.restingNotches(places: 8) == BraidMethodCatalog.diskRestingNotchesForEight)
        #expect(BookDiskKongo.standNotchCount(places: 8) == BookDiskKongo.notchCount)
        for recipe in [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe,
                       BraidMethodCatalog.yatsuKongoGaeshi8Recipe, BraidMethodCatalog.edoYatsu8Recipe] {
            for round in recipe.rounds {
                #expect(round.notchCount == 32 && round.threadsPerStep == 1 && round.stepReading == .oneThreadAnInstant)
                #expect(round.standPositionByRestingNotch == BraidMethodCatalog.diskRestingNotchesForEight)
            }
        }
    }

    // MARK: 2. The screens

    /// **The thread count picks them**: 12 offers 十二金剛組 S・Z, and 16 offers
    /// 十六金剛組 S・Z after 丸源氏 and 平源氏.
    @Test func theThreadCountOffersThem() {
        #expect(BraidPresetCatalog.availablePresets(threadCount: 12, standKind: .round).map(\.id.rawValue)
                == ["juni-kongo-s-12", "juni-kongo-z-12"])
        #expect(BraidPresetCatalog.availablePresets(threadCount: 16, standKind: .round).map(\.id.rawValue)
                == ["maru-genji-16", "hira-genji-16", "juroku-kongo-s-16", "juroku-kongo-z-16"])
        for id in Self.ids {
            let preset = BraidPresetCatalog.preset(for: BraidPresetID(rawValue: id))
            #expect(preset?.standKind == .round, "\(id)")
        }
        #expect(BraidMethodCatalog.juniKongoS12Recipe.name == "十二金剛組S")
        #expect(BraidMethodCatalog.juniKongoZ12Recipe.name == "十二金剛組Z")
        #expect(BraidMethodCatalog.jurokuKongoS16Recipe.name == "十六金剛組S")
        #expect(BraidMethodCatalog.jurokuKongoZ16Recipe.name == "十六金剛組Z")
    }

    /// **The colourings are the 30's, the figure's pairs**: a pair and the pair
    /// opposite one colour, and the colours of the figure kept apart — three on
    /// twelve, four on sixteen.
    @Test(arguments: ids)
    func theColouringIsTheFiguresInTheThirty(recipeID: String) throws {
        let recipe = try recipe(recipeID)
        let facts = try facts(recipeID)
        #expect(recipe.colouring.count == facts.threads)
        #expect(recipe.colouring.allSatisfy { ThreadColorCatalog.color(for: $0.colorID) != nil })
        #expect(recipe.colouring.allSatisfy { $0.colorID.rawValue.hasPrefix("amerry-f-") })
        let byPlace = Dictionary(uniqueKeysWithValues: recipe.colouring.map { ($0.position, $0.colorID) })
        let half = facts.threads / 2
        for place in 1...facts.threads {
            let partner = place % 2 == 1 ? place + 1 : place - 1
            let opposite = (place - 1 + half) % facts.threads + 1
            #expect(byPlace[place] == byPlace[partner] && byPlace[place] == byPlace[opposite], "\(recipeID) \(place)")
        }
        #expect(Set(byPlace.values).count == facts.threads / 4)
    }

    /// **The source is the page**: p.41, p.40, p.45, p.44.
    @Test func theSourcesAreThePages() {
        #expect(BraidMethodCatalog.juniKongoS12Recipe.source == BraidSource(book: .textbook, page: 41))
        #expect(BraidMethodCatalog.juniKongoZ12Recipe.source == BraidSource(book: .textbook, page: 40))
        #expect(BraidMethodCatalog.jurokuKongoS16Recipe.source == BraidSource(book: .textbook, page: 45))
        #expect(BraidMethodCatalog.jurokuKongoZ16Recipe.source == BraidSource(book: .textbook, page: 44))
    }

    // MARK: 3. The step animation

    /// **A dan is the book's numbers, the islands two by two**: three hands of
    /// two threads and six islands on twelve, four and eight on sixteen; the
    /// round is one dan, shown once; the dan ends by setting every thread back
    /// **one drawn notch against the drift**.
    @Test(arguments: ids)
    func theStepsAreTheBooks(recipeID: String) throws {
        let recipe = try recipe(recipeID)
        let facts = try facts(recipeID)
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        let working = try #require(BraidBookWorking(recipe: recipe, stand: stand))
        #expect(working.handsADan == facts.numbers)
        #expect(working.islandsAtStart.map(\.count) == Array(repeating: 2, count: facts.threads / 2))
        #expect(working.round.map(\.hands.count) == [facts.numbers])
        #expect(working.round.map(\.repeats) == [1])
        let notch = working.geometry.notchTurn(notches: BookDiskKongo.notchCount)
        for hand in working.hands {
            #expect(hand.carries.count == 2)
            guard let setting = hand.setting else {
                #expect(!hand.endsADan)
                continue
            }
            for (thread, to) in setting {
                let from = try #require(hand.after[thread])
                // The dan moved the slits `drift` a notch; setting back turns them the other way.
                let turned = BraidBookWorking.between(from.turn, to.turn)
                #expect(abs(turned + Double(facts.drift) * notch) < 1e-9, "\(recipeID) thread \(thread)")
            }
        }
    }

    /// **The stand is drawn the way the book's figure is**: slits 4 and 5 either
    /// side of the top, so places 1・2 (slits 1・2) stand up and to the left —
    /// their middle three notches before the top — and 12・13 on the right.
    @Test(arguments: ids)
    func theStandLiesOnTheBooksFigure(recipeID: String) throws {
        let recipe = try recipe(recipeID)
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        let working = try #require(BraidBookWorking(recipe: recipe, stand: stand))
        let one = try #require(working.homes[1]).turn, two = try #require(working.homes[2]).turn
        let middle = BraidBookWorking.unit(one + BraidBookWorking.between(one, two) / 2)
        #expect(abs(BraidBookWorking.between(middle, 1 - 3.0 / 32)) < 1e-9, "\(recipeID): \(middle)")
        // Each thread at its slit's own angle, pairs spread about their middle.
        let slits = try #require(recipe.startingSlits).placeOneOnward
        for island in working.islandsAtStart {
            let turns = island.compactMap { working.homes[$0]?.turn }
            let first = try #require(turns.first)
            let centre = BraidBookWorking.unit(first + turns.map { BraidBookWorking.between(first, $0) }.reduce(0, +)
                                               / Double(turns.count))
            let notches = island.map { Double(slits[$0 - 1]) }
            var slitMiddle = notches.reduce(0, +) / Double(notches.count)
            if notches.max()! - notches.min()! > 16 { slitMiddle += 16 }
            #expect(abs(BraidBookWorking.between(centre, (slitMiddle - 4.5) / 32)) < 1e-9, "\(recipeID) \(island)")
        }
    }

    /// **Two threads a hand, said as the book shows them** (p.40 「2の糸を16に、
    /// 18の糸を32に」): 「場所2の糸を右回りに場所7の隣へ、場所8の糸を右回りに場所1の
    /// 隣へ」 for 十二金剛組Z's first — slit 2 is place 2, 16 lies beside 17 (place
    /// 7), 18 is place 8 and 32 lies beside 1.
    @Test func aHandOfTwoIsSaidAsTwo() throws {
        let recipe = try recipe("juni-kongo-z-12")
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        let stage = try #require(BraidStepStage(recipe: recipe, stand: stand))
        #expect(stage.stations(ofHand: 0).sentence == "場所2の糸を右回りに場所7の隣へ、場所8の糸を右回りに場所1の隣へ")
    }

    // MARK: 4. The drawing

    /// **Each is drawn, by the family its thread count and its carry make**:
    /// twelve and sixteen carried one way — the sixteen **not** 丸源氏組's,
    /// which is sixteen carried both ways and drawn as it was.
    @Test(arguments: ids)
    func eachIsDrawnAsItsFamily(recipeID: String) throws {
        let recipe = try recipe(recipeID)
        let facts = try facts(recipeID)
        let family = BraidFamily.roundTube(threads: facts.threads, turning: .oneWay)
        #expect(BraidFamilyDrawing.drawer(for: recipe) == family)
        #expect(family != RoundTube16SurfaceMesh.family)
        #expect(BraidFamilyDrawing.shape(of: family) != nil)
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        guard case let .roundTubeOfEight(pattern)? = BraidFamilyDrawing.drawing(for: recipe, on: stand) else {
            Issue.record("\(recipeID) is not drawn by the one-way drawer")
            return
        }
        #expect(pattern.columnCount == facts.threads)
        #expect(RoundTube8SurfaceMesh.family(of: pattern) == family)
        // The same stitch as yatsu-kongo's: a cycle 8/n of the eight's in diameters.
        let pitch = RoundTube8SurfacePatternGenerator.pitchOverDiameter * 8 / Float(facts.threads)
        #expect(abs(pattern.aspectRatio - Float(pattern.rowCount) * pitch / .pi) < 1e-6)
        #expect(pattern.columnsCarried == (facts.way > 0 ? 1 : -1) * (facts.threads / 2 - 2))
        let mesh = try #require(RoundTube8SurfaceMesh.generate(pattern: pattern))
        #expect(mesh.positions.count > 0)
        #expect(RoundTube8CardImage.draw(pattern, bundle: pattern.bundle) != nil)
        #expect(BraidFamilyDrawing.drawer(for: BraidMethodCatalog.maruGenji16Recipe) == RoundTube16SurfaceMesh.family)
    }

    /// **As many spirals as the book says** — 八つ金剛 4, 十二 6, 十六 8
    /// (p.40 「らせんは2本増えて、6本」, p.44 「4本増えて、8本」) — **counted on
    /// the drawn face**: the card's map of what shows, coloured a pair and the
    /// pair opposite alike (the book's 「計4本が1組となって、2本のらせん」),
    /// laid along three repeats; a spiral is a band of one colour that runs the
    /// whole length, wrapping round the braid and not along it.
    ///
    /// **And the way they turn is the name's**: S the way yatsu-kongo S's
    /// spirals turn, Z the other way.
    @Test(arguments: [
        ("yatsu-kongo-s-8", 4), ("yatsu-kongo-z-8", 4), ("juni-kongo-s-12", 6), ("juni-kongo-z-12", 6),
        ("juroku-kongo-s-16", 8), ("juroku-kongo-z-16", 8),
    ])
    func theSpiralsAreTheBooks(recipeID: String, spirals: Int) throws {
        let recipe = try recipe(recipeID)
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        let count = stand.positionCount
        let colours = ["amerry-f-501", "amerry-f-506", "amerry-f-512", "amerry-f-517"]
        let colouring = (1...count).map { place in
            ThreadAssignment(position: place, colorID: ThreadColorID(rawValue: colours[((place - 1) / 2) % (count / 4)]))
        }
        let worked = try #require(recipe.worked(on: stand))
        let pattern = try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, rounds: worked.derivation.rounds, crossSection: worked.section, assignments: colouring))
        let bands = Self.bands(on: pattern)
        #expect(bands.count == spirals, "\(recipeID): \(bands.count) bands")
        let yatsuKongoS = try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: BraidMethodCatalog.stand8, rounds: [BraidMethodCatalog.yatsuKongoS8],
            crossSection: .tube(of: BraidMethodCatalog.stand8),
            assignments: (1...8).map { ThreadAssignment(position: $0, colorID: ThreadColorID(rawValue: colours[(($0 - 1) / 2) % 2])) }
        ))
        let sWay = try #require(Self.turning(of: yatsuKongoS))
        let way = try #require(Self.turning(of: pattern))
        #expect(way == (recipeID.contains("-s-") ? sWay : -sWay), "\(recipeID)")
        // The book's own colouring shows them too.
        let own = try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, rounds: worked.derivation.rounds, crossSection: worked.section,
            assignments: recipe.colouring))
        if recipeID.hasPrefix("juni") || recipeID.hasPrefix("juroku") {
            #expect(Self.bands(on: own).count == spirals, "\(recipeID), its own colouring")
        }
    }

    /// The colour of every pixel of the card's map, row by row: a repeat.
    private static func colourMap(of pattern: RoundTube8SurfacePattern) -> (colours: [String], width: Int, height: Int) {
        let (shown, width, height) = RoundTube8CardImage.shownMap(for: pattern)
        let colours = shown.map { place -> String in
            switch place {
            case .run(_, let segment)?, .beneath(_, let segment)?:
                return pattern.surface.segments[segment].colorID.rawValue
            case nil:
                return ""
            }
        }
        return (colours, width, height)
    }

    /// **The bands that run the whole length of three repeats**, each a set of
    /// pixels of one colour joined side to side, round the braid wrapping.
    private static func bands(on pattern: RoundTube8SurfacePattern) -> [Set<Int>] {
        let (colours, width, height) = colourMap(of: pattern)
        let repeats = 3
        let long = width * repeats
        func colour(_ row: Int, _ column: Int) -> String { colours[row * width + column % width] }
        var seen = [Bool](repeating: false, count: long * height)
        var found = [Set<Int>]()
        for start in 0..<(long * height) where !seen[start] {
            let key = colour(start / long, start % long)
            var stack = [start]
            var band = Set<Int>()
            seen[start] = true
            var columns = Set<Int>()
            while let here = stack.popLast() {
                band.insert(here)
                let row = here / long, column = here % long
                columns.insert(column)
                let next = [((row + 1) % height, column), ((row + height - 1) % height, column),
                            (row, column + 1), (row, column - 1)]
                for (r, c) in next where c >= 0 && c < long {
                    let index = r * long + c
                    if !seen[index], colour(r, c) == key {
                        seen[index] = true
                        stack.append(index)
                    }
                }
            }
            if columns.count == long { found.append(band) }
        }
        return found
    }

    /// **Which way the colour turns round the braid as it goes along it**, +1
    /// or −1: the shift round the card, up to a column and a half, that best
    /// lays one column's colours on the colours **half a cycle** along — a dan,
    /// in which the spiral moves on a column. (A cycle along it moves on two,
    /// which on yatsu-kongo's four-column colouring is the same both ways.)
    private static func turning(of pattern: RoundTube8SurfacePattern) -> Int? {
        let (colours, width, height) = colourMap(of: pattern)
        let along = max(1, width / (2 * pattern.rowCount))
        let column = height / pattern.columnCount
        var best: (shift: Int, agree: Int)?
        for shift in -(3 * column / 2)...(3 * column / 2) where shift != 0 {
            var agree = 0
            for column in 0..<width {
                for row in 0..<height {
                    let there = ((row + shift) % height + height) % height
                    if colours[row * width + column] == colours[there * width + (column + along) % width] { agree += 1 }
                }
            }
            if agree > (best?.agree ?? -1) { best = (shift, agree) }
        }
        return best.map { $0.shift > 0 ? 1 : -1 }
    }
}
