import Foundation
import simd
import Testing
@testable import Kumihimo

/// **Which way round, at each of the four places a braid passes through on its
/// way to the screen** (the author's ruling of 2026-09-11, Task 032 (1)).
///
/// "Seen from above" means what it means at the stand: from the braiding point,
/// looking down the braid, where the braider stands. Every sign here is said that
/// one way, so that a mirror anywhere in the chain shows as one place that
/// disagrees with the others rather than as a picture that looks wrong at the end.
@MainActor
struct BraidOrientationTests {
    private var stand: BraidStand { BraidMethodCatalog.stand8 }

    /// The turn from `a` to `b` round the origin, as the plane's own viewer sees
    /// it: positive is anticlockwise.
    private static func turn(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        a.x * b.y - a.y * b.x
    }

    // MARK: - 1. The table

    /// **The table carries S anticlockwise and Z clockwise, seen from above** —
    /// what book A's text says of the two. The stand's own drawing is seen from
    /// above, north up and east to the right, and numbers its positions clockwise
    /// (`docs/architecture.md`: 位置番号は上から見て時計回り).
    @Test func theTableCarriesSAnticlockwiseAndZClockwiseSeenFromAbove() throws {
        let one = try #require(stand.position(withID: 1)).point
        let two = try #require(stand.position(withID: 2)).point
        #expect(Self.turn(one, two) < 0, "the stand numbers clockwise seen from above")

        for (recipe, anticlockwise) in [
            (BraidMethodCatalog.yatsuKongoS8Recipe, true),
            (BraidMethodCatalog.yatsuKongoZ8Recipe, false),
        ] {
            let worked = try #require(recipe.worked(on: stand))
            for step in worked.method.steps {
                for move in step.moves {
                    let from = try #require(stand.position(withID: move.from)).point
                    let to = try #require(stand.position(withID: move.to)).point
                    #expect((Self.turn(from, to) > 0) == anticlockwise, "\(recipe.id): \(move)")
                }
            }
        }
    }

    // MARK: - 2. The occupancy history

    /// **The ring is the stand's rim, taken the same way round, and a thread goes
    /// round it the way the table sends it**: three slots back a cycle, which is
    /// anticlockwise seen from above. Nothing here turns the ring over.
    @Test func theOccupancyKeepsTheRimAndTheTablesWayRound() throws {
        let worked = try #require(BraidMethodCatalog.yatsuKongoS8Recipe.worked(on: stand))
        #expect(worked.section.order == stand.positionIDs)
        let derivation = try #require(BraidDerivation.derive(
            stand: stand, method: worked.method, crossSection: worked.section
        ))
        for course in derivation.courses {
            for row in 0..<derivation.repeatCycleCount {
                let step = RoundTube8SurfacePatternGenerator.shortestWayRound(
                    from: course.slots[row], to: course.slots[row + 1], around: 8
                )
                #expect(step == -3, "thread \(course.threadPosition), cycle \(row)")
            }
        }
    }

    // MARK: - 3. The drawer

    /// **Seen from the braiding point, the drawer puts the slots round the tube
    /// the way the stand puts the positions: clockwise.**
    ///
    /// Later cycles are made nearer the braiding point and the finished braid is
    /// pushed down away from it, so the braiding point is the end of the tile the
    /// rows run towards. Looking back down the braid from there, along `-x`, `+y`
    /// is to the right and `+z` is up.
    @Test func theDrawerPutsTheSlotsRoundTheTubeTheWayTheStandDoes() throws {
        let recipe = BraidMethodCatalog.yatsuKongoS8Recipe
        let worked = try #require(recipe.worked(on: stand))
        let pattern = try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, method: worked.method, crossSection: worked.section,
            assignments: recipe.colouring
        ))
        let mesh = try #require(RoundTube8SurfaceMesh.generate(pattern: pattern))

        func crest(slot: Int, row: Int) throws -> SIMD3<Float> {
            let middle = (Float(slot) + 0.5) / 8
            let height = (Float(row) + 0.5) / Float(pattern.rowCount)
            let cell = try #require(pattern.surface.segments.first {
                abs($0.centerlineStart.x - middle) < 1e-4
                    && $0.centerlineStart.y <= height && $0.centerlineEnd.y >= height
            })
            let along = (height - cell.centerlineStart.y)
                / (cell.centerlineEnd.y - cell.centerlineStart.y)
            return RoundTube8SurfaceMesh.frame(
                of: cell, along: along, across: 0,
                floor: mesh.valleyFloorRadius, radius: mesh.crestRadius,
                base: -mesh.length / 2, repeatLength: mesh.patternRepeatLength
            ).position
        }

        #expect(try crest(slot: 0, row: 1).x > crest(slot: 0, row: 0).x,
                "the rows run towards +x, so the braiding point is at +x")

        let first = try crest(slot: 0, row: 0)
        let second = try crest(slot: 1, row: 0)
        let seen = Self.turn(SIMD2(Double(first.y), Double(first.z)),
                             SIMD2(Double(second.y), Double(second.z)))
        #expect(seen < 0, "slot 0 to slot 1 turns \(seen > 0 ? "anticlockwise" : "clockwise") seen from the braiding point; the stand numbers clockwise")
    }

    /// **The shading normal comes out of the surface's own frame, never turned
    /// round afterwards.** A frame whose `tangent x bitangent` points into the
    /// braid is a ring strung the wrong way round.
    @Test func theNormalIsNeverTurnedRoundAfterTheFact() throws {
        let recipe = BraidMethodCatalog.yatsuKongoS8Recipe
        let worked = try #require(recipe.worked(on: stand))
        let pattern = try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, method: worked.method, crossSection: worked.section,
            assignments: recipe.colouring
        ))
        let mesh = try #require(RoundTube8SurfaceMesh.generate(pattern: pattern))
        var turnedRound = 0
        for index in mesh.positions.indices
        where dot(cross(mesh.tangents[index], mesh.bitangents[index]), mesh.normals[index]) < 0 {
            turnedRound += 1
        }
        #expect(turnedRound == 0, "turned round at \(turnedRound) of \(mesh.positions.count) vertices")
    }

    // MARK: - 4. The scene, and the sheet

    /// **Neither the scene nor the comparison sheet is a mirror.** RealityKit is
    /// right-handed and the camera stands on `+z` looking at the origin with `+y`
    /// up, so `+x` is to the right; the sheet's painter frame has right x down =
    /// the way it looks, which is an ordinary camera's.
    @Test func theSceneAndTheSheetAreNotMirrors() {
        let eye = SIMD3<Float>(0, 0, BraidSurfaceScene.cameraDistance)
        let forward = simd_normalize(-eye)
        let up = SIMD3<Float>(0, 1, 0)
        let right = cross(forward, up)
        #expect(simd_distance(right, SIMD3(1, 0, 0)) < 1e-6)
        #expect(simd_distance(cross(right, up), -forward) < 1e-6)

        let frame = BraidPicture.frame(looking: BraidComparisonSheet.camera(turned: false))
        #expect(simd_distance(cross(frame.u, frame.v), frame.n) < 1e-9)
    }

    // MARK: - Every drawer: a closed tube winds outward

    /// **Seen from outside, every triangle of a closed braid winds the same way**:
    /// `cross(b - a, c - a)` points away from the axis. A triangle wound the other
    /// way is a back face from outside and is not drawn, which is what let the
    /// near side of the eight-thread braid be seen through.
    ///
    /// **A wall that seals a crossing is judged only for not facing inward.** It
    /// stands across the braid, so it is edge-on to the axis by construction and
    /// the radial test cannot say which way it winds.
    ///
    /// **The flat braid does not pass** (found 2026-09-11, Task 032): some ten
    /// thousand of its triangles face inward. It is recorded here as a known issue
    /// and not touched (the author's ruling): a camera that discards back faces
    /// still finds no hole in it (`aCameraThatDiscardsBackFacesFindsNoHole`),
    /// because every inward triangle lies behind one turned the right way.
    @Test(arguments: ["flat sixteen", "round sixteen", "round eight"])
    func everyTriangleFacesOutward(drawer: String) throws {
        let mesh = try Self.mesh(drawer)
        var inward = 0
        var edgeOn = 0
        var edgeOnWalls = 0
        var total = 0
        var inwardWhere = [String: Int]()
        for (triangle, corner) in stride(from: 0, to: mesh.indices.count - 2, by: 3).enumerated() {
            let a = mesh.positions[Int(mesh.indices[corner])]
            let b = mesh.positions[Int(mesh.indices[corner + 1])]
            let c = mesh.positions[Int(mesh.indices[corner + 2])]
            let facing = cross(b - a, c - a)
            let middle = (a + b + c) / 3
            let out = SIMD3<Float>(0, middle.y, middle.z)
            guard simd_length(facing) > 1e-12, simd_length(out) > 1e-9 else { continue }
            total += 1
            // How squarely it faces away from the axis: 1 straight out, -1 straight in.
            let square = dot(simd_normalize(facing), simd_normalize(out))
            guard square <= 0 else { continue }
            if square < -0.01 {
                inward += 1
                inwardWhere[mesh.labels?[triangle] ?? "surface", default: 0] += 1
            } else if mesh.walls?[triangle] == true {
                edgeOnWalls += 1
            } else {
                edgeOn += 1
            }
        }
        let places = inwardWhere.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }
            .joined(separator: ", ")
        let summary = "\(drawer): \(inward) inward [\(places)], \(edgeOn) edge-on, "
            + "\(edgeOnWalls) edge-on crossing walls, of \(total) triangles"
        #expect(total > 0)
        if drawer == "flat sixteen" {
            // The numbers go in the known issue's own title, because that is what
            // a result bundle keeps of it.
            withKnownIssue("the flat braid has triangles wound inward (Task 032, 2026-09-11): \(summary)") {
                #expect(inward + edgeOn == 0, "\(summary)")
            }
        } else {
            #expect(inward + edgeOn == 0, "\(summary)")
        }
    }

    // MARK: - The same four places, for maru-genji (recorded; nothing drawn moves)

    /// **Maru-genji at the four places** (the author, 2026-09-11). **Recorded and
    /// stopped there**: no vertex of its drawing moves because of this.
    ///
    /// - **The table** sends its threads both ways round the stand: of the steps
    ///   the threads take in one repeat, sixteen each are -6, -1, +1 and +6 slots.
    ///   There is no one way round to compare.
    /// - **The occupancy history** keeps the stand's rim order. Its columns are the
    ///   landing slots 0, 3, 4, 7, 8, 11, 12 and 15, in ring order.
    /// - **The drawer** runs every column's rows against the cycles, all at the same
    ///   offset, so its braiding point is at `-x`; and drawn column `k` holds column
    ///   `4 - k` of the history — **a reflection of the ring**, which fits every
    ///   column, where no turn of it fits. Its ring is `(cos, sin)`, which seen from
    ///   `-x` goes round clockwise, so the history's columns go round it
    ///   anticlockwise: **seen from the braiding point, maru-genji is drawn as the
    ///   mirror of what its table works out.** This is the same mirror as the
    ///   "agreement through a mirror" with Task 004 (`BraidTubeFigureTests`).
    /// - **The scene** is the same one as every braid's, and not a mirror (above).
    ///
    /// **Which of the two is the real braid needs a source from outside.** Book A
    /// p94's photograph shows the twist stripes with a direction (Task 005G), and
    /// that may decide it.
    @Test func maruGenjiAtTheFourPlaces() throws {
        let stand = BraidMethodCatalog.stand16
        let recipe = BraidMethodCatalog.maruGenji16Recipe
        let worked = try #require(recipe.worked(on: stand))

        var steps = [Int: Int]()
        for course in worked.derivation.courses {
            for row in 0..<worked.derivation.repeatCycleCount {
                let step = RoundTube8SurfacePatternGenerator.shortestWayRound(
                    from: course.slots[row], to: course.slots[row + 1], around: 16
                )
                steps[step, default: 0] += 1
            }
        }
        #expect(steps == [-6: 16, -1: 16, 1: 16, 6: 16])

        #expect(worked.section.order == stand.positionIDs)
        let occupancy = try #require(BraidOccupancy.history(
            of: worked.method, on: stand, crossSection: worked.section, cycles: 4
        ))
        let columns = try #require(occupancy.columns(.landing))
        #expect(columns == [0, 3, 4, 7, 8, 11, 12, 15])
        let grid = try #require(occupancy.grid(atColumns: columns, rows: 4))

        var drawn = [[Int]: Int]()
        for strand in RoundTube16SurfacePatternGenerator.sourceStrands {
            for diamond in strand.diamonds {
                let cell = try #require(RoundTube16SurfacePatternGenerator.cell(for: diamond))
                drawn[[cell.column, cell.row]] = strand.threadPosition
            }
        }
        func run(ofDrawnColumn column: Int) -> [Int] {
            (1...4).compactMap { drawn[[column, $0]] }
        }
        func history(_ other: Int, shift: Int, upwards: Bool) -> [Int] {
            (0..<4).map { step in grid[((shift + (upwards ? step : -step)) % 4 + 4) % 4][other] }
        }
        func holds(_ column: Int, _ other: Int, upwards: Bool) -> Bool {
            (0..<4).contains { history(other, shift: $0, upwards: upwards) == run(ofDrawnColumn: column) }
        }

        for column in 0..<8 {
            // Every drawn column runs against the cycles, and none with them.
            #expect(!(0..<8).contains { holds(column, $0, upwards: true) }, "column \(column)")
            // Drawn column k holds history column 4 - k, two cycles on.
            #expect(history(((4 - column) % 8 + 8) % 8, shift: 2, upwards: false)
                    == run(ofDrawnColumn: column), "column \(column)")
        }
        // And no turn of the ring fits every column.
        for turn in 0..<8 {
            #expect((0..<8).contains { !holds($0, (turn + $0) % 8, upwards: false) }, "turn \(turn)")
        }
    }

    // MARK: - A camera that discards back faces

    /// **No braid shows a hole to a camera that discards back faces**, from any of
    /// four sides (the author, 2026-09-11). RealityKit's materials discard back
    /// faces by default and nothing here changes that — it is what let the
    /// eight-thread braid be seen through — so this is the view the app draws.
    ///
    /// **The flat braid passes although some ten thousand of its triangles wind
    /// inward** (`everyTriangleFacesOutward`): every one of them lies behind a face
    /// turned the right way, on every line of sight. **Not because its material is
    /// two-sided; it is not.** That is why the inward winding is left as a known
    /// issue rather than made a task of its own.
    ///
    /// **The check can see what it looks for**: the eight-thread braid with its
    /// winding turned round, as it was until Task 032, shows something behind the
    /// near surface on nearly every line of sight.
    @Test func aCameraThatDiscardsBackFacesFindsNoHole() throws {
        let sides = [SIMD3<Float>(0, 0, -1), SIMD3(0, 0, 1), SIMD3(0, -1, 0), SIMD3(0, 1, 0)]
        for drawer in ["flat sixteen", "round eight"] {
            let mesh = try Self.mesh(drawer)
            let tileEnd = mesh.positions.map { abs($0.x) }.max() ?? 0
            for look in sides {
                let view = CulledView(positions: mesh.positions, indices: mesh.indices,
                                      tileEndX: tileEnd, looking: look)
                #expect(view.rays > 5_000)
                #expect(view.background == 0 && view.deeper == 0,
                        "\(drawer) looking \(look): \(view.background) background, \(view.deeper) behind, of \(view.rays)")
            }
        }

        let eight = try Self.mesh("round eight")
        var turnedRound = eight.indices
        for corner in stride(from: 0, to: turnedRound.count - 2, by: 3) {
            turnedRound.swapAt(corner + 1, corner + 2)
        }
        let control = CulledView(positions: eight.positions, indices: turnedRound,
                                 tileEndX: eight.positions.map { abs($0.x) }.max() ?? 0,
                                 looking: SIMD3(0, 0, -1))
        #expect(control.background + control.deeper > control.rays * 9 / 10)
    }

    /// What a camera that discards every face turned away from it sees, line of
    /// sight by line of sight across the braid.
    private struct CulledView {
        let rays: Int
        /// No face turned towards the eye anywhere along the line: the background shows.
        let background: Int
        /// The nearest surface is turned away, so something behind it shows instead.
        let deeper: Int

        private struct Flat {
            let a: SIMD2<Float>
            let b: SIMD2<Float>
            let c: SIMD2<Float>
            let depth: SIMD3<Float>
            let facesTheEye: Bool
            var lowX: Float { min(a.x, b.x, c.x) }
            var highX: Float { max(a.x, b.x, c.x) }
        }

        init(positions: [SIMD3<Float>], indices: [UInt32], tileEndX: Float,
             looking: SIMD3<Float>, alongSteps: Int = 120, acrossSteps: Int = 48) {
            let look = simd_normalize(looking)
            let side = simd_normalize(cross(SIMD3<Float>(1, 0, 0), look))
            // The two ends of the tile are open by design, so stay clear of them.
            let low = -tileEndX * 0.85
            let span = tileEndX * 1.7
            var bins = [[Flat]](repeating: [], count: alongSteps)
            for corner in stride(from: 0, to: indices.count - 2, by: 3) {
                let p = [positions[Int(indices[corner])], positions[Int(indices[corner + 1])],
                         positions[Int(indices[corner + 2])]]
                let facing = cross(p[1] - p[0], p[2] - p[0])
                guard simd_length(facing) > 1e-12 else { continue }
                let flat = Flat(
                    a: SIMD2(p[0].x, dot(p[0], side)), b: SIMD2(p[1].x, dot(p[1], side)),
                    c: SIMD2(p[2].x, dot(p[2], side)),
                    depth: SIMD3(dot(p[0], look), dot(p[1], look), dot(p[2], look)),
                    facesTheEye: dot(facing, look) < 0
                )
                let first = max(0, Int(((flat.lowX - low) / span * Float(alongSteps)).rounded(.down)))
                let last = min(alongSteps - 1,
                               Int(((flat.highX - low) / span * Float(alongSteps)).rounded(.down)))
                guard first <= last else { continue }
                for bin in first...last { bins[bin].append(flat) }
            }
            var rays = 0
            var background = 0
            var deeper = 0
            for bin in 0..<alongSteps {
                let x = low + span * (Float(bin) + 0.381_966) / Float(alongSteps)
                let here = bins[bin].filter { $0.lowX <= x && $0.highX >= x }
                guard !here.isEmpty else { continue }
                let sides = here.flatMap { [$0.a.y, $0.b.y, $0.c.y] }
                guard let bottom = sides.min(), let top = sides.max() else { continue }
                let margin = (top - bottom) * 0.04
                guard top - bottom > 2 * margin else { continue }
                for step in 0..<acrossSteps {
                    let s = bottom + margin + (top - bottom - 2 * margin)
                        * (Float(step) + 0.618_034) / Float(acrossSteps)
                    var nearest = Float.infinity
                    var nearestFacing = Float.infinity
                    var nearestIsFacing = false
                    for flat in here {
                        let one = flat.b - flat.a
                        let two = flat.c - flat.a
                        let point = SIMD2(x, s) - flat.a
                        let det = one.x * two.y - two.x * one.y
                        guard abs(det) > 1e-12 else { continue }
                        let u = (point.x * two.y - two.x * point.y) / det
                        let v = (one.x * point.y - point.x * one.y) / det
                        guard u >= 0, v >= 0, u + v <= 1 else { continue }
                        let depth = flat.depth.x * (1 - u - v) + flat.depth.y * u + flat.depth.z * v
                        if depth < nearest {
                            nearest = depth
                            nearestIsFacing = flat.facesTheEye
                        }
                        if flat.facesTheEye { nearestFacing = min(nearestFacing, depth) }
                    }
                    guard nearest.isFinite else { continue }
                    rays += 1
                    if !nearestFacing.isFinite {
                        background += 1
                    } else if !nearestIsFacing && nearest < nearestFacing - 1e-4 {
                        deeper += 1
                    }
                }
            }
            self.rays = rays
            self.background = background
            self.deeper = deeper
        }
    }

    private struct Mesh {
        let positions: [SIMD3<Float>]
        let indices: [UInt32]
        /// Per triangle: a wall that seals a crossing. Only one drawer has walls.
        let walls: [Bool]?
        /// Per triangle: where on the braid it is, for saying where a fault lies.
        let labels: [String]?
    }

    private static func mesh(_ drawer: String) throws -> Mesh {
        switch drawer {
        case "flat sixteen":
            let pattern = try #require(Flat16SurfacePatternGenerator.generate(
                assignments: BraidMethodCatalog.hiraGenji16Colouring))
            let mesh = try #require(Flat16SurfaceMesh.generate(pattern: pattern))
            var indices = [UInt32]()
            var labels = [String]()
            for (groups, band) in [(mesh.colorGroups, ""), (mesh.boundaryColorGroups, " band")] {
                for group in groups.values {
                    indices += group
                    for corner in stride(from: 0, to: group.count - 2, by: 3) {
                        let vertex = Int(group[corner])
                        let region = mesh.surfaceVertexRegions.indices.contains(vertex)
                            ? "\(mesh.surfaceVertexRegions[vertex])" : "?"
                        labels.append(region + band)
                    }
                }
            }
            return Mesh(positions: mesh.positions, indices: indices, walls: nil, labels: labels)
        case "round sixteen":
            let pattern = try #require(RoundTube16SurfacePatternGenerator.generate(
                assignments: BraidMethodCatalog.maruGenji16Colouring))
            let mesh = try #require(RoundTube16SurfaceMesh.generate(pattern: pattern))
            // Every triangle of this drawer has vertices of its own, so a
            // triangle is a wall when its first vertex is.
            let indices = mesh.materialGroups.values.flatMap { $0 }
            let walls = stride(from: 0, to: indices.count - 2, by: 3).map {
                mesh.vertexIsCrossingWall[Int(indices[$0])]
            }
            return Mesh(positions: mesh.positions, indices: indices, walls: walls, labels: nil)
        default:
            let stand = BraidMethodCatalog.stand8
            let recipe = BraidMethodCatalog.yatsuKongoS8Recipe
            let worked = try #require(recipe.worked(on: stand))
            let pattern = try #require(RoundTube8SurfacePatternGenerator.generate(
                stand: stand, method: worked.method, crossSection: worked.section,
                assignments: recipe.colouring
            ))
            let mesh = try #require(RoundTube8SurfaceMesh.generate(pattern: pattern))
            return Mesh(positions: mesh.positions, indices: mesh.allTriangleIndices,
                        walls: nil, labels: nil)
        }
    }
}
