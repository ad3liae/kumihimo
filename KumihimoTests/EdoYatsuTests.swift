import Foundation
import Testing
@testable import Kumihimo

/// Task 009: 江戸八つ組, the second braid on the eight-place stand. **Since Task
/// 057 its table is the textbook's p.64–65**, one move a figure; until then it
/// was the recipe book's p.48, read off a round-stand picture two threads a step
/// (`BraidMethodCatalog.edoYatsuRecipeBookP48Disk`, kept for the comparison).
///
/// **The three checks of Task 025-5's step 6, on this braid**: it goes in as a
/// table, a colouring and measured values and nothing else; the working-out,
/// the figure and the stacking take it without being touched; and its family is
/// read off the braid.
@MainActor
struct EdoYatsuTests {
    private var recipe: BraidRecipe { BraidMethodCatalog.edoYatsu8Recipe }
    private var stand: BraidStand { BraidMethodCatalog.stand8 }

    // MARK: - The table (025-5, 1)

    /// **The textbook's ten figures run as one cycle of the eight-place stand**:
    /// one thread a figure, all eight carried once, nothing left for the
    /// closing. Figures 5 and 10 carry on the threads figures 1 and 6 laid, so
    /// ten figures braid eight threads. The carries are seven to nine notches
    /// and the tidies one.
    @Test func theTableIsACycleOfTheEightPlaceStand() throws {
        let worked = try #require(recipe.worked(on: stand))
        #expect(BraidMethodCatalog.stand(for: recipe) == stand)
        let disk = BraidMethodCatalog.edoYatsuDisk
        #expect(disk.stepReading == .oneThreadAnInstant)
        #expect(disk.threadsPerStep == 1)
        #expect(disk.braidingMoves.count == 8)
        #expect(disk.repositioningMoves.count == 8)
        #expect(disk.braidingMoves.allSatisfy { (7...9).contains(disk.notches($0)) })
        #expect(worked.method.steps.map { $0.moves.map { [$0.from, $0.to] } }
                == [[[7, 1]], [[5, 7]], [[3, 5]], [[1, 3]], [[8, 6]], [[2, 8]], [[4, 2]], [[6, 4]]])
        #expect(worked.method.instantCount == 9)
        #expect(worked.method.closing.moves.isEmpty)
        #expect(BraidMethodCatalog.edoYatsu8.steps.map(\.name) == BraidMethodCatalog.edoYatsuStepNames)
    }

    /// **Places 1, 3, 5, 7 go two on and places 2, 4, 6, 8 two back, each
    /// cycle**: 1→3 2→8 3→5 4→2 5→7 6→4 7→1 8→6, the reviewer's permutation.
    /// The places are numbered clockwise, as the disk's slits are, so the odd
    /// places turn clockwise — the anticlockwise thread of each of the book's
    /// pairs, slits 4, 12, 20 and 28 — and the book says 「【1】→【4】は糸を
    /// 右回りに4回組み、【6】→【9】は糸を左回りに4回組みます」.
    ///
    /// **Every thread is carried exactly once**, in the order 7 5 3 1 8 2 4 6:
    /// the first dan is the four odd places and the second the four even.
    @Test func oddPlacesGoTwoOnAndEvenPlacesTwoBack() throws {
        let worked = try #require(recipe.worked(on: stand))
        for course in worked.derivation.courses {
            for (from, to) in zip(course.slots, course.slots.dropFirst()) {
                let wanted = course.threadPosition % 2 == 1 ? 2 : 6
                #expect((to - from + 8) % 8 == wanted, "thread \(course.threadPosition)")
            }
        }
        #expect(netMove(of: worked.method) == [1: 3, 2: 8, 3: 5, 4: 2, 5: 7, 6: 4, 7: 1, 8: 6])

        let cycle = try #require(BraidWorking.cycle(
            of: worked.method, from: BraidStandState.start(on: stand)
        ))
        #expect(cycle.allCarried.map(\.thread) == [7, 5, 3, 1, 8, 2, 4, 6])
        let ended = try #require(cycle.endState.threadByPosition)
        #expect(Set(ended.values) == Set(1...8))
        // Two places on a ring of eight: every thread is home after four cycles.
        #expect(worked.derivation.repeatCycleCount == 4)
    }

    /// **The recipe book's p.48 and the textbook's p.64–65 are the same braid.**
    /// One was read off a round-stand picture, two threads at an instant and
    /// the landings read in (Task 008's reading); the other is printed on the
    /// disk one move a figure. **Named one place on, the recipe book's table
    /// carries every thread as the textbook's does, dan by dan**: its top pair
    /// stood at places 8 and 1, where the textbook's pairs stand at 1・2 … 7・8
    /// (Task 055).
    ///
    /// A turn of two places carries this braid onto itself, so every odd turn
    /// of the names fits and no even one does. What differs is only the order
    /// inside a dan, and how many threads go at an instant.
    @Test func theRecipeBooksTableIsTheSameBraid() throws {
        let textbook = BraidMethodCatalog.edoYatsu8
        let recipeBook = try recipeBookMethod()
        #expect(BraidMethodCatalog.edoYatsuRecipeBookP48Disk.stepReading == .oneStepAnInstant)
        #expect(netMove(of: recipeBook) == [1: 7, 2: 4, 3: 1, 4: 6, 5: 3, 6: 8, 7: 5, 8: 2])

        func named(_ move: BraidMove, on shift: Int) -> BraidMove {
            BraidMove(from: (move.from - 1 + shift) % 8 + 1, to: (move.to - 1 + shift) % 8 + 1)
        }
        // A dan is four threads: the recipe book's first two printed steps, the
        // textbook's first four figures (and the fifth, carrying on the first).
        let recipeBookDans = [recipeBook.steps[0..<2], recipeBook.steps[2..<4]]
        let textbookDans = [textbook.steps[0..<4], textbook.steps[4..<8]]
        let fits = (0..<8).filter { shift in
            zip(recipeBookDans, textbookDans).allSatisfy { old, new in
                Set(old.flatMap(\.moves).map { named($0, on: shift) }) == Set(new.flatMap(\.moves))
            }
        }
        #expect(fits == [1, 3, 5, 7])
    }

    // MARK: - Three things and nothing else (025-5, 6)

    @Test func nothingElseHadToBeDeclared() throws {
        #expect(recipe.crossSection(on: stand).order == stand.positionIDs)
        #expect(recipe.crossSection(on: stand).source == .standRim)
        #expect(recipe.shape == BraidShapeValues())
        let worked = try #require(recipe.worked(on: stand))
        #expect(worked.derivation.fold == nil)
        // Carried both ways round (Task 059): the both-ways family.
        #expect(BraidFamily.family(of: worked.derivation) == .roundTube(threads: 8, turning: .bothWays))
        let figure = try #require(BraidFigureBuilder.tube(
            from: worked.derivation, assignments: recipe.colouring
        ))
        #expect(figure.columns.count == 8)
        let stacking = try #require(BraidStacking.stacking(
            of: worked.method, on: stand, crossSection: worked.section,
            fold: worked.derivation.fold, cycles: 5
        ))
        #expect(stacking.pitchPerCycle.isDerived)
    }

    // MARK: - The colouring

    /// **The textbook's own colouring, read slit by slit off p.64's 組みはじめ**:
    /// 4・20 magenta (`pink`), 5・21 the cream (`natural`), 12・28 cyan
    /// (`light-blue`), 13・29 yellow-green (`yellow`, the nearer of the
    /// catalogue's two names). Laid on the places through the starting slits:
    /// 1 cyan, 2 yellow-green, 3 magenta, 4 cream, and round again.
    @Test func theColouringIsTheTextbooksBySlit() {
        let byPosition = Dictionary(uniqueKeysWithValues: recipe.colouring.map { ($0.position, $0.colorID.rawValue) })
        #expect((1...8).map { byPosition[$0] } == [
            "light-blue", "yellow", "pink", "natural", "light-blue", "yellow", "pink", "natural",
        ])
        let bySlit = [4: "pink", 20: "pink", 5: "natural", 21: "natural",
                      12: "light-blue", 28: "light-blue", 13: "yellow", 29: "yellow"]
        for (index, slit) in BraidMethodCatalog.edoYatsuStartingSlits.enumerated() {
            #expect(byPosition[index + 1] == bySlit[slit], "slit \(slit)")
        }
        #expect(recipe.colouring.allSatisfy { ThreadColorCatalog.contains($0.colorID) })
    }

    /// **The colours come back every two cycles, and not every one**: the
    /// book's 「糸の色は2段ごとに戻ります」, this page's 段 being a cycle. A pair's
    /// two opposite threads share a colour, and a thread goes two places a
    /// cycle, so a place holds the colour of the pair a quarter round, then its
    /// own.
    ///
    /// **The recipe book's colouring keeps every place its colour**, cycle
    /// after cycle — its two colours alternate round the stand, and each thread
    /// stays on its parity. Kept for that: it is what makes the straight bands
    /// the recipe book drew.
    @Test func theColoursComeBackEveryTwoCycles() throws {
        let grid = try colourGrid(recipe.colouring)
        #expect(grid.count == 4)
        #expect(grid[1] != grid[0])
        #expect(grid[2] == grid[0])
        #expect(grid[3] == grid[1])
        // Each place alternates between the two colours of one parity.
        for slot in 0..<8 {
            #expect(Set(grid.map { $0[slot] }).count == 2, "slot \(slot)")
        }

        let straight = try colourGrid(recipeBookColouring)
        #expect(straight.allSatisfy { $0 == straight[0] })
    }

    // MARK: - The drawing (the eight-thread tube's drawer, as it is)

    /// **Drawn by the eight-thread tube's drawer, with its own shape**: the
    /// family is read off the braid and that drawer returns a mesh, the only
    /// one that does. Since Task 059 the family is the both-ways one — the table
    /// carries its threads both ways round.
    @Test func theEightThreadTubesDrawerMakesAMesh() throws {
        #expect(BraidFamilyDrawing.drawer(for: recipe) == RoundTube8SurfaceMesh.familyTurningBothWays)
        let mesh = BraidFamilyDrawing.mesh(for: recipe, on: stand)
        let tube = try #require(mesh.tubeOfEight)
        #expect(tube.triangleCount > 0)
        #expect(mesh.flat == nil && mesh.tube == nil && mesh.tubeOfFour == nil)
    }

    /// **The threads do move, two places a cycle each, odd places on and even
    /// places back**; so the carry has no single number. A table that moved
    /// nothing would keep each place's colour under any colouring — under the
    /// textbook's, every place changes colour each cycle.
    ///
    /// The odd places receive their threads in the first half of the cycle and
    /// the even in the second. **Under the recipe book's colouring each place
    /// keeps its colour**: pink columns and white alternate straight along the
    /// braid, the pairs half a pitch apart — since Task 059 addendum 6 each row
    /// in the colour of the set that passes over it.
    @Test func theThreadsMoveAndThePlacesChangeColour() throws {
        let drawn = try pattern(recipe.colouring)
        // Slot s is place s + 1: odd places (even slots) are fed from two back.
        #expect(drawn.columnsCarriedBySlot == [2, -2, 2, -2, 2, -2, 2, -2])
        #expect(drawn.columnsCarried == nil)
        #expect(drawn.rowCount == 4)
        #expect(drawn.drawnPhaseByColumn == [0.5, 1, 0.5, 1, 0.5, 1, 0.5, 1])
        // **No one lean from the carry** (Task 055's rule on this braid): the
        // carries differ by place. Since Task 059 a stitch leans the way its
        // thread was carried (`EdoYatsuTurnTests`).
        #expect(drawn.leanDirection == nil)
        #expect(Set(drawn.leanBySegment) == [-1, 1])
        // **A place's row shows the threads that pass over it** (Task 059
        // addendum 6): the other set's, so the odd places' rows hold the even
        // places' colours and the even places' rows the odd places'.
        for slot in 0..<8 {
            let wanted: Set<String> = slot % 2 == 0 ? ["yellow", "natural"] : ["light-blue", "pink"]
            #expect(colours(of: drawn, atSlot: slot) == wanted, "slot \(slot)")
        }

        let straight = try pattern(recipeBookColouring)
        for slot in 0..<8 {
            #expect(colours(of: straight, atSlot: slot) == [slot % 2 == 0 ? "white" : "pink"], "slot \(slot)")
        }
    }

    /// **The textbook's table draws the recipe book's braid turned one column**
    /// (Task 057). Each thread given a colour of its own, the recipe book's
    /// named one place on, the two meshes are the same set of points colour by
    /// colour once the recipe book's is turned an eighth of the way round — the
    /// names one place on — and under no other turn. The order inside a dan
    /// does not reach the drawing.
    ///
    /// **The shape does not follow the colouring**: the recipe book's table
    /// with any colouring is the shape the app drew until Task 057, and the
    /// textbook's with its own colouring is the same points as with eight.
    @Test func theShapeIsTheRecipeBooksTurnedOneColumn() throws {
        let names = ["red", "orange", "yellow", "green", "light-blue", "blue", "purple", "pink"]
        let textbook = try mesh(BraidMethodCatalog.edoYatsuDisk, byPlace(names))
        // The recipe book's place p is the textbook's p % 8 + 1.
        let recipeBook = try mesh(
            BraidMethodCatalog.edoYatsuRecipeBookP48Disk, byPlace((1...8).map { names[$0 % 8] })
        )
        #expect(textbook.positions.count == recipeBook.positions.count)
        // The recipe book's table as the drawer draws it since Task 059: a place
        // shows the thread that passed over it, a cushion on its tile (addendum
        // 6); `0x4120_520e_ed66_35d5`, the thread standing there, until then.
        #expect(BraidMeshHashTests.hash(recipeBook.positions) == 0x154b_a8f9_dd7e_99b1)

        func key(_ point: SIMD3<Float>) -> [Int32] {
            [Int32((point.x * 2048).rounded()),
             Int32((point.y * 2048).rounded()),
             Int32((point.z * 2048).rounded())]
        }
        func painted(_ mesh: RoundTube8SurfaceMeshData, turnedBy columns: Int) -> [ThreadColorID: Set<[Int32]>] {
            let turn = 2 * Float.pi * Float(columns) / 8
            var out = [ThreadColorID: Set<[Int32]>]()
            for (colour, indices) in mesh.colorGroups {
                out[colour] = Set(indices.map { index in
                    let point = mesh.positions[Int(index)]
                    // The ring is laid out as `(sin, cos)` in `y` and `z`.
                    let angle = atan2(point.y, point.z) + turn
                    let radius = (point.y * point.y + point.z * point.z).squareRoot()
                    return key(SIMD3(point.x, radius * sin(angle), radius * cos(angle)))
                })
            }
            return out
        }
        // Within one step of the grid, not on it: a point on a grid line in one
        // mesh can round to the next cell in the other.
        func unmatched(_ places: Set<[Int32]>, in other: Set<[Int32]>) -> Int {
            places.filter { key in
                !(-1...1).contains { dx in (-1...1).contains { dy in (-1...1).contains { dz in
                    other.contains([key[0] + Int32(dx), key[1] + Int32(dy), key[2] + Int32(dz)])
                } } }
            }.count
        }
        let mine = painted(textbook, turnedBy: 0)
        #expect(mine.count == 8)
        // Found, not assumed: a few hundred points of each colour tell the
        // turns apart; the one that fits is then held point for point.
        let fits = (0..<8).filter { columns in
            let theirs = painted(recipeBook, turnedBy: columns)
            return mine.allSatisfy { colour, places in
                unmatched(Set(places.prefix(400)), in: theirs[colour] ?? []) == 0
            }
        }
        #expect(fits == [1])
        let theirs = painted(recipeBook, turnedBy: 1)
        #expect(Set(theirs.keys) == Set(mine.keys))
        for (colour, places) in mine {
            let other = theirs[colour] ?? []
            #expect(unmatched(places, in: other) == 0, "\(colour.rawValue): textbook points with no recipe book point")
            #expect(unmatched(other, in: places) == 0, "\(colour.rawValue): recipe book points with no textbook point")
        }

        let shipped = try #require(BraidFamilyDrawing.mesh(for: recipe, on: stand).tubeOfEight)
        #expect(BraidMeshHashTests.hash(shipped.positions) == BraidMeshHashTests.hash(textbook.positions))
    }

    /// **The mesh is the both-ways family's since Task 059** (`EdoYatsuTurnTests`):
    /// the table carries threads both ways round, and a place shows the thread
    /// that passed over it (addendum 6), once a cycle, a cushion on the rhombus
    /// its tile makes — as many stitches as cells, hence 18,240 vertices again.
    /// It was `0x395e_006f_6882_6dc1` from Task 057 until then — the eight-thread
    /// drawer's bundles on the textbook's table, each place its own thread.
    /// Moves only on purpose.
    @Test func theMeshIsTheShapeItWas() throws {
        let mesh = try #require(BraidFamilyDrawing.mesh(for: recipe, on: stand).tubeOfEight)
        #expect(mesh.positions.count == 18_240)
        #expect(BraidMeshHashTests.hash(mesh.positions) == 0x3e06_1290_d694_7769)
    }

    // MARK: - The preset

    /// **Eight threads offer 江戸八つ** beside yatsu-kongo, and it is the
    /// recipe's own preset.
    @Test func eightThreadsOfferEdoYatsu() {
        #expect(BraidPresetCatalog.availablePresets(threadCount: 8).contains(BraidPresetCatalog.edoYatsu))
        #expect(BraidMethodCatalog.recipe(for: .edoYatsu8) == recipe)
        #expect(BraidPresetCatalog.edoYatsu.displayName == "江戸八つ")
        for count in [4, 12, 16] {
            #expect(!BraidPresetCatalog.availablePresets(threadCount: count).contains(BraidPresetCatalog.edoYatsu))
        }
    }

    // MARK: - Helpers

    /// **The recipe book's p.48 colouring**, which the app shipped until Task
    /// 057: 131 (`pink`) and 129 (`white`) alternating round the stand, 131 at
    /// the recipe book's places 8, 2, 4, 6 — **the textbook's 1, 3, 5, 7**,
    /// the places named one on (`theRecipeBooksTableIsTheSameBraid`).
    private var recipeBookColouring: [ThreadAssignment] {
        byPlace(["pink", "white", "pink", "white", "pink", "white", "pink", "white"])
    }

    private func byPlace(_ names: [String]) -> [ThreadAssignment] {
        zip(1...8, names).map { ThreadAssignment(position: $0.0, colorID: ThreadColorID(rawValue: $0.1)) }
    }

    /// The recipe book's p.48 table, which the app braided until Task 057.
    private func recipeBookMethod() throws -> BraidMethod {
        try #require(BraidMethodCatalog.edoYatsuRecipeBookP48Disk.method(
            id: "edo-yatsu-8-recipe-book-p48", standID: stand.id,
            stepNames: BraidMethodCatalog.edoYatsuRecipeBookP48StepNames
        ))
    }

    /// Where each thread rests at the end of one cycle, by where it rested at
    /// the start.
    private func netMove(of method: BraidMethod) -> [Int: Int] {
        var result = [Int: Int]()
        for step in method.steps {
            for move in step.moves { result[move.from] = move.to }
        }
        return result
    }

    /// One row a cycle, one cell a slot round the braid: **the colour resting
    /// there**, as `YatsuKongoTests` reads it.
    private func colourGrid(_ colouring: [ThreadAssignment]) throws -> [[String]] {
        let worked = try #require(recipe.worked(on: stand))
        let rows = try #require(BraidWorking.repeatCycleCount(of: worked.method, on: stand))
        let occupancy = try #require(BraidOccupancy.history(
            of: worked.method, on: stand, crossSection: worked.section, cycles: rows
        ))
        let columns = try #require(occupancy.columns(.landing))
        #expect(columns == Array(0..<8))
        let grid = try #require(occupancy.grid(atColumns: columns, rows: rows))
        let colours = Dictionary(uniqueKeysWithValues: colouring.map { ($0.position, $0.colorID.rawValue) })
        return try grid.map { row in try row.map { try #require(colours[$0]) } }
    }

    private func pattern(_ colouring: [ThreadAssignment]) throws -> RoundTube8SurfacePattern {
        let worked = try #require(recipe.worked(on: stand))
        return try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, rounds: worked.derivation.rounds, crossSection: worked.section,
            assignments: colouring
        ))
    }

    /// The colours drawn along one slot of the braid.
    private func colours(of drawn: RoundTube8SurfacePattern, atSlot slot: Int) -> Set<String> {
        let middle = (Float(slot) + 0.5) / 8
        return Set(drawn.surface.segments
            .filter { abs($0.centerlineStart.x - middle) < 1e-4 }.map(\.colorID.rawValue))
    }

    /// The mesh the eight-thread drawer makes of a table under a colouring,
    /// the way the app makes it for a recipe.
    private func mesh(
        _ notation: BraidDiskNotation, _ colouring: [ThreadAssignment]
    ) throws -> RoundTube8SurfaceMeshData {
        let trial = BraidRecipe(
            id: "edo-yatsu-8-trial", name: "江戸八つ組", notation: notation,
            colouring: colouring, shape: BraidShapeValues(),
            orderRoundTheBraid: BraidMethodCatalog.edoYatsu8CrossSection
        )
        return try #require(BraidFamilyDrawing.mesh(for: trial, on: stand).tubeOfEight)
    }
}
