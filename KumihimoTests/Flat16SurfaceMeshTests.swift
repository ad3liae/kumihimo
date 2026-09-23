import Foundation
import RealityKit
import simd
import Testing
@testable import Kumihimo

struct HiraGenjiSurfaceMeshTests {
    @Test func meshIsAnOpenRoundedFlatBraidWithEveryRegion() throws {
        let pattern = try #require(Flat16SurfacePatternGenerator.generate(assignments: assignments))
        let mesh = try #require(SharedMeshes.flat(assignments))

        #expect(abs(Flat16SurfaceMesh.widthToThicknessRatio - 3.4) <= 0.3)
        #expect(Set(mesh.surfaceVertexRegions) == Set(Flat16SurfaceRegion.allCases))
        #expect(mesh.positions.count == mesh.normals.count)
        #expect(mesh.positions.count == mesh.textureCoordinates.count)
        #expect(mesh.positions.count == mesh.boundaryDistances.count)
        #expect(mesh.positions.count == mesh.surfaceVertexPatchIndices.count)
        #expect(mesh.positions.count == mesh.surfaceVertexIsFloor.count)
        // The floor is laid under every cell and is a small part of the whole.
        #expect(mesh.surfaceVertexIsFloor.contains(true))
        #expect(mesh.surfaceVertexIsFloor.contains(false))
        #expect(mesh.surfaceVertexPatchIndices.allSatisfy { pattern.patches.indices.contains($0) })
        #expect(mesh.normals.allSatisfy { abs(simd_length($0) - 1) < 0.001 })
        #expect(mesh.colorGroups.values.allSatisfy { !$0.isEmpty })
        #expect(mesh.boundaryColorGroups.values.allSatisfy { !$0.isEmpty })

        // The drawn braid reads squarer than the stated section, and by how much
        // is not a free number. The surface stands one crest proud of the outline
        // right round, and a crest is the same length wherever it is raised — a
        // fraction of one yarn's width, and the braid is two yarns thick. Adding
        // it to both half-dimensions carries the ratio from w/t to
        // (w/t + crest) / (1 + crest).
        //
        // This replaced a floor of 85% of the stated ratio, which was slack
        // enough to hold at the crest the flat braid had before it was measured
        // and says nothing about where the relief is put. The comment it carried
        // — that the crown vanishes at the widest point — is not what the mesh
        // does: the width grows by 93% of a crest, near enough the whole of it.
        let yExtent = extent(mesh.positions.map(\.y))
        let zExtent = extent(mesh.positions.map(\.z))
        let stated = Flat16SurfaceMesh.widthToThicknessRatio
        let crest = Flat16SurfaceMesh.crestHeightRatio
        #expect(yExtent / zExtent < stated)
        #expect(abs(yExtent / zExtent * (1 + crest) / (stated + crest) - 1) < 0.02)
        // The thickness is exactly the section plus a crest on each face.
        let halfThickness = Flat16SurfaceMesh.defaultHalfThickness
        #expect(abs(zExtent / (2 * halfThickness * (1 + crest)) - 1) < 0.005)
    }

    /// The width is not a chosen number: the braid is two threads thick and
    /// sixteen threads round, so the outline the generator draws has to measure
    /// sixteen thread widths right round.
    @Test func theCrossSectionIsSixteenThreadsRoundAndTwoThreadsThick() {
        let halfWidth = Flat16SurfaceMesh.defaultHalfWidth
        let halfThickness = Flat16SurfaceMesh.defaultHalfThickness
        // Two threads thick, so one thread is one half-thickness wide.
        let threadWidth = halfThickness
        let perimeter = Flat16SurfaceMesh.perimeter(
            halfWidth: halfWidth,
            halfThickness: halfThickness
        )

        #expect(abs(perimeter / threadWidth - 16) < 0.01)
        #expect(abs(halfWidth / halfThickness
            - Flat16SurfaceMesh.widthToThicknessRatio) < 0.000_1)
        // The same solving at any size: the ratio is a shape, not a length.
        let scaled = Flat16SurfaceMesh.perimeter(
            halfWidth: 3 * halfWidth,
            halfThickness: 3 * halfThickness
        )
        #expect(abs(scaled / (3 * threadWidth) - 16) < 0.01)
    }

    // MARK: - The visible run's own shape (Task 050)

    /// A bundle's swell is even about the middle of its own cell, and it does not
    /// die there: it meets the run before and the run after at `joinHeight`, so
    /// the two part in a groove rather than sharing a floor.
    @Test func aRunSwellsEvenlyAndMeetsItsNeighboursAboveTheValley() throws {
        let shape = Flat16SurfaceMesh.bundleShape

        #expect(shape.belly(atAlong: 0.5) == 1)
        // Even about the middle, which is the author's ruling on the round
        // braid's bundles (Task 049) applied here.
        for offset in stride(from: Float(0.05), through: 0.6, by: 0.05) {
            #expect(abs(shape.belly(atAlong: 0.5 + offset)
                - shape.belly(atAlong: 0.5 - offset)) < 0.000_1)
        }
        // And it is solved so that the cell's own ends stand at `joinHeight`.
        #expect(abs(shape.belly(atAlong: 0) - shape.joinHeight) < 0.000_5)
        #expect(abs(shape.belly(atAlong: 1) - shape.joinHeight) < 0.000_5)
        // Monotone from the crest out to either end of the swell.
        let falling = stride(from: Float(0.5), through: 0.5 + shape.bellyHalfSpan, by: 0.02)
            .map { shape.belly(atAlong: $0) }
        #expect(zip(falling, falling.dropFirst()).allSatisfy { $0 >= $1 - 0.000_1 })
        #expect(abs(falling.last ?? 1) < 0.01)

        // **Nothing here is a grid.** The drawing this replaced took the surface
        // all the way down to the valley at both ends of every cell and at both
        // sides of every lane.
        #expect(shape.joinHeight > 0.05)
        #expect(shape.laneJoinHeight > 0.05)
    }

    /// The two reaches are solved from the two join heights, not chosen: the
    /// swell's own profile, inverted.
    @Test func theReachAndTheWidthAreSolvedFromTheTwoJoins() {
        let shape = Flat16SurfaceMesh.bundleShape

        // Half a step from the middle of a cell is where the next cell begins.
        #expect(abs(Flat16BundleShape.swell(atPlace: 0.5 / shape.bellyHalfSpan)
            - shape.joinHeight) < 0.000_5)
        // Half a lane from the middle of a lane is where the next lane's crest
        // is a whole lane away.
        #expect(abs(Flat16BundleShape.swell(atPlace: 1 / shape.widthOverLane)
            - shape.laneJoinHeight) < 0.000_5)

        // A bundle lies over its neighbours' flanks, and still does where the
        // lens pinches it — otherwise every step would open a slot right across
        // the braid and the floor would show through it.
        #expect(shape.widthOverLane > 1)
        #expect(shape.widthOverLane * shape.endWidth > 1)
        #expect(shape.endWidth < 1)
    }

    /// At the join in a lane the run arriving lies on the run leaving. Which is
    /// which is not a matter of taste: one thread is coming from the other face
    /// and one is going to it.
    @Test func theRunArrivingLiesOnTheRunLeaving() {
        let shape = Flat16SurfaceMesh.bundleShape
        let head = shape.belly(atAlong: 0) * shape.endFactor(atAlong: 0)
        let tail = shape.belly(atAlong: 1) * shape.endFactor(atAlong: 1)

        #expect(head > tail)
        #expect(abs(shape.endFactor(atAlong: 0.5) - 1) < 0.000_1)
        // And the lift and the dip touch nothing at mid-span, so the swell keeps
        // its crest exactly where stage 2 put it.
        #expect(abs(shape.standing(atAlong: 0.5, across: 0) - 1) < 0.000_1)
        for along in stride(from: Float(0), through: 1, by: 0.02) {
            #expect(shape.standing(atAlong: along, across: 0) <= 1.000_1)
        }
    }

    /// A tip past the swell is buried: below the valley floor, so it cannot show
    /// between the runs covering it.
    @Test func aTipPastTheSwellIsBuried() {
        let shape = Flat16SurfaceMesh.bundleShape

        #expect(shape.standing(atAlong: shape.runEnd, across: 0) < 0)
        #expect(shape.standing(atAlong: shape.runStart, across: 0) < 0)
        #expect(abs(shape.standing(atAlong: shape.runEnd, across: 0)
            + shape.buriedTipSink) < 0.000_1)
        // And it is below the floor the mesh lays under every cell, in the same
        // units: the floor is a fraction of the half-thickness, the tip a
        // fraction of the crest.
        #expect(shape.buriedTipSink * Flat16SurfaceMesh.crestHeightRatio
            > Flat16SurfaceMesh.floorSink)
    }

    /// Read on the drawn mesh rather than on the formula: down the middle of a
    /// lane the surface rises and falls once per step — **and the low point is
    /// well above the valley**, which is what parts the face into beads instead
    /// of cutting a grid into it.
    @Test func theDrawnSurfaceFallsAtEveryJoinWithoutReachingTheValley() throws {
        let pattern = try #require(Flat16SurfacePatternGenerator.generate(assignments: assignments))
        let mesh = try #require(SharedMeshes.flat(assignments))
        let shape = Flat16SurfaceMesh.bundleShape
        let crest = Flat16SurfaceMesh.defaultHalfThickness
            * Flat16SurfaceMesh.crestHeightRatio

        // Vertices down the middle of a front bundle, which is where its texture
        // coordinate reads a half across. **The runs that dive under the body are
        // left out**: they take their own height down with them where they go
        // under, so their low points say nothing about a join between two runs of
        // one lane.
        let middle = mesh.positions.indices.filter { index in
            mesh.surfaceVertexRegions[index] == .front
                && !mesh.surfaceVertexIsFloor[index]
                && pattern.bundles[mesh.surfaceVertexPatchIndices[index]].drawnInPerStep == 0
                && abs(mesh.textureCoordinates[index].x - 0.5) < 0.01
        }
        #expect(middle.count > 200)
        let reliefs = middle.map { reliefFromThePlainOutline(mesh.positions[$0]) }
        #expect(reliefs.max() ?? 0 > crest * 0.9)

        // Where a bundle's own cell ends, the surface has fallen to the join and
        // no further. The texture runs over the whole run, so the cell's ends sit
        // where `runStart` and `runEnd` put them.
        let span = shape.runEnd - shape.runStart
        let atTheCellsEnd = middle.filter { index in
            let along = shape.runStart + span * mesh.textureCoordinates[index].y
            return abs(along) < 0.02 || abs(along - 1) < 0.02
        }
        #expect(!atTheCellsEnd.isEmpty)
        let joins = atTheCellsEnd.map { reliefFromThePlainOutline(mesh.positions[$0]) }
        // Below the crest, and above the valley by a clear margin.
        #expect(joins.allSatisfy { $0 < crest * 0.7 })
        #expect(joins.allSatisfy { $0 > crest * shape.joinHeight * 0.5 })
    }

    // MARK: - Stage 2.5c: the outline is divided by arc, not by angle

    /// Sixteen threads round the section: six across each face and two at each
    /// edge. So each region has to measure exactly that many thread widths of
    /// the outline.
    @Test func eachRegionIsAsManyThreadWidthsRoundAsItHasThreadsInIt() {
        let halfWidth = Flat16SurfaceMesh.defaultHalfWidth
        let halfThickness = Flat16SurfaceMesh.defaultHalfThickness
        let threadWidth = halfThickness

        for region in Flat16SurfaceRegion.allCases {
            let expected: Float = region == .front || region == .back
                ? Float(HiraGenjiWeaveDerivation.columnCount)
                : Float(HiraGenjiWeaveDerivation.edgeThreadCount)
            let threads = arcLength(of: region, from: 0, to: 1,
                                    halfWidth: halfWidth, halfThickness: halfThickness)
                / threadWidth
            #expect(abs(threads / expected - 1) < 0.03)
        }
        // The four spans tile the way round exactly once.
        let spans = Flat16SurfaceRegion.allCases
            .map { Flat16SurfaceMesh.arcSpan(of: $0).length }
        #expect(abs(spans.reduce(0, +) - 1) < 0.000_1)
    }

    /// Every lane of a face is one thread wide, measured round the outline. This
    /// is what the drawn braid's lanes come from; before this they were equal
    /// steps of the superellipse's angle, which made the middle two lanes five
    /// times the outermost two.
    @Test func everyLaneOfAFaceIsOneThreadWideRoundTheOutline() {
        let halfWidth = Flat16SurfaceMesh.defaultHalfWidth
        let halfThickness = Flat16SurfaceMesh.defaultHalfThickness
        let lanes = Flat16SurfacePatternGenerator.broadFaceColumnCount

        for region in [Flat16SurfaceRegion.front, .back] {
            let widths = (0..<lanes).map { lane in
                arcLength(
                    of: region,
                    from: Float(lane) / Float(lanes),
                    to: Float(lane + 1) / Float(lanes),
                    halfWidth: halfWidth,
                    halfThickness: halfThickness
                )
            }
            let mean = widths.reduce(0, +) / Float(lanes)
            #expect(widths.allSatisfy { abs($0 / mean - 1) < 0.01 })
            #expect(abs(mean / halfThickness - 1) < 0.03)
        }
    }

    /// And what that comes to on screen: the six lanes of a face are within
    /// fifteen per cent of one another across the width, and the middle ones are
    /// no wider than the outermost. The finished braids in the references
    /// measure 1.75 (book A p96) and 1.00 (book B p23); the angle-divided
    /// outline this replaced measured 5.17.
    @Test func theSixLanesOfAFaceComeOutTheSameWidthAcrossTheBraid() {
        let halfWidth = Flat16SurfaceMesh.defaultHalfWidth
        let halfThickness = Flat16SurfaceMesh.defaultHalfThickness
        let lanes = Flat16SurfacePatternGenerator.broadFaceColumnCount

        func edgeX(_ lane: Int) -> Float {
            Flat16SurfaceMesh.crossSectionPoint(
                region: .front,
                regionU: Float(lane) / Float(lanes),
                halfWidth: halfWidth,
                halfThickness: halfThickness
            ).x
        }
        let widths = (0..<lanes).map { abs(edgeX($0) - edgeX($0 + 1)) }
        let mean = widths.reduce(0, +) / Float(lanes)

        #expect(widths.allSatisfy { abs($0 / mean - 1) < 0.15 })
        let middleOverOutermost = widths[lanes / 2] / widths[0]
        #expect(abs(middleOverOutermost - 1) < 0.15)
    }

    /// The arc-length map is the inverse of the arc-length function, so equal
    /// steps of it are equal distances round the outline.
    @Test func theArcLengthMapDividesTheOutlineEvenly() {
        let arcs = Flat16SurfaceMesh.arcLengths(
            forRatio: Flat16SurfaceMesh.widthToThicknessRatio
        )
        #expect(arcs.angle(atArcFraction: 0) == 0)
        // Wrapping round lands back where it started.
        #expect(abs(arcs.angle(atArcFraction: 1.25) - arcs.angle(atArcFraction: 0.25)) < 0.001)
        // Sixteen equal steps of arc are sixteen equal distances round the
        // outline. Measured as arc, not as the chord: the outline turns sharply
        // at its four corners and a chord across one cuts it.
        let halfWidth = Flat16SurfaceMesh.defaultHalfWidth
        let halfThickness = Flat16SurfaceMesh.defaultHalfThickness
        let power = 2 / Flat16SurfaceMesh.superellipseExponent
        func point(_ fraction: Float) -> SIMD2<Float> {
            let angle = arcs.angle(atArcFraction: fraction)
            func signed(_ value: Float) -> Float {
                (value < 0 ? -1 : 1) * pow(abs(value), power)
            }
            return SIMD2<Float>(halfWidth * signed(cos(angle)),
                                halfThickness * signed(sin(angle)))
        }
        func walk(_ from: Float, _ to: Float) -> Float {
            var total: Float = 0
            var previous = point(from)
            for step in 1...512 {
                let current = point(from + (to - from) * Float(step) / 512)
                total += simd_distance(previous, current)
                previous = current
            }
            return total
        }
        let sixteenths = (0..<16).map { walk(Float($0) / 16, Float($0 + 1) / 16) }
        let mean = sixteenths.reduce(0, +) / 16
        #expect(sixteenths.allSatisfy { abs($0 / mean - 1) < 0.01 })
        // And one sixteenth of the way round is one thread wide.
        #expect(abs(mean / halfThickness - 1) < 0.03)
    }

    /// Arc length between two points of one region, walked on the outline the
    /// generator draws rather than taken from a formula for it.
    private func arcLength(
        of region: Flat16SurfaceRegion,
        from start: Float,
        to end: Float,
        halfWidth: Float,
        halfThickness: Float,
        samples: Int = 4_096
    ) -> Float {
        var total: Float = 0
        var previous = Flat16SurfaceMesh.crossSectionPoint(
            region: region, regionU: start, halfWidth: halfWidth, halfThickness: halfThickness
        )
        for step in 1...samples {
            let u = start + (end - start) * Float(step) / Float(samples)
            let point = Flat16SurfaceMesh.crossSectionPoint(
                region: region, regionU: u, halfWidth: halfWidth, halfThickness: halfThickness
            )
            total += simd_distance(previous, point)
            previous = point
        }
        return total
    }

    // MARK: - Stage 2: a rounded ridge per thread

    /// The section a bundle is given across its own width: full height on the
    /// crest, nothing at either rim, and **half way down at half its reach** —
    /// which is what a circle's own section does not do, and why a bundle drawn
    /// with one read as a flat tile (Task 050).
    @Test func theSectionFallsFromTheCrestFromTheStart() {
        let profile = Flat16SurfaceMesh.bundleShape.crestProfile(across:)

        #expect(profile(0) == 1)
        #expect(abs(profile(-1)) < 0.000_001)
        #expect(abs(profile(1)) < 0.000_001)
        #expect(abs(profile(0.5) - 0.5) < 0.000_01)
        #expect(profile(-0.5) == profile(0.5))
        // A circle would be 0.866 there, and a parabola 0.75. Both leave the
        // middle of the bundle almost flat.
        #expect(profile(0.5) < 0.75)
        // Off the ends it stays at the valley floor rather than turning back up.
        #expect(abs(profile(-2)) < 0.000_001)
        #expect(abs(profile(2)) < 0.000_001)
        // Monotone from the crest out to either rim.
        let samples = stride(from: Float(0), through: 1, by: 0.05).map(profile)
        #expect(zip(samples, samples.dropFirst()).allSatisfy { $0 >= $1 })
    }

    /// The crest is read off the finished braid in book A p96, not taken from the
    /// round braid. This pins the value that reading gave and the ripple it had to
    /// draw; a change to the value has to face the measurement again.
    ///
    /// Three estimates overlap over 0.41 to 0.50 — two readings of that edge at
    /// different heights in its blur, and one from the braid's own section that
    /// owes nothing to a photograph — and the value is the middle of the overlap.
    /// See `crestHeightRatio` for the working.
    ///
    /// **`sigma = 9.55 × crest` belongs to the shape this braid had before Task
    /// 050**, where a ridge filled each cell and died to the valley at its edges.
    /// The surface is overlapping bundles now, and **nobody has rendered the new
    /// one and measured its silhouette's ripple again.** So this test passing says
    /// the figure is still the one book A p96 gave — **it does not say the braid
    /// as drawn today ripples by that much.** Re-measuring it is left open
    /// (Task 050 §9). **The name is kept** so that Task 007E's record and Task
    /// 050 §9 still point at it.
    @Test func theCrestIsWhatTheFinishedBraidsEdgeMeasures() {
        let crest = Flat16SurfaceMesh.crestHeightRatio

        #expect((0.41...0.50).contains(crest))
        // Inverting the ripple the *old* shape's render drew:
        // sigma per cent = 9.55 * crest.
        let ripplePerCent = 9.55 * crest
        // Book A p96's edge, read the two ways, measures 5.29% and 3.9%.
        #expect(abs(ripplePerCent / 5.29 - 1) < 0.20)
        #expect(abs(ripplePerCent / 3.9 - 1) < 0.20)
        // A yarn lying on a surface stands about half its own diameter proud, and
        // the half-thickness is one yarn's diameter.
        #expect((0.40...0.50).contains(crest))
    }

    /// **The two braids' crests are not the same figure, and need not be.**
    ///
    /// The round braid's crest is a fraction of its nominal radius and was never
    /// checked against a photographed braid; the flat braid's is read off one.
    /// This test used to assert they agreed per yarn width, which fixed an
    /// assumption nothing had verified. It now records the gap so that closing it
    /// is a decision someone takes, not something that happens quietly.
    ///
    /// Task 005J could not measure the round braid's crest. **Task 052 raised it
    /// by eye from 0.12 to 0.20** (the author: too flat), which narrowed the gap
    /// from about three times to under two. That is a drawing choice, not a
    /// measurement closing it.
    @Test func theRoundBraidsCrestIsStillTheUnmeasuredOne() {
        let flatPerYarn = Flat16SurfaceMesh.crestHeightRatio
        let roundYarnWidth = 2 * Float.pi * RoundTube16SurfaceMesh.defaultRadius
            / Float(RoundTube16SurfacePatternGenerator.patchCount).squareRoot()
        let roundPerYarn = RoundTube16SurfaceMesh.defaultRadius
            * RoundTube16SurfaceMesh.crestHeightRatio / roundYarnWidth

        #expect(abs(roundPerYarn - 0.255) < 0.005)
        // The flat braid's yarn is one half-thickness wide, so its ratio is also
        // its crest in yarn widths. The round braid's stands a little over half
        // as proud of its own yarn (about a third before Task 052).
        #expect(flatPerYarn / roundPerYarn > 1.5)
        #expect(flatPerYarn / roundPerYarn < 2.1)
    }

    /// The swell is given to all four regions. An edge left flat would read as a
    /// cut side rather than as the yarn turning back on itself.
    ///
    /// **This had an allowance of its own from 2026-09-09 to 2026-09-12, and no
    /// longer does** (Task 018). It ran for four minutes and was cut off at the
    /// suite's sixty seconds on every run, which made a cut-off the normal state
    /// and hid anything else that went wrong; five minutes was given to it alone
    /// so that it could finish.
    ///
    /// **What made it slow was its own making, not the size of the mesh.** The
    /// note here used to say it "walks every vertex of the whole mesh four times
    /// over and takes about two minutes". Both halves were wrong, and the first
    /// hid the second: the cost was never four passes over the mesh but 1028
    /// outline points rebuilt for **each** vertex, and by the time anyone measured
    /// it, it had reached four minutes three seconds. **A cost written down in the
    /// wrong shape is one nobody can see grow.**
    ///
    /// The outline is built once now (`plainOutline`) and this took twenty-three
    /// seconds then, so **it is back on the ordinary sixty-second allowance**. That
    /// is deliberate and not tidying: five minutes around a twenty-three second
    /// test is room for it to grow tenfold again unseen.
    ///
    /// Measured again in Task 056 (2026-09-23): 7.3 seconds, of which about 3.6
    /// were making the mesh. It reads the shared one now (`SharedMeshes`), and the
    /// walk itself is 3.7 seconds: the vertices once over, each held first against the
    /// outline points in the thirteen bins round its own (about fifty of the 1028).
    @Test func everyRegionCarriesTheRidgeIncludingBothEdges() throws {
        let mesh = try #require(SharedMeshes.flat(assignments))
        let halfThickness = Flat16SurfaceMesh.defaultHalfThickness
        let crest = halfThickness * Flat16SurfaceMesh.crestHeightRatio

        var reliefByRegion = [Flat16SurfaceRegion: (low: Float, high: Float)]()
        for (index, position) in mesh.positions.enumerated() {
            let region = mesh.surfaceVertexRegions[index]
            let relief = reliefFromThePlainOutline(position)
            let seen = reliefByRegion[region] ?? (low: .greatestFiniteMagnitude,
                                                 high: -.greatestFiniteMagnitude)
            reliefByRegion[region] = (min(seen.low, relief), max(seen.high, relief))
        }

        #expect(Set(reliefByRegion.keys) == Set(Flat16SurfaceRegion.allCases))
        for region in Flat16SurfaceRegion.allCases {
            let seen = try #require(reliefByRegion[region])
            // Reaches the crest, within the sampling the mesh actually carries.
            #expect(seen.high > crest * 0.9)
            #expect(seen.high < crest * 1.2)
            // And comes back down past the valley, where a buried tip ends.
            #expect(seen.low < 0)
        }
    }

    /// The plain cross-section's outline, sampled once for the whole suite: every
    /// region in `allCases` order, 257 steps each — **and sorted into bins by the
    /// angle they stand at**, so a point being measured looks at the few that
    /// could be nearest instead of all 1028.
    ///
    /// **It does not depend on the point being measured**, and that is the whole
    /// reason it is built once (Task 018). `reliefFromThePlainOutline` used to
    /// build all 1028 of these points again for every vertex handed to it, and
    /// `crossSectionPoint` is not cheap — it walks an arc-length table each call.
    /// Over a whole mesh that was four minutes; building it once brought it to
    /// twenty-three seconds.
    ///
    /// **The bins are the second half of the same lesson** (Task 050). The mesh
    /// grew by a third when every cell became a bundle, and a test that walks
    /// every vertex past every outline point grows with the product: twenty-three
    /// seconds became thirty-five. The cost is `vertices × 1028`, and only the
    /// second factor was ever anyone's to choose. The outline is star-shaped
    /// about the middle of the braid, so the nearest point to a vertex stands at
    /// nearly the same angle, and a window of bins holds it.
    ///
    /// **And when it does not, the walk falls back to all of them.** The outline
    /// turns very unevenly — it is a superellipse of exponent 5 — so a window
    /// wide enough almost always is not wide enough always, and a narrow one
    /// quietly answers with the wrong point. If the nearest found lies against
    /// the edge of the window, something outside it may be nearer, and the whole
    /// outline is walked. **The answer is the full walk's, every time**; the bins
    /// only save the walking.
    ///
    /// **Within the candidates the order is the order the two nested loops had**,
    /// so which of two equally near points wins is unchanged.
    private static let plainOutline: [SIMD2<Float>] = {
        var points = [SIMD2<Float>]()
        points.reserveCapacity(Flat16SurfaceRegion.allCases.count * 257)
        for region in Flat16SurfaceRegion.allCases {
            for step in 0...256 {
                points.append(Flat16SurfaceMesh.crossSectionPoint(
                    region: region,
                    regionU: Float(step) / 256,
                    halfWidth: Flat16SurfaceMesh.defaultHalfWidth,
                    halfThickness: Flat16SurfaceMesh.defaultHalfThickness
                ))
            }
        }
        return points
    }()

    private static let outlineBins = 256
    /// How many bins either side of a point's own are looked at first.
    private static let outlineWindow = 6

    private static func bin(of point: SIMD2<Float>) -> Int {
        let turn = atan2(point.y, point.x) / (2 * .pi)
        let wrapped = turn - turn.rounded(.down)
        return min(Int(wrapped * Float(outlineBins)), outlineBins - 1)
    }

    /// Which outline points stand in each angular bin, in the order they were
    /// built.
    private static let outlineByBin: [[Int]] = {
        var bins = [[Int]](repeating: [], count: outlineBins)
        for (index, point) in plainOutline.enumerated() {
            bins[bin(of: point)].append(index)
        }
        return bins
    }()

    /// How far a point stands out of the plain cross-section the braid would have
    /// with no swell at all. Measured against the outline the generator draws,
    /// not against a formula for it.
    private func reliefFromThePlainOutline(_ position: SIMD3<Float>) -> Float {
        let point = SIMD2<Float>(position.y, position.z)
        let middle = Self.bin(of: point)
        var nearest = Float.greatestFiniteMagnitude
        var nearestBin = middle
        var nearestPoint = SIMD2<Float>.zero
        for step in -Self.outlineWindow...Self.outlineWindow {
            let bin = ((middle + step) % Self.outlineBins + Self.outlineBins) % Self.outlineBins
            for index in Self.outlineByBin[bin] {
                let outline = Self.plainOutline[index]
                let distance = simd_distance(outline, point)
                if distance < nearest {
                    nearest = distance
                    nearestBin = bin
                    nearestPoint = outline
                }
            }
        }
        // Against the edge of the window, or nothing found in it: walk all of it.
        let reach = (nearestBin - middle + Self.outlineBins) % Self.outlineBins
        let fromTheMiddle = min(reach, Self.outlineBins - reach)
        if nearest == .greatestFiniteMagnitude || fromTheMiddle >= Self.outlineWindow {
            for outline in Self.plainOutline {
                let distance = simd_distance(outline, point)
                if distance < nearest {
                    nearest = distance
                    nearestPoint = outline
                }
            }
        }
        return simd_length(point) >= simd_length(nearestPoint) ? nearest : -nearest
    }

    // MARK: - The stitch's shape

    /// The stitch pitch the mesh draws, against the two finished braids in the
    /// references it was measured from. Both are quoted so a change to the figure
    /// has to face both of them.
    @Test func aStitchIsAsLongAsTheReferenceBraidsMeasure() throws {
        let rowCount = try #require(Flat16SurfacePatternGenerator.rowCount)
        let braidWidth = 2 * Flat16SurfaceMesh.defaultHalfWidth
        let stitchLength = Flat16SurfaceMesh.defaultLength
            / Float(Flat16SurfaceMesh.defaultPatternRepeatCount)
            / Float(rowCount)
        let pitch = stitchLength / braidWidth

        // Book A p96: 43.5 px pitch on a 124 px braid. Book B p23: 26 on 68.
        #expect(abs(pitch / 0.351 - 1) < 0.15)
        #expect(abs(pitch / 0.382 - 1) < 0.15)
        // The two agree well enough to average, which is what the figure is.
        #expect(abs(pitch - (0.351 + 0.382) / 2) < 0.001)
        // Said against the yarn: a stitch is about twice as long as one thread
        // is wide. The hard-coded length this replaced made it 0.59.
        let yarnWidth = braidWidth / Float(Flat16SurfacePatternGenerator.broadFaceColumnCount)
        #expect((1.9...2.5).contains(stitchLength / yarnWidth))
    }

    /// Length is derived from the cross-section and the pattern, never stored, so
    /// a braid drawn at another size keeps its stitches the same shape.
    @Test func theLengthFollowsTheWidthSoAStitchKeepsItsShapeAtAnySize() throws {
        let pattern = try #require(Flat16SurfacePatternGenerator.generate(assignments: assignments))
        let halfWidth = Flat16SurfaceMesh.defaultHalfWidth

        for scale in [Float(0.5), 1, 3] {
            let length = Flat16SurfaceMesh.length(
                halfWidth: scale * halfWidth,
                aspectRatio: pattern.aspectRatio,
                patternRepeatCount: Flat16SurfaceMesh.defaultPatternRepeatCount
            )
            #expect(abs(length / (scale * Flat16SurfaceMesh.defaultLength) - 1) < 0.001)
        }
        // And repeats only add length; they never restretch a stitch.
        let one = Flat16SurfaceMesh.length(
            halfWidth: halfWidth, aspectRatio: pattern.aspectRatio, patternRepeatCount: 1
        )
        let three = Flat16SurfaceMesh.length(
            halfWidth: halfWidth, aspectRatio: pattern.aspectRatio, patternRepeatCount: 3
        )
        #expect(abs(three / one - 3) < 0.001)
        #expect(abs(pattern.aspectRatio
            - Float(pattern.rowCount)
            * Flat16SurfacePatternGenerator.stitchPitchPerBraidWidth) < 0.000_1)
    }

    @Test func meshHasNoEndCapTriangles() throws {
        let mesh = try #require(SharedMeshes.flat(assignments))
        let indices = mesh.allTriangleIndices

        let containsEndCap = stride(from: 0, to: indices.count, by: 3).contains { offset in
            let firstX = mesh.positions[Int(indices[offset])].x
            return abs(mesh.positions[Int(indices[offset + 1])].x - firstX) < 0.000_001
                && abs(mesh.positions[Int(indices[offset + 2])].x - firstX) < 0.000_001
        }
        #expect(!containsEndCap)
    }

    @Test func everySurfaceTriangleHasArea() throws {
        let mesh = try #require(SharedMeshes.flat(assignments))
        let indices = mesh.allTriangleIndices
        let containsDegenerateTriangle = stride(from: 0, to: indices.count, by: 3).contains { offset in
            let a = mesh.positions[Int(indices[offset])]
            let b = mesh.positions[Int(indices[offset + 1])]
            let c = mesh.positions[Int(indices[offset + 2])]
            return simd_length_squared(simd_cross(b - a, c - a))
                <= 0.000_000_000_001
        }

        #expect(!containsDegenerateTriangle)
    }

    /// One tile laid after another leaves no gap.
    ///
    /// **This asks whether the two cuts are the same surface, not whether they
    /// were divided up the same way.** They are not divided the same way any more:
    /// the lanes are not all in step along the braid (Task 007G), so a lane the
    /// tile's start cuts through the lower half of a row, its end cuts through the
    /// upper half of the row above. The two cuts still describe the same shape,
    /// which is what makes the tiles meet, and asking for the same sample points
    /// asks for something the braid does not owe.
    @Test func consecutiveTilesMeetOnTheSameSurface() throws {
        let mesh = try #require(SharedMeshes.flat(assignments))
        let length = Flat16SurfaceMesh.defaultLength
        let start = mesh.positions.indices.filter { abs(mesh.positions[$0].x + length / 2) < 0.000_001 }
        let end = mesh.positions.indices.filter { abs(mesh.positions[$0].x - length / 2) < 0.000_001 }

        #expect(start.count > 100)
        #expect(end.count > 100)
        // Every point of one cut is a point of the other, to within a tolerance
        // far finer than a yarn. Both ways round, so neither cut may cover only
        // part of the other.
        for (near, far) in [(start, end), (end, start)] {
            let strays = near.filter { index in
                !far.contains { other in
                    abs(mesh.positions[index].y - mesh.positions[other].y) < 0.001
                        && abs(mesh.positions[index].z - mesh.positions[other].z) < 0.001
                        && abs(mesh.normals[index].y - mesh.normals[other].y) < 0.01
                        && abs(mesh.normals[index].z - mesh.normals[other].z) < 0.01
                        && abs(mesh.boundaryDistances[index] - mesh.boundaryDistances[other]) < 0.01
                }
            }
            #expect(strays.isEmpty)
        }
    }

    @Test func consecutivePatternRepeatsKeepColorAndBoundaryMaterialPhase() throws {
        let pattern = try #require(Flat16SurfacePatternGenerator.generate(assignments: assignments))
        // Four repeats, and the two compared are the middle two. The first and
        // the last are the ones the tile's ends cut through, so they are missing
        // the piece that was carried to the other end of the tile; comparing a cut
        // repeat with an uncut one would be comparing the cut, not the pattern.
        let repeatCount = 4
        let mesh = try #require(Flat16SurfaceMesh.generate(
            pattern: pattern,
            patternRepeatCount: repeatCount
        ))
        let length = Flat16SurfaceMesh.length(
            halfWidth: Flat16SurfaceMesh.defaultHalfWidth,
            aspectRatio: pattern.aspectRatio,
            patternRepeatCount: repeatCount
        )

        var firstRepeat = [String: Int]()
        var secondRepeat = [String: Int]()
        for (isBoundary, groups) in [
            (false, mesh.colorGroups),
            (true, mesh.boundaryColorGroups),
        ] {
            for (colorID, indices) in groups {
                for offset in stride(from: 0, to: indices.count, by: 3) {
                    let vertexIndices = (0..<3).map { Int(indices[offset + $0]) }
                    let centerX = vertexIndices.reduce(Float.zero) {
                        $0 + mesh.positions[$1].x
                    } / 3
                    let centerUV = vertexIndices.reduce(SIMD2<Float>.zero) {
                        $0 + mesh.textureCoordinates[$1]
                    } / 3
                    let patchIndex = mesh.surfaceVertexPatchIndices[vertexIndices[0]]
                    let region = mesh.surfaceVertexRegions[vertexIndices[0]]
                    // Which repeat drew this, worked back from where it sits along
                    // the braid and where it sits inside its own patch. **Where it
                    // is along the braid does not say on its own any more**: a
                    // patch may reach past a repeat's ends, so a row of one repeat
                    // can lie partly in the next one's stretch of the tile.
                    let along = (centerX + length / 2) / length * Float(repeatCount)
                    let inPatch = Flat16SurfaceMesh.interpolate(
                        corners: pattern.patches[patchIndex].corners,
                        local: centerUV
                    ).y
                    let repeatIndex = Int((along - inPatch).rounded())
                    let signature = [
                        colorID.rawValue,
                        String(describing: region),
                        String(patchIndex),
                        String(Int((centerUV.x * 1_000_000).rounded())),
                        String(Int((centerUV.y * 1_000_000).rounded())),
                        String(isBoundary),
                    ].joined(separator: ":")
                    if repeatIndex == 1 {
                        firstRepeat[signature, default: 0] += 1
                    } else if repeatIndex == 2 {
                        secondRepeat[signature, default: 0] += 1
                    }
                }
            }
        }

        #expect(firstRepeat == secondRepeat)
    }

    @Test @MainActor func allMaterialGroupsBuildOneRealityKitMesh() throws {
        let mesh = try #require(SharedMeshes.flat(assignments))
        let groups = mesh.colorGroups.sorted { $0.key.rawValue < $1.key.rawValue }
            + mesh.boundaryColorGroups.sorted { $0.key.rawValue < $1.key.rawValue }
        var indices = [UInt32]()
        var materials = [UInt32]()
        for (materialIndex, group) in groups.enumerated() {
            indices.append(contentsOf: group.value)
            materials.append(contentsOf: repeatElement(
                UInt32(materialIndex),
                count: group.value.count / 3
            ))
        }
        var descriptor = MeshDescriptor(name: "hira-genji-surface-test")
        descriptor.positions = MeshBuffer(mesh.positions)
        descriptor.normals = MeshBuffer(mesh.normals)
        descriptor.textureCoordinates = MeshBuffer(mesh.textureCoordinates)
        descriptor.primitives = .triangles(indices)
        descriptor.materials = .perFace(materials)
        _ = try MeshResource.generate(from: [descriptor])
    }

    @Test func malformedInputsFailSafely() throws {
        let pattern = try #require(Flat16SurfacePatternGenerator.generate(assignments: assignments))
        #expect(Flat16SurfaceMesh.generate(
            pattern: Flat16SurfacePattern(
                patches: Array(pattern.patches.dropLast()),
                rowCount: pattern.rowCount,
                aspectRatio: pattern.aspectRatio
            )
        ) == nil)
        // A pattern that declares no shape cannot say how long a repeat is.
        #expect(Flat16SurfaceMesh.generate(
            pattern: Flat16SurfacePattern(
                patches: pattern.patches,
                rowCount: pattern.rowCount,
                aspectRatio: 0
            )
        ) == nil)
        #expect(Flat16SurfaceMesh.generate(pattern: pattern, halfWidth: .nan) == nil)
        #expect(Flat16SurfaceMesh.generate(pattern: pattern, halfThickness: 0) == nil)
        // Too round and too flat: both are outside the flat braid's own section.
        #expect(Flat16SurfaceMesh.generate(pattern: pattern, halfThickness: 0.5) == nil)
        #expect(Flat16SurfaceMesh.generate(pattern: pattern, halfThickness: 0.12) == nil)
        #expect(Flat16SurfaceMesh.generate(pattern: pattern, patternRepeatCount: 0) == nil)
    }

    private var assignments: [ThreadAssignment] {
        (1...16).map {
            ThreadAssignment(
                position: $0,
                colorID: ThreadColorCatalog.colors[$0 % ThreadColorCatalog.colors.count].id
            )
        }
    }

    private func extent(_ values: [Float]) -> Float {
        (values.max() ?? 0) - (values.min() ?? 0)
    }

    /// Cross-section and shading of the vertices on one end of the tile.
    ///
    /// Compared with a tolerance rather than as rounded text: the two ends are
    /// reached through different patches of the pattern, so the same point comes
    /// out a unit or two of Float apart, and a fixed rounding splits such a pair
    /// whenever it happens to straddle a step.
    private func boundaryProfile(
        _ indices: [Int],
        mesh: Flat16SurfaceMeshData
    ) -> [[Float]] {
        indices.map { index in
            [
                mesh.positions[index].y,
                mesh.positions[index].z,
                mesh.normals[index].y,
                mesh.normals[index].z,
                mesh.boundaryDistances[index],
            ]
        }
        .sorted(by: isOrderedBefore)
    }

    /// The twist stripes are drawn from a map read with the mesh's own texture
    /// coordinates, so the two ends of the tile have to sample the same phase for
    /// instanced tiles to meet without a seam in the stripes.
    private func twistPhaseProfile(
        _ indices: [Int],
        mesh: Flat16SurfaceMeshData
    ) -> [[Float]] {
        let twist = Flat16StitchTwistGrouping.groups().first
        return indices.map {
            let uv = mesh.textureCoordinates[$0]
            let phase = twist?.phase(along: uv.y, across: uv.x) ?? 0
            return [cos(phase)]
        }
        .sorted(by: isOrderedBefore)
    }

    private func isOrderedBefore(_ first: [Float], _ second: [Float]) -> Bool {
        for (left, right) in zip(first, second) where left != right {
            return left < right
        }
        return false
    }

    private func matches(_ first: [[Float]], _ second: [[Float]], tolerance: Float) -> Bool {
        first.count == second.count && zip(first, second).allSatisfy { left, right in
            zip(left, right).allSatisfy { abs($0 - $1) <= tolerance }
        }
    }
}
