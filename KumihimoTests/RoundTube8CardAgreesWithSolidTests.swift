import Foundation
import simd
import Testing
@testable import Kumihimo

/// Task 045 review fixes: **the card and the solid show the same thread at the
/// same place on the braid.**
///
/// The solid decides what shows by depth: of every surface on a line straight
/// out from the axis, the outermost is seen. This reads that off the real
/// generated triangles — a ray from the axis, every triangle it crosses, the
/// outermost hit — and holds the card's rule against it at the same place
/// round the braid and along it. Nothing here compares pictures.
@MainActor
struct RoundTube8CardAgreesWithSolidTests {

    private var stand: BraidStand { BraidMethodCatalog.stand8 }

    private func pattern(_ recipe: BraidRecipe) throws -> RoundTube8SurfacePattern {
        let worked = try #require(recipe.worked(on: stand))
        let eight = ["red", "orange", "yellow", "green", "light-blue", "blue", "purple", "pink"]
            .enumerated().map { ThreadAssignment(position: $0.offset + 1, colorID: ThreadColorID(rawValue: $0.element)) }
        return try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, method: worked.method, crossSection: worked.section, assignments: eight
        ))
    }

    /// What the solid shows at a place: the outermost triangle on the ray out
    /// from the axis, as the run (or the cell beneath) it belongs to.
    struct Solid {
        enum Part: Equatable { case run(repeatIndex: Int, segment: Int), beneath(repeatIndex: Int, segment: Int) }
        let mesh: RoundTube8SurfaceMeshData
        let cells: Int
        private var owner: [Part?]
        private var triangles: [SIMD3<Int>]
        private var bins: [[Int]]
        static let binsAlong = 128, binsRound = 64

        init(mesh: RoundTube8SurfaceMeshData, cells: Int) {
            self.mesh = mesh
            self.cells = cells
            owner = Array(repeating: nil, count: mesh.positions.count)
            for (index, range) in mesh.runVertexRanges.enumerated() {
                for vertex in range { owner[vertex] = .run(repeatIndex: index / cells, segment: index % cells) }
            }
            for (index, range) in mesh.beneathVertexRanges.enumerated() {
                for vertex in range { owner[vertex] = .beneath(repeatIndex: index / cells, segment: index % cells) }
            }
            let indices = mesh.allTriangleIndices
            triangles = stride(from: 0, to: indices.count, by: 3).map {
                SIMD3(Int(indices[$0]), Int(indices[$0 + 1]), Int(indices[$0 + 2]))
            }
            bins = Array(repeating: [], count: Self.binsAlong * Self.binsRound)
            let half = mesh.length / 2
            for (t, triangle) in triangles.enumerated() {
                let points = [triangle.x, triangle.y, triangle.z].map { mesh.positions[$0] }
                let xs = points.map { Int((($0.x + half) / mesh.length * Float(Self.binsAlong)).rounded(.down)) }
                var angles = points.map { atan2($0.y, $0.z) / (2 * .pi) }
                // A triangle on the seam: keep its corners on one side of it.
                if (angles.max() ?? 0) - (angles.min() ?? 0) > 0.5 { angles = angles.map { $0 < 0 ? $0 + 1 : $0 } }
                let rounds = angles.map { Int(($0 * Float(Self.binsRound)).rounded(.down)) }
                // Runs hang past both ends of the tile; what lies wholly outside
                // it is not binned.
                let low = max(0, xs.min()! - 1), high = min(Self.binsAlong - 1, xs.max()! + 1)
                guard low <= high else { continue }
                for x in low...high {
                    for r in (rounds.min()! - 1)...(rounds.max()! + 1) {
                        let wrapped = ((r % Self.binsRound) + Self.binsRound) % Self.binsRound
                        bins[x * Self.binsRound + wrapped].append(t)
                    }
                }
            }
        }

        /// The outermost surface on the ray out from the axis at `x` along the
        /// tile and `turns` round, and how far out it is.
        func outermost(x: Float, turns: Float) -> (part: Part, radius: Float)? {
            let angle = 2 * .pi * turns
            let origin = SIMD3<Float>(x, 0, 0)
            let direction = SIMD3<Float>(0, sin(angle), cos(angle))
            let bx = Int(((x + mesh.length / 2) / mesh.length * Float(Self.binsAlong)).rounded(.down))
            var wrappedTurns = turns.truncatingRemainder(dividingBy: 1)
            if wrappedTurns < 0 { wrappedTurns += 1 }
            let br = Int((wrappedTurns * Float(Self.binsRound)).rounded(.down)) % Self.binsRound
            guard (0..<Self.binsAlong).contains(bx) else { return nil }
            var best: (Part, Float)?
            for t in bins[bx * Self.binsRound + br] {
                let tri = triangles[t]
                let a = mesh.positions[tri.x], b = mesh.positions[tri.y], c = mesh.positions[tri.z]
                let e1 = b - a, e2 = c - a
                let p = cross(direction, e2)
                let det = dot(e1, p)
                guard abs(det) > 1e-12 else { continue }
                let s = origin - a
                let u = dot(s, p) / det
                guard u >= 0, u <= 1 else { continue }
                let q = cross(s, e1)
                let v = dot(direction, q) / det
                guard v >= 0, u + v <= 1 else { continue }
                let distance = dot(e2, q) / det
                guard distance > 0 else { continue }
                if best == nil || distance > best!.1, let part = owner[tri.x] { best = (part, distance) }
            }
            return best.map { (part: $0.0, radius: $0.1) }
        }
    }

    /// Mesh `x` of a place `along` repeats from the start of the tile's first repeat.
    private func x(_ mesh: RoundTube8SurfaceMeshData, along: Float) -> Float {
        -mesh.length / 2 + mesh.patternRepeatLength * along
    }

    /// **The places the review found**: S, lane 0, the run that begins at
    /// cycle -0.75 of a repeat and the one after it at +0.25, 1.10 cycles past
    /// the earlier one's start and 0.18 of a column back from the lane's middle
    /// (and 1.30, 0.42). Moved into the middle of the tile: the earlier run is
    /// the second repeat's first row.
    ///
    /// **Before the fix the card painted the later run here** (it painted whole
    /// runs in arrival order) **and the solid showed the earlier** — the mesh put
    /// the earlier one's flank at radius 0.41103 and 0.38191 (crest 0.48), as
    /// the review had worked out by hand. Now both read the one rule.
    @Test func thePlacesTheReviewFoundShowTheSameThreadOnTheCardAndTheSolid() throws {
        let drawn = try pattern(BraidMethodCatalog.yatsuKongoS8Recipe)
        let mesh = try #require(RoundTube8SurfaceMesh.generate(pattern: drawn))
        let solid = Solid(mesh: mesh, cells: drawn.surface.segments.count)
        let rows = Float(drawn.rowCount)
        let lane0 = try #require(drawn.surface.segments.firstIndex {
            abs($0.centerlineStart.x - 0.5 / 8) < 1e-5 && abs($0.centerlineStart.y * rows + 0.75) < 1e-4
        })
        for (past, back) in [(Float(1.10), Float(0.18)), (1.30, 0.42)] {
            let along = (-0.75 + past) / rows          // in the second repeat
            let turns = (0.5 - back) / 8
            let seen = try #require(solid.outermost(x: x(mesh, along: 1 + along), turns: turns))
            // The earlier run shows, on the solid.
            #expect(seen.part == .run(repeatIndex: 1, segment: lane0),
                    "\(past) cycles past: the solid shows \(seen.part) at radius \(seen.radius)")
            // And the card's rule says the same.
            let top = try #require(drawn.runsStanding(atTurns: turns, along: along).first)
            #expect(Solid.Part.run(repeatIndex: 1 + top.repeatOffset, segment: top.segment) == seen.part)
        }
    }

    /// **Across a whole repeat, the card's picture shows the thread the solid
    /// shows**, pixel by pixel of the card's own bitmap (every other row and
    /// column), S and Z, both flanks of every run and both sides of its
    /// shoulder, the seam round the braid and the join between repeats
    /// included. The solid is read off its real triangles — the outermost
    /// surface on the ray out from the axis, whichever run it belongs to — never
    /// off cell colours or the crest alone.
    ///
    /// **Where a pixel is let off, and why.** The mesh is the rule's smooth
    /// surface cut into flat triangles, and a flat triangle lies inside a curve
    /// that bends away from it: the run's section is a semi-ellipse, steepest at
    /// its edges, and its width and height rise from nothing at the arrival as a
    /// quarter ellipse, steepest there. So a pixel is let off **where the cut
    /// could change which run is highest**: where the highest run, taken at the
    /// mesh's own samples round the place and blended between them, stands
    /// within 3% of the ridge of the next one; where it stands within 3% of the
    /// floor; beyond its last sample inside its edge, where its outline is
    /// itself a chord; and before its second sample after its arrival. Found
    /// all in the outer tenth of a run's half-width or just after its arrival
    /// (the first sweep, before this was written in). Everywhere else the card
    /// and the solid must agree exactly, and how many were let off is bounded.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func theCardShowsWhatTheSolidShowsAcrossARepeat(recipe: BraidRecipe) throws {
        let drawn = try pattern(recipe)
        let mesh = try #require(RoundTube8SurfaceMesh.generate(pattern: drawn))
        let solid = Solid(mesh: mesh, cells: drawn.surface.segments.count)
        let map = RoundTube8CardImage.shownMap(for: drawn)
        let bundle = RoundTube8Bundle.standard
        let margin: Float = 0.03
        let steps = Float(RoundTube8SurfaceMesh.defaultAlongSubdivisions)
        let secondSample = (1 + RoundTube8SurfaceMesh.crossSectionOffset(forSample: 2 / steps)) / 2
            * bundle.lengthInCycles
        // The last sample inside a run's edge: beyond it the run's outline
        // itself is a chord.
        let edgeSample = RoundTube8SurfaceMesh.crossSectionOffset(
            forSample: 1 - 1 / Float(RoundTube8SurfaceMesh.defaultAcrossSubdivisions)
        )
        var compared = 0, letOff = 0
        var disagreements = [String]()
        for row in stride(from: 0, to: map.height, by: 2) {
            for column in stride(from: 0, to: map.width, by: 2) {
                let turns = RoundTube8CardImage.turns(atRow: Float(row), rows: map.height)
                let along = (Float(column) + 0.5) / Float(map.width)
                let standing = drawn.runsStanding(atTurns: turns, along: along)
                if let top = standing.first {
                    let next = standing.dropFirst().first?.height ?? -1
                    let (cycles, across) = place(of: top, in: drawn, turns: turns, along: along)
                    let asCut = min(top.height, sampled(cycles: cycles, across: across))
                    if top.height < margin || asCut - next < margin
                        || abs(across) >= edgeSample || cycles < secondSample {
                        letOff += 1
                        continue
                    }
                }
                // Read the solid in the middle of the tile, half a repeat either
                // side of the join between its two repeats: near the tile's own
                // ends, runs of the tile before and after reach in, and they are
                // not in this tile.
                let home = along < 0.5 ? 1 : 0
                let seen = try #require(solid.outermost(x: x(mesh, along: Float(home) + along), turns: turns),
                                        "no surface at \(turns), \(along)")
                let card: Solid.Part? = switch map.shown[row * map.width + column] {
                case .run(let offset, let segment)?: .run(repeatIndex: home + offset, segment: segment)
                case .beneath(let offset, let segment)?: .beneath(repeatIndex: home + offset, segment: segment)
                case nil: nil
                }
                compared += 1
                if card != seen.part {
                    disagreements.append(String(format: "turns %.4f along %.4f", turns, along)
                        + ": card \(String(describing: card)), solid \(seen.part)")
                }
            }
        }
        #expect(disagreements.count == 0,
                "\(disagreements.count) of \(compared): \(disagreements.prefix(8).joined(separator: "; "))")
        #expect(compared > 10_000)
        // Bounded: the band the triangles cannot follow is a small part of the card.
        #expect(letOff * 10 < compared + letOff, "let off \(letOff) of \(compared + letOff)")
    }

    /// How far a run stands at a place **as the mesh cuts it**: the rule's height
    /// at the mesh's own samples round the place, blended between them — what a
    /// flat triangle there stands at, near enough to say where the cut could
    /// change which run is highest.
    private func sampled(cycles: Float, across: Float) -> Float {
        let bundle = RoundTube8Bundle.standard
        let alongSteps = RoundTube8SurfaceMesh.defaultAlongSubdivisions
        let acrossSteps = RoundTube8SurfaceMesh.defaultAcrossSubdivisions
        let alongs = (0...alongSteps).map {
            (1 + RoundTube8SurfaceMesh.crossSectionOffset(forSample: Float($0) / Float(alongSteps))) / 2
                * bundle.lengthInCycles
        }
        let acrosses = (0...acrossSteps).map {
            RoundTube8SurfaceMesh.crossSectionOffset(forSample: Float($0) / Float(acrossSteps))
        }
        func bracket(_ values: [Float], _ value: Float) -> (Int, Float) {
            for index in 0..<(values.count - 1) where value <= values[index + 1] {
                let span = values[index + 1] - values[index]
                return (index, span > 0 ? (value - values[index]) / span : 0)
            }
            return (values.count - 2, 1)
        }
        let (i, u) = bracket(alongs, cycles)
        let (j, v) = bracket(acrosses, across)
        func at(_ i: Int, _ j: Int) -> Float { bundle.standingFraction(atCycles: alongs[i], across: acrosses[j]) }
        return (1 - u) * ((1 - v) * at(i, j) + v * at(i, j + 1)) + u * ((1 - v) * at(i + 1, j) + v * at(i + 1, j + 1))
    }

    /// Where a place lies on a run: cycles past its arrival, and across its
    /// width (-1...1).
    private func place(
        of run: RoundTube8StandingRun, in drawn: RoundTube8SurfacePattern, turns: Float, along: Float
    ) -> (cycles: Float, across: Float) {
        let segment = drawn.surface.segments[run.segment]
        let cycles = (along - Float(run.repeatOffset) - segment.centerlineStart.y)
            / (segment.centerlineEnd.y - segment.centerlineStart.y)
        let bundle = RoundTube8Bundle.standard
        let centre = segment.centerlineStart.x * 8
            + bundle.leanInColumns(atCycles: cycles, direction: drawn.leanDirection)
        var offset = (turns * 8 - centre).truncatingRemainder(dividingBy: 8)
        if offset > 4 { offset -= 8 }
        if offset < -4 { offset += 8 }
        return (cycles, offset / bundle.halfWidthInColumns(atCycles: cycles))
    }

    /// **The card is the braid seen from outside**: round the braid runs up the
    /// card, as it runs up the front of the solid, and the front of the solid —
    /// `turns` 0, facing the camera — is across the middle of the card. Along
    /// the braid runs to the right on both. So a run that leans one way on the
    /// solid leans the same way on the card.
    @Test func theCardRunsRoundTheBraidUpItsFaceWithTheFrontInTheMiddle() throws {
        let rows = 256
        #expect(abs(RoundTube8CardImage.turns(atRow: Float(rows) / 2 - 0.5, rows: rows)) < 1e-6)
        #expect(RoundTube8CardImage.turns(atRow: 10, rows: rows)
                > RoundTube8CardImage.turns(atRow: 11, rows: rows))

        // On the solid, going along the braid (to the right) a run's crest moves
        // round it by the lean; seen from the front, more turns is further up.
        // On the card the same run's crest has to move up too, for S and Z alike.
        for recipe in [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe] {
            let drawn = try pattern(recipe)
            let mesh = try #require(RoundTube8SurfaceMesh.generate(pattern: drawn))
            let segment = drawn.surface.segments[0]
            func crest(_ cycles: Float) -> SIMD3<Float> {
                RoundTube8SurfaceMesh.frame(
                    of: segment, cycles: cycles, across: 0, leanDirection: drawn.leanDirection,
                    floor: mesh.valleyFloorRadius, radius: mesh.crestRadius,
                    base: 0, repeatLength: mesh.patternRepeatLength
                ).position
            }
            // How far round the braid the crest moved. At the front of the solid
            // (angle 0, facing the camera) more angle is further up the screen,
            // `+y` (`BraidOrientationTests`): y = r sin(angle).
            func angle(_ point: SIMD3<Float>) -> Float { atan2(point.y, point.z) }
            let upOnTheSolid = angle(crest(0.8)) - angle(crest(0.2))
            #expect(sin(Float(0.01)) > 0)
            let map = RoundTube8CardImage.shownMap(for: drawn)
            func row(ofTurns turns: Float) -> Float {
                (0.5 - turns) * Float(map.height) - 0.5
            }
            let rowBefore = row(ofTurns: segment.centerlineStart.x + RoundTube8Bundle.standard
                .leanInColumns(atCycles: 0.2, direction: drawn.leanDirection) / 8)
            let rowAfter = row(ofTurns: segment.centerlineStart.x + RoundTube8Bundle.standard
                .leanInColumns(atCycles: 0.8, direction: drawn.leanDirection) / 8)
            let upOnTheCard = rowBefore - rowAfter      // rows count down the card
            #expect(upOnTheSolid * upOnTheCard > 0, "\(recipe.id): solid \(upOnTheSolid), card \(upOnTheCard)")
        }
    }

    // MARK: - Task 046: the floor, and where a run ends

    /// **The floor hardly shows** (Task 046), read the way the task asks: the
    /// outermost surface on rays out from the axis over one whole repeat, run or
    /// floor, on the real mesh — not dark pixels. It was 3.64% of the surface
    /// with a run widest just after its arrival and one column at most (Task
    /// 045); 1.78% with a lens of the same width; 0.32% with the lens's belly let
    /// show a little wider than its column, which is what ships. The bound is a
    /// guard against the floor coming back, not a target of zero.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func theFloorHardlyShows(recipe: BraidRecipe) throws {
        let drawn = try pattern(recipe)
        let mesh = try #require(RoundTube8SurfaceMesh.generate(pattern: drawn))
        let solid = Solid(mesh: mesh, cells: drawn.surface.segments.count)
        var floor = 0, runs = 0
        for row in 0..<128 {
            for column in 0..<128 {
                let turns = (Float(row) + 0.5) / 128
                let along = (Float(column) + 0.5) / 128
                let home: Float = along < 0.5 ? 1 : 0
                let seen = try #require(solid.outermost(x: x(mesh, along: home + along), turns: turns))
                switch seen.part {
                case .beneath: floor += 1
                case .run: runs += 1
                }
            }
        }
        #expect(Double(floor) / Double(floor + runs) < 0.01, "floor at \(floor) of \(floor + runs)")
    }

    /// **A run ends beneath another run** (Task 046): near its tip, along its
    /// crest, what the solid shows is some other thread's run — read off the real
    /// mesh, whichever run that is, not assumed to be the next one at its place.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func aRunEndsBeneathAnotherRun(recipe: BraidRecipe) throws {
        let drawn = try pattern(recipe)
        let mesh = try #require(RoundTube8SurfaceMesh.generate(pattern: drawn))
        let solid = Solid(mesh: mesh, cells: drawn.surface.segments.count)
        let bundle = RoundTube8Bundle.standard
        var checked = 0
        var coveredBy = [String: Int]()
        for (index, segment) in drawn.surface.segments.enumerated() {
            for cycles in [bundle.lengthInCycles - 0.2, bundle.lengthInCycles - 0.05] {
                let crest = RoundTube8SurfaceMesh.frame(
                    of: segment, cycles: cycles, across: 0, leanDirection: drawn.leanDirection,
                    floor: mesh.valleyFloorRadius, radius: mesh.crestRadius,
                    base: -mesh.length / 2, repeatLength: mesh.patternRepeatLength
                ).position
                // Only where the tile holds everything that reaches this far.
                guard abs(crest.x) < mesh.patternRepeatLength / 2 else { continue }
                let seen = try #require(solid.outermost(x: crest.x, turns: atan2(crest.y, crest.z) / (2 * .pi)))
                guard case let .run(_, other) = seen.part else {
                    Issue.record("run \(index) ends over the floor at \(cycles)")
                    continue
                }
                #expect(other != index, "run \(index) still shows at \(cycles) cycles")
                let lane = { (i: Int) in Int((drawn.surface.segments[i].centerlineStart.x * 8).rounded(.down)) }
                coveredBy[lane(other) == lane(index) ? "same lane" : "another lane", default: 0] += 1
                checked += 1
            }
        }
        #expect(checked > 20)
        // Both kinds of cover happen: the next thread at its place, and a run
        // leaning in from beside.
        #expect(coveredBy.count >= 1)
    }
}
