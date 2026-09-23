import CoreGraphics
import Foundation
import RealityKit
import simd
import Testing
@testable import Kumihimo

struct MaruGenjiSurfaceMeshTests {
    @Test func meshIsFiniteGroupedAndNondegenerate() throws {
        let mesh = try makeMesh()

        #expect(mesh.positions.count == mesh.normals.count)
        #expect(mesh.positions.count == mesh.tangents.count)
        #expect(mesh.positions.count == mesh.bitangents.count)
        #expect(mesh.positions.count == mesh.textureCoordinates.count)
        #expect(mesh.positions.count == mesh.strandCoordinates.count)
        #expect(mesh.positions.count == mesh.twistPhases.count)
        #expect(mesh.positions.count == mesh.vertexSegmentIndices.count)
        #expect(mesh.positions.count == mesh.vertexIsBeneath.count)
        #expect(mesh.positions.allSatisfy(isFinite))
        #expect(mesh.normals.allSatisfy(isUnit))
        #expect(mesh.tangents.allSatisfy(isUnit))
        #expect(mesh.bitangents.allSatisfy(isUnit))
        #expect(mesh.textureCoordinates.allSatisfy(isFiniteUnitCoordinate))
        #expect(mesh.strandCoordinates.allSatisfy { $0.x.isFinite && (-1.001...1.001).contains($0.y) })
        #expect(mesh.twistPhases.allSatisfy { $0.isFinite })
        #expect(Set(mesh.colorGroups.keys) == Set([blue, pink]))
        #expect(mesh.colorGroups.values.allSatisfy { !$0.isEmpty })
        #expect(mesh.triangleSegmentIndices.count == mesh.triangleCount)
        #expect(mesh.triangleSegmentIndices.count == mesh.triangleIsBeneath.count)

        let indices = mesh.allTriangleIndices
        #expect(indices.count.isMultiple(of: 3))
        #expect(indices.allSatisfy { Int($0) < mesh.positions.count })
        for offset in stride(from: 0, to: indices.count, by: 3) {
            let first = mesh.positions[Int(indices[offset])]
            let second = mesh.positions[Int(indices[offset + 1])]
            let third = mesh.positions[Int(indices[offset + 2])]
            #expect(simd_length_squared(simd_cross(second - first, third - first))
                > RoundTube16SurfaceMesh.minimumTriangleCross)
        }
    }

    @Test func meshContainsNoEndCapTriangles() throws {
        let mesh = try makeMesh()
        let indices = mesh.allTriangleIndices

        for offset in stride(from: 0, to: indices.count, by: 3) {
            let triangle = (0..<3).map { mesh.positions[Int(indices[offset + $0])] }
            let hasConstantX = triangle.allSatisfy { abs($0.x - triangle[0].x) < 0.000_001 }
            #expect(!hasConstantX)
        }
    }

    @Test func everySurfacePatchReachesTheMesh() throws {
        let pattern = try #require(
            RoundTube16SurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let mesh = try #require(SharedMeshes.tube(fixtureAssignments))

        #expect(mesh.triangleSegmentIndices.allSatisfy { pattern.patches.indices.contains($0) })
        for index in pattern.patches.indices {
            #expect(mesh.triangleSegmentIndices.contains(index))
        }
    }

    // MARK: - Wrapping aspect

    @Test func thePatternDeclaresTheRepeatMatchedToThePhotographedBraid() {
        // Read off the author's own braid, not calculated: a V every 0.44 to 0.47
        // braid widths, one V a row (Task 047 rework; Task 005I's 0.65 read one V
        // as two rows).
        #expect(abs(RoundTube16SurfacePatternGenerator.patternAspectRatio - 1.25) < 0.000_1)
        #expect(RoundTube16SurfacePattern(patches: []).aspectRatio
            == RoundTube16SurfacePatternGenerator.patternAspectRatio)
    }

    /// The one number the density depends on. A repeat is eight chevron rows, so the
    /// rows land `π × aspect / 8` braid widths apart. **Every row is a V** since the
    /// Task 047 rework drew every bundle the same size; until then a V was counted
    /// as a pair of rows, one over and one under, which the drawing then set apart.
    @Test(arguments: [(Float(0.48), 4), (Float(0.2), 7), (Float(1.35), 3)])
    func theChevronDensityFollowsTheDeclaredAspectAtAnySize(
        _ radius: Float,
        _ repeatCount: Int
    ) throws {
        let mesh = try #require(
            SharedMeshes.tube(fixtureAssignments, radius: radius, patternRepeatCount: repeatCount)
        )
        // Measured across the drawn surface, not across the mean one. A photograph
        // sees the braid's silhouette, and raising the crest fattens the braid
        // without moving the chevron pitch, so the density a photograph reads drifts
        // even though the pattern is untouched. `baseRadius` cannot see that: it
        // stays put whatever the crest does, which left the density unguarded
        // against exactly the change Task 005J was weighing.
        let vsPerBraidWidth = 8 * mesh.visibleWidth / mesh.patternRepeatLength

        // The author's own braid reads 2.13 Vs a braid width top-down and 2.27 close
        // up. The band is those two readings widened by 10 per cent either way. It
        // reads 2.22 with the crest line at 1.09 radii. The crest and the pattern's
        // aspect ratio are still not separable from a photograph (see
        // `docs/architecture.md`「畝の高さと模様の縦横比は写真からは分離できない」).
        #expect((1.9...2.5).contains(vsPerBraidWidth))
        // **Task 052 raised the crest and lowered the valley by the same 0.08**, so
        // the outline, and the density over it, did not move. Held here, so that a
        // rounder bundle cannot quietly fatten the braid and thin its chevrons.
        #expect(abs(mesh.crestRadius / mesh.baseRadius - 1.09) < 0.000_1)
    }

    @Test(arguments: [
        (Float(0.48), 4),
        (Float(0.48), 1),
        (Float(0.2), 7),
        (Float(1.35), 3),
    ])
    func oneRepeatMeasuresTheCircumferenceTimesTheDeclaredAspect(
        _ radius: Float,
        _ repeatCount: Int
    ) throws {
        let pattern = try #require(
            RoundTube16SurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let mesh = try #require(
            SharedMeshes.tube(fixtureAssignments, radius: radius, patternRepeatCount: repeatCount)
        )

        #expect(abs(mesh.patternAspectRatio - pattern.aspectRatio) < 0.000_1)
        #expect(abs(mesh.circumference - 2 * .pi * radius) < 0.000_1)
        #expect(abs(mesh.length - 2 * .pi * radius * pattern.aspectRatio * Float(repeatCount))
            < 0.000_1)
        #expect(mesh.patternRepeatCount == repeatCount)

        // The generated geometry, not just the reported length, spans that tile.
        let extremes = mesh.positions.map(\.x)
        #expect(abs((extremes.min() ?? 0) + mesh.length / 2) < 0.000_1)
        #expect(abs((extremes.max() ?? 0) - mesh.length / 2) < 0.000_1)
    }

    @Test func defaultsDeriveTheLengthFromTheRadiusAndTheAspect() {
        let expected = 2 * Float.pi
            * RoundTube16SurfaceMesh.defaultRadius
            * RoundTube16SurfacePatternGenerator.patternAspectRatio
            * Float(RoundTube16SurfaceMesh.defaultPatternRepeatCount)

        #expect(abs(RoundTube16SurfaceMesh.defaultLength - expected) < 0.000_1)
        #expect(abs(RoundTube16SurfaceMesh.defaultLength - 15.080) < 0.005)
    }

    @Test func everyRidgeLeansAtTheAngleTheDeclaredAspectImplies() throws {
        let pattern = try #require(
            RoundTube16SurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let mesh = try #require(SharedMeshes.tube(fixtureAssignments))

        // Grouped once, so the cost is the vertices once over rather than once per
        // strand: 64 walks of 419,184 vertices took 20 seconds (Task 052).
        let vertices = verticesBySegment(of: mesh)
        let angles = try pattern.patches.indices.map { index in
            try crestAngleToAxisInDegrees(of: mesh, segmentIndex: index, vertices: vertices[index] ?? [])
        }

        #expect(angles.count == RoundTube16SurfacePatternGenerator.patchCount)
        // The angle is a consequence of the density, not a target of its own: a
        // repeat 1.25 turns long puts a chevron at atan(1 / 1.25), 38.7 degrees, off
        // the axis. The tolerance only covers the sampling of the crest, not a shear.
        #expect(angles.allSatisfy { abs($0 - ridgeAngleToAxisInDegrees) < 1 })
        #expect(abs(ridgeAngleToAxisInDegrees - 38.7) < 0.5)
    }

    @Test func theRidgeAngleIsIndependentOfTheRadiusAndTheRepeatCount() throws {
        for (radius, repeatCount) in [(Float(0.2), 7), (Float(1.35), 3)] {
            let mesh = try #require(
                SharedMeshes.tube(fixtureAssignments, radius: radius, patternRepeatCount: repeatCount)
            )
            let angle = try crestAngleToAxisInDegrees(of: mesh, segmentIndex: 0)
            #expect(abs(angle - ridgeAngleToAxisInDegrees) < 1)
        }
    }

    /// The lean the declared aspect puts a chevron at, measured from the braid axis.
    private var ridgeAngleToAxisInDegrees: Float {
        atan(1 / RoundTube16SurfacePatternGenerator.patternAspectRatio) * 180 / .pi
    }

    // MARK: - Round strands

    @Test func everyStrandIsARidgeWithItsEdgesInTheSharedValley() throws {
        let pattern = try #require(
            RoundTube16SurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let mesh = try #require(SharedMeshes.tube(fixtureAssignments))
        let base = RoundTube16SurfaceMesh.defaultRadius
        let tolerance: Float = 0.000_1

        // Grouped once rather than walked once per strand (Task 052; see
        // `everyRidgeLeansAtTheAngleTheDeclaredAspectImplies`).
        let bySegment = verticesBySegment(of: mesh)
        for index in pattern.patches.indices {
            // Excludes the walls sealing a crossing and the lap past a strand's own
            // ends, which both sit at or below the valley floor by design.
            let vertices = (bySegment[index] ?? []).filter {
                !mesh.vertexIsBeneath[$0]
                    && (0...1).contains(mesh.strandCoordinates[$0].x)
            }
            #expect(!vertices.isEmpty)

            let crest = vertices.filter { abs(mesh.strandCoordinates[$0].y) < 0.000_1 }
            // The rim towards the next row. The one towards the previous row
            // stands on that row since Task 052 (`shingleRimHeight`).
            let edges = vertices.filter { mesh.strandCoordinates[$0].y > 1 - 0.000_1 }
            let restingEdges = vertices.filter { mesh.strandCoordinates[$0].y < -1 + 0.000_1 }
            #expect(!crest.isEmpty)
            #expect(!edges.isEmpty)
            // Above its own rim by at least the crest left where it passes under.
            // **Not above `base` any more** (Task 052): the valley was moved down
            // with the crest, so the sunk end of a bundle lies below the nominal
            // radius, beneath the bundle passing over it.
            let lowestCrest = mesh.valleyFloorRadius + base
                * RoundTube16SurfaceMesh.crestHeightRatio
                * (1 - RoundTube16SurfaceMesh.underCrossingDip)
            #expect(crest.allSatisfy { radius(of: mesh, at: $0) > lowestCrest - tolerance })
            #expect(edges.allSatisfy { radius(of: mesh, at: $0) <= base + tolerance })
            #expect(edges.allSatisfy {
                abs(radius(of: mesh, at: $0) - mesh.valleyFloorRadius) < tolerance
            })
            #expect(!restingEdges.isEmpty)
            #expect(restingEdges.allSatisfy { radius(of: mesh, at: $0) > mesh.valleyFloorRadius })
        }
    }

    /// **A bundle's face turns into its shoulder, and lies down again at its
    /// rims** (Task 052). Measured at mid-span, as the angle between the face
    /// and straight out, at the cross-section's own samples.
    ///
    /// Towards the next row, a third, three fifths, four fifths and nineteen
    /// twentieths of the way to the rim: 23, 38, 42, 33 degrees.
    /// - The shoulder turns about 40. At a crest of 0.12 it turned under 30, a
    ///   broad face the author read as a flat tile.
    /// - The belly turns less than the shoulder, so it is round rather than a
    ///   ridge down a flat roof.
    /// - **Near the rim it lies down again** — a bundle of threads does not stand
    ///   in a cliff (the author). The plain parabola turned 49 there, steepest at
    ///   the rim, and read as a cut wall wherever one bundle lay over another.
    ///   But not flat: laid down to 12 the bundle read as a spindle.
    ///
    /// Towards the previous row, where it rests on that row: 19, 26, 23, 11. It
    /// lies on the row it rests on rather than standing off it.
    @Test func aBundlesFaceTurnsIntoItsShoulderAndLiesDownAtItsRims() throws {
        let mesh = try makeMesh()
        func turn(at across: Float) -> Float? {
            let turns = mesh.positions.indices.compactMap { index -> Float? in
                let strand = mesh.strandCoordinates[index]
                guard
                    !mesh.vertexIsBeneath[index],
                    abs(strand.x - 0.5) < 0.000_1,
                    abs(strand.y - across) < 0.01
                else { return nil }
                let position = mesh.positions[index]
                let outwards = simd_normalize(SIMD3<Float>(0, position.y, position.z))
                return acos(min(simd_dot(mesh.normals[index], outwards), 1)) * 180 / .pi
            }.sorted()
            return turns.isEmpty ? nil : turns[turns.count / 2]
        }
        // The cross-section's own samples: sin(pi/2 (2k/10 - 1)).
        let belly = try #require(turn(at: 0.309))
        let shoulder = max(try #require(turn(at: 0.588)), try #require(turn(at: 0.809)))
        let rim = try #require(turn(at: 0.951))
        #expect((36...46).contains(shoulder), "the shoulder turns \(shoulder) degrees")
        #expect(belly < shoulder / 1.3, "belly \(belly), shoulder \(shoulder)")
        #expect(rim < shoulder * 0.85, "rim \(rim), shoulder \(shoulder)")
        #expect(rim > shoulder * 0.5, "rim \(rim), shoulder \(shoulder)")
        let resting = try #require(turn(at: -0.951))
        #expect(resting < shoulder / 2, "resting rim \(resting), shoulder \(shoulder)")
    }

    @Test func radiusStaysInsideTheConfiguredReliefRange() throws {
        let mesh = try makeMesh()
        let base = RoundTube16SurfaceMesh.defaultRadius
        let highest = base * (
            1 - RoundTube16SurfaceMesh.valleyDepthRatio
                + RoundTube16SurfaceMesh.crestHeightRatio
                * (1 + RoundTube16SurfaceMesh.overCrossingLift)
        )
        let radii = mesh.positions.indices.map { radius(of: mesh, at: $0) }

        // A buried tip ends below the floor, and the floor lies below every rim.
        let lowest = min(
            RoundTube16SurfaceMesh.beneathRadius(radius: base),
            mesh.valleyFloorRadius - base * RoundTube16SurfaceMesh.crestHeightRatio
                * RoundTube16SurfaceMesh.buriedTipSink
        )
        #expect(radii.allSatisfy { $0 >= lowest - 0.000_1 })
        #expect(radii.allSatisfy { $0 <= highest + 0.000_1 })
        // The silhouette has to undulate rather than trace a circle.
        #expect((radii.max() ?? 0) - (radii.min() ?? 0) > base * 0.08)
    }

    /// At every crossing a bundle's trailing end, which passes over, stands
    /// above the next bundle's leading end, which passes under; and a bundle's
    /// rim lies on the valley floor all along its own span, whatever its crest.
    @Test func theEndPassingOverACrossingStandsAboveTheEndPassingUnder() {
        let radius = RoundTube16SurfaceMesh.defaultRadius
        let floor = radius * (1 - RoundTube16SurfaceMesh.valleyDepthRatio)

        for step in 0...20 {
            let across = Float(step) / 10 - 1
            let over = RoundTube16SurfaceMesh.strandRadius(along: 1, across: across, radius: radius)
            let under = RoundTube16SurfaceMesh.strandRadius(along: 0, across: across, radius: radius)
            #expect(over >= under)
            #expect(under >= floor - 0.000_1)
        }
        for along in [Float(0), Float(0.5), Float(1)] {
            // The rim towards the next row lies on the floor; the one towards the
            // previous row stands `shingleRimHeight` of the crest there above it
            // (Task 052), so it rests on that row's flank.
            #expect(abs(RoundTube16SurfaceMesh.strandRadius(
                along: along, across: 1, radius: radius
            ) - floor) < 0.000_01)
            let resting = floor + radius * RoundTube16SurfaceMesh.crestHeightRatio
                * RoundTube16SurfaceMesh.crossingCrestFactor(along: along)
                * RoundTube16SurfaceMesh.shingleRimHeight
            #expect(abs(RoundTube16SurfaceMesh.strandRadius(
                along: along, across: -1, radius: radius
            ) - resting) < 0.000_01)
        }
    }

    /// Every cell has its floor laid beneath its bundle, at the floor's radius,
    /// so a gap between bundles shows the thread lying there rather than the
    /// background (Task 047 rework; this replaced the walls that sealed a
    /// crossing step, which bundles that overlap no longer have).
    @Test func everyCellHasItsFloorBeneathItsBundle() throws {
        let pattern = try #require(
            RoundTube16SurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let mesh = try #require(SharedMeshes.tube(fixtureAssignments))
        let floor = RoundTube16SurfaceMesh.beneathRadius(radius: mesh.baseRadius)

        #expect(mesh.triangleIsBeneath.contains(true))
        #expect(mesh.triangleIsBeneath.contains(false))
        for index in pattern.patches.indices {
            #expect(zip(mesh.triangleSegmentIndices, mesh.triangleIsBeneath)
                .contains { $0 == index && $1 })
        }
        for index in mesh.positions.indices where mesh.vertexIsBeneath[index] {
            #expect(abs(simd_length(SIMD2<Float>(mesh.positions[index].y,
                                                 mesh.positions[index].z)) - floor) < 0.000_1)
        }
    }

    // MARK: - Seams

    @Test func longitudinalTileBoundariesHaveMatchingGeometry() throws {
        let mesh = try makeMesh()
        let halfLength = RoundTube16SurfaceMesh.defaultLength / 2
        // The visible skin has to present the same ring at both ends so tiles can be
        // repeated. The floor is left out; it is checked on its own.
        let surface = mesh.positions.indices.filter { !mesh.vertexIsBeneath[$0] }
        let start = surface.filter { abs(mesh.positions[$0].x + halfLength) < 0.000_001 }
        let end = surface.filter { abs(mesh.positions[$0].x - halfLength) < 0.000_001 }

        #expect(!start.isEmpty)
        #expect(boundariesMatch(start, end, in: mesh))
        #expect(edgeColorIDs(start, in: mesh) == edgeColorIDs(end, in: mesh))
    }

    /// The floor alone closes the tube, the circumferential seam included: every
    /// line of sight across the braid meets it twice. Whatever the bundles do
    /// above it, nothing behind can show.
    @Test func theFloorAloneClosesTheTubeAcrossTheSeam() throws {
        let mesh = try makeMesh()
        let all = mesh.allTriangleIndices
        var floor = [UInt32]()
        for offset in stride(from: 0, to: all.count, by: 3)
        where mesh.vertexIsBeneath[Int(all[offset])] {
            floor.append(contentsOf: all[offset..<(offset + 3)])
        }
        for axis in SurfaceOpacityAudit.Axis.allCases {
            let audit = SurfaceOpacityAudit(
                positions: mesh.positions,
                indices: floor,
                tileEndX: mesh.length / 2,
                axis: axis
            )
            #expect(audit.rays > 1_000)
            #expect(audit.raysReachingTheBackground == 0)
            #expect(audit.raysMeetingOneSurfaceOnly == 0)
        }
    }

    // MARK: - Twist

    @Test func twistPhaseIsAffineAndThereforeContinuousInsideAStrand() throws {
        let mesh = try makeMesh()

        #expect(mesh.twist.groups.allSatisfy { $0.coefficients.phasePerAlong.isFinite })
        #expect(mesh.twist.groups.allSatisfy { $0.coefficients.phasePerAcross.isFinite })
        #expect(mesh.twist.groups.allSatisfy { abs($0.coefficients.phasePerAcross) > 0 })
        // The same number of stripes runs down every strand, whichever group it is
        // in, so only the shear the group corrects for differs.
        #expect(mesh.twist.groups.allSatisfy {
            abs($0.coefficients.phasePerAlong)
                == 2 * .pi * Float(RoundTube16SurfaceMesh.strandFibreCount)
        })

        // Grouped once rather than walked once per strand (Task 056; see
        // `twistPhaseFit`).
        let bySegment = verticesBySegment(of: mesh)
        for segmentIndex in 0..<RoundTube16SurfacePatternGenerator.patchCount {
            let fit = try twistPhaseFit(
                of: mesh, segmentIndex: segmentIndex, vertices: bySegment[segmentIndex] ?? [])
            let coefficients = try #require(mesh.twist.coefficients(forSegment: segmentIndex))
            // An affine phase is a phase with no break in it: every vertex of the
            // strand sits on one plane through (along, across, phase).
            #expect(fit.maximumResidual < 0.001)
            #expect(abs(fit.phasePerAlong - coefficients.phasePerAlong) < 0.001)
            #expect(abs(fit.phasePerAcross - coefficients.phasePerAcross) < 0.001)
        }

        for index in mesh.positions.indices {
            let coefficients = try #require(
                mesh.twist.coefficients(forSegment: mesh.vertexSegmentIndices[index])
            )
            let expected = coefficients.phase(
                along: mesh.strandCoordinates[index].x,
                across: mesh.strandCoordinates[index].y
            )
            #expect(abs(mesh.twistPhases[index] - expected) < 0.000_5)
        }
    }

    /// Replaces `twistKeepsOneHandAndOneAnglePerChevronDirection`, which recorded
    /// the compromise a single shared stripe texture forced: it asserted that the
    /// two chevron directions ended up at two different angles, one short of the
    /// nominal twist and one past it. Task 005G gives each twist group its own
    /// texture, so the compromise is gone and the completed behaviour — one angle
    /// and one hand on all 64 strands — is what is asserted here.
    @Test func twistKeepsOneHandAndOneAngleOnEveryStrand() throws {
        let mesh = try makeMesh()
        let surface = BraidStrandSurfaceBuilder.surface(
            for: try #require(
                RoundTube16SurfacePatternGenerator.generate(assignments: fixtureAssignments)
            )
        )

        // Grouped once rather than walked once per strand (Task 056).
        let bySegment = verticesBySegment(of: mesh)
        let angles = try surface.segments.indices.map { segmentIndex in
            try stripeAngleInDegrees(
                of: mesh,
                surface: surface,
                segmentIndex: segmentIndex,
                vertices: bySegment[segmentIndex] ?? []
            )
        }

        #expect(angles.count == RoundTube16SurfacePatternGenerator.patchCount)
        // Every strand twists the same way round, which is what makes the braid
        // read as one yarn rather than two.
        #expect(angles.allSatisfy { $0 > 0 })
        #expect(angles.allSatisfy {
            abs($0 - RoundTube16SurfaceMesh.twistAngleDegrees) <= 3
        })
    }

    @Test func twistGroupsStayWithinOneTexturePairAndMatchTheGeneratedTextures() throws {
        let mesh = try makeMesh()

        // Two chevron directions, so two shears to correct and two textures. More
        // groups than this would mean more materials than colours times two.
        #expect(mesh.twist.groups.count == 2)
        #expect(mesh.twist.groupIndexBySegment.count
            == RoundTube16SurfacePatternGenerator.patchCount)
        #expect(Set(mesh.twist.groupIndexBySegment) == Set(mesh.twist.groups.indices))
        #expect(mesh.materialGroups.count
            <= Set(mesh.materialGroups.keys.map(\.colorID)).count * 2)
        #expect(mesh.materialGroups.keys.allSatisfy {
            mesh.twist.groups.indices.contains($0.twistGroupIndex)
        })

        // The maps are baked from a fixed reference surface, so their groups have
        // to be numbered the same way the mesh numbers its own.
        let factoryGroups = RoundTube16StrandTextureFactory.twistGroups
        #expect(factoryGroups.count == mesh.twist.groups.count)
        for (factory, group) in zip(factoryGroups, mesh.twist.groups) {
            #expect(abs(factory.coefficients.phasePerAlong
                - group.coefficients.phasePerAlong) < 0.001)
            #expect(abs(factory.coefficients.phasePerAcross
                - group.coefficients.phasePerAcross) < 0.001)
        }
    }

    @Test func strandMapRowsCarryTheCrossSectionTheSamplerWillReadThere() {
        // The sampler reads a generated bitmap's rows in the reverse of the mesh's
        // own `v`, so the maps are drawn mirrored to compensate. Every map before
        // the twist was symmetric across the strand and could not show the
        // mirroring; the stripes can, so the convention is pinned here.
        #expect(RoundTube16StrandTextureFactory.crossSectionOffset(forRow: 0) == 1)
        #expect(RoundTube16StrandTextureFactory.crossSectionOffset(forRow: 1) == -1)
        #expect(abs(RoundTube16StrandTextureFactory.crossSectionOffset(forRow: 0.5)) < 0.000_1)
        for sample in stride(from: Float(0), through: 1, by: 0.125) {
            let offset = RoundTube16SurfaceMesh.crossSectionOffset(forSample: sample)
            let row = 1 - RoundTube16SurfaceMesh.crossSectionSample(forOffset: offset)
            #expect(abs(RoundTube16StrandTextureFactory.crossSectionOffset(forRow: row) - offset)
                < 0.000_1)
        }
    }

    @Test func twistGroupsAndStrandTexturesAreDeterministic() throws {
        let pattern = try #require(
            RoundTube16SurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let surface = BraidStrandSurfaceBuilder.surface(for: pattern)
        func grouping(radius: Float) -> RoundTube16SurfaceMesh.TwistGrouping {
            RoundTube16SurfaceMesh.twistGrouping(
                for: surface,
                radius: radius,
                length: RoundTube16SurfaceMesh.length(radius: radius),
                repeatCount: RoundTube16SurfaceMesh.defaultPatternRepeatCount
            )
        }

        #expect(grouping(radius: RoundTube16SurfaceMesh.defaultRadius)
            == grouping(radius: RoundTube16SurfaceMesh.defaultRadius))
        // A larger braid is the same braid: the strands group the same way and the
        // maps built once at the default radius still belong to them.
        #expect(grouping(radius: 2 * RoundTube16SurfaceMesh.defaultRadius)
            .groupIndexBySegment
            == grouping(radius: RoundTube16SurfaceMesh.defaultRadius)
            .groupIndexBySegment)

        for twist in RoundTube16StrandTextureFactory.twistGroups {
            #expect(pixels(RoundTube16StrandTextureFactory.occlusionImage(twist: twist))
                == pixels(RoundTube16StrandTextureFactory.occlusionImage(twist: twist)))
            #expect(pixels(RoundTube16StrandTextureFactory.roughnessImage(twist: twist))
                == pixels(RoundTube16StrandTextureFactory.roughnessImage(twist: twist)))
            #expect(pixels(RoundTube16StrandTextureFactory.normalImage(twist: twist))
                == pixels(RoundTube16StrandTextureFactory.normalImage(twist: twist)))
        }
        // Two groups sharing one set of maps would be the bug this task fixes.
        let normals = RoundTube16StrandTextureFactory.twistGroups.map {
            pixels(RoundTube16StrandTextureFactory.normalImage(twist: $0))
        }
        #expect(Set(normals.map { $0?.count ?? 0 }).count == 1)
        #expect(normals[0] != normals[1])
    }

    // MARK: - Regression

    @Test func meshGenerationIsDeterministic() throws {
        let pattern = try #require(
            RoundTube16SurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )
        let first = try #require(RoundTube16SurfaceMesh.generate(pattern: pattern))
        let second = try #require(RoundTube16SurfaceMesh.generate(pattern: pattern))

        #expect(first.positions == second.positions)
        #expect(first.normals == second.normals)
        #expect(first.tangents == second.tangents)
        #expect(first.bitangents == second.bitangents)
        #expect(first.textureCoordinates == second.textureCoordinates)
        #expect(first.strandCoordinates == second.strandCoordinates)
        #expect(first.twistPhases == second.twistPhases)
        #expect(first.colorGroups == second.colorGroups)
        #expect(first.triangleSegmentIndices == second.triangleSegmentIndices)
        #expect(first.triangleIsBeneath == second.triangleIsBeneath)
        #expect(first.triangleCount == second.triangleCount)
    }

    @Test func malformedPatternAndParametersFailSafely() throws {
        let pattern = try #require(
            RoundTube16SurfacePatternGenerator.generate(assignments: fixtureAssignments)
        )

        #expect(RoundTube16SurfaceMesh.generate(
            pattern: RoundTube16SurfacePattern(patches: Array(pattern.patches.dropLast()))
        ) == nil)
        #expect(RoundTube16SurfaceMesh.generate(pattern: pattern, radius: .nan) == nil)
        #expect(RoundTube16SurfaceMesh.generate(pattern: pattern, radius: 0) == nil)
        #expect(RoundTube16SurfaceMesh.generate(
            pattern: RoundTube16SurfacePattern(patches: pattern.patches, aspectRatio: 0)
        ) == nil)
        #expect(RoundTube16SurfaceMesh.generate(
            pattern: RoundTube16SurfacePattern(patches: pattern.patches, aspectRatio: .nan)
        ) == nil)
        #expect(RoundTube16SurfaceMesh.generate(pattern: pattern, patternRepeatCount: 0) == nil)
        #expect(RoundTube16SurfaceMesh.generate(
            pattern: pattern,
            alongStrandSubdivisions: RoundTube16SurfaceMesh.minimumAlongStrandSubdivisions - 1
        ) == nil)
        #expect(RoundTube16SurfaceMesh.generate(
            pattern: pattern,
            acrossStrandSubdivisions: RoundTube16SurfaceMesh.minimumAcrossStrandSubdivisions - 1
        ) == nil)
    }

    @Test @MainActor func allMaterialGroupsBuildOneRealityKitMesh() throws {
        for assignments in [
            fixtureAssignments,
            verifiedFixture1,
            ProjectEditorPreviewData.maruGenjiSurfaceFixture1,
        ] {
            let mesh = try #require(SharedMeshes.tube(assignments))

            var indices = [UInt32]()
            var materialIndices = [UInt32]()
            for (materialIndex, group) in mesh.colorGroups
                .sorted(by: { $0.key.rawValue < $1.key.rawValue })
                .enumerated() {
                indices.append(contentsOf: group.value)
                materialIndices.append(
                    contentsOf: repeatElement(UInt32(materialIndex), count: group.value.count / 3)
                )
            }
            var descriptor = MeshDescriptor(name: "maru-genji-surface")
            descriptor.positions = MeshBuffer(mesh.positions)
            descriptor.normals = MeshBuffer(mesh.normals)
            descriptor.tangents = MeshBuffer(mesh.tangents)
            descriptor.bitangents = MeshBuffer(mesh.bitangents)
            descriptor.textureCoordinates = MeshBuffer(mesh.textureCoordinates)
            descriptor.primitives = .triangles(indices)
            descriptor.materials = .perFace(materialIndices)
            _ = try MeshResource.generate(from: [descriptor])
        }
    }

    // MARK: - Helpers

    private let blue = ThreadColorID(rawValue: "blue")
    private let pink = ThreadColorID(rawValue: "pink")

    private var fixtureAssignments: [ThreadAssignment] {
        (1...16).map { position in
            ThreadAssignment(
                position: position,
                colorID: position.isMultiple(of: 2) ? pink : blue
            )
        }
    }

    private var verifiedFixture1: [ThreadAssignment] {
        let colors = [
            blue, pink, pink, blue,
            blue, pink, pink, blue,
            blue, pink, pink, blue,
            blue, pink, pink, blue,
        ]
        return colors.enumerated().map { index, colorID in
            ThreadAssignment(position: index + 1, colorID: colorID)
        }
    }

    /// The fixture's mesh, made once a run and shared (Task 056).
    private func makeMesh() throws -> RoundTube16SurfaceMeshData {
        try #require(SharedMeshes.tube(fixtureAssignments))
    }

    private func radius(of mesh: RoundTube16SurfaceMeshData, at index: Int) -> Float {
        let position = mesh.positions[index]
        return hypot(position.y, position.z)
    }

    /// Angle between a strand's stripes and the strand itself, in degrees, read
    /// off the phases the mesh actually carries. Normalized into (-90, 90]: a
    /// stripe and its reverse are the same stripe, so only that range tells the
    /// two hands apart.
    private func stripeAngleInDegrees(
        of mesh: RoundTube16SurfaceMeshData,
        surface: BraidStrandSurface,
        segmentIndex: Int,
        vertices: [Int]? = nil
    ) throws -> Float {
        // Measured on the bundle as drawn, at mid-span, where it is wider than its
        // cell (Task 047 rework). Towards its leading end a bundle narrows, and the
        // stripes meet it at another angle there.
        let segment = surface.segments[segmentIndex]
        let fit = try twistPhaseFit(of: mesh, segmentIndex: segmentIndex, vertices: vertices)
        let along = RoundTube16SurfaceMesh.worldOffset(
            segment.centerlineDelta,
            radius: mesh.baseRadius,
            length: mesh.length,
            repeatCount: mesh.patternRepeatCount
        )
        let across = RoundTube16SurfaceMesh.worldOffset(
            segment.meanHalfWidth * RoundTube16SurfaceMesh.bundleWidth(along: 0.5),
            radius: mesh.baseRadius,
            length: mesh.length,
            repeatCount: mesh.patternRepeatCount
        )
        // The direction the fitted phase does not change in, which is the
        // direction a stripe runs in on the unwrapped surface.
        let stripe = along * fit.phasePerAcross - across * fit.phasePerAlong
        var angle = signedAngle(from: along, to: stripe)
        while angle > 90 { angle -= 180 }
        while angle <= -90 { angle += 180 }
        return angle
    }

    /// Least-squares fit of `phase ≈ phasePerAlong * along + phasePerAcross *
    /// across + offset` over every vertex of one strand. A stripe that broke or
    /// restarted inside the strand would leave a residual behind.
    ///
    /// Pass the strand's `vertices` from `verticesBySegment(of:)` when fitting
    /// every strand: finding them here walks the whole mesh, and 64 such walks
    /// were most of what the two twist tests cost (Task 056). Either way they come
    /// in ascending order, so the sums run in the same order.
    private func twistPhaseFit(
        of mesh: RoundTube16SurfaceMeshData,
        segmentIndex: Int,
        vertices: [Int]? = nil
    ) throws -> (phasePerAlong: Float, phasePerAcross: Float, maximumResidual: Float) {
        let indices = vertices ?? mesh.positions.indices.filter {
            mesh.vertexSegmentIndices[$0] == segmentIndex
        }
        #expect(indices.count >= 3)

        var moments = simd_double3x3()
        var projection = SIMD3<Double>()
        for index in indices {
            let sample = SIMD3<Double>(
                Double(mesh.strandCoordinates[index].x),
                Double(mesh.strandCoordinates[index].y),
                1
            )
            moments += simd_double3x3(
                sample * sample.x,
                sample * sample.y,
                sample * sample.z
            )
            projection += sample * Double(mesh.twistPhases[index])
        }
        #expect(abs(moments.determinant) > 0.000_001)
        let solution = moments.inverse * projection

        let residual = indices.map { index -> Float in
            let expected = solution.x * Double(mesh.strandCoordinates[index].x)
                + solution.y * Double(mesh.strandCoordinates[index].y)
                + solution.z
            return Float(abs(Double(mesh.twistPhases[index]) - expected))
        }
        return (
            phasePerAlong: Float(solution.x),
            phasePerAcross: Float(solution.y),
            maximumResidual: residual.max() ?? 0
        )
    }

    private func pixels(_ image: CGImage?) -> Data? {
        guard let image, let data = image.dataProvider?.data else { return nil }
        return Data(referencing: data)
    }

    /// Angle between one strand's crest line and the braid axis, measured on the
    /// generated geometry: axial distance against arc length around the braid.
    /// Every vertex index, by the strand it belongs to.
    private func verticesBySegment(of mesh: RoundTube16SurfaceMeshData) -> [Int: [Int]] {
        Dictionary(grouping: mesh.positions.indices) { mesh.vertexSegmentIndices[$0] }
    }

    private func crestAngleToAxisInDegrees(
        of mesh: RoundTube16SurfaceMeshData,
        segmentIndex: Int,
        vertices: [Int]? = nil
    ) throws -> Float {
        let candidates = vertices ?? mesh.positions.indices.filter {
            mesh.vertexSegmentIndices[$0] == segmentIndex
        }
        let crest = candidates.filter {
            mesh.vertexSegmentIndices[$0] == segmentIndex
                && !mesh.vertexIsBeneath[$0]
                && abs(mesh.strandCoordinates[$0].y) < 0.000_1
                && (0...1).contains(mesh.strandCoordinates[$0].x)
        }
        // A strand is emitted once per repeat, so measure the instance nearest the
        // middle of the tile, which no tile-boundary clipping has shortened.
        let reference = try #require(crest.min { abs(mesh.positions[$0].x) < abs(mesh.positions[$1].x) })
        let instance = crest.filter {
            abs(mesh.positions[$0].x - mesh.positions[reference].x) < mesh.patternRepeatLength / 2
        }
        let start = try #require(instance.min { mesh.strandCoordinates[$0].x < mesh.strandCoordinates[$1].x })
        let end = try #require(instance.max { mesh.strandCoordinates[$0].x < mesh.strandCoordinates[$1].x })
        #expect(mesh.strandCoordinates[end].x - mesh.strandCoordinates[start].x > 0.9)

        let axial = mesh.positions[end].x - mesh.positions[start].x
        var turn = atan2(mesh.positions[end].z, mesh.positions[end].y)
            - atan2(mesh.positions[start].z, mesh.positions[start].y)
        // A strand covers an eighth of the circumference, so the shorter way round
        // is always its own direction, even where the tile seam resets the angle.
        while turn > .pi { turn -= 2 * .pi }
        while turn < -.pi { turn += 2 * .pi }
        let around = turn * mesh.baseRadius
        // A chevron leans either way, so measure the acute angle the ridge makes
        // with the axis rather than the direction it happens to be travelling in.
        let angle = abs(atan2(around, axial)) * 180 / .pi
        return min(angle, 180 - angle)
    }

    private func signedAngle(from first: SIMD2<Float>, to second: SIMD2<Float>) -> Float {
        let cross = first.x * second.y - first.y * second.x
        let dot = simd_dot(first, second)
        return atan2(cross, dot) * 180 / .pi
    }

    private func isFinite(_ vector: SIMD3<Float>) -> Bool {
        vector.x.isFinite && vector.y.isFinite && vector.z.isFinite
    }

    private func isUnit(_ vector: SIMD3<Float>) -> Bool {
        isFinite(vector) && abs(simd_length(vector) - 1) < 0.001
    }

    private func isFiniteUnitCoordinate(_ vector: SIMD2<Float>) -> Bool {
        vector.x.isFinite && vector.y.isFinite
            && (0...1).contains(vector.x)
            && (0...1).contains(vector.y)
    }

    /// A tile end must present the same ring of geometry at both ends so instances
    /// can be repeated. Strand surfaces and the walls sealing a crossing are matched
    /// separately: they can share a position on the valley line while facing apart.
    private func boundariesMatch(
        _ startIndices: [Int],
        _ endIndices: [Int],
        in mesh: RoundTube16SurfaceMeshData
    ) -> Bool {
        func hasMatch(for sourceIndex: Int, in candidates: [Int]) -> Bool {
            let sourcePosition = mesh.positions[sourceIndex]
            let sourceNormal = mesh.normals[sourceIndex]
            let sourceIsWall = mesh.vertexIsBeneath[sourceIndex]
            return candidates.contains { candidateIndex in
                guard mesh.vertexIsBeneath[candidateIndex] == sourceIsWall else { return false }
                let candidatePosition = mesh.positions[candidateIndex]
                return hypot(
                    sourcePosition.y - candidatePosition.y,
                    sourcePosition.z - candidatePosition.z
                ) < 0.000_2
                    && simd_distance(sourceNormal, mesh.normals[candidateIndex]) < 0.002
            }
        }

        return startIndices.allSatisfy { hasMatch(for: $0, in: endIndices) }
            && endIndices.allSatisfy { hasMatch(for: $0, in: startIndices) }
    }

    private func edgeColorIDs(
        _ boundaryIndices: [Int],
        in mesh: RoundTube16SurfaceMeshData
    ) -> Set<ThreadColorID> {
        let boundarySet = Set(boundaryIndices.map(UInt32.init))
        return Set(mesh.colorGroups.compactMap { colorID, indices in
            indices.contains(where: boundarySet.contains) ? colorID : nil
        })
    }
}
