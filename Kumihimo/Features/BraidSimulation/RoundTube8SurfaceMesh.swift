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
/// **A thread shows as a bundle that leans, with a blunt head on top and a tail
/// that goes under the runs laid after it** (Task 045, reshaped by Task 051).
/// Each cell of the pattern — the thread standing at its place from its arrival
/// to the next thread's — is drawn as that thread's visible run
/// (`RoundTube8Bundle`): full width a short way after it arrives, leaning round
/// the braid the way the carry goes, and past its middle bending into the next
/// lane, where it goes under the side of the run laid half a cycle after it and
/// under the next thread's head, and only then narrows. Runs overlap, and
/// **whichever stands higher at a place is the one seen**: the depth test draws
/// the line where two cross, so where a tail stops showing is the covering
/// run's own side. The card reads the same rule
/// (`RoundTube8SurfacePattern.runsStanding`).
///
/// **Beneath every cell lies the thread's own cell at the valley floor**, a hair
/// below it, so that a gap between two runs shows the thread lying there rather
/// than the background. It is the same cell the pattern gives, so the tube is
/// closed whatever the runs do.
///
/// It replaced a round-ended bead one column wide and one cycle long, square to
/// the braid, with a groove of its own depth at each end (Task 033). That read
/// as a cob of corn (the author, 2026-09-18). Then a lens pointed at both ends
/// under an arc over its whole length (Tasks 046-049), which read as closed
/// ovals in a row (the author, 2026-09-21).
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
        var values: [String: BraidMeasurement] = [
            "one cycle over the braid's diameter": BraidMeasurement(
                Double(RoundTube8SurfacePatternGenerator.pitchOverDiameter),
                // Task 031's two readings of the colour's period over the braid's
                // width, halved as the cycle is now read (S 1.614/2, Z-a
                // 2.023/2), rounded outward.
                spread: 0.80...1.02,
                basis: .fractionOf("the braid's own diameter"),
                source: .observed("book A p.8-9, the zoom; Task 031 stage 1"),
                unsettled: "**the measurement is the colour's period, 1.614 of the braid's "
                    + "width on S** (book A p.8-9's zoom, Task 031); this is that period "
                    + "divided by the two drawn cycles it now takes to come round (Task "
                    + "048's rework). Nothing was measured again, and 0.807 was not "
                    + "observed on its own. Divided by four, as Task 031 read it, it gave "
                    + "0.403 and drew each colour two cells at a time. The three braids "
                    + "photographed do not agree — S gives 0.807 and Z-a 1.012, and "
                    + "colouring b cannot be read this way at all — and the spread is those "
                    + "two braids, not an error bar. The value shipped is S's, whose signal "
                    + "is the cleanest and whose braid is drawn. **History, not a current "
                    + "result**: while the cycle was 0.403 and a place held one column, Task "
                    + "031 and 032 compared the colour band (derived 46.5 degrees against "
                    + "54.5 measured on S) and found the drawn band swinging from 17.5 to "
                    + "63.0 degrees with the turn of the braid; those comparisons belong to "
                    + "that placement"
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
                Double(fibreStripeRelief),
                calibratedBy: "calibrated by eye against a photograph, not derived: how much "
                    + "the stripes stand out, held against book A p.8's zoom at one braid "
                    + "width (Task 049). It was the sixteen-thread tube's 0.005, borrowed; "
                    + "this braid's runs are broader on screen and that read as a few big "
                    + "ridges"
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
            "a run's lean, in columns per cycle": .declared(
                Double(RoundTube8Bundle.standard.leanColumnsPerCycle),
                calibratedBy: "calibrated by eye against a photograph, not derived: how far "
                    + "a bean's centreline moves round the braid as it goes along it, on book "
                    + "A p.8's zoom. The table gives only which way (the carry's); this is "
                    + "not Task 032's 36 degrees, which is the step between neighbouring "
                    + "beans and not the lean of one"
            ),
            "how far a run goes on beneath the next thread, in cycles": .declared(
                Double(RoundTube8Bundle.standard.tuckedCycles),
                calibratedBy: "calibrated by eye against a photograph, not derived: how far "
                    + "past the next thread's arrival a run's tail goes on under the runs laid "
                    + "after it, keeping its width until they cover it (Task 051). Since Task "
                    + "051 it no longer sets the height, which has a span of its own"
            ),
            "how far a run's head is rounded, in cycles past its arrival": .declared(
                Double(RoundTube8Bundle.standard.headRoundingCycles),
                calibratedBy: "calibrated by eye against a photograph, not derived: how soon a "
                    + "bundle's head is at its full width, on book A p.8's zoom; short, so the "
                    + "head is blunt where the photograph's bundles are (Task 051)"
            ),
            "over how much of a run its height's arc stands, in cycles": .declared(
                Double(RoundTube8Bundle.standard.arcSpanCycles),
                calibratedBy: "calibrated by eye against a photograph, not derived: the arc is "
                    + "the author's form (even, semicircular); its span was set so that a run "
                    + "is down on the floor where the runs laid after it cover its tail "
                    + "(Task 051)"
            ),
            "how far a run's tail bends round the braid, in columns": .declared(
                Double(RoundTube8Bundle.standard.tailBendColumns),
                calibratedBy: "calibrated by eye against a photograph, not derived: how far a "
                    + "tail goes into the next lane the way the run leans, so that it goes "
                    + "under the side of the run laid half a cycle after it, on book A p.8's "
                    + "zoom (Task 051). The same for every run; no neighbour is chosen"
            ),
            "where a run's tail begins to bend, in cycles past its arrival": .declared(
                Double(RoundTube8Bundle.standard.tailBendFromCycles),
                calibratedBy: "calibrated by eye against a photograph, not derived: past the "
                    + "run's middle, so the belly stays where Task 048 put it (Task 051)"
            ),
            "where a run's tail begins to narrow, in cycles past its arrival": .declared(
                Double(RoundTube8Bundle.standard.tailNarrowsFromCycles),
                calibratedBy: "calibrated by eye against a photograph, not derived: the next "
                    + "thread's arrival, so that a tail is still as wide as the run where it "
                    + "goes under (Task 051)"
            ),
            "how far a run stands over the valley floor, over the braid's radius": .declared(
                Double(runHeightOverRadius),
                basis: .fractionOf("the braid's outer radius"),
                calibratedBy: "calibrated by eye against a photograph, not derived: how much "
                    + "a bean domes on book A p.8's zoom. The derived figure beside it is for "
                    + "threads one to a column that do not overlap; these runs are wider than "
                    + "a column and do overlap (Task 049's rework)"
            ),
            "where a run stands highest, in cycles past its arrival": BraidMeasurement(
                Double(RoundTube8Bundle.standard.crestAtCycles),
                source: .derived("the middle of the height's arc: it is a circular arc, even "
                                 + "about the middle, so there is no figure to set here (the "
                                 + "author's ruling on Task 049's rework: the swelling is not "
                                 + "to be lopsided)")
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
    /// thread holds, and set by eye once a run is let show wider (Task 046).
    private static var bellyWidth: [String: BraidMeasurement] {
        let widest = RoundTube8Bundle.standard.widestHalfWidthInColumns
        let name = "a run's widest half-width, in columns"
        if widest == RoundTube8Bundle.oneThreadHalfWidthInColumns {
            return [name: BraidMeasurement(
                Double(widest),
                basis: .fractionOf("one column"),
                source: .derived("a thread is one column wide: eight threads round the tube")
            )]
        }
        return [name: .declared(
            Double(widest),
            basis: .fractionOf("one column"),
            calibratedBy: "calibrated by eye against a photograph, not derived: how wide a "
                + "bean's belly looks against the columns, on book A p.8's zoom; wider than "
                + "the column its thread holds, so that bellies meet over the floor (Task 046)"
        )]
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

    /// How far a run stands above the valley floor, as a fraction of the braid's
    /// outer radius — **the drawing's own depth since Task 049's rework**, and
    /// no longer `crestHeightRatio`.
    ///
    /// `crestHeightRatio` is worked out for threads lying side by side, one to a
    /// column, each standing half its own width proud. **The runs drawn here are
    /// not that**: they are wider than a column (`widestHalfWidthInColumns`) and
    /// they overlap, so a run 0.47 of the braid's width across stood 0.14 of it
    /// tall and read as a flat tile (the author, 2026-09-20). This deepens the
    /// valley between the runs so that one domes.
    ///
    /// **Calibrated by eye against a photograph, not derived, and not read off
    /// the braid's outline** — measuring procedure 2 and Task 005J say the
    /// outline of a round braid cannot give the grooves between its ridges.
    static let runHeightOverRadius: Float = 0.44

    /// How far beneath the valley floor the cell under a run lies, as a
    /// fraction of the ridge. **Not a shape figure**: it only keeps the cell
    /// beneath from sharing the floor with the edges of the runs above it, so
    /// the two never draw over each other.
    static let beneathClearanceOfRidge: Float = 0.02

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
    /// size is 14.9, which is where the eye first put it.
    ///
    /// **Eight since Task 049's rework.** At 15 the stripes crossed the run
    /// plainly on screen, where the photograph's run nearly along the bean; the
    /// figure is set by how the stripes lie on the drawn run, not by the reading
    /// on the photograph alone.
    static let fibreStripeAngleDegrees: Float = 8
    /// How many fibre stripes lie side by side across one thread's width.
    /// **Calibrated by eye against the same photograph, not derived** — counted
    /// across a thread, because the stripes run nearly along it and that is the
    /// way they can be counted.
    ///
    /// The same five beans give 6.6 across a thread, counted on the beans that
    /// showed a readable period. **Fourteen since Task 049**: with the cycle
    /// twice as long and a run about one cycle, eight across drew a handful of
    /// broad ridges down each bean, where the photograph has a fine grain over
    /// the whole of it. The stripes still have to come back whole at the end of
    /// a run (`RoundTube8StrandTexture.stripesPerCell`).
    static let fibreStripesAcrossThreadWidth: Float = 14

    /// How far the fibre stripes stand out, as the sixteen-thread factory reads
    /// it. **The eight-thread tube's own figure since Task 049**, lower than the
    /// sixteen-thread tube's 0.005 it used to borrow: held beside book A p.8's
    /// zoom at one braid width, the borrowed relief drew a few broad ridges
    /// where the photograph has a fine, close grain. **The sixteen-thread side
    /// is not touched** — the factory already takes the figure as an argument.
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
        pattern: RoundTube8SurfacePattern,
        radius: Float = defaultRadius,
        patternRepeatCount: Int = defaultPatternRepeatCount,
        alongSubdivisions: Int = defaultAlongSubdivisions,
        acrossSubdivisions: Int = defaultAcrossSubdivisions,
        bundle: RoundTube8Bundle = .standard
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
        bundle: RoundTube8Bundle = .standard,
        floor: Float,
        radius: Float,
        base: Float,
        repeatLength: Float
    ) -> (position: SIMD3<Float>, normal: SIMD3<Float>,
          tangent: SIMD3<Float>, bitangent: SIMD3<Float>) {
        let columns = Float(RoundTube8SurfacePatternGenerator.requiredThreadCount)
        // One cycle along the braid, as a share of the repeat: the pattern's
        // (`RoundTube8SurfacePattern.cycleInRepeats`). A cell is one cycle long
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
            // The height the card reads too (`RoundTube8Bundle.standingFraction`
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

    private static func isConsistent(_ mesh: RoundTube8SurfaceMeshData) -> Bool {
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
