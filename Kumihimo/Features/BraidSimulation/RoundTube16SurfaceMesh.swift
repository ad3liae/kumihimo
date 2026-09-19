import Foundation
import simd

/// One draw group: the thread colour it is painted in, and the twist group whose
/// stripe textures it is dressed with.
struct RoundTube16SurfaceMaterialKey: Hashable, Sendable {
    let colorID: ThreadColorID
    let twistGroupIndex: Int
    /// Which side of its crossings the strand takes. The two sides are shaded
    /// apart — a strand is darkened where it goes under, not where it lies on
    /// top — and their maps span different lengths (Task 047).
    let layer: BraidCrossingLayer
}

struct RoundTube16SurfaceMeshData: Sendable {
    let positions: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let tangents: [SIMD3<Float>]
    let bitangents: [SIMD3<Float>]
    /// Strand-local coordinates: `x` runs 0...1 along the strand's texture, `y`
    /// runs 0...1 across it. On a strand passing over, `x` spans the laps as well
    /// (`textureAlong`), so the stripes run on into them instead of smearing.
    /// The stripe angle a strand needs is carried by its twist group's textures,
    /// not by these coordinates.
    let textureCoordinates: [SIMD2<Float>]
    /// Bundle coordinates: `x` runs along the bundle and reaches past 0...1 where
    /// it laps over a crossing or tucks under one; `y` runs across it, -1...1, 0 on
    /// the crest.
    let strandCoordinates: [SIMD2<Float>]
    /// Twist phase in radians. Continuous inside one strand segment.
    let twistPhases: [Float]
    /// The twist groups the strands fall into, and which group each strand uses.
    let twist: RoundTube16SurfaceMesh.TwistGrouping
    /// Triangle indices per colour, twist group and layer. One material per entry.
    let materialGroups: [RoundTube16SurfaceMaterialKey: [UInt32]]
    let vertexSegmentIndices: [Int]
    /// The floor laid beneath every cell, as against the bundle drawn over it.
    let vertexIsBeneath: [Bool]
    let triangleSegmentIndices: [Int]
    let triangleIsBeneath: [Bool]
    /// Every vertex sitting on the circumferential seam, at `u == 0` and `u == 1`.
    let seamStartVertexIndices: [Int]
    let seamEndVertexIndices: [Int]
    let baseRadius: Float
    let valleyFloorRadius: Float
    /// Length of the whole tile along the braid axis.
    let length: Float
    let patternRepeatCount: Int

    var circumference: Float {
        2 * .pi * baseRadius
    }

    /// The top of a strand's ridge away from a crossing — the line the finished
    /// braid's outline follows, and so what a photograph measures across.
    ///
    /// `baseRadius` is the mean surface and does not move when the crest does,
    /// which is why it cannot stand in for this. The other candidate, the widest
    /// point of the drawn surface, sits higher still: a strand lifts over a
    /// crossing, and that local bump does not set the outline. Measuring the
    /// rendered outline against both settles it — the ridge line is out by
    /// −1.2 to −1.6 per cent at every crest, which is the sub-pixel edge, while
    /// the widest point is out by −3.3 to −5.4 per cent and **the error grows
    /// with the crest**, so no constant could absorb it.
    ///
    /// Read through `strandRadius` rather than from the constants directly, so a
    /// change to how the ridge is built comes through here too. Mid-span puts the
    /// crossing weight at zero and the cross-section on its crest.
    var crestRadius: Float {
        RoundTube16SurfaceMesh.strandRadius(
            layer: .over, along: 0.5, across: 0, radius: baseRadius
        )
    }

    /// What a photograph of the finished braid measures across.
    /// See `docs/architecture.md`「紐幅の取り方」.
    var visibleWidth: Float {
        2 * crestRadius
    }

    var patternRepeatLength: Float {
        length / Float(patternRepeatCount)
    }

    /// One repeat along the braid divided by one turn around it. Matches the
    /// aspect ratio the surface pattern declares, whatever the radius is.
    var patternAspectRatio: Float {
        patternRepeatLength / circumference
    }

    var triangleCount: Int {
        materialGroups.values.reduce(0) { $0 + $1.count / 3 }
    }

    var allTriangleIndices: [UInt32] {
        sortedMaterialGroups.flatMap(\.value)
    }

    /// Triangle indices per colour, with the twist groups of one colour merged.
    /// The renderer draws the twist groups apart; everything that only cares
    /// which thread a triangle belongs to reads them together.
    var colorGroups: [ThreadColorID: [UInt32]] {
        sortedMaterialGroups.reduce(into: [ThreadColorID: [UInt32]]()) { result, group in
            result[group.key.colorID, default: []].append(contentsOf: group.value)
        }
    }

    /// Draw groups in a fixed order, so every derived grouping is deterministic.
    var sortedMaterialGroups: [(key: RoundTube16SurfaceMaterialKey, value: [UInt32])] {
        materialGroups.sorted {
            if $0.key.colorID.rawValue != $1.key.colorID.rawValue {
                return $0.key.colorID.rawValue < $1.key.colorID.rawValue
            }
            if $0.key.twistGroupIndex != $1.key.twistGroupIndex {
                return $0.key.twistGroupIndex < $1.key.twistGroupIndex
            }
            return $0.key.layer == .over && $1.key.layer == .under
        }
    }
}

/// Turns the fixed surface pattern into a braid of separate, overlapping thread
/// bundles.
///
/// **Each cell of the pattern is drawn as one bundle, and the bundle is not the
/// cell** (Task 047 rework). The cell says which thread is where and which side
/// of each crossing it takes; the bundle is that thread's visible run, wider than
/// its cell so it lies over its neighbours' flanks, and longer, so that a bundle
/// passing over a crossing goes on across it with its full width over the end of
/// the bundle passing under, and only then narrows and sinks beneath the bundles
/// beyond. The bundle passing under narrows and sinks at its ends and is buried.
/// **Whichever bundle stands higher at a place is the one seen**; the depth test
/// draws the outline where two meet, so a hidden outline breaks off under the
/// one that goes on. Beneath every cell lies the floor of that cell, in its
/// thread's colour, a hair below every bundle's rim, so the tube is closed
/// whatever the bundles do.
///
/// Until then (Task 004 to the first round of 047) each cell was drawn as a ridge
/// filling exactly its cell, the ridges sharing their valleys and meeting end to
/// end at the crossings, sealed by a short wall. That read as short slanted parts
/// facing each other end to end, which the author rejected: the two sides of a V
/// are **separate bundles lying over one another** (the author, 2026-09-19).
///
/// The crossing rule is still the pattern's checkerboard, an approximation of the
/// braid's own order that nothing here claims to settle.
enum RoundTube16SurfaceMesh {
    /// **The family this draws**: sixteen threads, a tube.
    static let family = BraidFamily.roundTube(threads: 16)

    /// Where every number this drawing rests on came from. **No value here is
    /// changed by saying so.**
    static var shape: BraidFamilyShape {
        BraidFamilyShape(family: family, values: [
            "crest over nominal radius": BraidMeasurement(
                Double(crestHeightRatio),
                basis: .fractionOf("the tube's nominal radius"),
                source: .observed("Task 005J"),
                unsettled: "only the product with the pattern's aspect ratio is held by "
                    + "the photographs, and it is not in thread diameters"
            ),
            "one repeat over one turn": BraidMeasurement(
                Double(RoundTube16SurfacePatternGenerator.patternAspectRatio),
                source: .observed("photographs, Task 005I: 1.8 to 2.15 chevrons a braid "
                                  + "width, read two ways"),
                unsettled: "found by rendering and comparing, and only its product with "
                    + "the crest height is held"
            ),
            "valley below the nominal radius": .declared(
                Double(valleyDepthRatio), calibratedBy: "how deep the groove looks"
            ),
            "extra crest where a thread passes over": .declared(
                Double(overCrossingLift), calibratedBy: "how far the over thread stands up"
            ),
            "crest lost where a thread passes under": .declared(
                Double(underCrossingDip), calibratedBy: "how far the under thread sinks"
            ),
            "how far a bundle passing over goes on past the crossing": .declared(
                Double(overCrossingLap),
                calibratedBy: "how far one side of a V lies over the other before it "
                    + "sinks, held against the author's sketch by eye (Task 047 rework)"
            ),
            "how far a bundle passing under goes on beneath the crossing": .declared(
                Double(underCrossingTuck), calibratedBy: "only that its end is buried"
            ),
            "a bundle's rise over one column, over its cell's": .declared(
                Double(bundleLean),
                calibratedBy: "the bundles of the author's sketch and own braid lie "
                    + "much nearer the axis than the cells' diagonal (57 degrees); "
                    + "the cells, the card and the chevron density are unchanged"
            ),
            "a bundle passing over, its half-width over its cell's": .declared(
                Double(overBundleWidth),
                calibratedBy: "how far its broad face lies over its neighbours' flanks"
            ),
            "a bundle passing under, its half-width over its cell's": .declared(
                Double(underBundleWidth), calibratedBy: "as above"
            ),
            "how much a bundle passing under narrows at its ends": .declared(
                Double(underEndNarrowing),
                calibratedBy: "so its outline goes in beneath the one passing over"
            ),
            "how much a bundle passing over narrows at its tip": .declared(
                Double(overTipNarrowing), calibratedBy: "the rounded tip of the sketch"
            ),
            "how the cross-section falls to its rim, as the power of |across|":
                .declared(
                    Double(crestProfilePower),
                    calibratedBy: "a flattened bundle rather than a tube (Task 047)"
                ),
            "how far a buried tip sinks, in crests": .declared(
                Double(buriedTipSink), calibratedBy: "only that it is buried"
            ),
            "the floor below a bundle's rim": .declared(
                Double(beneathSink), calibratedBy: "only that it never shows through a bundle"
            ),
            "twist angle in degrees": .declared(
                Double(twistAngleDegrees), calibratedBy: "the slant of the fibre stripes"
            ),
            "fibre stripes along one strand": .declared(
                Double(strandFibreCount),
                calibratedBy: "how fine the fibres look close up (Task 047; was 8)"
            ),
            "twist relief": .declared(
                Double(strandTwistReliefRatio),
                calibratedBy: "how much the stripes stand out (Task 047; was 0.005)"
            ),
            "radius on screen": .declared(
                Double(defaultRadius),
                calibratedBy: "how big the braid should be in the view; a display size, "
                    + "not a shape"
            ),
        ])
    }

    static let defaultRadius: Float = 0.48
    static let defaultPatternRepeatCount = 4

    /// The braid is a cylinder the unwrapped pattern is rolled onto, so one repeat
    /// along the axis has to be the circumference times the aspect ratio the
    /// pattern declares. Length is therefore derived, never chosen: a radius and a
    /// length picked independently would shear every chevron.
    static func length(
        radius: Float,
        aspectRatio: Float = RoundTube16SurfacePatternGenerator.patternAspectRatio,
        patternRepeatCount: Int = defaultPatternRepeatCount
    ) -> Float {
        2 * .pi * radius * aspectRatio * Float(patternRepeatCount)
    }

    static var defaultLength: Float {
        length(radius: defaultRadius)
    }

    /// Samples down one bundle's own span. The laps and tucks past its ends are
    /// sampled at about the same spacing.
    static let defaultAlongStrandSubdivisions = 12
    /// Samples across one strand. Resolves the round cross-section.
    static let defaultAcrossStrandSubdivisions = 10
    static let minimumAlongStrandSubdivisions = 4
    static let minimumAcrossStrandSubdivisions = 6

    /// Ridge crest above the valley floor, as a fraction of the nominal radius.
    static let crestHeightRatio: Float = 0.12
    /// Valley floor below the nominal radius, as a fraction of it.
    static let valleyDepthRatio: Float = 0.03
    /// Extra crest for the strand passing over a crossing.
    static let overCrossingLift: Float = 0.16
    /// Crest removed from the strand passing under a crossing.
    static let underCrossingDip: Float = 0.55
    /// How far past its own ends a bundle passing over a crossing goes on, as a
    /// fraction of its length: over the end of the bundle passing under, and on
    /// until it sinks beneath the bundles beyond.
    static let overCrossingLap: Float = 0.45
    /// How far past its own ends a bundle passing under goes on, sinking, so its
    /// end is buried rather than cut.
    static let underCrossingTuck: Float = 0.15
    /// Half-widths over the cell's half-width. Wider than 1 lies over the
    /// neighbouring rows' flanks.
    static let overBundleWidth: Float = 1.25
    static let underBundleWidth: Float = 1.05
    /// How far a bundle rises along the braid over one column, over what its
    /// cell rises. Above 1 a bundle lies nearer the braid's axis than its cell
    /// does, turned about the cell's middle, so its ends still land on the
    /// column's edges; the neighbours it meets there are the same, because the
    /// two sides of every crossing turn by the same amount the same way.
    static let bundleLean: Float = 2
    /// How much narrower a bundle passing under is at its ends than mid-span.
    static let underEndNarrowing: Float = 0.6
    /// How much narrower a bundle passing over is at the tip of its lap.
    static let overTipNarrowing: Float = 0.55
    /// How far below its rim a buried tip ends, in crest heights.
    static let buriedTipSink: Float = 0.08
    /// The floor beneath every cell, below a bundle's rim, as a fraction of the
    /// radius.
    static let beneathSink: Float = 0.004
    static let beneathAlongSubdivisions = 8

    /// Twist stripes crossing one strand segment lengthwise, **as hira-genji's
    /// stitch and the eight-thread tube borrow it**. Maru-genji itself draws
    /// finer stripes since Task 047 (`strandFibreCount`); this stays, so the
    /// borrowers draw what they drew.
    static let fiberCount = 8
    /// Twist stripes along one maru-genji strand. More than `fiberCount` so that
    /// close up the strand reads as a bundle of fine fibres rather than a rope
    /// with a few thick grooves (Task 047).
    static let strandFibreCount = 20
    /// Angle between the twist stripes and the strand direction.
    static let twistAngleDegrees: Float = 30
    /// Twist relief as a fraction of the nominal radius. Rendered as a normal and
    /// roughness variation rather than as displaced geometry, so the stripes stay
    /// free of the moire a mesh at this subdivision level would produce.
    static let twistReliefRatio: Float = 0.005
    /// Maru-genji's own twist relief. Lower than `twistReliefRatio`, which the
    /// other families borrow, because finer stripes at the same height would be
    /// steeper and so stand out more, not less (Task 047).
    static let strandTwistReliefRatio: Float = 0.0022

    static func generate(
        pattern: RoundTube16SurfacePattern,
        radius: Float = defaultRadius,
        patternRepeatCount: Int = defaultPatternRepeatCount,
        alongStrandSubdivisions: Int = defaultAlongStrandSubdivisions,
        acrossStrandSubdivisions: Int = defaultAcrossStrandSubdivisions
    ) -> RoundTube16SurfaceMeshData? {
        let tileLength = length(
            radius: radius,
            aspectRatio: pattern.aspectRatio,
            patternRepeatCount: patternRepeatCount
        )
        guard
            pattern.patches.count == RoundTube16SurfacePatternGenerator.patchCount,
            radius.isFinite,
            radius > 0,
            pattern.aspectRatio.isFinite,
            pattern.aspectRatio > 0,
            tileLength.isFinite,
            tileLength > 0,
            patternRepeatCount > 0,
            alongStrandSubdivisions >= minimumAlongStrandSubdivisions,
            acrossStrandSubdivisions >= minimumAcrossStrandSubdivisions,
            pattern.patches.allSatisfy(isValid)
        else {
            return nil
        }

        let surface = BraidStrandSurfaceBuilder.surface(for: pattern)
        guard surface.segments.count == pattern.patches.count else { return nil }

        let metrics = SurfaceMetrics(
            radius: radius,
            length: tileLength,
            repeatCount: patternRepeatCount,
            twist: twistGrouping(
                for: surface,
                radius: radius,
                length: tileLength,
                repeatCount: patternRepeatCount
            )
        )
        let alongSamples: [BraidCrossingLayer: [Float]] = [
            .over: bundleAlongSamples(layer: .over, count: alongStrandSubdivisions),
            .under: bundleAlongSamples(layer: .under, count: alongStrandSubdivisions),
        ]
        let acrossSamples = subdivisionSamples(from: 0, to: 1, count: acrossStrandSubdivisions)

        var builder = MeshBuilder()
        // The repeats on both sides are included because the final chevron row
        // crosses v == 1 and a bundle reaches past its own cell, so both tile ends
        // need the slivers that belong to the neighbouring repeat. Anything outside
        // the requested length is clipped away below.
        for repeatIndex in -1...patternRepeatCount {
            for (segmentIndex, segment) in surface.segments.enumerated() {
                appendStrand(
                    bundle(for: segment),
                    segmentIndex: segmentIndex,
                    repeatIndex: repeatIndex,
                    metrics: metrics,
                    alongSamples: alongSamples[segment.layer] ?? [],
                    acrossSamples: acrossSamples,
                    builder: &builder
                )
            }
        }

        let mesh = RoundTube16SurfaceMeshData(
            positions: builder.positions,
            normals: builder.normals,
            tangents: builder.tangents,
            bitangents: builder.bitangents,
            textureCoordinates: builder.textureCoordinates,
            strandCoordinates: builder.strandCoordinates,
            twistPhases: builder.twistPhases,
            twist: metrics.twist,
            materialGroups: builder.materialGroups,
            vertexSegmentIndices: builder.vertexSegmentIndices,
            vertexIsBeneath: builder.vertexIsBeneath,
            triangleSegmentIndices: builder.triangleSegmentIndices,
            triangleIsBeneath: builder.triangleIsBeneath,
            seamStartVertexIndices: builder.seamStartVertexIndices,
            seamEndVertexIndices: builder.seamEndVertexIndices,
            baseRadius: radius,
            valleyFloorRadius: radius * (1 - valleyDepthRatio),
            length: tileLength,
            patternRepeatCount: patternRepeatCount
        )
        return isConsistent(mesh) ? mesh : nil
    }

    // MARK: - Bundle surface

    /// Radius of a bundle's surface, before the twist relief is applied by the
    /// normal map. `across` is 0 on the crest and ±1 at the rim, which lies on the
    /// valley floor. Past its ends the bundle sinks, and ends buried below the
    /// floor.
    static func strandRadius(
        layer: BraidCrossingLayer,
        along: Float,
        across: Float,
        radius: Float
    ) -> Float {
        let past = pastTheEnd(along)
        let sinking = smoothstep(0, pastTheEnds(layer: layer), past)
        let crest = crossingCrestFactor(layer: layer, along: along)
            * crestProfile(across: across)
            * (1 - sinking)
            - buriedTipSink * sinking
        return radius * (1 - valleyDepthRatio + crestHeightRatio * crest)
    }

    /// The floor beneath every cell.
    static func beneathRadius(radius: Float) -> Float {
        radius * (1 - valleyDepthRatio - beneathSink)
    }

    /// The bundle a cell is drawn as: its centreline turned about the cell's
    /// middle to rise `bundleLean` times as far over the column. The width stays
    /// the cell's, along the braid.
    static func bundle(for segment: BraidStrandSegment) -> BraidStrandSegment {
        let middle = (segment.centerlineStart + segment.centerlineEnd) / 2
        let half = segment.centerlineDelta / 2
        let turned = SIMD2<Float>(half.x, half.y * bundleLean)
        return BraidStrandSegment(
            threadPosition: segment.threadPosition,
            colorID: segment.colorID,
            layer: segment.layer,
            centerlineStart: middle - turned,
            centerlineEnd: middle + turned,
            startHalfWidth: segment.startHalfWidth,
            endHalfWidth: segment.endHalfWidth
        )
    }

    /// How far a layer's bundle reaches past each of its cell's ends.
    static func pastTheEnds(layer: BraidCrossingLayer) -> Float {
        layer == .over ? overCrossingLap : underCrossingTuck
    }

    /// 0 inside the cell's own span, the distance past the nearer end outside it.
    static func pastTheEnd(_ along: Float) -> Float {
        max(-along, along - 1, 0)
    }

    /// A bundle's half-width over its cell's, along it. A bundle passing over
    /// keeps its width through the crossing and narrows only at the tip of its
    /// lap; one passing under narrows towards its ends, so its outline goes in
    /// beneath the one lying over it.
    static func bundleWidth(layer: BraidCrossingLayer, along: Float) -> Float {
        switch layer {
        case .over:
            let tip = smoothstep(0, overCrossingLap, pastTheEnd(along))
            return overBundleWidth * (1 - overTipNarrowing * tip)
        case .under:
            let span = min(max(along, 0), 1)
            let end = 1 - smoothstep(0, 0.4, min(span, 1 - span))
            return underBundleWidth * (1 - underEndNarrowing * end)
        }
    }

    private static func smoothstep(_ edge0: Float, _ edge1: Float, _ value: Float) -> Float {
        guard edge1 > edge0 else { return value < edge0 ? 0 : 1 }
        let progress = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return progress * progress * (3 - 2 * progress)
    }

    /// How the cross-section falls to the rim: `1 - |across|^power`.
    static let crestProfilePower: Float = 2

    /// Cross-section: 1 on the crest, 0 at the rim.
    static func crestProfile(across: Float) -> Float {
        let clamped = min(abs(across), 1)
        return max(0, 1 - pow(clamped, crestProfilePower))
    }

    /// Peaks at both ends of a cell, where it meets the cells running the other
    /// way, and vanishes at mid-span.
    static func crossingWeight(along: Float) -> Float {
        (1 + cos(2 * .pi * min(max(along, 0), 1))) / 2
    }

    static func crossingCrestFactor(layer: BraidCrossingLayer, along: Float) -> Float {
        let weight = crossingWeight(along: along)
        switch layer {
        case .over:
            return 1 + overCrossingLift * weight
        case .under:
            return 1 - underCrossingDip * weight
        }
    }

    /// Maps an even 0...1 sampling onto the cross-section so that steps in the
    /// sample stay even along the elliptical arc instead of bunching on the crest.
    static func crossSectionOffset(forSample sample: Float) -> Float {
        sin(.pi / 2 * (2 * min(max(sample, 0), 1) - 1))
    }

    static func crossSectionSample(forOffset offset: Float) -> Float {
        asin(min(max(offset, -1), 1)) / .pi + 0.5
    }

    // MARK: - Twist

    /// How the twist stripes run in one strand's own coordinates: `along` is
    /// 0...1 down the centreline, `across` is -1...1 over the cross-section, and
    /// the phase is affine in both, so the stripes never break inside a strand.
    ///
    /// One pair cannot serve every strand. The two chevron directions hand the
    /// stripe field frames that are sheared opposite ways, so a shared pair puts
    /// one direction short of the nominal angle and the other past it. Strands
    /// that need the same pair are gathered into a twist group instead, and each
    /// group carries its own stripe textures.
    struct TwistCoefficients: Equatable, Sendable {
        let phasePerAlong: Float
        let phasePerAcross: Float

        func phase(along: Float, across: Float) -> Float {
            phasePerAlong * along + phasePerAcross * across
        }
    }

    /// One stripe texture's worth of strands.
    struct TwistGroup: Equatable, Sendable {
        let coefficients: TwistCoefficients
        /// Phase gradient in the strand's tangent frame — `x` along the tangent,
        /// `y` along the bitangent — multiplied by the braid radius so it does not
        /// depend on how large the braid is drawn. The normal map needs it because
        /// the strand frame is sheared: a relief differentiated in strand
        /// coordinates alone would lean away from the stripes it is meant to be.
        let normalizedPhaseGradient: SIMD2<Float>
    }

    /// The twist groups a surface needs, and which group each of its strands uses.
    struct TwistGrouping: Equatable, Sendable {
        let groups: [TwistGroup]
        let groupIndexBySegment: [Int]

        func coefficients(forSegment segmentIndex: Int) -> TwistCoefficients? {
            group(forSegment: segmentIndex)?.coefficients
        }

        func group(forSegment segmentIndex: Int) -> TwistGroup? {
            guard
                groupIndexBySegment.indices.contains(segmentIndex),
                groups.indices.contains(groupIndexBySegment[segmentIndex])
            else {
                return nil
            }
            return groups[groupIndexBySegment[segmentIndex]]
        }
    }

    /// Phase turned over one strand length. Fixed, so every strand shows the same
    /// number of stripes however its frame is sheared.
    static var twistPhasePerAlong: Float {
        -2 * .pi * Float(strandFibreCount)
    }

    // MARK: - Texture span

    /// Where a point `along` a strand falls in its texture, 0...1.
    ///
    /// A bundle reaches past both of its cell's ends — a long way when it passes
    /// over, a little when it passes under — and its texture spans all of it:
    /// were it clamped at the ends, the part past them would repeat the last
    /// column and the stripes would smear out just where the tip is seen going
    /// on over the crossing (Task 047).
    static func textureAlong(_ along: Float, layer: BraidCrossingLayer) -> Float {
        let span = pastTheEnds(layer: layer)
        return min(max((along + span) / (1 + 2 * span), 0), 1)
    }

    /// The inverse of `textureAlong`: the point along the strand a texture
    /// column stands for.
    static func strandAlong(forTextureAlong textureAlong: Float, layer: BraidCrossingLayer) -> Float {
        let span = pastTheEnds(layer: layer)
        return textureAlong * (1 + 2 * span) - span
    }

    static func twistGrouping(
        for surface: BraidStrandSurface,
        radius: Float,
        length: Float,
        repeatCount: Int
    ) -> TwistGrouping {
        let measured = surface.segments.map { segment in
            twistGroup(for: segment, radius: radius, length: length, repeatCount: repeatCount)
                ?? untwistedGroup
        }
        // Rounded before grouping so a strand shape lands in the same group at any
        // radius, which is what lets the textures be built once from the shared
        // reference surface and reused by every mesh.
        let keys = measured.map(twistGroupingKey)
        let orderedKeys = Set(keys).sorted()
        let groups = orderedKeys.compactMap { key in
            keys.firstIndex(of: key).map { measured[$0] }
        }
        return TwistGrouping(
            groups: groups,
            groupIndexBySegment: keys.map { orderedKeys.firstIndex(of: $0) ?? 0 }
        )
    }

    /// Solves the across coefficient that puts this strand's stripes at
    /// `twistAngleDegrees` to its own centreline. Doing it per strand is the whole
    /// point: the sheared frames then cancel out and every strand reads as the
    /// same yarn, twisted the same way and by the same amount.
    static func twistGroup(
        for segment: BraidStrandSegment,
        radius: Float,
        length: Float,
        repeatCount: Int
    ) -> TwistGroup? {
        let angle = twistAngleDegrees * .pi / 180
        let sine = sin(angle)
        let cosine = cos(angle)
        guard sine != 0 else { return nil }

        let drawn = bundle(for: segment)
        let along = worldOffset(
            drawn.centerlineDelta,
            radius: radius,
            length: length,
            repeatCount: repeatCount
        )
        // The bundle's own width, not its cell's: the stripes have to meet the
        // bundle that is drawn at the angle, and it is wider than its cell.
        let across = worldOffset(
            segment.meanHalfWidth * bundleWidth(layer: segment.layer, along: 0.5),
            radius: radius,
            length: length,
            repeatCount: repeatCount
        )
        let alongLength = simd_length(along)
        guard alongLength > 0 else { return nil }
        let alongUnit = along / alongLength
        // Turned a quarter turn the same way the mesh turns a tangent into a
        // bitangent, so this axis and the normal map's second channel agree.
        let acrossUnit = SIMD2<Float>(-alongUnit.y, alongUnit.x)
        let shear = simd_dot(across, alongUnit)
        let halfWidth = simd_dot(across, acrossUnit)
        guard halfWidth != 0 else { return nil }

        let phasePerAlong = twistPhasePerAlong
        let phasePerAcross = phasePerAlong
            * (shear * sine - halfWidth * cosine)
            / (alongLength * sine)
        let gradient = SIMD2<Float>(
            phasePerAlong / alongLength,
            (phasePerAcross - phasePerAlong * shear / alongLength) / halfWidth
        )
        guard phasePerAcross.isFinite, gradient.x.isFinite, gradient.y.isFinite else {
            return nil
        }
        return TwistGroup(
            coefficients: TwistCoefficients(
                phasePerAlong: phasePerAlong,
                phasePerAcross: phasePerAcross
            ),
            normalizedPhaseGradient: gradient * radius
        )
    }

    /// Fallback for a strand with no measurable direction, which contributes no
    /// visible surface anyway. Stripes run straight across it.
    private static var untwistedGroup: TwistGroup {
        TwistGroup(
            coefficients: TwistCoefficients(
                phasePerAlong: twistPhasePerAlong,
                phasePerAcross: 0
            ),
            normalizedPhaseGradient: .zero
        )
    }

    /// The along coefficient is the same for every strand, so the across
    /// coefficient alone identifies a group.
    private static func twistGroupingKey(_ group: TwistGroup) -> Int {
        Int((group.coefficients.phasePerAcross * 1_000).rounded())
    }

    /// Surface coordinates scaled to world distances: `x` around the braid,
    /// `y` along it.
    static func worldOffset(
        _ surfaceOffset: SIMD2<Float>,
        radius: Float,
        length: Float,
        repeatCount: Int
    ) -> SIMD2<Float> {
        SIMD2<Float>(
            surfaceOffset.x * 2 * .pi * radius,
            surfaceOffset.y * length / Float(repeatCount)
        )
    }

    // MARK: - Mesh assembly

    private struct SurfaceMetrics {
        let radius: Float
        let length: Float
        let repeatCount: Int
        let twist: TwistGrouping
    }

    /// A point being assembled. `strandCoordinate` is `(along, across)` in the
    /// bundle's own terms; `surfaceCoordinate` is where that lands on the unrolled
    /// braid, the bundle's width included. `radialLevel` is 0 on a bundle and 1 on
    /// the floor beneath it.
    private struct StrandVertex {
        let surfaceCoordinate: SIMD2<Float>
        let strandCoordinate: SIMD2<Float>
        let radialLevel: Float

        /// Texture coordinates, both 0...1. See `textureAlong`.
        func textureCoordinate(layer: BraidCrossingLayer) -> SIMD2<Float> {
            SIMD2<Float>(
                RoundTube16SurfaceMesh.textureAlong(strandCoordinate.x, layer: layer),
                RoundTube16SurfaceMesh.crossSectionSample(forOffset: strandCoordinate.y)
            )
        }
    }

    private struct MeshBuilder {
        var positions = [SIMD3<Float>]()
        var normals = [SIMD3<Float>]()
        var tangents = [SIMD3<Float>]()
        var bitangents = [SIMD3<Float>]()
        var textureCoordinates = [SIMD2<Float>]()
        var strandCoordinates = [SIMD2<Float>]()
        var twistPhases = [Float]()
        var materialGroups = [RoundTube16SurfaceMaterialKey: [UInt32]]()
        var vertexSegmentIndices = [Int]()
        var vertexIsBeneath = [Bool]()
        var triangleSegmentIndices = [Int]()
        var triangleIsBeneath = [Bool]()
        var seamStartVertexIndices = [Int]()
        var seamEndVertexIndices = [Int]()
    }

    /// One cell's bundle, then the floor of the same cell beneath it.
    private static func appendStrand(
        _ segment: BraidStrandSegment,
        segmentIndex: Int,
        repeatIndex: Int,
        metrics: SurfaceMetrics,
        alongSamples: [Float],
        acrossSamples: [Float],
        builder: inout MeshBuilder
    ) {
        appendGrid(
            segment, segmentIndex: segmentIndex, repeatIndex: repeatIndex,
            metrics: metrics, alongSamples: alongSamples, acrossSamples: acrossSamples,
            radialLevel: 0, builder: &builder
        )
        appendGrid(
            segment, segmentIndex: segmentIndex, repeatIndex: repeatIndex,
            metrics: metrics,
            alongSamples: subdivisionSamples(from: 0, to: 1, count: beneathAlongSubdivisions),
            acrossSamples: subdivisionSamples(from: 0, to: 1, count: 2),
            radialLevel: 1, builder: &builder
        )
    }

    private static func appendGrid(
        _ segment: BraidStrandSegment,
        segmentIndex: Int,
        repeatIndex: Int,
        metrics: SurfaceMetrics,
        alongSamples: [Float],
        acrossSamples: [Float],
        radialLevel: Float,
        builder: inout MeshBuilder
    ) {
        for alongIndex in 0..<(alongSamples.count - 1) {
            for acrossIndex in 0..<(acrossSamples.count - 1) {
                let a0 = alongSamples[alongIndex]
                let a1 = alongSamples[alongIndex + 1]
                let c0 = acrossSamples[acrossIndex]
                let c1 = acrossSamples[acrossIndex + 1]
                let corners = [
                    SIMD2<Float>(a0, c0),
                    SIMD2<Float>(a1, c0),
                    SIMD2<Float>(a1, c1),
                    SIMD2<Float>(a0, c1),
                ].map {
                    vertex(segment: segment, sample: $0, radialLevel: radialLevel)
                }

                for triangle in [
                    [corners[0], corners[1], corners[2]],
                    [corners[0], corners[2], corners[3]],
                ] {
                    append(
                        polygon: triangle,
                        segment: segment,
                        segmentIndex: segmentIndex,
                        repeatIndex: repeatIndex,
                        isBeneath: radialLevel > 0.5,
                        metrics: metrics,
                        builder: &builder
                    )
                }
            }
        }
    }

    private static func append(
        polygon: [StrandVertex],
        segment: BraidStrandSegment,
        segmentIndex: Int,
        repeatIndex: Int,
        isBeneath: Bool,
        metrics: SurfaceMetrics,
        builder: inout MeshBuilder
    ) {
        // Clipped in the repeat's own terms, so a bundle cut at one tile end and
        // the same bundle cut at the other are cut by the same arithmetic; adding
        // the repeat first rounded the two apart where a triangle meets the cut
        // almost edge-on.
        let clipped = clip(
            polygon: polygon,
            minimumV: -Float(repeatIndex),
            maximumV: Float(metrics.repeatCount - repeatIndex)
        )
        guard
            clipped.count >= 3,
            let twist = metrics.twist.coefficients(forSegment: segmentIndex),
            metrics.twist.groupIndexBySegment.indices.contains(segmentIndex)
        else {
            return
        }
        let twistGroupIndex = metrics.twist.groupIndexBySegment[segmentIndex]

        for index in 1..<(clipped.count - 1) {
            var triangle = [clipped[0], clipped[index], clipped[index + 1]]
            // Placed as repeat 0 first and moved along after, so whether a sliver
            // left by the cut is kept is decided the same way at both tile ends.
            let shift = SIMD3<Float>(
                metrics.length * Float(repeatIndex) / Float(metrics.repeatCount), 0, 0
            )
            var mapped = triangle.map {
                position(of: $0, segment: segment, repeatIndex: 0, metrics: metrics)
            }
            let faceNormal = simd_cross(mapped[1] - mapped[0], mapped[2] - mapped[0])
            // Only a triangle the cut has all but flattened is dropped. A looser
            // bound dropped the tiny corner a tile-end cut leaves on one side of
            // the cut and not the other, and the two ends no longer met.
            guard simd_length_squared(faceNormal) > minimumTriangleCross else { continue }
            // Wound to face outwards, whichever way the sampling ran.
            let centre = (mapped[0] + mapped[1] + mapped[2]) / 3
            if simd_dot(faceNormal, SIMD3<Float>(0, centre.y, centre.z)) < 0 {
                triangle.swapAt(1, 2)
                mapped.swapAt(1, 2)
            }

            mapped = mapped.map { $0 + shift }

            let firstIndex = UInt32(builder.positions.count)
            for (vertex, mappedPosition) in zip(triangle, mapped) {
                let vertexIndex = builder.positions.count
                let frame = isBeneath
                    ? beneathFrame(for: vertex)
                    : surfaceFrame(for: vertex, segment: segment, metrics: metrics)
                builder.positions.append(mappedPosition)
                builder.normals.append(frame.normal)
                builder.tangents.append(frame.tangent)
                builder.bitangents.append(frame.bitangent)
                builder.textureCoordinates.append(vertex.textureCoordinate(layer: segment.layer))
                builder.strandCoordinates.append(vertex.strandCoordinate)
                builder.twistPhases.append(
                    twist.phase(
                        along: vertex.strandCoordinate.x,
                        across: vertex.strandCoordinate.y
                    )
                )
                builder.vertexSegmentIndices.append(segmentIndex)
                builder.vertexIsBeneath.append(isBeneath)
                if approximatelyEqual(vertex.surfaceCoordinate.x, 0) {
                    builder.seamStartVertexIndices.append(vertexIndex)
                } else if approximatelyEqual(vertex.surfaceCoordinate.x, 1) {
                    builder.seamEndVertexIndices.append(vertexIndex)
                }
            }

            builder.materialGroups[
                RoundTube16SurfaceMaterialKey(
                    colorID: segment.colorID,
                    twistGroupIndex: twistGroupIndex,
                    layer: segment.layer
                ),
                default: []
            ].append(contentsOf: [firstIndex, firstIndex + 1, firstIndex + 2])
            builder.triangleSegmentIndices.append(segmentIndex)
            builder.triangleIsBeneath.append(isBeneath)
        }
    }

    /// `sample` is `(along, cross-section sample)`. On a bundle the across
    /// offset is widened by the bundle's own width; the floor keeps the cell's.
    /// The surface coordinate is the repeat's own; `position` places the repeat.
    private static func vertex(
        segment: BraidStrandSegment,
        sample: SIMD2<Float>,
        radialLevel: Float
    ) -> StrandVertex {
        let strandCoordinate = SIMD2<Float>(
            sample.x,
            crossSectionOffset(forSample: sample.y)
        )
        let width = radialLevel > 0.5
            ? 1
            : bundleWidth(layer: segment.layer, along: strandCoordinate.x)
        let surfaceCoordinate = segment.surfacePoint(
            along: strandCoordinate.x,
            across: strandCoordinate.y * width
        )
        return StrandVertex(
            surfaceCoordinate: surfaceCoordinate,
            strandCoordinate: strandCoordinate,
            radialLevel: radialLevel
        )
    }

    private static func position(
        of vertex: StrandVertex,
        segment: BraidStrandSegment,
        repeatIndex: Int,
        metrics: SurfaceMetrics
    ) -> SIMD3<Float> {
        let displacedRadius = vertex.radialLevel > 0.5
            ? beneathRadius(radius: metrics.radius)
            : strandRadius(
                layer: segment.layer,
                along: vertex.strandCoordinate.x,
                across: vertex.strandCoordinate.y,
                radius: metrics.radius
            )
        let normalizedV = (vertex.surfaceCoordinate.y + Float(repeatIndex))
            / Float(metrics.repeatCount)
        let angle = angle(around: vertex.surfaceCoordinate.x)
        return SIMD3<Float>(
            -metrics.length / 2 + metrics.length * normalizedV,
            displacedRadius * cos(angle),
            displacedRadius * sin(angle)
        )
    }

    private struct VertexFrame {
        let normal: SIMD3<Float>
        let tangent: SIMD3<Float>
        let bitangent: SIMD3<Float>
    }

    /// Measured on the bundle's own shape by finite differences, laps and tucks
    /// included, so a tip sloping under the next bundle is lit as a slope.
    private static func surfaceFrame(
        for vertex: StrandVertex,
        segment: BraidStrandSegment,
        metrics: SurfaceMetrics
    ) -> VertexFrame {
        let radial = radialDirection(around: vertex.surfaceCoordinate.x)
        let epsilon: Float = 0.002
        let reach = pastTheEnds(layer: segment.layer)
        let along = min(max(vertex.strandCoordinate.x, -reach), 1 + reach)
        let sample = crossSectionSample(forOffset: vertex.strandCoordinate.y)

        func sampled(_ point: SIMD2<Float>) -> SIMD3<Float> {
            position(
                of: self.vertex(segment: segment, sample: point, radialLevel: 0),
                segment: segment,
                repeatIndex: 0,
                metrics: metrics
            )
        }

        let alongTangent = sampled(SIMD2<Float>(min(1 + reach, along + epsilon), sample))
            - sampled(SIMD2<Float>(max(-reach, along - epsilon), sample))
        let acrossTangent = sampled(SIMD2<Float>(along, min(1, sample + epsilon)))
            - sampled(SIMD2<Float>(along, max(0, sample - epsilon)))

        var normal = simd_cross(alongTangent, acrossTangent)
        guard simd_length_squared(normal) > 0.000_000_000_001 else {
            return fallbackFrame(radial: radial)
        }
        normal = simd_normalize(normal)
        if simd_dot(normal, radial) < 0 {
            normal = -normal
        }
        return orthonormalFrame(normal: normal, alongTangent: alongTangent)
    }

    /// The floor faces straight out.
    private static func beneathFrame(for vertex: StrandVertex) -> VertexFrame {
        let radial = radialDirection(around: vertex.surfaceCoordinate.x)
        return orthonormalFrame(
            normal: radial,
            alongTangent: circumferentialDirection(around: vertex.surfaceCoordinate.x)
        )
    }

    private static func orthonormalFrame(
        normal: SIMD3<Float>,
        alongTangent: SIMD3<Float>
    ) -> VertexFrame {
        var tangent = alongTangent - normal * simd_dot(alongTangent, normal)
        guard simd_length_squared(tangent) > 0.000_000_000_001 else {
            return fallbackFrame(radial: normal)
        }
        tangent = simd_normalize(tangent)
        return VertexFrame(
            normal: normal,
            tangent: tangent,
            bitangent: simd_normalize(simd_cross(normal, tangent))
        )
    }

    private static func fallbackFrame(radial: SIMD3<Float>) -> VertexFrame {
        let tangent = SIMD3<Float>(1, 0, 0)
        let projected = tangent - radial * simd_dot(tangent, radial)
        let safeTangent = simd_length_squared(projected) > 0.000_001
            ? simd_normalize(projected)
            : SIMD3<Float>(0, 0, 1)
        return VertexFrame(
            normal: radial,
            tangent: safeTangent,
            bitangent: simd_normalize(simd_cross(radial, safeTangent))
        )
    }

    private static func angle(around u: Float) -> Float {
        approximatelyEqual(u, 1) ? 0 : 2 * .pi * u
    }

    private static func radialDirection(around u: Float) -> SIMD3<Float> {
        let value = angle(around: u)
        return SIMD3<Float>(0, cos(value), sin(value))
    }

    private static func circumferentialDirection(around u: Float) -> SIMD3<Float> {
        let value = angle(around: u)
        return SIMD3<Float>(0, -sin(value), cos(value))
    }

    // MARK: - Clipping

    private static func subdivisionSamples(from start: Float, to end: Float, count: Int) -> [Float] {
        (0...count).map { start + (end - start) * Float($0) / Float(count) }
    }

    /// A bundle's samples along it: its own span in `count` steps, and past each
    /// end as far as the layer reaches, in steps about as long.
    private static func bundleAlongSamples(layer: BraidCrossingLayer, count: Int) -> [Float] {
        let reach = pastTheEnds(layer: layer)
        let steps = max(1, Int((reach * Float(count)).rounded(.up)))
        let before = subdivisionSamples(from: -reach, to: 0, count: steps).dropLast()
        let after = subdivisionSamples(from: 1, to: 1 + reach, count: steps).dropFirst()
        return Array(before) + subdivisionSamples(from: 0, to: 1, count: count) + Array(after)
    }

    private static func clip(
        polygon: [StrandVertex],
        minimumV: Float,
        maximumV: Float
    ) -> [StrandVertex] {
        let aboveMinimum = clip(polygon: polygon) { $0.surfaceCoordinate.y >= minimumV }
            intersection: { intersection($0, $1, atV: minimumV) }
        return clip(polygon: aboveMinimum) { $0.surfaceCoordinate.y <= maximumV }
            intersection: { intersection($0, $1, atV: maximumV) }
    }

    private static func clip(
        polygon: [StrandVertex],
        isInside: (StrandVertex) -> Bool,
        intersection: (StrandVertex, StrandVertex) -> StrandVertex
    ) -> [StrandVertex] {
        guard var previous = polygon.last else { return [] }
        var result = [StrandVertex]()
        var previousIsInside = isInside(previous)

        for current in polygon {
            let currentIsInside = isInside(current)
            if currentIsInside != previousIsInside {
                result.append(intersection(previous, current))
            }
            if currentIsInside {
                result.append(current)
            }
            previous = current
            previousIsInside = currentIsInside
        }
        return removingAdjacentDuplicates(from: result)
    }

    private static func intersection(
        _ one: StrandVertex,
        _ other: StrandVertex,
        atV boundaryV: Float
    ) -> StrandVertex {
        // The same edge is cut from either side at the two tile ends; ordering
        // its ends first makes both cuts the same arithmetic, which matters where
        // an edge meets the cut almost along it.
        let swap = (one.surfaceCoordinate.y, one.surfaceCoordinate.x)
            > (other.surfaceCoordinate.y, other.surfaceCoordinate.x)
        let first = swap ? other : one
        let second = swap ? one : other
        let span = second.surfaceCoordinate.y - first.surfaceCoordinate.y
        let progress = span == 0 ? 0 : (boundaryV - first.surfaceCoordinate.y) / span
        let blend = SIMD2<Float>(repeating: progress)
        return StrandVertex(
            surfaceCoordinate: simd_mix(first.surfaceCoordinate, second.surfaceCoordinate, blend),
            strandCoordinate: simd_mix(first.strandCoordinate, second.strandCoordinate, blend),
            radialLevel: first.radialLevel + (second.radialLevel - first.radialLevel) * progress
        )
    }

    private static func removingAdjacentDuplicates(
        from polygon: [StrandVertex]
    ) -> [StrandVertex] {
        var result = [StrandVertex]()
        for vertex in polygon where result.last.map({
            !isSamePoint($0, vertex)
        }) ?? true {
            result.append(vertex)
        }
        if result.count > 1, let first = result.first, let last = result.last,
           isSamePoint(first, last) {
            result.removeLast()
        }
        return result
    }

    private static func isSamePoint(_ first: StrandVertex, _ second: StrandVertex) -> Bool {
        simd_distance(first.surfaceCoordinate, second.surfaceCoordinate) <= 0.000_001
            && abs(first.radialLevel - second.radialLevel) <= 0.000_001
    }

    // MARK: - Validation

    private static func isValid(_ patch: RoundTube16SurfacePatch) -> Bool {
        patch.corners.count == 4 && patch.corners.allSatisfy { corner in
            corner.x.isFinite && corner.y.isFinite
                && (0...1).contains(corner.x)
                && (0...RoundTube16SurfacePatternGenerator.maximumUnwrappedV).contains(corner.y)
        }
    }

    private static func isConsistent(_ mesh: RoundTube16SurfaceMeshData) -> Bool {
        let vertexCount = mesh.positions.count
        let indices = mesh.allTriangleIndices
        return !mesh.positions.isEmpty
            && mesh.normals.count == vertexCount
            && mesh.tangents.count == vertexCount
            && mesh.bitangents.count == vertexCount
            && mesh.textureCoordinates.count == vertexCount
            && mesh.strandCoordinates.count == vertexCount
            && mesh.twistPhases.count == vertexCount
            && mesh.vertexSegmentIndices.count == vertexCount
            && mesh.vertexIsBeneath.count == vertexCount
            && mesh.triangleSegmentIndices.count == mesh.triangleIsBeneath.count
            && mesh.triangleSegmentIndices.count == mesh.triangleCount
            && !mesh.materialGroups.isEmpty
            && mesh.materialGroups.values.allSatisfy { !$0.isEmpty && $0.count.isMultiple(of: 3) }
            && mesh.materialGroups.keys.allSatisfy { mesh.twist.groups.indices.contains($0.twistGroupIndex) }
            && mesh.vertexSegmentIndices.allSatisfy {
                mesh.twist.groupIndexBySegment.indices.contains($0)
            }
            && indices.allSatisfy { Int($0) < vertexCount }
            && mesh.positions.allSatisfy(isFinite)
            && mesh.normals.allSatisfy(isUnit)
            && mesh.tangents.allSatisfy(isUnit)
            && mesh.bitangents.allSatisfy(isUnit)
            && mesh.textureCoordinates.allSatisfy(isFiniteUnitCoordinate)
            && mesh.strandCoordinates.allSatisfy(isFiniteStrandCoordinate)
            && mesh.twistPhases.allSatisfy(\.isFinite)
            && trianglesAreNondegenerate(indices: indices, positions: mesh.positions)
    }

    /// Squared length of a triangle's edge cross product, below which it is
    /// taken as flat and dropped.
    static let minimumTriangleCross: Float = 0.000_000_000_000_000_1

    private static func trianglesAreNondegenerate(
        indices: [UInt32],
        positions: [SIMD3<Float>]
    ) -> Bool {
        guard indices.count.isMultiple(of: 3) else { return false }
        return stride(from: 0, to: indices.count, by: 3).allSatisfy { offset in
            let first = positions[Int(indices[offset])]
            let second = positions[Int(indices[offset + 1])]
            let third = positions[Int(indices[offset + 2])]
            return simd_length_squared(simd_cross(second - first, third - first))
                > minimumTriangleCross
        }
    }

    private static func isFinite(_ vector: SIMD3<Float>) -> Bool {
        vector.x.isFinite && vector.y.isFinite && vector.z.isFinite
    }

    private static func isUnit(_ vector: SIMD3<Float>) -> Bool {
        isFinite(vector) && abs(simd_length(vector) - 1) < 0.001
    }

    private static var maximumReach: Float { max(overCrossingLap, underCrossingTuck) }

    private static func isFiniteStrandCoordinate(_ vector: SIMD2<Float>) -> Bool {
        vector.x.isFinite && vector.y.isFinite
            && (-maximumReach - 0.001...1 + maximumReach + 0.001).contains(vector.x)
            && (-1.001...1.001).contains(vector.y)
    }

    private static func isFiniteUnitCoordinate(_ vector: SIMD2<Float>) -> Bool {
        vector.x.isFinite && vector.y.isFinite
            && (0...1).contains(vector.x)
            && (0...1).contains(vector.y)
    }

    private static func approximatelyEqual(_ lhs: Float, _ rhs: Float) -> Bool {
        abs(lhs - rhs) < 0.000_001
    }
}
