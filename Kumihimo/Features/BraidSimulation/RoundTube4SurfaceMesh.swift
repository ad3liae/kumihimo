import Foundation
import simd

struct RoundTube4SurfaceMeshData: Sendable {
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
    /// The vertices of each thread's visible run, repeat by repeat and cell by
    /// cell: `runVertexRanges[repeat * cells + cell]`. A run's vertices are one
    /// block, `along` by `across`, laid down in that order.
    let runVertexRanges: [Range<Int>]
    /// The vertices of what lies beneath each cell, in the same order: the
    /// thread's own cell at the valley floor, which is what a gap between two
    /// runs shows.
    let beneathVertexRanges: [Range<Int>]
    /// Samples along a run and across it, plus one each.
    let runAlongSamples: Int
    let runAcrossSamples: Int

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

/// Draws a tube of four threads (Task 054): a run for each cell of the surface,
/// laid on a cylinder, with the cell beneath it at the valley floor so the tube
/// closes.
///
/// **Made the way `RoundTube8SurfaceMesh` is, and kept apart from it** — the
/// author's ruling of 2026-09-22: a drawer belongs to its family and so do its
/// shape values. It takes over what Tasks 045-053 settled for the eight-thread
/// tube: **a bundle with a blunt head on top and a tail that keeps its width and
/// goes under the runs laid after it** (`RoundTube4Bundle`), whichever stands
/// higher at a place being the one seen, and the same rule read by the card
/// (`RoundTube4SurfacePattern.runsStanding`). The crest's section and its even
/// sampling are the sixteen-thread tube's, as they are for the eight.
///
/// **The other drawers are untouched.** This is an addition beside them.
enum RoundTube4SurfaceMesh {
    /// **The family this draws**: four threads, a tube.
    static let family = BraidFamily.roundTube(threads: 4)

    /// Where every number this drawing rests on came from. **No value here is
    /// changed by saying so.**
    static var shape: BraidFamilyShape {
        let bundle = RoundTube4Bundle.standard
        let byEye = "calibrated by eye against a photograph, not derived: "
        var values: [String: BraidMeasurement] = [
            "one cycle over the braid's diameter": BraidMeasurement(
                Double(RoundTube4SurfacePatternGenerator.pitchOverDiameter),
                // Photographs a and b; c's width could not be read cleanly.
                spread: 0.77...0.80,
                basis: .fractionOf("the braid's own diameter"),
                source: .observed("book A p.10, photograph b; Task 054, "
                                  + "Scripts/task054/measure_photograph.py"),
                unsettled: "**the stitch's period, not the colour's**: 47.3 px along a braid "
                    + "59 px across (b; a gives 46.0 over 60, 0.767). Measuring procedure 6 "
                    + "reads the colour's period, and with these colourings a place keeps "
                    + "its colour, so there is none. **Read below the resolution procedure 6 "
                    + "asks for**: the page is at the spread's scale, about 59 px a braid "
                    + "against the zoom's 230-260, and the braid was cut by its texture "
                    + "because Task 031's cut does not find braids this small"
            ),
            "half a thread over the braid's radius": BraidMeasurement(
                Double(crestHeightRatio),
                basis: .fractionOf("the braid's outer radius"),
                source: .derived("four threads round the tube, so one thread is a "
                                 + "quarter of the circumference and a round one stands "
                                 + "half its own width proud")
            ),
            "fibre stripe angle in degrees": .declared(
                Double(fibreStripeAngleDegrees),
                calibratedBy: byEye + "the eight-thread tube's figure, held against "
                    + "book A p.10's photograph b, where the fibre runs nearly along a bundle"
            ),
            "fibre stripes across a thread's width": .declared(
                Double(fibreStripesAcrossThreadWidth),
                calibratedBy: byEye + "how many fibre stripes lie across one bundle on "
                    + "book A p.10's photograph b; a bundle here is twice as wide a share "
                    + "of the braid as on the eight-thread tube"
            ),
            "fibre stripe relief": .declared(
                Double(fibreStripeRelief),
                calibratedBy: byEye + "the eight-thread tube's figure, held against "
                    + "book A p.10's photograph b"
            ),
            "valley shading at a cell's edge": .declared(
                Double(RoundTube16StrandTextureFactory.valleyOcclusion),
                calibratedBy: byEye + "the sixteen-thread tube's figure, borrowed as the "
                    + "eight-thread tube borrows it"
            ),
            "how far across a cell the valley shading reaches": .declared(
                Double(RoundTube16StrandTextureFactory.valleyOcclusionWidth),
                calibratedBy: byEye + "the sixteen-thread tube's figure, borrowed as the "
                    + "eight-thread tube borrows it"
            ),
            "a run's lean, in columns per cycle": .declared(
                Double(bundle.leanColumnsPerCycle),
                calibratedBy: byEye + "how far a bundle's centreline moves round the "
                    + "braid as it goes along it, on book A p.10's photograph b (about 23 "
                    + "degrees to the braid). Which way is the stitch's, not the carry's "
                    + "(Task 053), and it is the other way from the eight-thread tube's"
            ),
            "how far a run goes on beneath the next thread, in cycles": .declared(
                Double(bundle.tuckedCycles),
                calibratedBy: byEye + "the eight-thread tube's figure (Task 051), in "
                    + "cycles, kept because a place here too takes a new thread every "
                    + "cycle, half a cycle from its neighbours"
            ),
            "how far a run's head is rounded, in cycles past its arrival": .declared(
                Double(bundle.headRoundingCycles),
                calibratedBy: byEye + "the eight-thread tube's figure (Task 051); short, "
                    + "so the head is blunt, as photograph b's bundles are"
            ),
            "over how much of a run its height's arc stands, in cycles": .declared(
                Double(bundle.arcSpanCycles),
                calibratedBy: byEye + "the eight-thread tube's figure (Task 051): the "
                    + "run is down on the floor where the runs laid after it cover its tail"
            ),
            "how far a run's tail bends round the braid, in columns": .declared(
                Double(bundle.tailBendColumns),
                calibratedBy: byEye + "how far a tail goes into the next lane the way the "
                    + "run leans, on book A p.10's photograph b, where the purple bundles' "
                    + "tails go under the white lane beside them"
            ),
            "where a run's tail begins to bend, in cycles past its arrival": .declared(
                Double(bundle.tailBendFromCycles),
                calibratedBy: byEye + "the eight-thread tube's figure (Task 051): past "
                    + "the run's middle"
            ),
            "where a run's tail begins to narrow, in cycles past its arrival": .declared(
                Double(bundle.tailNarrowsFromCycles),
                calibratedBy: byEye + "the eight-thread tube's figure (Task 051): the "
                    + "next thread's arrival, so the tail is as wide as the run where it "
                    + "goes under"
            ),
            "how far a run stands over the valley floor, over the braid's radius": .declared(
                Double(runHeightOverRadius),
                basis: .fractionOf("the braid's outer radius"),
                calibratedBy: byEye + "how much a bundle domes on book A p.10's "
                    + "photograph b. The derived figure beside it is for threads one to a "
                    + "column that do not overlap; these runs are wider than a column"
            ),
            "where a run stands highest, in cycles past its arrival": BraidMeasurement(
                Double(bundle.crestAtCycles),
                source: .derived("the middle of the height's arc, which is even about "
                                 + "its middle")
            ),
            "radius on screen": .declared(
                Double(defaultRadius),
                calibratedBy: "how big the braid should be in the view; a display size, "
                    + "not a shape"
            ),
        ]
        values.merge(bellyWidth) { first, _ in first }
        return BraidFamilyShape(family: family, values: values)
    }

    /// **A run's widest half-width**: derived while it is the one column a
    /// thread holds, and set by eye once a run is let show wider.
    private static var bellyWidth: [String: BraidMeasurement] {
        let widest = RoundTube4Bundle.standard.widestHalfWidthInColumns
        let name = "a run's widest half-width, in columns"
        if widest == RoundTube4Bundle.oneThreadHalfWidthInColumns {
            return [name: BraidMeasurement(
                Double(widest),
                basis: .fractionOf("one column"),
                source: .derived("a thread is one column wide: four threads round the tube")
            )]
        }
        return [name: .declared(
            Double(widest),
            basis: .fractionOf("one column"),
            calibratedBy: "calibrated by eye against a photograph, not derived: how wide a "
                + "bundle looks against the columns on book A p.10's photograph b; wider "
                + "than the column its thread holds, so that bundles meet over the floor"
        )]
    }

    static let defaultRadius: Float = 0.48
    /// Two repeats of two cycles each: a tile as long as the eight-thread
    /// tube's is in cycles would be twice this, and the tiles are laid end to
    /// end anyway.
    static let defaultPatternRepeatCount = 2

    /// How far a ridge stands above the valley, as a fraction of the outer radius.
    ///
    /// **Worked out, not measured**, the eight-thread tube's way: four threads
    /// side by side round the tube, one thread a quarter of the valley floor's
    /// circumference, standing half its own width proud. With the floor `f` and
    /// the outer radius `1`, `1 - f = (2 pi f / 4) / 2`, so `f = 1 / (1 + pi/4)`.
    static let crestHeightRatio: Float = 1 - 1 / (1 + .pi / 4)

    /// How far a run stands above the valley floor, as a fraction of the braid's
    /// outer radius — **the drawing's own depth**, not `crestHeightRatio`, which
    /// is for threads one to a column that do not overlap.
    ///
    /// **Calibrated by eye against book A p.10's photograph b, not derived**,
    /// and not read off the braid's outline (measuring procedure 2 cannot give
    /// the grooves of a round braid).
    static let runHeightOverRadius: Float = 0.44

    /// How far beneath the valley floor the cell under a run lies, as a
    /// fraction of the ridge. **Not a shape figure**: it only keeps the cell
    /// beneath from sharing the floor with the edges of the runs above it.
    static let beneathClearanceOfRidge: Float = 0.02

    /// Angle between the fibre stripes and a thread's own run. **Calibrated by
    /// eye, not derived**: the eight-thread tube's figure (Task 049), held
    /// against book A p.10's photograph b, where the fibre runs nearly along a
    /// bundle. Signed as the eight-thread tube's is.
    static let fibreStripeAngleDegrees: Float = 8
    /// How many fibre stripes lie side by side across one thread's width.
    /// **Calibrated by eye, not derived**: a bundle here is a quarter of the
    /// braid round, twice the eight-thread tube's share, and photograph b's
    /// bundles carry a fine grain across the whole of that.
    static let fibreStripesAcrossThreadWidth: Float = 24

    /// How far the fibre stripes stand out, as the sixteen-thread factory reads
    /// it. **The eight-thread tube's figure**, held against photograph b.
    static let fibreStripeRelief: Float = 0.003

    /// Samples along one run and across it. Across resolves the round ridge;
    /// along resolves the shoulder and the tip, **packed towards both ends the
    /// way the across samples are packed towards the edges**
    /// (`crossSectionOffset`), because that is where the run turns fastest. A
    /// run is about one and a half cycles long, so it has twice the samples
    /// along that a one-cycle cell had.
    static let defaultAlongSubdivisions = 24
    static let defaultAcrossSubdivisions = 10
    static let minimumAlongSubdivisions = 4
    static let minimumAcrossSubdivisions = 4
    /// Round the arc of a cell beneath. Only the curvature needs resolving.
    static let beneathAcrossSubdivisions = 4

    /// The tile's length, derived from the radius and the aspect ratio the pattern
    /// declares. **Never chosen independently**: a radius and a length picked apart
    /// would lean every ridge at an angle the pattern never had.
    static func length(radius: Float, aspectRatio: Float, patternRepeatCount: Int) -> Float {
        2 * .pi * radius * aspectRatio * Float(patternRepeatCount)
    }

    static func generate(
        pattern: RoundTube4SurfacePattern,
        radius: Float = defaultRadius,
        patternRepeatCount: Int = defaultPatternRepeatCount,
        alongSubdivisions: Int = defaultAlongSubdivisions,
        acrossSubdivisions: Int = defaultAcrossSubdivisions,
        bundle: RoundTube4Bundle = .standard
    ) -> RoundTube4SurfaceMeshData? {
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
            bundle.leanColumnsPerCycle.isFinite,
            bundle.tuckedCycles >= 0,
            bundle.headRoundingCycles > 0,
            bundle.arcSpanCycles > 0, bundle.arcSpanCycles <= bundle.lengthInCycles,
            bundle.tailBendColumns.isFinite,
            bundle.tailBendFromCycles >= 0, bundle.tailBendFromCycles < bundle.lengthInCycles,
            bundle.tailNarrowsFromCycles > bundle.headRoundingCycles,
            bundle.tailNarrowsFromCycles < bundle.lengthInCycles,
            bundle.widestHalfWidthInColumns > 0,
            !pattern.surface.segments.isEmpty
        else {
            return nil
        }

        let floor = radius * (1 - runHeightOverRadius)
        let repeatLength = tileLength / Float(patternRepeatCount)
        let beneath = floor - beneathClearanceOfRidge * (radius - floor)

        var positions = [SIMD3<Float>]()
        var normals = [SIMD3<Float>]()
        var tangents = [SIMD3<Float>]()
        var bitangents = [SIMD3<Float>]()
        var textures = [SIMD2<Float>]()
        var colorGroups = [ThreadColorID: [UInt32]]()
        var triangleSegments = [Int]()
        var runRanges = [Range<Int>]()
        var beneathRanges = [Range<Int>]()

        func grid(first: UInt32, along: Int, across: Int, segmentIndex: Int,
                  into indices: inout [UInt32]) {
            let stride = UInt32(across + 1)
            for alongStep in 0..<UInt32(along) {
                for acrossStep in 0..<UInt32(across) {
                    let corner = first + alongStep * stride + acrossStep
                    indices.append(contentsOf: [
                        corner, corner + stride, corner + 1,
                        corner + 1, corner + stride, corner + stride + 1,
                    ])
                    triangleSegments.append(contentsOf: [segmentIndex, segmentIndex])
                }
            }
        }

        for repeatIndex in 0..<patternRepeatCount {
            let base = -tileLength / 2 + Float(repeatIndex) * repeatLength
            for (segmentIndex, segment) in pattern.surface.segments.enumerated() {
                var indices = colorGroups[segment.colorID] ?? []

                // The run: the thread as it shows.
                let first = positions.count
                for alongStep in 0...alongSubdivisions {
                    let along = (1 + crossSectionOffset(
                        forSample: Float(alongStep) / Float(alongSubdivisions)
                    )) / 2
                    for acrossStep in 0...acrossSubdivisions {
                        let sample = Float(acrossStep) / Float(acrossSubdivisions)
                        let frame = self.frame(
                            of: segment,
                            cycles: along * bundle.lengthInCycles,
                            across: crossSectionOffset(forSample: sample),
                            leanDirection: pattern.leanBySegment[segmentIndex],
                            bundle: bundle,
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
                runRanges.append(first..<positions.count)
                grid(first: UInt32(first), along: alongSubdivisions,
                     across: acrossSubdivisions, segmentIndex: segmentIndex, into: &indices)

                // Beneath it: the thread's own cell, at the valley floor. Straight
                // along the braid, so one step along is enough.
                let under = positions.count
                for end in [segment.centerlineStart.y, segment.centerlineEnd.y] {
                    for acrossStep in 0...beneathAcrossSubdivisions {
                        let sample = Float(acrossStep) / Float(beneathAcrossSubdivisions)
                        let turns = segment.centerlineStart.x
                            + segment.startHalfWidth.x * (2 * sample - 1)
                        let angle = 2 * .pi * turns
                        let outward = SIMD3<Float>(0, sin(angle), cos(angle))
                        positions.append(SIMD3(
                            base + repeatLength * end,
                            beneath * sin(angle),
                            beneath * cos(angle)
                        ))
                        normals.append(outward)
                        tangents.append(SIMD3(1, 0, 0))
                        bitangents.append(cross(outward, SIMD3(1, 0, 0)))
                        // The edge of a thread in the stripe and shading maps:
                        // this is only ever seen down a gap.
                        textures.append(SIMD2(0.5, 0))
                    }
                }
                beneathRanges.append(under..<positions.count)
                grid(first: UInt32(under), along: 1, across: beneathAcrossSubdivisions,
                     segmentIndex: segmentIndex, into: &indices)

                colorGroups[segment.colorID] = indices
            }
        }

        let mesh = RoundTube4SurfaceMeshData(
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
            rowCount: pattern.rowCount,
            runVertexRanges: runRanges,
            beneathVertexRanges: beneathRanges,
            runAlongSamples: alongSubdivisions + 1,
            runAcrossSamples: acrossSubdivisions + 1
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

    /// Where a point of a thread's visible run sits on the braid, and the frame
    /// there: `cycles` past the thread's arrival (0 to the run's length) and
    /// `across` its width, -1...1.
    ///
    /// The normal is taken from the surface itself rather than assumed radial: a
    /// ridge falls away to the valley on both sides, and a shading that ignored
    /// that would leave the grooves invisible. **The frame is right-handed and its
    /// normal points out of the braid**, so the triangles built on it wind outward
    /// and the near side of the braid is drawn.
    static func frame(
        of segment: BraidStrandSegment,
        cycles: Float,
        across: Float,
        leanDirection: Float,
        cycleLength: Float? = nil,
        bundle: RoundTube4Bundle = .standard,
        floor: Float,
        radius: Float,
        base: Float,
        repeatLength: Float
    ) -> (position: SIMD3<Float>, normal: SIMD3<Float>,
          tangent: SIMD3<Float>, bitangent: SIMD3<Float>) {
        let columns = Float(RoundTube4SurfacePatternGenerator.requiredThreadCount)
        // One cycle along the braid, as a share of the repeat: the pattern's
        // (`RoundTube4SurfacePattern.cycleInRepeats`). A cell is one cycle long
        // only for a braid of one table, which is what it defaults to.
        let cycle = cycleLength ?? (segment.centerlineEnd.y - segment.centerlineStart.y)
        let ridge = radius - floor
        // Never quite a point, so that the width still has a direction at the
        // tip and the frame there is defined.
        let narrowest: Float = 1e-3
        func at(_ cycles: Float, _ across: Float) -> SIMD3<Float> {
            let halfWidth = max(bundle.halfWidthInColumns(atCycles: cycles), narrowest)
            let turns = segment.centerlineStart.x
                + (bundle.leanInColumns(atCycles: cycles, direction: leanDirection)
                    + halfWidth * across) / columns
            // The height the card reads too (`RoundTube4Bundle.standingFraction`
            // is this, the envelope times the crest's section), written the way
            // it was so that not one vertex moves.
            let height = floor + ridge * bundle.heightFraction(atCycles: cycles)
                * crestProfile(across: across)
            let angle = 2 * .pi * turns
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
                base + repeatLength * (segment.centerlineStart.y + cycles * cycle),
                height * sin(angle),
                height * cos(angle)
            )
        }
        let length = bundle.lengthInCycles
        let step: Float = 1e-3 * length
        let position = at(cycles, across)
        var tangent = at(min(cycles + step, length), across) - at(max(cycles - step, 0), across)
        var bitangent = at(cycles, min(across + 1e-3, 1)) - at(cycles, max(across - 1e-3, -1))
        tangent = normalised(tangent)
        bitangent = normalised(bitangent)
        // **Outward by construction**: along the braid towards the braiding point,
        // then round it clockwise seen from there, and the right hand points out.
        // Nothing turns the normal round afterwards. Something did until Task 032,
        // at every vertex, because the ring was strung the other way round.
        let normal = normalised(cross(tangent, bitangent))
        return (position, normal, tangent, bitangent)
    }

    private static func normalised(_ vector: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(vector)
        return length > 0 ? vector / length : SIMD3(0, 0, 1)
    }

    private static func isConsistent(_ mesh: RoundTube4SurfaceMeshData) -> Bool {
        let count = mesh.positions.count
        guard
            count > 0,
            mesh.normals.count == count,
            mesh.tangents.count == count,
            mesh.bitangents.count == count,
            mesh.textureCoordinates.count == count,
            mesh.triangleCount == mesh.triangleSegmentIndices.count,
            mesh.positions.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }),
            mesh.normals.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
        else { return false }
        return mesh.allTriangleIndices.allSatisfy { $0 < UInt32(count) }
    }
}
