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
                    + "braid is the one drawn"
            ),
            "half a thread over the braid's radius": BraidMeasurement(
                Double(crestHeightRatio),
                basis: .fractionOf("the braid's outer radius"),
                source: .derived("eight threads round the tube, so one thread is an "
                                 + "eighth of the circumference and a round one stands "
                                 + "half its own width proud")
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
    /// that would leave the grooves invisible.
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
            return SIMD3(
                base + repeatLength * surface.y,
                height * cos(angle),
                height * sin(angle)
            )
        }
        let step: Float = 1e-3
        let position = at(along, across)
        var tangent = at(min(along + step, 1), across) - at(max(along - step, 0), across)
        var bitangent = at(along, min(across + step, 1)) - at(along, max(across - step, -1))
        tangent = normalised(tangent)
        bitangent = normalised(bitangent)
        var normal = normalised(cross(tangent, bitangent))
        // Outward, away from the axis.
        if dot(normal, SIMD3(0, position.y, position.z)) < 0 { normal = -normal }
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
