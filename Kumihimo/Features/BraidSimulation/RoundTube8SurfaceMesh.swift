import Foundation
import simd

struct RoundTube8SurfaceMeshData: Sendable {
    let positions: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let tangents: [SIMD3<Float>]
    let bitangents: [SIMD3<Float>]
    /// Cell-local: `x` runs 0...1 along the cell, `y` 0...1 across it.
    let textureCoordinates: [SIMD2<Float>]
    /// Triangle indices per thread colour. One material each.
    let colorGroups: [ThreadColorID: [UInt32]]
    /// Which cell of the pattern each triangle came from, so a reading can ask
    /// what is at a place without measuring the geometry back.
    let triangleSegmentIndices: [Int]
    /// The radius the crest of a ridge stands at — **what a photograph of the
    /// braid measures across**, and what the pitch is a fraction of.
    let crestRadius: Float
    let valleyFloorRadius: Float
    /// Length of the whole tile along the braid axis.
    let length: Float
    let patternRepeatCount: Int
    let rowCount: Int

    var visibleWidth: Float { 2 * crestRadius }
    var circumference: Float { 2 * .pi * crestRadius }
    var patternRepeatLength: Float { length / Float(patternRepeatCount) }
    var triangleCount: Int { colorGroups.values.reduce(0) { $0 + $1.count / 3 } }

    var allTriangleIndices: [UInt32] {
        sortedColorGroups.flatMap(\.value)
    }

    /// Colour groups in a fixed order, so anything derived from them is the same
    /// every run.
    var sortedColorGroups: [(key: ThreadColorID, value: [UInt32])] {
        colorGroups.sorted { $0.key.rawValue < $1.key.rawValue }
    }
}

/// Draws a tube of eight threads: a ridge along each cell of the surface, laid on
/// a cylinder, with the valley between neighbouring ridges shared so the tube
/// closes.
///
/// **The third drawer, and the first whose cells are not copied from a figure.**
/// The sixteen-thread drawers keep the shape of every cell transcribed from book
/// A; this one is handed a pattern worked out from the move table and the measured
/// pitch (`RoundTube8SurfacePatternGenerator`) and does nothing but give it a
/// cross-section and wrap it.
///
/// **Borrowed from `RoundTube16SurfaceMesh`**, and named so: the semi-elliptical
/// crest across a strand (`crestProfile`), the even sampling of that ellipse by
/// arc rather than by chord (`crossSectionOffset`), and the way a strand's
/// surface point is read as a radius above a valley floor. What is *not* borrowed
/// is everything about crossings — the lift, the dip, the lap, the walls that
/// seal a step — because on this braid nothing crosses.
///
/// **The fibre stripes and the valley shading are borrowed too**, from the
/// sixteen-thread tube's maps (`RoundTube8StrandTexture`), and only they are set
/// by eye; none of them moves a vertex.
///
/// **The sixteen-thread drawers are untouched.** This is an addition beside them.
enum RoundTube8SurfaceMesh {
    /// **The family this draws**: eight threads, a tube.
    static let family = BraidFamily.roundTube(threads: 8)

    /// Where every number this drawing rests on came from. **No value here is
    /// changed by saying so.**
    static var shape: BraidFamilyShape {
        BraidFamilyShape(family: family, values: [
            "one cycle over the braid's diameter": BraidMeasurement(
                Double(RoundTube8SurfacePatternGenerator.pitchOverDiameter),
                // The two readings, rounded outward: 0.403 on S and 0.506 on Z-a.
                spread: 0.40...0.51,
                basis: .fractionOf("the braid's own diameter"),
                source: .observed("book A p.8-9, the zoom; Task 031 stage 1"),
                unsettled: "the three braids photographed do not agree: S gives 0.403 "
                    + "and Z-a 0.506, and colouring b cannot be read this way at all "
                    + "because its colour turns in eight cycles rather than four. The "
                    + "value shipped is S's, whose signal is the cleanest and whose "
                    + "braid is the one drawn. On S itself the pitch and the colour band "
                    + "cannot both hold: a pitch of 0.403 puts the band at 46.5 degrees "
                    + "from across the braid, the band measured on the same photograph is "
                    + "54.5, and 54.5 would need a pitch of 0.536. Neither is moved to "
                    + "meet the other (the author, 2026-09-11)"
            ),
            "half a thread over the braid's radius": BraidMeasurement(
                Double(crestHeightRatio),
                basis: .fractionOf("the braid's outer radius"),
                source: .derived("eight threads round the tube, so one thread is an "
                                 + "eighth of the circumference and a round one stands "
                                 + "half its own width proud"),
                unsettled: "the photograph's outline ripple gives 0.025 of the braid's "
                    + "width on S (0.023 on Z-a, 0.038 on Z-b), against 0.141 of the "
                    + "width here (0.282 of the radius). That ripple is measuring "
                    + "procedure 2, which reads a floor at best, and Task 005J found it "
                    + "cannot be used on a round braid at all: the outline of a round "
                    + "braid is the envelope of its ridges and hides the grooves between "
                    + "them. So the derived value stays, and nothing measured stands "
                    + "either for it or against it (the author, 2026-09-11)"
            ),
            "fibre stripe angle in degrees": .declared(
                Double(fibreStripeAngleDegrees),
                calibratedBy: "calibrated by eye against a photograph, not derived: the "
                    + "slant of the fibre inside a thread against the thread's own run, "
                    + "on book A p.8's zoom. Which way it leans is not settled by the "
                    + "photograph: four of five readable beans lean the way drawn and "
                    + "one the other"
            ),
            "fibre stripes across a thread's width": .declared(
                Double(fibreStripesAcrossThreadWidth),
                calibratedBy: "calibrated by eye against a photograph, not derived: how "
                    + "many fibre stripes lie side by side across one thread, on book A "
                    + "p.8's zoom"
            ),
            "fibre stripe relief": .declared(
                Double(RoundTube16SurfaceMesh.twistReliefRatio),
                calibratedBy: "calibrated by eye against a photograph, not derived: the "
                    + "sixteen-thread tube's own figure, borrowed and held against book A "
                    + "p.8's zoom for how much the stripes stand out"
            ),
            "valley shading at a cell's edge": .declared(
                Double(RoundTube16StrandTextureFactory.valleyOcclusion),
                calibratedBy: "calibrated by eye against a photograph, not derived: the "
                    + "sixteen-thread tube's own figure, borrowed and held against book A "
                    + "p.8's zoom for how dark the groove between two columns looks"
            ),
            "how far across a cell the valley shading reaches": .declared(
                Double(RoundTube16StrandTextureFactory.valleyOcclusionWidth),
                calibratedBy: "calibrated by eye against a photograph, not derived: the "
                    + "sixteen-thread tube's own figure, borrowed and held against book A "
                    + "p.8's zoom for how wide the groove looks"
            ),
            "radius on screen": .declared(
                Double(defaultRadius),
                calibratedBy: "how big the braid should be in the view; a display size, "
                    + "not a shape"
            ),
        ])
    }

    static let defaultRadius: Float = 0.48
    static let defaultPatternRepeatCount = 2

    /// How far a ridge stands above the valley, as a fraction of the outer radius.
    ///
    /// **Worked out, not measured.** Eight threads lie side by side round the
    /// tube, so one thread's width is an eighth of the valley floor's
    /// circumference, and a round thread stands half its own width proud. Writing
    /// the floor as `f` and the outer radius as `1`, that is
    /// `1 - f = (2 pi f / 8) / 2`, so `f = 1 / (1 + pi/8)` and the ridge is
    /// `1 - f` of the outer radius. It uses the same relation the measurements do
    /// — the circumference is the thread count — rather than a new conversion
    /// (`docs/tasks/025-5-adding-a-recipe.md`).
    static let crestHeightRatio: Float = 1 - 1 / (1 + .pi / 8)

    /// Angle between the fibre stripes and a thread's own run.
    ///
    /// **Calibrated by eye against a photograph, not derived** (Task 032 stage 3):
    /// book A p.8's zoom, where the fibre shows as fine stripes inside every
    /// thread. It is a look and not a shape -- nothing in how the braid is made
    /// sets it -- so `shape` carries it as `.declared`. The maps it goes into are
    /// the sixteen-thread tube's, borrowed (`RoundTube8StrandTexture`).
    ///
    /// **Signed, for which way the stripes lean.** Positive leans them falling to
    /// the right with the braid lying across the view, which is rising to the
    /// right with it standing up, as it stands in the photograph. **Which way the
    /// photograph's fibre leans is not settled**: of five beans whose spectrum
    /// shows a fibre-sized period, four lean this way and one the other, and a
    /// first look by eye had it the other way (`RoundTube8StrandTexture.twist`).
    ///
    /// The fibre runs nearly along the thread, so the angle is small. Those five
    /// beans lean between 11 and 41 degrees either way, and the median of their
    /// size is 14.9, which is where the eye had put it.
    static let fibreStripeAngleDegrees: Float = 15
    /// How many fibre stripes lie side by side across one thread's width.
    /// **Calibrated by eye against the same photograph, not derived** — counted
    /// across a thread, because the stripes run nearly along it and that is the
    /// way they can be counted.
    ///
    /// The same five beans give 6.6 across. The stripes have to come back whole
    /// at the end of a cell (`RoundTube8StrandTexture.stripesPerCell`), and at 15
    /// degrees that allows 5.2 across or 7.8; this gives 7.8, which the eye kept.
    static let fibreStripesAcrossThreadWidth: Float = 8

    /// Samples down one cell and across it. Across resolves the round ridge; along
    /// resolves the curve of the cylinder the cell is wrapped onto, which matters
    /// here because a cell reaches a long way round.
    static let defaultAlongSubdivisions = 12
    static let defaultAcrossSubdivisions = 10
    static let minimumAlongSubdivisions = 4
    static let minimumAcrossSubdivisions = 4

    /// The tile's length, derived from the radius and the aspect ratio the pattern
    /// declares. **Never chosen independently**: a radius and a length picked apart
    /// would lean every ridge at an angle the pattern never had.
    static func length(radius: Float, aspectRatio: Float, patternRepeatCount: Int) -> Float {
        2 * .pi * radius * aspectRatio * Float(patternRepeatCount)
    }

    static func generate(
        pattern: RoundTube8SurfacePattern,
        radius: Float = defaultRadius,
        patternRepeatCount: Int = defaultPatternRepeatCount,
        alongSubdivisions: Int = defaultAlongSubdivisions,
        acrossSubdivisions: Int = defaultAcrossSubdivisions
    ) -> RoundTube8SurfaceMeshData? {
        let tileLength = length(
            radius: radius,
            aspectRatio: pattern.aspectRatio,
            patternRepeatCount: patternRepeatCount
        )
        guard
            radius.isFinite, radius > 0,
            pattern.aspectRatio.isFinite, pattern.aspectRatio > 0,
            tileLength.isFinite, tileLength > 0,
            patternRepeatCount > 0,
            pattern.rowCount > 0,
            alongSubdivisions >= minimumAlongSubdivisions,
            acrossSubdivisions >= minimumAcrossSubdivisions,
            !pattern.surface.segments.isEmpty
        else {
            return nil
        }

        let floor = radius * (1 - crestHeightRatio)
        let repeatLength = tileLength / Float(patternRepeatCount)

        var positions = [SIMD3<Float>]()
        var normals = [SIMD3<Float>]()
        var tangents = [SIMD3<Float>]()
        var bitangents = [SIMD3<Float>]()
        var textures = [SIMD2<Float>]()
        var colorGroups = [ThreadColorID: [UInt32]]()
        var triangleSegments = [Int]()

        for repeatIndex in 0..<patternRepeatCount {
            let base = -tileLength / 2 + Float(repeatIndex) * repeatLength
            for (segmentIndex, segment) in pattern.surface.segments.enumerated() {
                let first = UInt32(positions.count)
                for alongStep in 0...alongSubdivisions {
                    let along = Float(alongStep) / Float(alongSubdivisions)
                    for acrossStep in 0...acrossSubdivisions {
                        let sample = Float(acrossStep) / Float(acrossSubdivisions)
                        let across = crossSectionOffset(forSample: sample)
                        let frame = self.frame(
                            of: segment, along: along, across: across,
                            floor: floor, radius: radius,
                            base: base, repeatLength: repeatLength
                        )
                        positions.append(frame.position)
                        normals.append(frame.normal)
                        tangents.append(frame.tangent)
                        bitangents.append(frame.bitangent)
                        textures.append(SIMD2(along, sample))
                    }
                }

                let stride = UInt32(acrossSubdivisions + 1)
                var indices = colorGroups[segment.colorID] ?? []
                for alongStep in 0..<UInt32(alongSubdivisions) {
                    for acrossStep in 0..<UInt32(acrossSubdivisions) {
                        let corner = first + alongStep * stride + acrossStep
                        indices.append(contentsOf: [
                            corner, corner + stride, corner + 1,
                            corner + 1, corner + stride, corner + stride + 1,
                        ])
                        triangleSegments.append(contentsOf: [segmentIndex, segmentIndex])
                    }
                }
                colorGroups[segment.colorID] = indices
            }
        }

        let mesh = RoundTube8SurfaceMeshData(
            positions: positions,
            normals: normals,
            tangents: tangents,
            bitangents: bitangents,
            textureCoordinates: textures,
            colorGroups: colorGroups,
            triangleSegmentIndices: triangleSegments,
            crestRadius: radius,
            valleyFloorRadius: floor,
            length: tileLength,
            patternRepeatCount: patternRepeatCount,
            rowCount: pattern.rowCount
        )
        return isConsistent(mesh) ? mesh : nil
    }

    // MARK: - The surface

    /// **Borrowed from `RoundTube16SurfaceMesh.crestProfile`**: a semi-ellipse,
    /// 1 on the crest and 0 at both edges, so that neighbouring ridges meet on the
    /// valley floor however tall either of them is.
    static func crestProfile(across: Float) -> Float {
        let clamped = min(max(across, -1), 1)
        return sqrt(max(0, 1 - clamped * clamped))
    }

    /// **Borrowed from `RoundTube16SurfaceMesh.crossSectionOffset`**: maps an even
    /// 0...1 sampling onto the cross-section so the steps stay even along the
    /// elliptical arc instead of bunching on the crest.
    static func crossSectionOffset(forSample sample: Float) -> Float {
        sin(.pi / 2 * (2 * min(max(sample, 0), 1) - 1))
    }

    /// Where a point of a cell sits on the braid, and the frame there.
    ///
    /// The normal is taken from the surface itself rather than assumed radial: a
    /// ridge falls away to the valley on both sides, and a shading that ignored
    /// that would leave the grooves invisible. **The frame is right-handed and its
    /// normal points out of the braid**, so the triangles built on it wind outward
    /// and the near side of the braid is drawn.
    static func frame(
        of segment: BraidStrandSegment,
        along: Float,
        across: Float,
        floor: Float,
        radius: Float,
        base: Float,
        repeatLength: Float
    ) -> (position: SIMD3<Float>, normal: SIMD3<Float>,
          tangent: SIMD3<Float>, bitangent: SIMD3<Float>) {
        func at(_ along: Float, _ across: Float) -> SIMD3<Float> {
            let surface = segment.surfacePoint(along: along, across: across)
            let height = floor + (radius - floor) * crestProfile(across: across)
            let angle = 2 * .pi * surface.x
            // **The stand's own placement, seen from the braiding point**: `(sin,
            // cos)`, as `BraidStands.round` puts a position on the stand seen from
            // above. The braiding point is at `+x` — later cycles are made nearer
            // it — so looking back down the braid from there, `+y` is to the right
            // and `+z` is up, which is the stand's east and north.
            //
            // It was `(cos, sin)` until Task 032, which is the same formula with
            // the two turned round: **a mirror.** Every braid this drawer drew came
            // out as its own reflection, and every triangle was wound facing into
            // the braid (`BraidOrientationTests`).
            return SIMD3(
                base + repeatLength * surface.y,
                height * sin(angle),
                height * cos(angle)
            )
        }
        let step: Float = 1e-3
        let position = at(along, across)
        var tangent = at(min(along + step, 1), across) - at(max(along - step, 0), across)
        var bitangent = at(along, min(across + step, 1)) - at(along, max(across - step, -1))
        tangent = normalised(tangent)
        bitangent = normalised(bitangent)
        // **Outward by construction**: along the braid towards the braiding point,
        // then round it clockwise seen from there, and the right hand points out.
        // Nothing turns the normal round afterwards. Something did until Task 032,
        // at every one of the 18,304 vertices, because the ring was strung the
        // other way round.
        let normal = normalised(cross(tangent, bitangent))
        return (position, normal, tangent, bitangent)
    }

    private static func normalised(_ vector: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(vector)
        return length > 0 ? vector / length : SIMD3(0, 0, 1)
    }

    private static func isConsistent(_ mesh: RoundTube8SurfaceMeshData) -> Bool {
        let count = mesh.positions.count
        guard
            count > 0,
            mesh.normals.count == count,
            mesh.tangents.count == count,
            mesh.bitangents.count == count,
            mesh.textureCoordinates.count == count,
            mesh.triangleCount == mesh.triangleSegmentIndices.count,
            mesh.positions.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
        else { return false }
        return mesh.allTriangleIndices.allSatisfy { $0 < UInt32(count) }
    }
}
