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
            "boundary width": .declared(
                Double(boundaryWidth),
                calibratedBy: "how wide the dark line between threads looks"
            ),
            "boundary depth": .declared(
                Double(boundaryDepthRatio),
                calibratedBy: "how deep the dark line between threads looks"
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
    static let boundaryWidth: Float = 0.035
    static let boundaryDepthRatio: Float = 0.012
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

        var builder = MeshBuilder()
        let uSamples = subdivisionSamples(count: widthSubdivisionsPerPatch)
        let vSamples = subdivisionSamples(count: longitudinalSubdivisionsPerPatch)
        // One repeat either side of the tile as well. A column shifted along its
        // own length leaves the tile at one end and is wanted at the other, and
        // the pattern repeats, so the material that falls off the end is exactly
        // the material missing at the start. Everything outside the tile is cut
        // away in `append`, so these two extra passes contribute only that.
        for repeatIndex in -1...patternRepeatCount {
            for (patchIndex, patch) in pattern.patches.enumerated() {
                append(
                    patch: patch,
                    patchIndex: patchIndex,
                    repeatIndex: repeatIndex,
                    repeatCount: patternRepeatCount,
                    halfWidth: halfWidth,
                    halfThickness: halfThickness,
                    length: length,
                    uSamples: uSamples,
                    vSamples: vSamples,
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
            surfaceVertexRegions: builder.surfaceVertexRegions
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
    }

    private static func append(
        patch: Flat16SurfacePatch,
        patchIndex: Int,
        repeatIndex: Int,
        repeatCount: Int,
        halfWidth: Float,
        halfThickness: Float,
        length: Float,
        uSamples: [Float],
        vSamples: [Float],
        builder: inout MeshBuilder
    ) {
        // Where the tile's two ends fall inside this patch, one edge of the patch
        // at a time. A patch that runs past an end of the tile is not drawn whole
        // and then cut: **the part of it that is inside is what gets divided up.**
        // The cut is then always a line of the grid, so it never leaves a sliver
        // to be dropped, and dropping one is what would leave a hole.
        //
        // Solved rather than searched for: where a patch sits along the braid is
        // affine in its own coordinates, so the tile's ends are straight lines
        // there and each is one division.
        // Where the patch is wholly outside the tile the range closes to nothing
        // rather than being dropped, so the piece that is inside tapers to a
        // corner instead of ending at a hole. The triangles of zero area that
        // leaves are dropped below.
        func insideRange(atU u: Float) -> (low: Float, high: Float) {
            let low = simd_mix(patch.corners[0].y, patch.corners[3].y, u)
            let high = simd_mix(patch.corners[1].y, patch.corners[2].y, u)
            let span = high - low
            guard abs(span) > 1e-12 else { return (0, 1) }
            let starts = (-Float(repeatIndex) - low) / span
            let ends = (Float(repeatCount - repeatIndex) - low) / span
            let lower = max(0, min(starts, ends))
            let upper = min(1, max(starts, ends))
            guard upper > lower else {
                let closed = min(max(0.5 * (lower + upper), 0), 1)
                return (closed, closed)
            }
            return (lower, upper)
        }
        let ranges = uSamples.map(insideRange(atU:))
        guard ranges.contains(where: { $0.high > $0.low }) else { return }

        for vIndex in 0..<(vSamples.count - 1) {
            for uIndex in 0..<(uSamples.count - 1) {
                let left = ranges[uIndex], right = ranges[uIndex + 1]
                func at(_ side: (low: Float, high: Float), _ sample: Float) -> Float {
                    side.low + (side.high - side.low) * sample
                }
                let locals = [
                    SIMD2<Float>(uSamples[uIndex], at(left, vSamples[vIndex])),
                    SIMD2<Float>(uSamples[uIndex + 1], at(right, vSamples[vIndex])),
                    SIMD2<Float>(uSamples[uIndex], at(left, vSamples[vIndex + 1])),
                    SIMD2<Float>(uSamples[uIndex + 1], at(right, vSamples[vIndex + 1])),
                ]
                for triangleLocals in [[locals[0], locals[1], locals[2]],
                                       [locals[1], locals[3], locals[2]]] {
                    let center = triangleLocals.reduce(.zero, +) / 3
                    let isBoundary = boundaryDistance(center) < boundaryWidth
                    // A cut that grazes a corner leaves a sliver of no area. It
                    // would draw nothing and would fail the mesh's own check that
                    // every triangle has some, so it is dropped rather than
                    // emitted — measured on the drawn surface, by the same
                    // criterion that check uses.
                    let drawn = triangleLocals.map { local in
                        surfacePosition(
                            patch: patch,
                            localCoordinate: local,
                            repeatIndex: repeatIndex,
                            repeatCount: repeatCount,
                            halfWidth: halfWidth,
                            halfThickness: halfThickness,
                            length: length
                        )
                    }
                    // Where the patch tapers to a corner two of the three fall
                    // together. Such a triangle draws nothing and would leave the
                    // mesh with a repeated corner, so it is not emitted.
                    // Two corners closer together than the tolerance a reader
                    // would merge them at count as one corner, not two.
                    let merged = coincidentCornerDistance * coincidentCornerDistance
                    guard simd_distance_squared(drawn[0], drawn[1]) > merged,
                          simd_distance_squared(drawn[1], drawn[2]) > merged,
                          simd_distance_squared(drawn[2], drawn[0]) > merged,
                          simd_length_squared(
                              simd_cross(drawn[1] - drawn[0], drawn[2] - drawn[0])
                          ) > 0.000_000_000_001
                    else { continue }
                    // Nor a triangle lying wholly in the cut. It would be a cap
                    // across the tile's end, which is not part of the surface.
                    let end = length / 2
                    guard !drawn.allSatisfy({ abs(abs($0.x) - end) < 0.000_001 })
                    else { continue }
                    let firstIndex = UInt32(builder.positions.count)
                    for local in triangleLocals {
                        let position = surfacePosition(
                            patch: patch,
                            localCoordinate: local,
                            repeatIndex: repeatIndex,
                            repeatCount: repeatCount,
                            halfWidth: halfWidth,
                            halfThickness: halfThickness,
                            length: length
                        )
                        let normal = surfaceNormal(
                            patch: patch,
                            localCoordinate: local,
                            repeatIndex: repeatIndex,
                            repeatCount: repeatCount,
                            halfWidth: halfWidth,
                            halfThickness: halfThickness,
                            length: length
                        ) ?? fallbackNormal(
                            patch: patch,
                            localCoordinate: local,
                            halfWidth: halfWidth,
                            halfThickness: halfThickness
                        )
                        builder.positions.append(position)
                        builder.normals.append(normal)
                        builder.textureCoordinates.append(local)
                        builder.boundaryDistances.append(boundaryDistance(local))
                        builder.surfaceVertexPatchIndices.append(patchIndex)
                        builder.surfaceVertexRegions.append(patch.region)
                    }
                    let indices = [firstIndex, firstIndex + 1, firstIndex + 2]
                    if isBoundary {
                        builder.boundaryColorGroups[patch.colorID, default: []]
                            .append(contentsOf: indices)
                    } else {
                        builder.colorGroups[patch.colorID, default: []]
                            .append(contentsOf: indices)
                    }
                }
            }
        }
    }

    private static func surfacePosition(
        patch: Flat16SurfacePatch,
        localCoordinate: SIMD2<Float>,
        repeatIndex: Int,
        repeatCount: Int,
        halfWidth: Float,
        halfThickness: Float,
        length: Float
    ) -> SIMD3<Float> {
        let surface = interpolate(corners: patch.corners, local: localCoordinate)
        let longitudinal = (surface.y + Float(repeatIndex)) / Float(repeatCount)
        let base = crossSectionPoint(
            region: patch.region,
            regionU: surface.x,
            halfWidth: halfWidth,
            halfThickness: halfThickness
        )
        let outward = crossSectionNormal(
            point: base,
            halfWidth: halfWidth,
            halfThickness: halfThickness
        )
        let relief = reliefOffset(localCoordinate: localCoordinate, scale: halfThickness)
        return SIMD3<Float>(
            -length / 2 + length * longitudinal,
            base.x + outward.x * relief,
            base.y + outward.y * relief
        )
    }

    /// The relief is geometry, so its gradient must also affect the normal. Using
    /// the flat cross-section normal hid the yarn crown and fibre grooves even
    /// though their vertices existed in the mesh.
    private static func surfaceNormal(
        patch: Flat16SurfacePatch,
        localCoordinate: SIMD2<Float>,
        repeatIndex: Int,
        repeatCount: Int,
        halfWidth: Float,
        halfThickness: Float,
        length: Float
    ) -> SIMD3<Float>? {
        let epsilon: Float = 0.002
        // Patch joins are recessed yarn boundaries. Keep their normal aligned to
        // the braid surface so the first and last repeat share an exact lighting
        // seam; the relief gradient resumes immediately inside the stitch.
        guard localCoordinate.y > epsilon, localCoordinate.y < 1 - epsilon else {
            return nil
        }
        let lowerU = max(0, localCoordinate.x - epsilon)
        let upperU = min(1, localCoordinate.x + epsilon)
        let lowerV = max(0, localCoordinate.y - epsilon)
        let upperV = min(1, localCoordinate.y + epsilon)
        guard upperU > lowerU, upperV > lowerV else { return nil }

        func position(_ u: Float, _ v: Float) -> SIMD3<Float> {
            surfacePosition(
                patch: patch,
                localCoordinate: SIMD2<Float>(u, v),
                repeatIndex: repeatIndex,
                repeatCount: repeatCount,
                halfWidth: halfWidth,
                halfThickness: halfThickness,
                length: length
            )
        }

        let tangentU = position(upperU, localCoordinate.y)
            - position(lowerU, localCoordinate.y)
        let tangentV = position(localCoordinate.x, upperV)
            - position(localCoordinate.x, lowerV)
        let cross = simd_cross(tangentU, tangentV)
        guard simd_length_squared(cross) > 0.000_000_000_001 else { return nil }
        return simd_normalize(cross)
    }

    private static func fallbackNormal(
        patch: Flat16SurfacePatch,
        localCoordinate: SIMD2<Float>,
        halfWidth: Float,
        halfThickness: Float
    ) -> SIMD3<Float> {
        let surface = interpolate(corners: patch.corners, local: localCoordinate)
        let base = crossSectionPoint(
            region: patch.region,
            regionU: surface.x,
            halfWidth: halfWidth,
            halfThickness: halfThickness
        )
        let outward = crossSectionNormal(
            point: base,
            halfWidth: halfWidth,
            halfThickness: halfThickness
        )
        return SIMD3<Float>(0, outward.x, outward.y)
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
    /// The braid is sixteen threads round: six across the front, two at the right
    /// edge, six across the back and two at the left. So the outline divides
    /// 6 : 2 : 6 : 2, measured along itself. The regions are centred on the
    /// middles of the two faces and the two edges, which is where the symmetry
    /// puts them.
    ///
    /// This replaced quarter-angles. Cutting the outline at ±π/4 gave the front
    /// 36.4 per cent of the perimeter and each edge 13.6, which is 5.83 and 2.17
    /// threads instead of 6 and 2 — a face thread 0.97 of a thread wide and an
    /// edge thread 1.09. The braid is worked in one thickness of thread, so that
    /// cannot be right.
    static func arcSpan(of region: Flat16SurfaceRegion) -> (start: Float, length: Float) {
        let round = Float(HiraGenjiWeaveDerivation.boardPositionCount)
        let face = Float(HiraGenjiWeaveDerivation.columnCount) / round
        let edge = Float(HiraGenjiWeaveDerivation.edgeThreadCount) / round
        switch region {
        // Centred on the right-hand end of the width, so it straddles the wrap.
        case .rightEdge: return (1 - edge / 2, edge)
        case .front: return (edge / 2, face)
        case .leftEdge: return (edge / 2 + face, edge)
        case .back: return (edge + face + edge / 2, face)
        }
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
        let arcs = arcLengths(forRatio: halfWidth / halfThickness)
        let angle = arcs.angle(atArcFraction: span.start + regionU * span.length)
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

    /// The whole of the surface's relief: the groove between one lane and the
    /// next, and the two yarns that meet at every place.
    ///
    /// The twist is not here. It is carried by the normal and roughness maps, as
    /// it is on the round braid, because a mesh at this subdivision would moire.
    /// What used to be here leaned one way for the threads worked lengthwise and
    /// the other for those worked across, which is two hands of yarn in one
    /// braid; `HiraGenjiStitchTwistGrouping` gives them one.
    private static func reliefOffset(
        localCoordinate: SIMD2<Float>,
        scale: Float
    ) -> Float {
        // The groove marks the join between one lane and the next. The join along
        // the braid is a crossing, drawn by `crossingRelief`, not a seam to cut.
        let acrossBlend = smoothstep(
            0,
            boundaryWidth,
            min(localCoordinate.x, 1 - localCoordinate.x)
        )
        let boundary = -scale * boundaryDepthRatio * (1 - acrossBlend)
        return boundary + scale * crossingRelief(localCoordinate)
    }

    /// How far the surface stands proud at one place, in crest heights: the two
    /// yarns that meet there, whichever of them is on top.
    ///
    /// A thread on a face is seen for one step along the braid. It comes up over
    /// the pick laid at the start of that step, rides across it, and dives under
    /// the next — so its own bulge dies away at both ends of its run and the run
    /// reads as one leaf-shaped cell rather than as a length of band.
    ///
    /// What shows at the join is the pick, lying right across the braid. It goes
    /// under every thread of the face, so it is sunk by the round braid's
    /// `underCrossingDip`, which is that figure's own meaning — the crest taken
    /// off a strand passing underneath.
    ///
    /// Nothing here raises the surface above what stage 2 set: the top of a run
    /// is still exactly `crestHeightRatio`.
    static func crossingRelief(_ local: SIMD2<Float>) -> Float {
        let alongTheRun = sin(.pi * local.y)
        let thread = crestHeightRatio
            * crestProfile(across: 2 * local.x - 1)
            * alongTheRun * alongTheRun
        let fromTheJoin = min(local.y, 1 - local.y) / pickHalfSpan
        let pick = crestHeightRatio
            * (1 - RoundTube16SurfaceMesh.underCrossingDip)
            * crestProfile(across: min(fromTheJoin, 1))
        return max(thread, pick)
    }

    /// Half a pick's width, as a fraction of one step along the braid.
    ///
    /// A pick is one yarn wide and a step is `stitchPitchPerBraidWidth` of the
    /// braid's width, which is six yarns. Derived, so it follows the aspect ratio
    /// measured in stage 2.5a rather than standing on its own.
    static var pickHalfSpan: Float {
        0.5 / (Flat16SurfacePatternGenerator.stitchPitchPerBraidWidth
            * Float(Flat16SurfacePatternGenerator.broadFaceColumnCount))
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

    private static func boundaryDistance(_ local: SIMD2<Float>) -> Float {
        min(local.x, 1 - local.x, local.y, 1 - local.y)
    }

    private static func subdivisionSamples(count: Int) -> [Float] {
        var samples = (0...count).map { Float($0) / Float(count) }
        samples.append(contentsOf: [boundaryWidth, 1 - boundaryWidth])
        return samples.sorted().reduce(into: []) { result, value in
            if result.last.map({ abs($0 - value) > 0.000_001 }) ?? true {
                result.append(value)
            }
        }
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
