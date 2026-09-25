import Foundation
import simd
import Testing
@testable import Kumihimo

/// Task 059 addendum 6: **on 江戸八つ組's face a place shows the thread that
/// passed over it.** A thread carried round the stand goes over the thread of
/// the other set standing between where it was and where it lands, and that
/// place shows a stitch of it — once a cycle for every place and every thread.
/// The rows are the places; a row's stitches are a cycle apart and the rows
/// beside it half a cycle from them. Each stitch is a cushion on the rhombus
/// that tile makes.
///
/// **Counted from the table on the lattice, not from pixels** (the reviewer's
/// section 4): which colour stands beside which, along a row and on the
/// diagonals, under four colourings — the textbook's figure, the figure with
/// cyan and yellow-green swapped (which the p.64 photograph's pairs are), the
/// p.65 left example and the author's.
@MainActor
struct EdoYatsuTurnTests {
    private var recipe: BraidRecipe { BraidMethodCatalog.edoYatsu8Recipe }
    private var stand: BraidStand { BraidMethodCatalog.stand8 }

    /// Colours by place 1-8, repeating.
    private func byPlace(_ names: [String]) -> [ThreadAssignment] {
        (1...8).map { ThreadAssignment(position: $0, colorID: ThreadColorID(rawValue: names[($0 - 1) % names.count])) }
    }

    /// **The figure with its cyan and yellow-green swapped** (the reviewer's
    /// reading of the p.64 photograph): places 1・5 yellow-green, 2・6 cyan, 3・7
    /// magenta, 4・8 cream. Yellow-green is `yellow` until the catalogue has one
    /// (the author, 2026-09-25).
    private var swappedColouring: [ThreadAssignment] { byPlace(["kiiro", "tsuyukusa", "fuji", "zoge"]) }

    /// **The p.65 left example**: the left thread of every pair one colour and
    /// the right another — teal and yellow-green on the page, `light-blue` and
    /// `yellow` here, the nearest the catalogue has.
    private var leftAndRightColouring: [ThreadAssignment] { byPlace(["light-blue", "yellow"]) }

    /// **The author's colouring** (2026-09-24): places 1・5 pink, 2・6 white,
    /// 3・7 blue, 4・8 green.
    private var authorsColouring: [ThreadAssignment] { byPlace(["pink", "white", "blue", "green"]) }

    private func pattern(_ colouring: [ThreadAssignment], of recipe: BraidRecipe? = nil) throws -> RoundTube8SurfacePattern {
        let recipe = recipe ?? self.recipe
        let worked = try #require(recipe.worked(on: stand))
        return try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, rounds: worked.derivation.rounds, crossSection: worked.section,
            assignments: colouring
        ))
    }

    /// The textbook's colours as the reviewer names them: C cyan, M magenta, Y
    /// yellow-green (`yellow`), N cream; any other colour by its own name.
    private static let letters = ["tsuyukusa": "C", "fuji": "M", "kiiro": "Y", "zoge": "N"]

    /// **The stitches on the face's lattice**: row (the place), and middle in
    /// half cycles over one repeat.
    private func lattice(_ drawn: RoundTube8SurfacePattern, letters: [String: String] = letters) throws -> [Int: String] {
        let rows = Float(drawn.rowCount), halves = drawn.rowCount * 2
        var at = [Int: String]()
        for segment in drawn.surface.segments {
            let row = Int((segment.centerlineStart.x * 8).rounded(.down)) % 8
            let middle = (segment.centerlineStart.y + segment.centerlineEnd.y) / 2 * rows * 2
            #expect(abs(middle - middle.rounded()) < 1e-3, "a stitch off the half cycles")
            let key = row * halves + ((Int(middle.rounded()) % halves) + halves) % halves
            #expect(at[key] == nil, "two stitches at one place")
            at[key] = letters[segment.colorID.rawValue] ?? segment.colorID.rawValue
        }
        return at
    }

    /// **Which colours stand beside which**, once a pair: along the braid, the
    /// next stitch in the row (a cycle on); on the diagonals, the stitches of
    /// the next row half a cycle either side. A pair is its two names, sorted,
    /// joined by a space.
    private func neighbourPairs(
        _ drawn: RoundTube8SurfacePattern, letters: [String: String] = letters
    ) throws -> (along: [String: Int], diagonal: [String: Int]) {
        let at = try lattice(drawn, letters: letters), halves = drawn.rowCount * 2
        func stitch(_ row: Int, _ time: Int) -> String? {
            at[((row % 8) + 8) % 8 * halves + ((time % halves) + halves) % halves]
        }
        func pair(_ one: String, _ other: String) -> String { [one, other].sorted().joined(separator: " ") }
        var along = [String: Int](), diagonal = [String: Int]()
        for (key, colour) in at {
            let row = key / halves, time = key % halves
            if let next = stitch(row, time + 2) { along[pair(colour, next), default: 0] += 1 }
            for step in [-1, 1] {
                if let next = stitch(row + 1, time + step) { diagonal[pair(colour, next), default: 0] += 1 }
            }
        }
        return (along, diagonal)
    }

    // MARK: - Who shows where

    /// **Every place shows one stitch a cycle, and every thread one**, and a
    /// place's stitch is a thread of the other set — the one that passed over
    /// it (the textbook's table: 4→11 goes over 5, 28→4 over 29, 5→30 over 4, …).
    /// The rows are the places: the face does not turn.
    @Test func everyPlaceShowsOneStitchACycleOfTheOtherSet() throws {
        let worked = try #require(recipe.worked(on: stand))
        let drawn = try pattern(recipe.colouring)
        let rows = Float(drawn.rowCount)
        #expect(drawn.surface.segments.count == 8 * drawn.rowCount)
        var slotsByCycle = [Int: [Int]](), threadsByCycle = [Int: [Int]]()
        for segment in drawn.surface.segments {
            let slot = Int((segment.centerlineStart.x * 8).rounded(.down)) % 8
            let middle = (segment.centerlineStart.y + segment.centerlineEnd.y) / 2 * rows
            let cycle = ((Int((middle - 0.25).rounded(.down)) % drawn.rowCount) + drawn.rowCount) % drawn.rowCount
            slotsByCycle[cycle, default: []].append(slot)
            threadsByCycle[cycle, default: []].append(segment.threadPosition)
            // Threads keep to their set's places (odd or even), and the one that
            // shows at a place is of the other.
            let home = try #require(worked.section.slotIndex(ofPositionID: segment.threadPosition))
            #expect(home % 2 != slot % 2, "slot \(slot) shows thread \(segment.threadPosition)")
            // A cycle long.
            #expect(abs(drawn.runCycle(of: segment) - drawn.cycleInRepeats) < 1e-5)
        }
        #expect(slotsByCycle.count == drawn.rowCount)
        for (cycle, slots) in slotsByCycle {
            #expect(slots.sorted() == Array(0..<8), "cycle \(cycle)")
            #expect(Set(threadsByCycle[cycle] ?? []).count == 8, "cycle \(cycle)")
        }
        // The rows beside each other are half a cycle apart.
        let at = try lattice(drawn)
        let halves = drawn.rowCount * 2
        for row in 0..<8 {
            let mine = Set(at.keys.filter { $0 / halves == row }.map { $0 % halves % 2 })
            let next = Set(at.keys.filter { $0 / halves == (row + 1) % 8 }.map { $0 % halves % 2 })
            #expect(mine.count == 1 && next.count == 1 && mine != next, "rows \(row) and \(row + 1)")
        }
        // Yatsu-kongo S, Z and 返し組 are not drawn this way.
        for kongo in [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe,
                      BraidMethodCatalog.yatsuKongoGaeshi8Recipe] {
            #expect(try pattern(kongo.colouring, of: kongo).bundle == .standard, "\(kongo.id)")
        }
    }

    /// **The textbook's figure** (4・20 magenta, 5・21 cream, 12・28 cyan, 13・29
    /// yellow-green): along the braid only cyan–magenta and yellow-green–cream,
    /// so the rows alternate set by set; on the diagonals the four pairs across
    /// the sets, every one of them; and a row's colours come back every two
    /// cycles.
    @Test func theFiguresColouringRunsSetBySet() throws {
        let drawn = try pattern(recipe.colouring)
        let pairs = try neighbourPairs(drawn)
        #expect(Set(pairs.along.keys) == ["C M", "N Y"])
        #expect(Set(pairs.diagonal.keys) == ["M Y", "C N", "M N", "C Y"])
        let at = try lattice(drawn), halves = drawn.rowCount * 2
        for row in 0..<8 {
            let held = at.filter { $0.key / halves == row }.sorted { $0.key < $1.key }.map(\.value)
            #expect(Set(held) == (row % 2 == 0 ? ["Y", "N"] : ["C", "M"]), "row \(row): \(held)")
            for (index, colour) in held.enumerated() {
                #expect(colour != held[(index + 1) % held.count], "row \(row)")
                #expect(colour == held[(index + 2) % held.count], "row \(row)")
            }
        }
    }

    /// **The figure with cyan and yellow-green swapped gives the photograph's
    /// pairs**: along the braid only magenta–yellow-green and cyan–cream, on the
    /// diagonals only magenta–cyan, cyan–yellow-green, yellow-green–cream and
    /// cream–magenta. On the textbook p.64's photograph those are 121 of 122
    /// pairs along and 178 of 180 on the diagonals
    /// (`Scripts/task059/count_neighbours.py`); the figure's own colouring gives
    /// other pairs, so the photograph's braid reads as the swapped one (the
    /// reviewer's reading).
    @Test func theSwappedColouringHasThePhotographsPairs() throws {
        let pairs = try neighbourPairs(try pattern(swappedColouring))
        let photographAlong: Set<String> = ["M Y", "C N"]
        let photographDiagonal: Set<String> = ["C M", "C Y", "N Y", "M N"]
        #expect(Set(pairs.along.keys) == photographAlong)
        #expect(Set(pairs.diagonal.keys) == photographDiagonal)
        let figure = try neighbourPairs(try pattern(recipe.colouring))
        #expect(Set(figure.along.keys) != photographAlong)
    }

    /// **The p.65 left example is stripes along the braid** (「リズミカルな点線の入った
    /// 縦縞」): with the left thread of every pair one colour and the right
    /// another, every row is one colour, and the rows alternate.
    @Test func theLeftAndRightColouringIsStripesAlongTheBraid() throws {
        let drawn = try pattern(leftAndRightColouring)
        let at = try lattice(drawn, letters: [:]), halves = drawn.rowCount * 2
        var rows = [String]()
        for row in 0..<8 {
            let held = Set(at.filter { $0.key / halves == row }.map(\.value))
            #expect(held.count == 1, "row \(row): \(held)")
            rows.append(held.first ?? "")
        }
        for row in 0..<8 { #expect(rows[row] != rows[(row + 1) % 8]) }
        let pairs = try neighbourPairs(drawn, letters: [:])
        #expect(Set(pairs.diagonal.keys) == ["light-blue yellow"])
    }

    /// **The author's colouring**: along the braid pink–blue and white–green; on
    /// the diagonals pink–white, pink–green, blue–white and blue–green.
    @Test func theAuthorsColouring() throws {
        let pairs = try neighbourPairs(try pattern(authorsColouring), letters: [:])
        #expect(Set(pairs.along.keys) == ["blue pink", "green white"])
        #expect(Set(pairs.diagonal.keys) == ["pink white", "green pink", "blue white", "blue green"])
    }

    // MARK: - The stitch

    /// **A stitch is a low cushion on its tile** (the reviewer, addendum 6): the
    /// tile's edge is where the norm is 1 — a cycle along its middle and two rows
    /// across — the stitch still stands a little on it and is down to the floor
    /// only at its own outline, its tuck past it. No higher over the floor than
    /// yatsu-kongo's bundle, and nothing out of the braid's cylinder.
    @Test func aStitchIsALowCushionOnItsTile() throws {
        let stitch = RoundTube8Bundle.bothWays
        let tile = try #require(stitch.tile)
        #expect(tile == .cushion)
        #expect(tile.reachInColumns == 1)
        #expect(tile.tuck > 0)
        #expect(stitch.firstCycles == 0.5 - tile.alongReachInStitches)
        #expect(stitch.lengthInCycles == 0.5 + tile.alongReachInStitches)
        #expect(stitch.leanColumnsPerCycle == 0)
        #expect(RoundTube8Bundle.standard.firstCycles == 0)
        #expect(RoundTube8SurfaceMesh.runHeightOverRadius(for: .bothWays) <= RoundTube8SurfaceMesh.runHeightOverRadius)
        #expect(abs(tile.norm(atStitches: 0, columns: 0) - 1) < 1e-5)
        #expect(abs(tile.norm(atStitches: 1, columns: 0) - 1) < 1e-5)
        #expect(abs(tile.norm(atStitches: 0.5, columns: 1) - 1) < 1e-5)
        #expect(tile.heightFraction(atStitches: 0, across: 0) > 0.3)
        #expect(tile.heightFraction(atStitches: 0.5, across: 0) == 1)
        #expect(stitch.halfWidthInColumns(atCycles: stitch.lengthInCycles + 0.01) == 0)
        #expect(stitch.halfWidthInColumns(atCycles: stitch.firstCycles - 0.01) == 0)
        #expect(RoundTube8SurfacePatternGenerator.pitchOverDiameterTurningBothWays == 0.5)

        let mesh = try #require(BraidFamilyDrawing.mesh(for: recipe, on: stand).tubeOfEight)
        let outermost = mesh.positions.map { ($0.y * $0.y + $0.z * $0.z).squareRoot() }.max() ?? .infinity
        #expect(outermost <= mesh.crestRadius + 1e-4)
    }

    /// **It shows over its own tile and goes under past it**: at its middle a
    /// stitch is the highest thing there; a little past the middle of each of
    /// its four edges — a quarter of its tuck out in the norm — a neighbour is.
    @Test func aStitchShowsOverItsTileAndGoesUnderPastIt() throws {
        let drawn = try pattern(authorsColouring)
        let tile = try #require(drawn.bundle.tile)
        let outside: [(Float, Float)] = [Float(45), 135, 225, 315].map { degrees in
            let angle = degrees * .pi / 180
            func place(_ reach: Float) -> (Float, Float) {
                (0.5 + reach * 0.5 * cos(angle), reach * tile.reachInColumns * sin(angle))
            }
            var reach: Float = 0
            while tile.norm(atStitches: place(reach).0, columns: place(reach).1) < 1 + tile.tuck / 4 { reach += 0.001 }
            return place(reach)
        }
        var shown = 0, under = 0, checked = 0
        for (index, segment) in drawn.surface.segments.enumerated() {
            let length = drawn.runCycle(of: segment)
            func top(_ stitches: Float, _ columns: Float) -> Int? {
                drawn.runsStanding(
                    atTurns: segment.centerlineStart.x + columns / 8,
                    along: segment.centerlineStart.y + stitches * length
                ).first?.segment
            }
            if top(0.5, 0) == index { shown += 1 }
            for (stitches, columns) in outside {
                checked += 1
                if let other = top(stitches, columns), other != index { under += 1 }
            }
        }
        #expect(shown == drawn.surface.segments.count)
        #expect(under == checked)
    }

    /// **The fibre runs the way the thread is carried over the one beneath**
    /// (addendum 6): a stitch leans the way its thread was carried, +1 or -1 by
    /// set, and the stripes' angle is the carry's on the drawn face — two rows a
    /// cycle — not a figure read off the photograph. The maps are drawn once, the
    /// stripes falling round the braid as it goes along, which is the way a
    /// thread carried back runs; a stitch carried on reads them mirrored across
    /// it, its bitangent turned with them.
    @Test func theStripesRunTheWayTheThreadIsCarried() throws {
        let worked = try #require(recipe.worked(on: stand))
        let drawn = try pattern(authorsColouring)
        for (index, segment) in drawn.surface.segments.enumerated() {
            let home = try #require(worked.section.slotIndex(ofPositionID: segment.threadPosition))
            let carried = drawn.columnsCarriedBySlot[home]
            #expect(drawn.leanBySegment[index] == (carried > 0 ? 1 : -1), "stitch \(index)")
        }
        #expect(Set(drawn.leanBySegment) == [-1, 1])
        let angle = RoundTube8SurfaceMesh.fibreStripeAngleDegrees(for: .bothWays)
        let wanted = atan(2 * Float.pi / 8 / 0.5) * 180 / .pi
        #expect(abs(angle - wanted) < 1e-3, "\(angle)")
        #expect(RoundTube8SurfaceMesh.fibreStripeAngleDegrees(for: .oneWay) == RoundTube8SurfaceMesh.fibreStripeAngleDegrees)

        // The drawn maps: along and across the phase moves the same way, so the
        // stripes fall round the braid as they go along it.
        let twist = try #require(RoundTube8StrandTexture.twist(on: .bothWays))
        #expect(twist.coefficients.phasePerAlong * twist.coefficients.phasePerAcross > 0)

        let mesh = try #require(RoundTube8SurfaceMesh.generate(pattern: drawn))
        let across = RoundTube8SurfaceMesh.defaultAcrossSubdivisions + 1
        let middle = RoundTube8SurfaceMesh.defaultAlongSubdivisions / 2
        for (index, lean) in drawn.leanBySegment.enumerated() {
            let vertex = mesh.runVertexRanges[index].lowerBound + middle * across + across - 1
            let row = mesh.textureCoordinates[vertex].y
            #expect(lean > 0 ? row < 0.5 : row > 0.5, "stitch \(index)")
            let geometric = simd_cross(mesh.normals[vertex], mesh.tangents[vertex])
            #expect((simd_dot(mesh.bitangents[vertex], geometric) < 0) == (lean > 0), "stitch \(index)")
        }
    }

    // MARK: - The card

    /// **No floor shows, and the grooves between the cushions do** (addendum 6):
    /// on the card not one pixel is the cell beneath, and 10-20% are not a
    /// thread's own colour — the grooves and the lines where stitches meet. On
    /// the textbook p.64's photograph 15.3% of the front is none of the four
    /// colours (`Scripts/task059/count_neighbours.py`).
    @Test func theCardShowsNoFloorAndItsGrooves() throws {
        for colouring in [recipe.colouring, swappedColouring, authorsColouring] {
            let drawn = try pattern(colouring)
            let map = RoundTube8CardImage.shownMap(for: drawn)
            let beneath = map.shown.filter { if case .beneath? = $0 { true } else { false } }.count
            #expect(beneath == 0)
            #expect(!map.shown.contains(nil))
            let share = try Self.shareNotAThreadColour(drawn)
            #expect((0.10...0.20).contains(share), "\(share)")
        }
    }

    /// The share of a card's pixels that are none of its threads' own colours.
    static func shareNotAThreadColour(_ drawn: RoundTube8SurfacePattern) throws -> Double {
        let image = try #require(RoundTube8CardImage.draw(drawn, bundle: drawn.bundle))
        let data = try #require(image.dataProvider?.data as Data?)
        func byte(_ value: Double) -> UInt8 { UInt8(min(max(Float(value), 0), 1) * 255 + 0.5) }
        let own = Set(drawn.surface.segments.map(\.colorID).map { id -> [UInt8] in
            let value = (ThreadColorCatalog.color(for: id) ?? ThreadColorCatalog.defaultColor).value
            return [byte(value.red), byte(value.green), byte(value.blue)]
        })
        let bytes = [UInt8](data)
        var other = 0
        let pixels = image.width * image.height
        for pixel in 0..<pixels {
            let offset = pixel * 4
            if !own.contains([bytes[offset], bytes[offset + 1], bytes[offset + 2]]) { other += 1 }
        }
        return Double(other) / Double(pixels)
    }
}
