import Foundation
import simd

struct Flat16SurfaceMeshData: Sendable {
    let positions: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let textureCoordinates: [SIMD2<Float>]
    let boundaryDistances: [Float]
    let colorGroups: [ThreadColorID: [UInt32]]
    let boundaryColorGroups: [ThreadColorID: [UInt32]]
    let surfaceVertexPatchIndices: [Int]
    let surfaceVertexRegions: [Flat16SurfaceRegion]
    /// The floor laid beneath every cell, as against the bundle drawn over it.
    /// A floor vertex is not part of any run, so its run coordinates mean
    /// nothing and anything measuring the shape has to leave it out.
    let surfaceVertexIsFloor: [Bool]

    var allTriangleIndices: [UInt32] {
        (Array(colorGroups.values) + Array(boundaryColorGroups.values)).flatMap { $0 }
    }

    var triangleCount: Int { allTriangleIndices.count / 3 }
}

enum Flat16SurfaceMesh {
    /// **The family this draws**, and nothing narrower. Sixteen threads folded to
    /// six columns a face; which braid it is does not come into it.
    static let family = BraidFamily.flat(threads: 16, columns: 6)

    /// Where every number this drawing rests on came from. **No value here is
    /// changed by saying so** — this only says what each one is.
    static var shape: BraidFamilyShape {
        BraidFamilyShape(family: family, values: [
            "width over thickness": .observed(
                Double(widthToThicknessRatio),
                from: "a perimeter of sixteen threads and a thickness of two, solved "
                    + "on this file's own outline (docs/measurement-procedures.md)"
            ),
            "width over thickness, least": .observed(
                Double(minimumWidthToThicknessRatio), from: "the band the two readings allow"
            ),
            "width over thickness, most": .observed(
                Double(maximumWidthToThicknessRatio), from: "the band the two readings allow"
            ),
            "crest over half thickness": .observed(
                Double(crestHeightRatio), basis: .threadDiameters,
                from: "book A p96's silhouette with the physics; the half-thickness is "
                    + "one thread's diameter (docs/measurement-procedures.md, 1 and 2)"
            ),
            "pitch of one step over braid width": .observed(
                Double(Flat16SurfacePatternGenerator.stitchPitchPerBraidWidth),
                from: "book A p96 / book B p23"
            ),
            "outline exponent": .declared(
                Double(superellipseExponent),
                calibratedBy: "the shape of the section as drawn; set against the "
                    + "photographs by eye, not derived"
            ),
            "how high two runs of one lane meet, in crests": .declared(
                Double(bundleShape.joinHeight),
                calibratedBy: "the groove between two beads on book A p.72 and on the "
                    + "author's own braid, by eye (Task 050; the drawing before it "
                    + "took every groove all the way down to the valley)"
            ),
            "how high two lanes' bundles meet, in crests": .declared(
                Double(bundleShape.laneJoinHeight),
                calibratedBy: "the parting between two lanes, which the braid leaves "
                    + "shallower than the one along it: along a lane two threads cross "
                    + "over, across it they only press together"
            ),
            "a bundle's width at its cell's ends, over its widest": .declared(
                Double(bundleShape.endWidth),
                calibratedBy: "the lens; enough of one that four bundles part at a "
                    + "point, and never so much that they part along a line"
            ),
            "a bundle's width over its lane's": BraidMeasurement(
                Double(bundleShape.widthOverLane),
                source: .derived("solved from how high two lanes' bundles meet")
            ),
            "a bundle's swell, in steps either side of its cell's middle":
                BraidMeasurement(
                    Double(bundleShape.bellyHalfSpan),
                    source: .derived("solved from how high two runs of one lane meet")
                ),
            "extra height at the end that laps over": .declared(
                Double(bundleShape.headLift),
                calibratedBy: "how plainly the run arriving lies on the one leaving"
            ),
            "height lost at the end that passes under": .declared(
                Double(bundleShape.tailDip), calibratedBy: "the same join, read the other way"
            ),
            "how far a buried tip goes on, in steps": .declared(
                Double(bundleShape.tipReach), calibratedBy: "only that the tip is buried"
            ),
            "how far a buried tip sinks, in crests": .declared(
                Double(bundleShape.buriedTipSink),
                calibratedBy: "only that it ends below the floor beneath the cells"
            ),
            "how much a buried tip narrows": .declared(
                Double(bundleShape.tipNarrowing),
                calibratedBy: "only that it does not stand out sideways from under "
                    + "the run covering it"
            ),
            "the floor below a bundle's rim": .declared(
                Double(floorSink),
                calibratedBy: "only that it never shows through a bundle"
            ),
            "half width on screen": .declared(
                Double(defaultHalfWidth),
                calibratedBy: "how big the braid should be in the view; a display size, "
                    + "not a shape"
            ),
        ])
    }

    static let defaultHalfWidth: Float = 0.72

    /// Half-width over half-thickness.
    ///
    /// Derived inside the flat braid rather than chosen. The braid is two threads
    /// thick, so one thread is one half-thickness wide, and the sixteen threads
    /// take one sixteenth of the way round the cross-section each. Solving the
    /// outline this file already draws — a superellipse of exponent 5 — for the
    /// half-width whose perimeter is sixteen thread widths gives 3.3359.
    ///
    /// The thread width is not shared with the round braid. How many threads the
    /// round braid carries around itself is still unsettled — Task 005H assumed
    /// sixteen and was reverted — so this stays a flat-braid figure.
    ///
    /// The previous 6:1 was two absolute numbers picked to look flat.
    static let widthToThicknessRatio: Float = 3.3359
    static let minimumWidthToThicknessRatio: Float = 3.1
    static let maximumWidthToThicknessRatio: Float = 3.7

    /// The width is kept, so the braid stays the size it was on screen and only
    /// its thickness changes.
    static var defaultHalfThickness: Float {
        defaultHalfWidth / widthToThicknessRatio
    }
    /// The flat braid is a band the unwrapped pattern is laid on, so one repeat
    /// along it has to be the braid's width times the aspect ratio the pattern
    /// declares. Length is therefore derived, never chosen: a width and a length
    /// picked independently would draw every stitch the wrong shape.
    ///
    /// This replaced a hard-coded 3.4, which drew a stitch three and a half times
    /// too fine along the braid. The aspect ratio itself is measured from the
    /// finished braids in the references — see `stitchPitchPerBraidWidth`.
    static func length(
        halfWidth: Float,
        aspectRatio: Float,
        patternRepeatCount: Int
    ) -> Float {
        2 * halfWidth * aspectRatio * Float(patternRepeatCount)
    }

    /// **Length of one repeat over one turn round the braid**, which is what a
    /// drawing of the whole surface unrolled is measured in — the card's own
    /// ratio.
    ///
    /// **Measured on the outline this file draws** (Task 050), not counted from
    /// the lanes. Task 029 scaled `patternAspectRatio` — which is over the
    /// braid's *width* — by six lanes over sixteen places, and recorded that this
    /// carries an approximation: it treats the arc of one broad face as the width
    /// across the braid. The section says otherwise. The front's six lanes are six
    /// thread widths of arc, and a thread is one half-thickness wide, so the front
    /// measures 6 / 3.3359 = 1.799 half-widths against a width of 2. **The card
    /// was drawing every cell eleven per cent too short for its width**: a cell is
    /// one step long over one thread high, which is 2.445, and the card drew
    /// 2.199.
    ///
    /// **Taken on the plain outline, not on the drawn relief.** The cells are laid
    /// on the plain section and every lane's width is measured round it (stage
    /// 2.5c); the bundles stand proud of it by a crest that is not part of where a
    /// cell is. **This updates Task 029's decision to leave the figure alone**:
    /// 0.54975 becomes 0.6113, so at a given card height one repeat is drawn 11.2
    /// per cent **longer** — 61.57 points becomes 68.47 on a card 112 high — and
    /// every cell grows by as much along the braid.
    ///
    /// Task 047's handover compared **the two families' cards**, and this narrows
    /// that comparison by the same amount, to 2.05 times (the round braid's 1.25
    /// over this 0.6113). **Two braids' cards are not owed the same density**, so
    /// what is left there is a comparison and not a fault.
    static var patternAspectRatioRoundTheBraid: Float? {
        guard
            let acrossTheWidth = Flat16SurfacePatternGenerator.patternAspectRatio,
            defaultHalfWidth > 0
        else { return nil }
        let perimeter = perimeter(
            halfWidth: defaultHalfWidth, halfThickness: defaultHalfThickness
        )
        guard perimeter > 0 else { return nil }
        return acrossTheWidth * 2 * defaultHalfWidth / perimeter
    }

    /// Zero when the move rules cannot be read, which `generate` rejects.
    static var defaultLength: Float {
        length(
            halfWidth: defaultHalfWidth,
            aspectRatio: Flat16SurfacePatternGenerator.patternAspectRatio ?? 0,
            patternRepeatCount: defaultPatternRepeatCount
        )
    }
    /// Six repeats of the four-step pattern keep each step close to one yarn
    /// width. It was twelve when the pattern had two steps to a repeat rather
    /// than the move rules' four; the tile carries the same twenty-four steps
    /// either way, and the same stitch length.
    static let defaultPatternRepeatCount = 6
    static let widthSubdivisionsPerPatch = 4
    static let longitudinalSubdivisionsPerPatch = 24
    /// How near the rim of its own run a triangle has to be to be drawn in the
    /// second group. **A grouping, not a shape**: both groups take the same
    /// material, and what parts one bundle from the next is the geometry.
    static let boundaryWidth: Float = 0.035
    /// Ridge crest above the valley floor, as a fraction of the half-thickness.
    ///
    /// Read off the finished braid's own silhouette, not borrowed. The braid's
    /// edge ripples once a stitch as each yarn rises and falls, and how deep that
    /// ripple runs is what says how far a yarn stands proud.
    ///
    /// Measured on the top edge of the braid photographed in book A p96: the edge
    /// is found column by column where the luminance crosses halfway between page
    /// and braid, a moving average of two stitch pitches is subtracted, and the
    /// residual's standard deviation is taken as a fraction of the pitch. The
    /// ripple's own period comes out at 45 px against a stitch pitch of 43.6, so
    /// the ripple being measured really is the stitches. Rendering the braid at
    /// three crests gives a ripple exactly proportional to the crest —
    /// 1.15, 2.29 and 4.56 per cent at 0.12, 0.24 and 0.48 — so
    /// `sigma per cent = 9.55 * crest` inverts the measurement.
    ///
    /// **That calibration was taken on the shape this braid had before Task 050**
    /// — a ridge filling each cell, dying to the valley at its edges. The surface
    /// is drawn as overlapping bundles now, and **nobody has rendered the new one
    /// and measured its silhouette's ripple again.** The figure is kept because
    /// the reading it came from is unchanged, not because it has been checked
    /// against what is drawn today.
    ///
    /// Three estimates, and this value is the middle of where they overlap:
    ///
    /// - 0.554, from that measurement's own reading of the edge (sigma 5.29%)
    /// - 0.408, from a second reading of the same edge taken at a different height
    ///   in the blur (sigma 3.9%)
    /// - 0.40 to 0.50, from the braid itself and no photograph: the half-thickness
    ///   is one yarn's diameter, since the section is sixteen yarns round and two
    ///   thick, and a yarn lying on a surface stands about half its own diameter
    ///   proud of it
    ///
    /// They overlap over 0.41 to 0.50. The value this replaced, 0.12, lies outside
    /// all three: it says a yarn rises an eighth of its own diameter.
    ///
    /// No second braid could check it. Only book A p96's edge gives a ripple whose
    /// period matches its stitch pitch; book B p23's white edge yarn is too hairy
    /// (its ripple would mean a yarn standing 1.3 diameters proud) and the top-down
    /// photograph has no detectable period at all. The two readings above differ by
    /// where the edge is taken in a blurred photograph, which is a known systematic
    /// difference rather than noise, and the estimate that owes nothing to any
    /// photograph lands in the same place. See `.build/task007e-screenshots/`.
    ///
    /// **This is not the round braid's figure and does not have to be.** The round
    /// braid's 0.12 is a fraction of its nominal radius and has never been checked
    /// against a photographed braid either; Task 005J is to do for it what this
    /// did here. See `docs/architecture.md`.
    static let crestHeightRatio: Float = 0.45
    static let superellipseExponent: Float = 5

    /// The shape every visible run is drawn with.
    static let bundleShape = Flat16BundleShape.standard

    /// Samples down one bundle's own span, per step along the braid.
    ///
    /// **Ten, where the drawing this replaced took twenty-four a step.** A run
    /// covers a little under two steps and a step is 2.2 yarn widths, so this is
    /// a sample every sixth of a yarn width, and the swell along a run is a slow
    /// cosine. A bundle covers about three cells' worth of surface, so drawing
    /// them at the old density would have trebled the mesh; at ten the vertex
    /// count comes out within two per cent of the grid's, and the whole unit
    /// suite within a few seconds of it.
    static let alongBundleSubdivisions = 10
    /// Samples across one bundle. Resolves the rounded section.
    static let acrossBundleSubdivisions = 8
    /// Samples the floor of one cell takes.
    static let floorSubdivisions = 2
    /// How far below the plain outline the floor of a cell lies, as a fraction
    /// of the half-thickness.
    ///
    /// **It is not the shape and must never be read as it** (Task 050): the
    /// bundles meet above it everywhere except at the four-cornered points where
    /// two lanes and two steps come together, and there it stops the background
    /// showing between them. Deep enough to stay under every bundle's rim, and
    /// no deeper.
    static let floorSink: Float = 0.02

    static func generate(
        pattern: Flat16SurfacePattern,
        halfWidth: Float = defaultHalfWidth,
        halfThickness: Float = defaultHalfThickness,
        patternRepeatCount: Int = defaultPatternRepeatCount
    ) -> Flat16SurfaceMeshData? {
        let length = length(
            halfWidth: halfWidth,
            aspectRatio: pattern.aspectRatio,
            patternRepeatCount: patternRepeatCount
        )
        guard
            pattern.patches.count == Flat16SurfacePatternGenerator.patchCount,
            pattern.bundles.count == pattern.patches.count,
            halfWidth.isFinite,
            halfThickness.isFinite,
            pattern.aspectRatio.isFinite,
            pattern.aspectRatio > 0,
            length.isFinite,
            halfWidth > 0,
            halfThickness > 0,
            halfWidth / halfThickness >= minimumWidthToThicknessRatio,
            halfWidth / halfThickness <= maximumWidthToThicknessRatio,
            length > 0,
            patternRepeatCount > 0,
            pattern.patches.allSatisfy(isValid)
        else {
            return nil
        }

        let metrics = Metrics(
            halfWidth: halfWidth,
            halfThickness: halfThickness,
            length: length,
            repeatCount: patternRepeatCount
        )
        let alongSamples = bundleAlongSamples()
        let acrossSamples = bundleAcrossSamples()

        var builder = MeshBuilder()
        // One repeat either side of the tile as well. A bundle reaches past its
        // own cell at both ends, and the lanes are not all in step along the
        // braid, so what falls off one end of the tile is exactly what is missing
        // at the other. Everything outside the tile is cut away in `append`.
        for repeatIndex in -1...patternRepeatCount {
            for (index, bundle) in pattern.bundles.enumerated() {
                appendBundle(
                    bundle,
                    patch: pattern.patches[index],
                    patchIndex: index,
                    repeatIndex: repeatIndex,
                    metrics: metrics,
                    alongSamples: alongSamples,
                    acrossSamples: acrossSamples,
                    builder: &builder
                )
            }
        }

        let indices = (Array(builder.colorGroups.values)
            + Array(builder.boundaryColorGroups.values)).flatMap { $0 }
        guard
            !builder.positions.isEmpty,
            builder.positions.count == builder.normals.count,
            builder.positions.count == builder.textureCoordinates.count,
            builder.positions.count == builder.boundaryDistances.count,
            builder.positions.count == builder.surfaceVertexPatchIndices.count,
            builder.positions.count == builder.surfaceVertexRegions.count,
            builder.positions.count == builder.surfaceVertexIsFloor.count,
            indices.allSatisfy({ Int($0) < builder.positions.count }),
            builder.positions.allSatisfy(isFinite),
            builder.normals.allSatisfy(isFinite),
            builder.normals.allSatisfy({ abs(simd_length($0) - 1) < 0.001 }),
            trianglesAreNondegenerate(indices: indices, positions: builder.positions)
        else {
            return nil
        }

        return Flat16SurfaceMeshData(
            positions: builder.positions,
            normals: builder.normals,
            textureCoordinates: builder.textureCoordinates,
            boundaryDistances: builder.boundaryDistances,
            colorGroups: builder.colorGroups,
            boundaryColorGroups: builder.boundaryColorGroups,
            surfaceVertexPatchIndices: builder.surfaceVertexPatchIndices,
            surfaceVertexRegions: builder.surfaceVertexRegions,
            surfaceVertexIsFloor: builder.surfaceVertexIsFloor
        )
    }

    private struct MeshBuilder {
        var positions = [SIMD3<Float>]()
        var normals = [SIMD3<Float>]()
        var textureCoordinates = [SIMD2<Float>]()
        var boundaryDistances = [Float]()
        var colorGroups = [ThreadColorID: [UInt32]]()
        var boundaryColorGroups = [ThreadColorID: [UInt32]]()
        var surfaceVertexPatchIndices = [Int]()
        var surfaceVertexRegions = [Flat16SurfaceRegion]()
        var surfaceVertexIsFloor = [Bool]()
    }

    /// How large the braid is drawn and how much of it, shared by every vertex.
    private struct Metrics {
        let halfWidth: Float
        let halfThickness: Float
        let length: Float
        let repeatCount: Int
    }

    /// A point being assembled. `surface` is where it lands on the unrolled
    /// braid — `x` round the cross-section by arc, `y` along it in repeats — and
    /// `bundle` is `(along, across)` in the run's own terms. `onTheFloor` marks
    /// the floor laid beneath a cell as against the bundle drawn over it.
    struct SurfacePoint {
        let surface: SIMD2<Float>
        let bundle: SIMD2<Float>
        /// How far the run stands here, in crests. Carried rather than worked out
        /// again from `bundle`, because a run that dives under the body takes its
        /// own height down with it and only the run knows that.
        let standing: Float
        let onTheFloor: Bool
    }

    /// One cell's bundle, then the floor of the same cell beneath it.
    private static func appendBundle(
        _ bundle: Flat16Bundle,
        patch: Flat16SurfacePatch,
        patchIndex: Int,
        repeatIndex: Int,
        metrics: Metrics,
        alongSamples: [Float],
        acrossSamples: [Float],
        builder: inout MeshBuilder
    ) {
        // **Which way the run's own surface faces, decided once for the whole
        // run.** The sampling's handedness does not change along a bundle, so one
        // reading at mid-span settles it — and settling it per vertex against the
        // plain outline instead is what turned the steep parts of a diving tail
        // inside out.
        let sense = facing(of: bundle, metrics: metrics)
        for alongIndex in 0..<(alongSamples.count - 1) {
            for acrossIndex in 0..<(acrossSamples.count - 1) {
                let corners = [
                    SIMD2<Float>(alongSamples[alongIndex], acrossSamples[acrossIndex]),
                    SIMD2<Float>(alongSamples[alongIndex + 1], acrossSamples[acrossIndex]),
                    SIMD2<Float>(alongSamples[alongIndex + 1], acrossSamples[acrossIndex + 1]),
                    SIMD2<Float>(alongSamples[alongIndex], acrossSamples[acrossIndex + 1]),
                ].map { point(of: bundle, atAlong: $0.x, across: $0.y) }
                append(
                    polygon: corners, bundle: bundle, sense: sense,
                    patch: patch, patchIndex: patchIndex,
                    repeatIndex: repeatIndex, metrics: metrics, builder: &builder
                )
            }
        }

        // The floor: the cell's own four corners, in the cell's own thread
        // colour, a hair below every bundle's rim.
        let floor = floorSamples()
        for alongIndex in 0..<(floor.count - 1) {
            for acrossIndex in 0..<(floor.count - 1) {
                let corners = [
                    SIMD2<Float>(floor[alongIndex], floor[acrossIndex]),
                    SIMD2<Float>(floor[alongIndex + 1], floor[acrossIndex]),
                    SIMD2<Float>(floor[alongIndex + 1], floor[acrossIndex + 1]),
                    SIMD2<Float>(floor[alongIndex], floor[acrossIndex + 1]),
                ].map { sample -> SurfacePoint in
                    SurfacePoint(
                        surface: Flat16SurfacePatternGenerator.surfacePoint(
                            of: patch, local: SIMD2<Float>(sample.y, sample.x)
                        ),
                        bundle: SIMD2<Float>(sample.x, 2 * sample.y - 1),
                        standing: 0,
                        onTheFloor: true
                    )
                }
                append(
                    polygon: corners, bundle: nil, sense: 1,
                    patch: patch, patchIndex: patchIndex,
                    repeatIndex: repeatIndex, metrics: metrics, builder: &builder
                )
            }
        }
    }

    private static func point(
        of bundle: Flat16Bundle,
        atAlong along: Float,
        across: Float
    ) -> SurfacePoint {
        SurfacePoint(
            surface: bundle.point(atAlong: along, across: across, shape: bundleShape),
            bundle: SIMD2<Float>(along, across),
            standing: bundle.standing(atAlong: along, across: across, shape: bundleShape),
            onTheFloor: false
        )
    }

    /// Cuts the polygon to the tile and emits what is left, wound outwards.
    private static func append(
        polygon: [SurfacePoint],
        bundle: Flat16Bundle?,
        sense: Float,
        patch: Flat16SurfacePatch,
        patchIndex: Int,
        repeatIndex: Int,
        metrics: Metrics,
        builder: inout MeshBuilder
    ) {
        // Cut in the repeat's own terms, so a bundle cut at one end of the tile
        // and the same bundle cut at the other are cut by the same arithmetic.
        let clipped = clip(
            polygon: polygon,
            minimumV: -Float(repeatIndex),
            maximumV: Float(metrics.repeatCount - repeatIndex)
        )
        guard clipped.count >= 3 else { return }

        for index in 1..<(clipped.count - 1) {
            var triangle = [clipped[0], clipped[index], clipped[index + 1]]
            var drawn = triangle.map {
                position(of: $0, repeatIndex: repeatIndex, metrics: metrics)
            }
            let merged = coincidentCornerDistance * coincidentCornerDistance
            guard simd_distance_squared(drawn[0], drawn[1]) > merged,
                  simd_distance_squared(drawn[1], drawn[2]) > merged,
                  simd_distance_squared(drawn[2], drawn[0]) > merged
            else { continue }
            let face = simd_cross(drawn[1] - drawn[0], drawn[2] - drawn[0])
            guard simd_length_squared(face) > 0.000_000_000_001 else { continue }
            // **Wound to face the way the surface itself faces.** The braid is
            // drawn with back faces dropped, so a triangle wound the other way is
            // a hole. Held against the run's own normal rather than against the
            // plain outline: where a tail dives under the body its surface turns
            // right over, and asking the outline there winds it inside out.
            let normals = triangle.map {
                normal(of: $0, bundle: bundle, sense: sense,
                       repeatIndex: repeatIndex, metrics: metrics)
            }
            let facing = normals.reduce(SIMD3<Float>.zero, +)
            if simd_dot(face, facing) < 0 {
                triangle.swapAt(1, 2)
                drawn.swapAt(1, 2)
            }

            let firstIndex = UInt32(builder.positions.count)
            var isBoundary = true
            for (point, drawnPosition) in zip(triangle, drawn) {
                let texture = textureCoordinate(of: point)
                let distance = boundaryDistance(texture)
                if distance >= boundaryWidth { isBoundary = false }
                builder.positions.append(drawnPosition)
                builder.normals.append(normal(
                    of: point, bundle: bundle, sense: sense,
                    repeatIndex: repeatIndex, metrics: metrics
                ))
                builder.textureCoordinates.append(texture)
                builder.boundaryDistances.append(distance)
                builder.surfaceVertexPatchIndices.append(patchIndex)
                builder.surfaceVertexRegions.append(patch.region)
                builder.surfaceVertexIsFloor.append(point.onTheFloor)
            }
            let indices = [firstIndex, firstIndex + 1, firstIndex + 2]
            if isBoundary {
                builder.boundaryColorGroups[patch.colorID, default: []]
                    .append(contentsOf: indices)
            } else {
                builder.colorGroups[patch.colorID, default: []].append(contentsOf: indices)
            }
        }
    }

    private static func position(
        of point: SurfacePoint,
        repeatIndex: Int,
        metrics: Metrics
    ) -> SIMD3<Float> {
        let base = crossSectionPoint(
            atArcFraction: point.surface.x,
            halfWidth: metrics.halfWidth,
            halfThickness: metrics.halfThickness
        )
        let outward = crossSectionNormal(
            point: base, halfWidth: metrics.halfWidth, halfThickness: metrics.halfThickness
        )
        let height = point.onTheFloor
            ? -metrics.halfThickness * floorSink
            : metrics.halfThickness * crestHeightRatio * point.standing
        let longitudinal = (point.surface.y + Float(repeatIndex)) / Float(metrics.repeatCount)
        return SIMD3<Float>(
            -metrics.length / 2 + metrics.length * longitudinal,
            base.x + outward.x * height,
            base.y + outward.y * height
        )
    }

    private static func outwardDirection(atArc arc: Float, metrics: Metrics) -> SIMD2<Float> {
        let base = crossSectionPoint(
            atArcFraction: arc, halfWidth: metrics.halfWidth, halfThickness: metrics.halfThickness
        )
        return crossSectionNormal(
            point: base, halfWidth: metrics.halfWidth, halfThickness: metrics.halfThickness
        )
    }

    /// Measured on the bundle's own shape by finite differences, so a tail
    /// sloping in under the body is lit as a slope rather than as the face it
    /// left. The floor faces straight out.
    private static func normal(
        of vertex: SurfacePoint,
        bundle: Flat16Bundle?,
        sense: Float,
        repeatIndex: Int,
        metrics: Metrics
    ) -> SIMD3<Float> {
        let outward = outwardDirection(atArc: vertex.surface.x, metrics: metrics)
        let flat = SIMD3<Float>(0, outward.x, outward.y)
        guard !vertex.onTheFloor, let bundle else { return flat }
        guard let measured = surfaceNormal(
            of: bundle, atAlong: vertex.bundle.x, across: vertex.bundle.y,
            repeatIndex: repeatIndex, metrics: metrics
        ) else { return flat }
        return sense < 0 ? -measured : measured
    }

    /// The run's surface normal from its own shape, in the sampling's own
    /// handedness — which way round that is, `facing(of:metrics:)` settles once
    /// for the whole run.
    private static func surfaceNormal(
        of bundle: Flat16Bundle,
        atAlong along: Float,
        across: Float,
        repeatIndex: Int,
        metrics: Metrics
    ) -> SIMD3<Float>? {
        let epsilon: Float = 0.004
        func sampled(along: Float, across: Float) -> SIMD3<Float> {
            position(
                of: point(of: bundle, atAlong: along, across: across),
                repeatIndex: repeatIndex,
                metrics: metrics
            )
        }
        let lowAlong = max(bundleShape.runStart, along - epsilon)
        let highAlong = min(bundleShape.runEnd, along + epsilon)
        let lowAcross = max(-1, across - epsilon)
        let highAcross = min(1, across + epsilon)
        guard highAlong > lowAlong, highAcross > lowAcross else { return nil }

        let alongStep = sampled(along: highAlong, across: across)
            - sampled(along: lowAlong, across: across)
        let acrossStep = sampled(along: along, across: highAcross)
            - sampled(along: along, across: lowAcross)
        let cross = simd_cross(alongStep, acrossStep)
        guard simd_length_squared(cross) > 0.000_000_000_001 else { return nil }
        return simd_normalize(cross)
    }

    /// Which way round a run's own sampling faces: `+1` if it already points out
    /// of the braid at mid-span, `-1` if it points in. **One reading a run**, so
    /// that every part of it agrees with every other.
    private static func facing(of bundle: Flat16Bundle, metrics: Metrics) -> Float {
        guard let measured = surfaceNormal(
            of: bundle, atAlong: 0.5, across: 0, repeatIndex: 0, metrics: metrics
        ) else { return 1 }
        let outward = outwardDirection(
            atArc: bundle.centre(atAlong: 0.5).x, metrics: metrics
        )
        return simd_dot(measured, SIMD3<Float>(0, outward.x, outward.y)) < 0 ? -1 : 1
    }

    /// Where a point of a run falls in the stitch's map: `x` across the bundle
    /// and `y` along its whole run, the laps and the buried tips included, so
    /// the stripes run on into them instead of smearing at the ends.
    static func textureCoordinate(of point: SurfacePoint) -> SIMD2<Float> {
        let span = bundleShape.runEnd - bundleShape.runStart
        let along = span > 0
            ? min(max((point.bundle.x - bundleShape.runStart) / span, 0), 1)
            : 0
        return SIMD2<Float>(min(max((point.bundle.y + 1) / 2, 0), 1), along)
    }

    /// How near a point is to the rim of its own bundle or to the end of its
    /// run, in its texture's own units.
    private static func boundaryDistance(_ texture: SIMD2<Float>) -> Float {
        min(texture.x, 1 - texture.x, texture.y, 1 - texture.y)
    }

    /// A bundle's samples along it: its whole run, at about the same spacing as
    /// `alongBundleSubdivisions` gives one step.
    static func bundleAlongSamples() -> [Float] {
        let span = bundleShape.runEnd - bundleShape.runStart
        let steps = max(2, Int((span * Float(alongBundleSubdivisions)).rounded(.up)))
        return (0...steps).map {
            bundleShape.runStart + span * Float($0) / Float(steps)
        }
    }

    /// Samples across a bundle, gathered towards the two rims, where the rounded
    /// section turns fastest.
    static func bundleAcrossSamples() -> [Float] {
        (0...acrossBundleSubdivisions).map { step in
            sin(.pi / 2 * (2 * Float(step) / Float(acrossBundleSubdivisions) - 1))
        }
    }

    private static func floorSamples() -> [Float] {
        (0...floorSubdivisions).map { Float($0) / Float(floorSubdivisions) }
    }

    // MARK: - Cutting the tile

    private static func clip(
        polygon: [SurfacePoint],
        minimumV: Float,
        maximumV: Float
    ) -> [SurfacePoint] {
        let above = clip(polygon: polygon) { $0.surface.y >= minimumV }
            intersection: { intersection($0, $1, atV: minimumV) }
        return clip(polygon: above) { $0.surface.y <= maximumV }
            intersection: { intersection($0, $1, atV: maximumV) }
    }

    private static func clip(
        polygon: [SurfacePoint],
        isInside: (SurfacePoint) -> Bool,
        intersection: (SurfacePoint, SurfacePoint) -> SurfacePoint
    ) -> [SurfacePoint] {
        guard var previous = polygon.last else { return [] }
        var result = [SurfacePoint]()
        var previousIsInside = isInside(previous)
        for current in polygon {
            let currentIsInside = isInside(current)
            if currentIsInside != previousIsInside {
                result.append(intersection(previous, current))
            }
            if currentIsInside { result.append(current) }
            previous = current
            previousIsInside = currentIsInside
        }
        return result
    }

    private static func intersection(
        _ one: SurfacePoint,
        _ other: SurfacePoint,
        atV boundaryV: Float
    ) -> SurfacePoint {
        // The same edge is cut from either side at the two ends of the tile;
        // ordering its ends first makes both cuts the same arithmetic.
        let swap = (one.surface.y, one.surface.x) > (other.surface.y, other.surface.x)
        let first = swap ? other : one
        let second = swap ? one : other
        let span = second.surface.y - first.surface.y
        let progress = span == 0 ? 0 : (boundaryV - first.surface.y) / span
        let blend = SIMD2<Float>(repeating: progress)
        return SurfacePoint(
            surface: simd_mix(first.surface, second.surface, blend),
            bundle: simd_mix(first.bundle, second.bundle, blend),
            standing: first.standing + (second.standing - first.standing) * progress,
            onTheFloor: first.onTheFloor
        )
    }

    /// Distance right round the cross-section, measured on the outline this file
    /// draws rather than assumed from a formula. This is what states the width in
    /// thread widths, so it is the check `widthToThicknessRatio` has to answer to.
    static func perimeter(
        halfWidth: Float,
        halfThickness: Float,
        samplesPerRegion: Int = 4_096
    ) -> Float {
        guard samplesPerRegion > 0 else { return 0 }
        var total: Float = 0
        var previous = crossSectionPoint(
            region: .rightEdge,
            regionU: 0,
            halfWidth: halfWidth,
            halfThickness: halfThickness
        )
        // The four regions meet end to end and close the outline between them.
        for region in [Flat16SurfaceRegion.rightEdge, .front, .leftEdge, .back] {
            for step in 1...samplesPerRegion {
                let point = crossSectionPoint(
                    region: region,
                    regionU: Float(step) / Float(samplesPerRegion),
                    halfWidth: halfWidth,
                    halfThickness: halfThickness
                )
                total += simd_distance(previous, point)
                previous = point
            }
        }
        return total
    }

    /// Where each region starts and how far it reaches, as a fraction of the way
    /// round the cross-section **by arc length**.
    ///
    /// **Worked out once, by the pattern**
    /// (`Flat16SurfacePatternGenerator.arcSpan`), and read here so that the
    /// solid, the card and the checks all put a lane in one place. The counts it
    /// divides by are the working-out's: how many places round the braid, how
    /// many lanes a face has, how many threads turn at an edge.
    ///
    /// This replaced quarter-angles. Cutting the outline at ±π/4 gave the front
    /// 36.4 per cent of the perimeter and each edge 13.6, which is 5.83 and 2.17
    /// threads instead of 6 and 2 — a face thread 0.97 of a thread wide and an
    /// edge thread 1.09. The braid is worked in one thickness of thread, so that
    /// cannot be right.
    static func arcSpan(of region: Flat16SurfaceRegion) -> (start: Float, length: Float) {
        Flat16SurfacePatternGenerator.arcSpan(of: region)
    }

    /// A point on the outline. `regionU` runs 0...1 across the region **in arc
    /// length**, so every lane inside it is the same distance round — which is
    /// what makes each lane one thread wide.
    static func crossSectionPoint(
        region: Flat16SurfaceRegion,
        regionU: Float,
        halfWidth: Float,
        halfThickness: Float
    ) -> SIMD2<Float> {
        let span = arcSpan(of: region)
        return crossSectionPoint(
            atArcFraction: span.start + regionU * span.length,
            halfWidth: halfWidth,
            halfThickness: halfThickness
        )
    }

    /// The same point, from the fraction of the way round alone.
    ///
    /// **A bundle is wider than its lane and may be drawn in across the width,
    /// so it reaches past its own region** — a run leaving the face passes out
    /// of the front and under the lanes beside it. The outline is one closed
    /// curve, so this asks it directly rather than through a region.
    static func crossSectionPoint(
        atArcFraction fraction: Float,
        halfWidth: Float,
        halfThickness: Float
    ) -> SIMD2<Float> {
        let arcs = arcLengths(forRatio: halfWidth / halfThickness)
        let angle = arcs.angle(atArcFraction: fraction)
        let power = 2 / superellipseExponent
        return SIMD2<Float>(
            halfWidth * signedPower(cos(angle), power),
            halfThickness * signedPower(sin(angle), power)
        )
    }

    /// Arc length round the outline, and the angle that draws each point of it.
    ///
    /// The outline is a superellipse of exponent 5 and its angle runs round it
    /// very unevenly: an equal step of angle covers a fifth as much of the width
    /// near the edge of a face as it does near the middle. Anything that has to
    /// be one thread wide has to be spaced by arc, so this inverts the arc-length
    /// function once and everything else reads the answer off it.
    ///
    /// The shape depends only on the ratio of the two half-axes, so one table
    /// serves a braid drawn at any size.
    struct ArcLengths: Sendable {
        static let stepsPerQuarter = 8192
        static let entries = 8192

        let widthToThickness: Float
        private let anglesByArc: [Float]

        /// Where the outline is walked to measure it.
        ///
        /// Not at even steps of angle. The point runs round infinitely fast at the
        /// four places the outline crosses an axis — `|cos|` to the power 0.4 has
        /// no finite slope where the cosine is zero — so even steps of angle leave
        /// those four places barely sampled and everything measured through them
        /// is wrong. Steps are gathered towards them instead, at the power that
        /// makes the walk near-even along the outline itself.
        static func angle(atStep step: Int) -> Float {
            let quarter = min(step / stepsPerQuarter, 3)
            let within = Float(step - quarter * stepsPerQuarter) / Float(stepsPerQuarter)
            let towardsTheStart = within <= 0.5
            let distance = towardsTheStart ? 2 * within : 2 * (1 - within)
            let eased = pow(distance, superellipseExponent / 2) * (.pi / 4)
            let local = towardsTheStart ? eased : .pi / 2 - eased
            return Float(quarter) * .pi / 2 + local
        }

        init(widthToThickness ratio: Float) {
            self.widthToThickness = ratio
            let power = 2 / superellipseExponent
            func point(_ angle: Float) -> SIMD2<Float> {
                SIMD2<Float>(
                    ratio * signedPower(cos(angle), power),
                    signedPower(sin(angle), power)
                )
            }
            let steps = 4 * Self.stepsPerQuarter
            var walked = [Float](repeating: 0, count: steps + 1)
            var previous = point(0)
            for step in 1...steps {
                let current = point(step == steps ? 2 * .pi : Self.angle(atStep: step))
                walked[step] = walked[step - 1] + simd_distance(previous, current)
                previous = current
            }
            let total = walked[steps]
            var angles = [Float](repeating: 0, count: Self.entries + 1)
            var step = 0
            for entry in 0...Self.entries {
                let target = total * Float(entry) / Float(Self.entries)
                while step < steps, walked[step + 1] < target { step += 1 }
                let low = walked[step]
                let high = walked[min(step + 1, steps)]
                let within = high > low ? (target - low) / (high - low) : 0
                let a0 = Self.angle(atStep: step)
                let a1 = step + 1 >= steps ? 2 * Float.pi : Self.angle(atStep: step + 1)
                angles[entry] = a0 + (a1 - a0) * within
            }
            self.anglesByArc = angles
        }

        /// `fraction` is measured from the right-hand end of the width and wraps.
        func angle(atArcFraction fraction: Float) -> Float {
            let wrapped = fraction - floor(fraction)
            let position = wrapped * Float(Self.entries)
            let index = min(Int(position), Self.entries - 1)
            let within = position - Float(index)
            return anglesByArc[index]
                + (anglesByArc[index + 1] - anglesByArc[index]) * within
        }
    }

    private static let defaultArcLengths = ArcLengths(
        widthToThickness: widthToThicknessRatio
    )

    /// The table for the braid's own section, which is what every drawn vertex
    /// asks for. Anything else builds its own, which only a test does.
    static func arcLengths(forRatio ratio: Float) -> ArcLengths {
        guard ratio.isFinite, ratio > 0 else { return defaultArcLengths }
        return abs(ratio - defaultArcLengths.widthToThickness) < 0.000_5
            ? defaultArcLengths
            : ArcLengths(widthToThickness: ratio)
    }

    private static func crossSectionNormal(
        point: SIMD2<Float>,
        halfWidth: Float,
        halfThickness: Float
    ) -> SIMD2<Float> {
        let y = signedPower(point.x, superellipseExponent - 1)
            / pow(halfWidth, superellipseExponent)
        let z = signedPower(point.y, superellipseExponent - 1)
            / pow(halfThickness, superellipseExponent)
        let normal = SIMD2<Float>(y, z)
        return simd_length_squared(normal) > 0 ? simd_normalize(normal) : SIMD2<Float>(0, 1)
    }

    private static func signedPower(_ value: Float, _ exponent: Float) -> Float {
        (value < 0 ? -1 : 1) * pow(abs(value), exponent)
    }

    /// Semi-elliptical cross-section: 1 on the crest, 0 at either side.
    ///
    /// `across` is -1 and 1 in the valleys the strand shares with the strands
    /// either side of it, and the profile vanishes there, so neighbouring strands
    /// meet at the same point however their crests are scaled. This is the round
    /// braid's profile; a yarn is a yarn on either braid.
    static func crestProfile(across: Float) -> Float {
        let clamped = min(max(across, -1), 1)
        return (max(0, 1 - clamped * clamped)).squareRoot()
    }

    /// Where a point of a patch sits across the braid and along it, in the
    /// pattern's own coordinates. Internal so a test can work out which repeat a
    /// triangle came from: a patch may now reach past a repeat's ends, so where
    /// it is along the braid no longer says which repeat drew it.
    static func interpolate(
        corners: [SIMD2<Float>],
        local: SIMD2<Float>
    ) -> SIMD2<Float> {
        let leading = simd_mix(corners[0], corners[1], SIMD2<Float>(repeating: local.y))
        let trailing = simd_mix(corners[3], corners[2], SIMD2<Float>(repeating: local.y))
        return simd_mix(leading, trailing, SIMD2<Float>(repeating: local.x))
    }

    private static func smoothstep(_ edge0: Float, _ edge1: Float, _ value: Float) -> Float {
        let progress = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return progress * progress * (3 - 2 * progress)
    }

    /// How far past either end of the repeat a patch may reach.
    ///
    /// The columns do not change at the same point along a row — the six moves of
    /// a cycle are ordered, Task 007G — so a column shifted along its own length
    /// starts before the repeat does and finishes after it. Half a row is the most
    /// the move order asks for; the allowance is one row so the check is about
    /// catching nonsense rather than about the phase.
    ///
    /// What reaches past the **tile's** ends is cut off and emitted at the other
    /// end instead, so the tile itself stays flat-ended and closed. See
    /// `append(patch:...)`.
    static let maximumRepeatOverhang: Float = 1

    /// How near two corners of one triangle may be before they are the same
    /// corner. Matches the tolerance the surface audits merge points at.
    static let coincidentCornerDistance: Float = 0.000_1


    private static func isValid(_ patch: Flat16SurfacePatch) -> Bool {
        let low = -maximumRepeatOverhang
        let high = 1 + maximumRepeatOverhang
        return patch.corners.count == 4 && patch.corners.allSatisfy {
            $0.x.isFinite && $0.y.isFinite
                && (0...1).contains($0.x)
                && (low...high).contains($0.y)
        }
    }

    private static func isFinite(_ vector: SIMD3<Float>) -> Bool {
        vector.x.isFinite && vector.y.isFinite && vector.z.isFinite
    }

    private static func trianglesAreNondegenerate(
        indices: [UInt32],
        positions: [SIMD3<Float>]
    ) -> Bool {
        indices.count.isMultiple(of: 3) && stride(from: 0, to: indices.count, by: 3).allSatisfy {
            let a = positions[Int(indices[$0])]
            let b = positions[Int(indices[$0 + 1])]
            let c = positions[Int(indices[$0 + 2])]
            return simd_length_squared(simd_cross(b - a, c - a)) > 0.000_000_000_001
        }
    }
}
