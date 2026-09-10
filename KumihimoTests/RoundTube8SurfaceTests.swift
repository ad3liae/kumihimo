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
    /// A cell is read where it begins, which is the row boundary the figure's own
    /// row is taken at; a cell leans away from there as it goes.
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
            for column in 0..<8 {
                let shape = try #require(figure.appearance(atColumn: column, row: row))
                // The cell standing at this place for this cycle. It does not
                // lean, so it is at this column for the whole of the row.
                let middle = (Float(column) + 0.5) / 8
                let along = Float(row) / Float(drawn.rowCount)
                let cell = try #require(drawn.surface.segments.first {
                    abs($0.centerlineStart.x - middle) < 1e-4
                        && abs($0.centerlineStart.y - along) < 1e-4
                })
                #expect(cell.centerlineEnd.x == cell.centerlineStart.x)
                #expect(cell.colorID == shape.colorID, "row \(row), column \(column)")
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
        // with no turn to line the two numberings up.
        func mirrored(_ point: SIMD3<Float>) -> SIMD3<Float> {
            SIMD3(point.x, point.y, -point.z)
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
        for (colour, places) in mine {
            #expect(theirs[colour] == places, "\(colour.rawValue)")
        }
    }

    // MARK: - 3. One repeat closes

    /// **The tile joins itself, round and along, and has no end face.**
    ///
    /// Round: every ring of the surface is closed, because neighbouring cells meet
    /// on the valley floor they share. Along: the ring of vertices at the far end
    /// of the tile is the ring at the near end, moved by the tile's length — which
    /// is what lets a tile be laid end to end without a cap between.
    @Test(arguments: [BraidMethodCatalog.yatsuKongoS8Recipe, BraidMethodCatalog.yatsuKongoZ8Recipe])
    func oneRepeatClosesAndMakesNoEndFace(recipe: BraidRecipe) throws {
        let mesh = try mesh(recipe)
        let ends = mesh.length / 2

        func ring(at x: Float) -> Set<[Int32]> {
            Set(mesh.positions.filter { abs($0.x - x) < 1e-4 }.map {
                [Int32((atan2($0.z, $0.y) * 4096).rounded()),
                 Int32((sqrt($0.y * $0.y + $0.z * $0.z) * 4096).rounded())]
            })
        }
        let start = ring(at: -ends)
        let end = ring(at: ends)
        #expect(!start.isEmpty)
        #expect(start == end)

        // No triangle lies in either end plane, which is what an end face would be.
        let indices = mesh.allTriangleIndices
        var capped = 0
        for triangle in stride(from: 0, to: indices.count, by: 3) {
            let xs = (0..<3).map { mesh.positions[Int(indices[triangle + $0])].x }
            if xs.allSatisfy({ abs($0 - ends) < 1e-5 }) || xs.allSatisfy({ abs($0 + ends) < 1e-5 }) {
                capped += 1
            }
        }
        #expect(capped == 0)
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
        // Sixty-four cells a repeat, two repeats, and thirteen by eleven samples
        // over each: 128 * 143.
        // **Changed once, on purpose.** It was `0x03aa_f419_737c_1859` while a cell
        // was drawn stretched across the three places of the carry; a cell is the
        // thread standing still, so every cell is now square to the braid. **The
        // vertex count did not change** — the same surface, straightened.
        #expect(s.positions.count == 18_304)
        #expect(BraidMeshHashTests.hash(s.positions) == 0xa2b9_f4b5_1eab_3079)
    }

    // MARK: - 6. Which of a pair goes first does not reach the drawing

    /// **The one thing Task 008 left open must not be showing.** Which thread of a
    /// printed pair is carried first is not settled, so a drawing that depended on
    /// it would be a drawing resting on a guess.
    ///
    /// It does not, and the reason is stronger than a tolerance: **nothing crosses
    /// on this braid.** Every cell leans by the same three places, so the cells of
    /// one cycle lie side by side and the next cycle's carry on where they left
    /// off. There is no crossing whose order could matter, and the order never
    /// reaches the geometry at all.
    @Test func swappingWhichOfAPairGoesFirstDoesNotMoveTheMesh() throws {
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

    /// The steps of one cycle with the two of each printed pair exchanged. Book A
    /// prints two threads to a step and book C's order inside the pair is what is
    /// not known for this braid.
    private func swappingPairs(of steps: [BraidStep]) -> [BraidStep] {
        var out = steps
        for index in stride(from: 0, to: steps.count - 1, by: 2) {
            out.swapAt(index, index + 1)
        }
        return out
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
        #expect(s.rowCount == 8)
        #expect(s.surface.segments.count == 64)
    }

    /// Every number the drawing rests on says where it came from, and the one that
    /// is not settled says so.
    @Test func everyValueTheDrawingRestsOnSaysWhereItCameFrom() throws {
        let shape = try #require(BraidFamilyDrawing.shape(of: RoundTube8SurfaceMesh.family))
        #expect(!shape.values.isEmpty)
        #expect(shape.values.values.allSatisfy { !$0.source.origin.isEmpty })
        #expect(shape.values.values.allSatisfy { $0.agreesWithItsSpread })
        // **Nothing here was set by eye against a photograph** except how big the
        // braid is drawn, which is a display size and not a shape.
        #expect(shape.calibratedByEye.keys.sorted() == ["radius on screen"])
        let pitch = try #require(shape.values["one cycle over the braid's diameter"])
        #expect(pitch.isObserved)
        #expect(pitch.unsettled != nil)
    }

    /// **What the drawing puts on the face at a slant is the colour**, and how far
    /// that is from the photographs is written down here rather than closed.
    ///
    /// Nothing in the drawing leans: every cell stands square to the braid. The
    /// diagonal comes from which thread is standing where — one place round the
    /// braid a cycle, because these colourings repeat every four places and the
    /// table carries three, which is one back in four.
    ///
    /// Measured against a photograph, near the middle of the braid where the turn
    /// is least foreshortened, one place is `sin(pi/8)` of the width and one cycle
    /// is the pitch. **Derived 46.5 degrees; measured 54.5 on S and 51.0 on Z-a**
    /// (`Scripts/task031/measure_photographs.py`, the colour read with the stitch
    /// texture blurred away). The gap is four to eight degrees, and **closing it
    /// would mean moving the measured pitch**, which is `.observed` and not for
    /// moving.
    @Test func theColourDiagonalIsRecordedAgainstThePhotographs() throws {
        let drawn = try pattern(BraidMethodCatalog.yatsuKongoS8Recipe)
        // Nothing in the geometry leans.
        #expect(drawn.surface.segments.allSatisfy {
            $0.centerlineStart.x == $0.centerlineEnd.x
        })
        // The colour walks one place a cycle, which is what makes the diagonal:
        // three places on is one place back in a colouring that repeats every four.
        let drift = RoundTube8SurfacePatternGenerator.shortestWayRound(
            from: 0, to: drawn.columnsCarried, around: 4
        )
        #expect(abs(drift) == 1)

        let acrossOnePlace = sin(Double.pi / 8)          // of the braid's width
        let along = Double(RoundTube8SurfacePatternGenerator.pitchOverDiameter)
        let derived = atan2(along, acrossOnePlace) * 180 / .pi
        #expect(abs(derived - 46.5) < 0.5)

        // The colour bands measured on the photographs, S and Z-a.
        let measured = [54.5, -51.0]
        #expect(measured.allSatisfy { abs(abs($0) - derived) < 9 })
        // And they lean opposite ways, as the two tables do.
        #expect(measured[0] * measured[1] < 0)
    }
}
