import CoreGraphics
import Foundation
import simd
import Testing
@testable import Kumihimo

/// Task 031: the drawer for a tube of eight threads.
///
/// **The first drawer whose cells are not copied from a printed figure.** There
/// is no cell drawing for the eight-bobbin braids, so the shape of a cell comes
/// from the cross-section (eight places round a ring), the measured pitch (how
/// long a cycle is), and the move table (how far a cell leans). These tests hold
/// that up.
@MainActor
struct RoundTube8SurfaceTests {

    private var stand: BraidStand { BraidMethodCatalog.stand8 }

    private func pattern(
        _ recipe: BraidRecipe,
        assignments: [ThreadAssignment]? = nil
    ) throws -> RoundTube8SurfacePattern {
        let worked = try #require(recipe.worked(on: stand))
        return try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, method: worked.method, crossSection: worked.section,
            assignments: assignments ?? recipe.colouring
        ))
    }

    private func mesh(_ recipe: BraidRecipe) throws -> RoundTube8SurfaceMeshData {
        try #require(RoundTube8SurfaceMesh.generate(pattern: pattern(recipe)))
    }

    // MARK: - 1. The face agrees with the figure

    /// **The colours of the solid are the colours of the figure, cell for cell.**
    /// Both read the occupancy history and neither reads the other, so this is the
    /// guard on Task 025-4's ruling that the face's colour comes from what is
    /// resting at a place.
    ///
    /// A cell is read at the row boundary the figure's own row is taken at. A
    /// cell begins where its thread arrives, part way through the cycle before,
    /// so the cell standing at a place across that boundary is the row's.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func theSolidsCellsCarryTheSameColoursAsTheFigure(recipe: BraidRecipe) throws {
        let colouring = BraidReferenceColourings.yatsuKongoChecker
        let drawn = try pattern(recipe, assignments: colouring)

        guard case let .tube(figure) = BraidPatternForRecipe.figure(
            for: recipe, assignments: colouring, repeats: 1
        ) else {
            Issue.record("八つ金剛の模様図は筒として描けるはずです")
            return
        }
        #expect(figure.columns.count == 8)
        #expect(figure.rowCount == drawn.rowCount)

        for row in 0..<drawn.rowCount {
            for place in 0..<8 {
                let shape = try #require(figure.appearance(atColumn: place, row: row))
                // **The figure is by place on the stand, and so is the solid**
                // since Task 053: a column is a place (the drawing no longer
                // turns the braid a column a cycle).
                let column = place
                let middle = (Float(column) + 0.5) / 8
                let along = Float(row) / Float(drawn.rowCount)
                let cell = try #require(drawn.surface.segments.first {
                    abs($0.centerlineStart.x - middle) < 1e-4
                        && $0.centerlineStart.y <= along + 1e-4
                        && $0.centerlineEnd.y > along + 1e-4
                })
                #expect(cell.centerlineEnd.x == cell.centerlineStart.x)
                #expect(cell.colorID == shape.colorID, "row \(row), place \(place)")
                #expect(cell.threadPosition == shape.threadPosition)
            }
        }
    }

    // MARK: - 2. S and Z are mirrors

    /// **Mirroring Z gives S.** Reflecting the braid in a plane through its axis
    /// turns one into the other, and it is checked on the vertices themselves:
    /// the same number of them, and the same set of positions once one is
    /// reflected.
    ///
    /// The reflection used is the one the tables are mirrors under — position `p`
    /// to `9 - p` round the stand — which on the drawn tube is the angle `a` going
    /// to `-a` plus the turn that lines the two numberings up.
    @Test func theZBraidIsTheMirrorOfTheSBraid() throws {
        let s = try mesh(BraidMethodCatalog.yatsuKongoS8Recipe)
        let z = try mesh(BraidMethodCatalog.yatsuKongoZ8Recipe)
        #expect(s.positions.count == z.positions.count)
        #expect(s.triangleCount == z.triangleCount)
        #expect(abs(s.length - z.length) < 1e-5)

        // Place p becomes place 9 - p. A place spans the angles from
        // 2*pi*(p-1)/8 to 2*pi*p/8, and negating the angle sends that span to the
        // span of 9 - p exactly — **so the mirror is simply the angle reversed**,
        // with no turn to line the two numberings up. The ring is laid out as
        // `(sin, cos)` in `y` and `z`, so reversing the angle is `y` to `-y`.
        func mirrored(_ point: SIMD3<Float>) -> SIMD3<Float> {
            SIMD3(point.x, -point.y, point.z)
        }
        // **Compared colour by colour**, which is the whole of the claim now. A
        // cell stands still, so both braids are the same eight straight lanes and
        // comparing the bare geometry would pass whatever the tables did. What
        // mirrors is *which colour is standing where*, cycle by cycle.
        func key(_ point: SIMD3<Float>) -> [Int32] {
            [Int32((point.x * 2048).rounded()),
             Int32((point.y * 2048).rounded()),
             Int32((point.z * 2048).rounded())]
        }
        func painted(_ mesh: RoundTube8SurfaceMeshData,
                     _ move: (SIMD3<Float>) -> SIMD3<Float>) -> [ThreadColorID: Set<[Int32]>] {
            var out = [ThreadColorID: Set<[Int32]>]()
            for (colour, indices) in mesh.colorGroups {
                out[colour] = Set(indices.map { key(move(mesh.positions[Int($0)])) })
            }
            return out
        }
        let mine = painted(s) { $0 }
        let theirs = painted(z, mirrored)
        #expect(!mine.isEmpty)
        #expect(Set(mine.keys) == Set(theirs.keys))
        // **Within one step of the grid, not on it.** A point that falls on a
        // grid line in one braid can round to the next cell in the other; the
        // mirror is only exact to the last bit of a float. So every point must
        // have a match in its own cell or a neighbouring one, both ways round.
        func matched(_ places: Set<[Int32]>, in other: Set<[Int32]>) -> Int {
            places.filter { key in
                !(-1...1).contains { dx in (-1...1).contains { dy in (-1...1).contains { dz in
                    other.contains([key[0] + Int32(dx), key[1] + Int32(dy), key[2] + Int32(dz)])
                } } }
            }.count
        }
        for (colour, places) in mine {
            let other = theirs[colour] ?? []
            #expect(matched(places, in: other) == 0, "\(colour.rawValue): S points with no Z point")
            #expect(matched(other, in: places) == 0, "\(colour.rawValue): Z points with no S point")
            #expect(abs(places.count - other.count) <= places.count / 100)
        }
    }

    // MARK: - 3. One repeat closes

    /// **The tile repeats itself exactly, and has no end face.**
    ///
    /// A thread's run reaches past both ends of its repeat — its thread arrived
    /// part way through the cycle before, and it goes on beneath the next thread
    /// for most of a cycle more — so the tile's ends are not flat. What lets tiles
    /// be laid end to end with neither a cap nor a gap between is that **every
    /// repeat is the one before moved one repeat along**, vertex for vertex,
    /// texture included: whatever hangs past one end is met by what the next tile
    /// hangs back. And **beneath every lane, the cells lie end to end for exactly
    /// the tile's length**, so the tube is closed under the runs.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func oneRepeatClosesAndMakesNoEndFace(recipe: BraidRecipe) throws {
        let drawn = try pattern(recipe)
        let mesh = try mesh(recipe)
        let cells = drawn.surface.segments.count
        #expect(mesh.runVertexRanges.count == cells * mesh.patternRepeatCount)
        #expect(mesh.patternRepeatCount >= 2)
        let shift = SIMD3<Float>(mesh.patternRepeatLength, 0, 0)
        for cell in 0..<cells {
            for ranges in [mesh.runVertexRanges, mesh.beneathVertexRanges] {
                let here = ranges[cell]
                let next = ranges[cells + cell]
                #expect(here.count == next.count)
                for (mine, theirs) in zip(here, next) {
                    #expect(simd_distance(mesh.positions[mine] + shift, mesh.positions[theirs]) < 1e-4,
                            "cell \(cell)")
                    #expect(mesh.textureCoordinates[mine] == mesh.textureCoordinates[theirs])
                }
            }
        }

        // Beneath: in every lane, the cells lie end to end over the tile.
        for lane in 0..<8 {
            var spans = [(Float, Float)]()
            for repeatIndex in 0..<mesh.patternRepeatCount {
                for (index, segment) in drawn.surface.segments.enumerated()
                where Int((segment.centerlineStart.x * 8).rounded(.down)) == lane {
                    let xs = mesh.beneathVertexRanges[repeatIndex * cells + index]
                        .map { mesh.positions[$0].x }
                    spans.append((try #require(xs.min()), try #require(xs.max())))
                }
            }
            spans.sort { $0.0 < $1.0 }
            for (earlier, later) in zip(spans, spans.dropFirst()) {
                #expect(abs(earlier.1 - later.0) < 1e-4, "lane \(lane) has a gap or an overlap beneath")
            }
            let covered = (spans.last?.1 ?? 0) - (spans.first?.0 ?? 0)
            #expect(abs(covered - mesh.length) < 1e-4, "lane \(lane)")
        }

        // No end face: no triangle stands square across the braid.
        let indices = mesh.allTriangleIndices
        var square = 0
        for triangle in stride(from: 0, to: indices.count, by: 3) {
            let xs = (0..<3).map { mesh.positions[Int(indices[triangle + $0])].x }
            if abs(xs[0] - xs[1]) < 1e-6 && abs(xs[1] - xs[2]) < 1e-6 { square += 1 }
        }
        #expect(square == 0)
    }

    // MARK: - No line runs across the whole braid

    /// **On the card, in no repeat does a cell boundary run the full height**
    /// (the author, 2026-09-11): two neighbouring lanes never have a cell end at
    /// the same place along the braid, so no boundary can line up across all
    /// eight. The arrival phase staggers them everywhere, the joins between
    /// repeats included.
    @Test func noCellBoundaryRunsTheFullHeightOfTheCard() throws {
        let drawn = try pattern(BraidMethodCatalog.yatsuKongoS8Recipe)
        let layout = try #require(UnrolledPatternThumbnailLayout(
            size: CGSize(width: 1_300, height: 208), aspectRatio: drawn.aspectRatio
        ))
        var ends = [Int: [CGFloat]]()
        for repeatIndex in layout.repeatIndices {
            for segment in drawn.surface.segments {
                let lane = Int((segment.centerlineStart.x * 8).rounded(.down))
                for along in [segment.centerlineStart.y, segment.centerlineEnd.y] {
                    ends[lane, default: []].append(layout.point(
                        surfaceCoordinate: SIMD2(segment.centerlineStart.x, along),
                        repeatIndex: repeatIndex
                    ).x)
                }
            }
        }
        for lane in 0..<8 {
            let next = (lane + 1) % 8
            let shared = (ends[lane] ?? []).filter { mine in
                (ends[next] ?? []).contains { abs($0 - mine) < 0.5 }
            }
            #expect(shared.isEmpty, "lanes \(lane) and \(next) both end a cell at \(shared.prefix(4).map { Int($0) }) pt along the card")
        }
    }

    /// **On the solid, no ring of run ends goes round the braid.** The same
    /// thing read off the mesh: where each thread's run begins and ends along the
    /// braid, and no two neighbouring lanes begin or end one at the same place.
    /// A run leans, so its ends are not square to the braid either; what is
    /// compared is where each end reaches furthest.
    @Test func noRingOfCellEndsGoesRoundTheSolid() throws {
        let drawn = try pattern(BraidMethodCatalog.yatsuKongoS8Recipe)
        let mesh = try #require(RoundTube8SurfaceMesh.generate(pattern: drawn))
        let cells = drawn.surface.segments.count
        var ends = [Int: [Float]]()
        for repeatIndex in 0..<mesh.patternRepeatCount {
            for (segmentIndex, segment) in drawn.surface.segments.enumerated() {
                let lane = Int((segment.centerlineStart.x * 8).rounded(.down))
                let xs = mesh.runVertexRanges[repeatIndex * cells + segmentIndex]
                    .map { mesh.positions[$0].x }
                ends[lane, default: []] += [xs.min() ?? 0, xs.max() ?? 0]
            }
        }
        for lane in 0..<8 {
            let next = (lane + 1) % 8
            let shared = (ends[lane] ?? []).filter { mine in
                (ends[next] ?? []).contains { abs($0 - mine) < 1e-4 }
            }
            #expect(shared.isEmpty, "lanes \(lane) and \(next) both end a run at x = \(Array(Set(shared)).sorted())")
        }
    }

    // MARK: - 4. Watertight

    /// **No line of sight inside the braid's outline reaches the background** —
    /// the invariant `BraidSurfaceWatertightnessTests` holds the round braid to,
    /// applied to this one through the same audit.
    @Test func theSurfaceIsOpaqueFromEveryLineOfSight() throws {
        let mesh = try mesh(BraidMethodCatalog.yatsuKongoS8Recipe)
        for axis in SurfaceOpacityAudit.Axis.allCases {
            let audit = SurfaceOpacityAudit(
                positions: mesh.positions,
                indices: mesh.allTriangleIndices,
                tileEndX: mesh.length / 2,
                axis: axis
            )
            #expect(audit.rays > 1_000)
            #expect(audit.raysReachingTheBackground == 0, "\(axis): \(String(describing: audit.firstGap))")
        }
    }

    // MARK: - 5. The shape is pinned

    /// **A guard on the shape moving, not a proof that it is right.** The same
    /// thing `BraidMeshHashTests` does for the other two: a hash of every vertex,
    /// so that a change to how a cell is built shows up as a failure and has to be
    /// explained rather than slipping through.
    @Test func theMeshIsTheShapeItWas() throws {
        let s = try mesh(BraidMethodCatalog.yatsuKongoS8Recipe)
        // Sixty-four cells a repeat, two repeats.
        // **Changed seven times, on purpose.** It was `0x03aa_f419_737c_1859` while a
        // cell was drawn stretched across the three places of the carry; a cell is
        // the thread standing still, so every cell is square to the braid. Then
        // `0xa2b9_f4b5_1eab_3079` while the ring was laid out as `(cos, sin)`, the
        // mirror of the stand's own `(sin, cos)` (Task 032): every vertex moved to
        // its reflection. Then `0x6834_c61f_818c_0af9` until a cell began where its
        // thread arrives (the same day). Then `0xf338_db23_dcb7_8ab5` while the
        // first row's cells were cut at the tile's edge, which put a cell boundary
        // in every lane at the same place once a repeat (Task 033): they now begin
        // in the repeat before and are drawn whole, so the count is back to 18,304.
        // Then `0x8fd5_91a2_0cdd_bf39` while a lane was one unbroken ridge: every
        // thread's end now rounds down to the valley floor where the next thread
        // at the same place begins, and the samples along a cell are packed
        // towards its ends (Task 033). Then `0x2c96_1f1d_a3f7_dad9` while that
        // groove was the ridge's own depth, borrowed from across the braid: it has
        // its own figure now, shallower, and the ends round over less of a thread's
        // half-width (the author, 2026-09-12). **The vertex count did not change.**
        // Then `0x2873_a90b_e028_6589` (18,304 vertices) while a cell was drawn
        // as a round-ended bead one column wide and one cycle long, square to the
        // braid (Task 033): it read as a cob of corn (the author, 2026-09-18). A
        // thread now shows as a run that leans the carry's way and goes on
        // beneath the next thread, 25 by 11 samples, with its own cell lying
        // beneath at the valley floor, 2 by 5 (Task 045).
        #expect(s.positions.count == 128 * (25 * 11 + 2 * 5)
                / 2)
        // Then `0xfbb4_48c0_8f4a_7fdd` while a run was widest at a shoulder just
        // after its arrival and narrowed all the way to its tip, one column at
        // most: a lens with a belly now, pointed at both ends and a little wider
        // than its column (Task 046). The vertex count did not change.
        // Then `0x94ae_7327_2c10_992d` while each place's cells began at its
        // arrival (¼, ¾, ½, 1 … of a cycle on S): they are drawn half a pitch
        // from their neighbours round the braid now (Task 048).
        // Then `0x059f_de6a_459f_8b01` while a place on the stand stayed at one
        // column of the finished braid: the braid turns a column a cycle now,
        // the cycle is twice as long, and a run is about one cycle (Task 048's
        // rework).
        // Then `0x2716_6247_a8d0_b579` before Task 049 measured the finished
        // drawing against the photograph: the belly runs further along a run,
        // the tail is shorter and the lean shallower.
        // Then `0xd757_face_7799_2ef5` while a run held one height across its
        // belly — half a cycle of it, which read as flat tiles (the author,
        // 2026-09-20): the height became a hump, and the valley between runs is
        // the drawing's own depth (Task 049's rework).
        // Then `0xcc3d_f13e_a529_f765` while that hump's crest sat before the
        // middle of the run, which read as a lopsided swelling (the author, the
        // same day): the height is an even circular arc now.
        // Then `0x4da8_5335_9b7e_b01d` while a run was a lens under an arc over
        // its whole length, and every run read as a closed oval (the author,
        // 2026-09-21): the head is blunt, the tail keeps its width, bends into
        // the next lane and goes under the runs laid after it, and the arc has
        // its own span (Task 051). The vertex count did not change.
        // Then `0x7b20_db3a_0f1e_b941` (36,480 vertices) while the table was
        // book A p.54's, which comes round in eight cycles: the disk book's comes
        // round in four, so a repeat has half the cells (Task 053). The drawing
        // turned the braid a column a cycle then and does not now; **what shows
        // on the front is pixel for pixel the same** (Task 053's record).
        #expect(BraidMeshHashTests.hash(s.positions) == 0x4ba0_4e68_e894_23ed)
    }

    // MARK: - 6. The order inside a dan does not reach the drawing

    /// **The order of the moves inside a dan must not be showing** (Task 053).
    /// The disk book and book C print the moves of a dan in different orders —
    /// which of two opposite pairs is worked first — so a drawing that depended
    /// on it would rest on which book was copied.
    ///
    /// It does not: a place's cells begin in the half of the cycle its thread
    /// arrives in, and the dan is that half whatever order its four moves come
    /// in. Nothing crosses, so there is no over and under for the order to
    /// decide. (Until Task 053 this asked the same of which thread of a printed
    /// pair went first, under book A's table.)
    @Test func swappingTheOrderInsideADanDoesNotMoveTheMesh() throws {
        let recipe = BraidMethodCatalog.yatsuKongoS8Recipe
        let worked = try #require(recipe.worked(on: stand))
        let swapped = BraidMethod(
            id: worked.method.id + "-pairs-the-other-way-round",
            standID: worked.method.standID,
            steps: swappingPairs(of: worked.method.steps),
            closing: worked.method.closing
        )
        #expect(swapped.steps.map(\.moves) != worked.method.steps.map(\.moves))

        let asIs = try mesh(recipe)
        let otherPattern = try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, method: swapped, crossSection: worked.section,
            assignments: recipe.colouring
        ))
        let otherMesh = try #require(RoundTube8SurfaceMesh.generate(pattern: otherPattern))

        #expect(otherMesh.positions.count == asIs.positions.count)
        #expect(BraidMeshHashTests.hash(otherMesh.positions)
                == BraidMeshHashTests.hash(asIs.positions))
    }

    /// The steps of one cycle with neighbouring figures of each dan swapped:
    /// the order book C prints its lines in against the disk book's.
    private func swappingPairs(of steps: [BraidStep]) -> [BraidStep] {
        var swapped = steps
        for index in stride(from: 0, to: steps.count - 1, by: 2) {
            swapped.swapAt(index, index + 1)
        }
        return swapped
    }

    // MARK: - 7. It draws no other family

    @Test func nothingButATubeOfEightIsDrawnByThisDrawer() throws {
        #expect(RoundTube8SurfaceMesh.family == .roundTube(threads: 8))
        for recipe in [BraidMethodCatalog.maruGenji16Recipe,
                       BraidMethodCatalog.hiraGenji16Recipe] {
            let sixteen = try #require(BraidMethodCatalog.stand(for: recipe))
            let worked = try #require(recipe.worked(on: sixteen))
            #expect(RoundTube8SurfacePatternGenerator.generate(
                stand: sixteen, method: worked.method,
                crossSection: worked.section, assignments: recipe.colouring
            ) == nil)
            #expect(BraidFamilyDrawing.drawer(for: recipe) != RoundTube8SurfaceMesh.family)
        }
        for recipe in [BraidMethodCatalog.yatsuKongoS8Recipe,
                       BraidMethodCatalog.yatsuKongoZ8Recipe] {
            #expect(BraidFamilyDrawing.drawer(for: recipe) == RoundTube8SurfaceMesh.family)
        }
    }

    // MARK: - What the drawing rests on

    /// **The carry is read off the courses, and it runs opposite ways for S and
    /// Z.** Neither table is told which way; each says so itself. It is not the
    /// cell's shape — the carry is buried — but it is what sends the colour round.
    @Test func theCarryComesFromTheTableAndTurnsWithIt() throws {
        let s = try pattern(BraidMethodCatalog.yatsuKongoS8Recipe)
        let z = try pattern(BraidMethodCatalog.yatsuKongoZ8Recipe)
        #expect(s.columnsCarried == -RoundTube8SurfacePatternGenerator.columnsCarriedPerCycle)
        #expect(z.columnsCarried == RoundTube8SurfacePatternGenerator.columnsCarriedPerCycle)
        #expect(s.rowCount == 4)
        // Thirty-two cells, every one whole: the first row's begin in the repeat
        // before and are drawn from there, not cut at the tile's edge. (Sixty-four
        // with book A's table, which came round in eight cycles.)
        #expect(s.surface.segments.count == 32)
    }

    /// Every number the drawing rests on says where it came from, and the one that
    /// is not settled says so.
    @Test func everyValueTheDrawingRestsOnSaysWhereItCameFrom() throws {
        let shape = try #require(BraidFamilyDrawing.shape(of: RoundTube8SurfaceMesh.family))
        #expect(!shape.values.isEmpty)
        #expect(shape.values.values.allSatisfy { !$0.source.origin.isEmpty })
        #expect(shape.values.values.allSatisfy { $0.agreesWithItsSpread })
        // **What is set by eye is the look, never the shape** (Task 032 stage 3):
        // the fibre stripes and the valley shading, and how big the braid is
        // drawn. None of them moves a vertex.
        #expect(shape.calibratedByEye.keys.sorted() == ([
            "a run's lean, in columns per cycle",
            "fibre stripe angle in degrees",
            "fibre stripe relief",
            "fibre stripes across a thread's width",
            "how far a run goes on beneath the next thread, in cycles",
            "how far a run stands over the valley floor, over the braid's radius",
            "how far across a cell the valley shading reaches",
            "radius on screen",
            "valley shading at a cell's edge",
            "how far a run's head is rounded, in cycles past its arrival",
            "how far a run's tail bends round the braid, in columns",
            "over how much of a run its height's arc stands, in cycles",
            "where a run's tail begins to bend, in cycles past its arrival",
            "where a run's tail begins to narrow, in cycles past its arrival",
        ] + (RoundTube8Bundle.standard.widestHalfWidthInColumns
            == RoundTube8Bundle.oneThreadHalfWidthInColumns ? [] : ["a run's widest half-width, in columns"]))
            .sorted())
        // And each of the looks says, in so many words, what it is.
        for (name, value) in shape.calibratedByEye where name != "radius on screen" {
            #expect(value.source.origin.contains("calibrated by eye against a photograph, not derived"),
                    "\(name)")
        }

        let pitch = try #require(shape.values["one cycle over the braid's diameter"])
        #expect(pitch.isObserved)
        // **The colour band does not settle the pitch**: what a measurement reads
        // off the drawn face swings with the turn of the braid, and a photograph is
        // one turn (the author, 2026-09-11). Every number is kept.
        let pitchNote = try #require(pitch.unsettled)
        #expect(pitchNote.contains("0.403") && pitchNote.contains("54.5"))
        #expect(pitchNote.contains("17.5") && pitchNote.contains("63.0"))

        // **The valley stays derived** (the author, 2026-09-11). The photograph's
        // reading is written beside it, with the reason it cannot replace it.
        let valley = try #require(shape.values["half a thread over the braid's radius"])
        #expect(valley.isDerived)
        let valleyNote = try #require(valley.unsettled)
        #expect(valleyNote.contains("0.025") && valleyNote.contains("0.282")
                && valleyNote.contains("Task 005J"))
    }

    // MARK: - Stage 3 of Task 032: the stripes and the shading

    /// **The shading is where the run touches something** (Task 045): the
    /// sixteen-thread tube's valley at its two sides, the same depth where its
    /// tail has gone under the runs laid after it, and none on the head, which
    /// lies on top, once it has rounded to its width (Task 051). It replaced a
    /// valley on all four sides of a cell alike (Task 033), which fixed
    /// "四辺の陰が同じ"; the run is not the same end to end, so its shading is
    /// not either.
    ///
    /// **Where the tail darkens is where it is covered on the real shape**
    /// (Task 051's record: the next lane covers the tail's side from about 0.85
    /// of a cycle and its centreline from about 1.1; the arc is down at 1.2).
    @Test func theShadingIsWhereTheRunTouchesSomething() {
        let valley = RoundTube16StrandTextureFactory.valleyOcclusion
        let bundle = RoundTube8Bundle.standard
        func at(_ row: Float, cycles: Float) -> Float {
            RoundTube8StrandTexture.shading(across: row, along: cycles / bundle.lengthInCycles)
        }
        // On the crest at the middle of the run: nothing touches it.
        #expect(abs(at(0.5, cycles: bundle.crestAtCycles) - 1) < 0.001)
        // Its sides: the valley.
        #expect(abs(at(0, cycles: bundle.crestAtCycles) - valley) < 0.001)
        #expect(abs(at(1, cycles: bundle.crestAtCycles) - valley) < 0.001)
        // The head lies on top: unshaded once it has its width.
        #expect(abs(at(0.5, cycles: bundle.headRoundingCycles) - 1) < 0.001)
        // The tail: light before the next lane reaches it, under from where the
        // arc is down on the floor, and darkening across the hand-over.
        #expect(abs(at(0.5, cycles: 0.75) - 1) < 0.001)
        #expect(abs(at(0.5, cycles: bundle.arcSpanCycles) - valley) < 0.001)
        #expect(abs(at(0.5, cycles: bundle.lengthInCycles) - valley) < 0.001)
        #expect(at(0.5, cycles: 0.85) > at(0.5, cycles: 1.1))
        #expect(at(0.5, cycles: 1.1) > valley)
        // Still the same both sides of the crest.
        for value in stride(from: Float(0), through: 1, by: 0.05) {
            #expect(abs(at(value, cycles: 0.6) - at(1 - value, cycles: 0.6)) < 0.000_1)
        }
    }

    /// **A run's form** (Task 051): a blunt head, a width it keeps until the
    /// runs laid after it cover it, and a tail that bends into the next lane
    /// the way it leans — under **an even circular arc** of height, the
    /// author's form (Task 049's second rework), set over its own span.
    ///
    /// **Where the tail is actually covered is read off the real mesh**, width
    /// by width, in `RoundTube8CardAgreesWithSolidTests
    /// .aTailGoesUnderTheRunsLaidAfterItWithItsWidth`; this holds the form those
    /// readings rest on.
    @Test func aRunHasABluntHeadAndATailThatKeepsItsWidth() throws {
        let bundle = RoundTube8Bundle.standard
        let widest = bundle.widestHalfWidthInColumns

        // The head is blunt: nothing at the arrival, the full width a short
        // rounding after it — and not the lens's quarter cycle and more.
        #expect(bundle.halfWidthInColumns(atCycles: 0) == 0)
        #expect(abs(bundle.halfWidthInColumns(atCycles: bundle.headRoundingCycles) - widest) < 1e-6)
        #expect(bundle.headRoundingCycles <= 0.15)
        // Full width through the run and up to the next thread's arrival: the
        // tail is as wide as the run where it goes under.
        for cycles in stride(from: bundle.headRoundingCycles, through: bundle.tailNarrowsFromCycles, by: 0.05) {
            #expect(abs(bundle.halfWidthInColumns(atCycles: cycles) - widest) < 1e-6, "\(cycles)")
        }
        #expect(bundle.tailNarrowsFromCycles >= 1)
        // Then it narrows, and ends.
        #expect(bundle.halfWidthInColumns(atCycles: bundle.lengthInCycles) < 1e-6)
        #expect(bundle.halfWidthInColumns(atCycles: bundle.lengthInCycles + 0.01) == 0)

        // **The height is an even circular arc**: zero at the arrival and at the
        // end of its span, one in the middle, the same either side of it, and
        // on the floor past the span.
        #expect(bundle.crestAtCycles == bundle.arcSpanCycles / 2)
        #expect(abs(bundle.heightFraction(atCycles: bundle.crestAtCycles) - 1) < 1e-6)
        #expect(bundle.heightFraction(atCycles: 0) == 0)
        #expect(bundle.heightFraction(atCycles: bundle.arcSpanCycles) < 1e-6)
        for cycles in stride(from: bundle.arcSpanCycles, through: bundle.lengthInCycles, by: 0.05) {
            #expect(bundle.heightFraction(atCycles: cycles) < 1e-6)
        }
        for step in stride(from: Float(0.05), to: bundle.crestAtCycles, by: 0.05) {
            let head = bundle.heightFraction(atCycles: bundle.crestAtCycles - step)
            let tail = bundle.heightFraction(atCycles: bundle.crestAtCycles + step)
            #expect(abs(head - tail) < 1e-6, "\(step) either side of the middle")
            #expect(head < 1)
            // And it really is an arc, not some other even curve.
            let onACircle = (1 - pow(step / bundle.crestAtCycles, 2)).squareRoot()
            #expect(abs(head - onACircle) < 1e-6)
        }
        // **The arc's span is its own**: how far the tail goes on under the
        // others does not move the crest.
        let longer = RoundTube8Bundle(
            leanColumnsPerCycle: bundle.leanColumnsPerCycle, tuckedCycles: bundle.tuckedCycles + 0.2,
            headRoundingCycles: bundle.headRoundingCycles, arcSpanCycles: bundle.arcSpanCycles,
            tailBendColumns: bundle.tailBendColumns, tailBendFromCycles: bundle.tailBendFromCycles,
            tailNarrowsFromCycles: bundle.tailNarrowsFromCycles,
            widestHalfWidthInColumns: bundle.widestHalfWidthInColumns
        )
        #expect(longer.crestAtCycles == bundle.crestAtCycles)

        // **The tail bends the way the run leans, and only the tail**: the
        // centreline is the lean's straight line up to where the bend begins,
        // hardly off it at the crest, and further round by the bend at the end.
        for direction: Float in [1, -1] {
            for cycles in stride(from: Float(0), through: bundle.tailBendFromCycles, by: 0.05) {
                let straight = direction * bundle.leanColumnsPerCycle * (cycles - 0.5)
                #expect(abs(bundle.leanInColumns(atCycles: cycles, direction: direction) - straight) < 1e-6)
            }
            let atCrest = bundle.leanInColumns(atCycles: bundle.crestAtCycles, direction: direction)
                - direction * bundle.leanColumnsPerCycle * (bundle.crestAtCycles - 0.5)
            #expect(abs(atCrest) < 0.01)
            let atEnd = bundle.leanInColumns(atCycles: bundle.lengthInCycles, direction: direction)
                - direction * bundle.leanColumnsPerCycle * (bundle.lengthInCycles - 0.5)
            #expect(abs(atEnd - direction * bundle.tailBendColumns) < 1e-5)
        }
        // A thread is one column wide: that is half a column, and a run may show
        // wider than that (Task 046) but never narrower across its middle.
        #expect(RoundTube8Bundle.oneThreadHalfWidthInColumns == 0.5)
        #expect(widest >= RoundTube8Bundle.oneThreadHalfWidthInColumns)
    }

    /// **A run leans the way its thread is carried**, so S and Z lean opposite
    /// ways because their tables carry opposite ways — the sign is read off the
    /// courses, never written in. Along the run, towards the braiding point, the
    /// crest moves round the braid by the declared lean per cycle.
    @Test func aRunLeansTheWayTheCarryGoes() throws {
        let bundle = RoundTube8Bundle.standard
        for recipe in [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe] {
            let drawn = try pattern(recipe)
            let mesh = try mesh(recipe)
            #expect(drawn.leanDirection == Float(drawn.columnsCarried.signum()))
            let segment = drawn.surface.segments[0]
            func turns(_ cycles: Float) -> Float {
                let point = RoundTube8SurfaceMesh.frame(
                    of: segment, cycles: cycles, across: 0,
                    leanDirection: drawn.leanDirection,
                    floor: mesh.valleyFloorRadius, radius: mesh.crestRadius,
                    base: 0, repeatLength: mesh.patternRepeatLength
                ).position
                return atan2(point.y, point.z) / (2 * .pi)
            }
            // Over the part of the run before its tail bends (Task 051): the
            // bend is the tail's, and is held by `aRunHasABluntHeadAndATailThatKeepsItsWidth`.
            let span = bundle.tailBendFromCycles
            let moved = (turns(span) - turns(0)) * 8 / span
            #expect(abs(moved - drawn.leanDirection * bundle.leanColumnsPerCycle) < 1e-4,
                    "\(recipe.id): \(moved) columns a cycle")
            // And the tail goes on round the same way.
            #expect((turns(bundle.lengthInCycles) - turns(span)) * drawn.leanDirection > 0)
        }
    }

    /// **The stripes lie at the declared slant to the thread's run, and come back
    /// to where they started at the end of a cell**, so a column — one ridge from
    /// end to end — never shows them breaking at a cycle.
    @Test func theStripesLieAtTheDeclaredSlantAndJoinAtEveryCycle() throws {
        let twist = try #require(RoundTube8StrandTexture.twist)
        let stripes = RoundTube8StrandTexture.stripesPerCell
        #expect(stripes == stripes.rounded() && stripes >= 1)
        for across in stride(from: Float(-1), through: 1, by: 0.25) {
            let start = twist.coefficients.phase(along: 0, across: across)
            let end = twist.coefficients.phase(along: 1, across: across)
            #expect(abs(cos(start) - cos(end)) < 0.001)
        }

        // A line of one phase runs `tan(angle)` across for one along, in world
        // units: a run is `lengthInCycles` cycles long and, at its widest, an
        // eighth of the crest wide.
        let along = 2 * RoundTube8SurfacePatternGenerator.pitchOverDiameter
            * RoundTube8Bundle.standard.lengthInCycles
        let halfWidth = Float.pi / 8
        let perAlong = abs(twist.coefficients.phasePerAlong) / along
        let perAcross = abs(twist.coefficients.phasePerAcross) / halfWidth
        let slant = atan(perAlong / perAcross) * 180 / .pi
        #expect(abs(slant - abs(RoundTube8SurfaceMesh.fibreStripeAngleDegrees)) < 0.01)

        // **The lean is the one the render was measured for.** With both terms of
        // one sign, a line of one phase goes along the braid as it goes back round
        // it — which on this mesh, read off a render of its outside, falls to the
        // right with the braid lying across the view: the way four of the five
        // photographed beans with a readable fibre lean. The photograph does not
        // settle it.
        #expect(RoundTube8SurfaceMesh.fibreStripeAngleDegrees > 0)
        #expect((twist.coefficients.phasePerAlong > 0) == (twist.coefficients.phasePerAcross > 0))
    }

    /// **The relief lights the same stripes the tint draws.** The normal map's
    /// second channel runs along the normal crossed with the tangent, and this
    /// mesh's frame is right-handed, so that is its own bitangent and the gradient
    /// counts across the way the coefficients do. While the ring was strung the
    /// wrong way round the frame was left-handed, the two disagreed, and on a
    /// render they crossed into a lattice.
    @Test func theReliefLightsTheStripesTheTintDraws() throws {
        let mesh = try mesh(BraidMethodCatalog.yatsuKongoS8Recipe)
        for index in stride(from: 0, to: mesh.positions.count, by: 97) {
            let turned = cross(mesh.normals[index], mesh.tangents[index])
            #expect(dot(turned, mesh.bitangents[index]) > 0, "vertex \(index)")
        }
        let twist = try #require(RoundTube8StrandTexture.twist)
        #expect((twist.normalizedPhaseGradient.y > 0) == (twist.coefficients.phasePerAcross > 0))
        #expect((twist.normalizedPhaseGradient.x > 0) == (twist.coefficients.phasePerAlong > 0))
    }

    /// **The sixteen-thread factory draws the eight-thread stripes unchanged.**
    /// Nothing on that side was given a parameter; the eight's coefficients are
    /// simply handed to it.
    @Test func theSixteenThreadFactoryDrawsTheStripes() throws {
        let twist = try #require(RoundTube8StrandTexture.twist)
        #expect(RoundTube16StrandTextureFactory.roughnessImage(twist: twist) != nil)
        #expect(RoundTube16StrandTextureFactory.normalImage(twist: twist) != nil)
        #expect(RoundTube8StrandTexture.occlusionImage(twist: twist) != nil)
    }

    /// **What the drawing puts on the face at a slant is the colour**, and how far
    /// that is from the photographs is written down here rather than closed.
    ///
    /// No cell leans: every cell stands square to the braid (a thread's run on
    /// the solid does, Task 045, but that is how it shows and not which thread is
    /// where). The diagonal comes from which thread is standing where — one place round the
    /// braid a cycle, because these colourings repeat every four places and the
    /// table carries three, which is one back in four.
    ///
    /// Measured against a photograph, near the middle of the braid where the turn
    /// is least foreshortened, one place is `sin(pi/8)` of the width and one cycle
    /// is the pitch. **Derived 46.5 degrees; measured 54.5 on S and 51.0 on Z-a**
    /// (`Scripts/task031/measure_photographs.py`, the colour read with the stitch
    /// texture blurred away). **This is a record, not a gap to close**: the band a
    /// measurement reads off the drawn face depends on which way the braid is
    /// turned about its axis — 17.5 to 63.0 degrees over sixteen turns (Task 032)
    /// — so a derived figure and one photograph are not the like for like.
    @Test func theColourDiagonalIsRecordedAgainstThePhotographs() throws {
        let drawn = try pattern(BraidMethodCatalog.yatsuKongoS8Recipe)
        // The cells — which thread stands where, and when — do not lean. What
        // leans since Task 045 is how each thread shows, its run
        // (`aRunLeansTheWayTheCarryGoes`); the colour diagonal below is still
        // the cells', and the run's lean is a drawing figure, not this.
        #expect(drawn.surface.segments.allSatisfy {
            $0.centerlineStart.x == $0.centerlineEnd.x
        })
        // The colour walks one column every half cycle, which is what makes the
        // diagonal: the braid turns a column a cycle and the columns are half a
        // pitch apart (`RoundTube8HalfPitchTests`).
        #expect(drawn.drawnPhaseByColumn.count == 8)

        // **A colour band steps one column round the braid every half cycle**
        // since Task 048's rework (the braid turns a column a cycle, and the
        // columns are staggered half a pitch), where it used to step one place
        // every whole cycle of a cycle half as long. The two give the same
        // angle: the cycle doubled and the step halved.
        let acrossOnePlace = sin(Double.pi / 8)          // of the braid's width
        let along = Double(RoundTube8SurfacePatternGenerator.pitchOverDiameter) / 2
        let derived = atan2(along, acrossOnePlace) * 180 / .pi
        #expect(abs(derived - 46.5) < 0.5)

        // The colour bands measured on the photographs, S and Z-a.
        let measured = [54.5, -51.0]
        #expect(measured.allSatisfy { abs(abs($0) - derived) < 9 })
        // And they lean opposite ways, as the two tables do.
        #expect(measured[0] * measured[1] < 0)
    }
}
