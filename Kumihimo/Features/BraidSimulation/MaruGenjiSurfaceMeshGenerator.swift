import Foundation
import simd

struct MaruGenjiSurfaceMeshData: Sendable {
    let positions: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let tangents: [SIMD3<Float>]
    let bitangents: [SIMD3<Float>]
    /// Strand-local coordinates: `x` runs 0...1 along the strand, `y` runs 0...1
    /// across it. Shared by every strand, so one twist texture serves all of them.
    let textureCoordinates: [SIMD2<Float>]
    /// Strand coordinates: `x` runs along the strand and reaches past 0...1 where a
    /// strand laps over a crossing; `y` runs across it, -1...1, 0 on the crest.
    let strandCoordinates: [SIMD2<Float>]
    /// Twist phase in radians. Continuous inside one strand segment.
    let twistPhases: [Float]
    let colorGroups: [ThreadColorID: [UInt32]]
    let vertexSegmentIndices: [Int]
    let vertexIsCrossingWall: [Bool]
    let triangleSegmentIndices: [Int]
    let triangleIsCrossingWall: [Bool]
    /// Every vertex sitting on the circumferential seam, at `u == 0` and `u == 1`.
    let seamStartVertexIndices: [Int]
    let seamEndVertexIndices: [Int]
    let baseRadius: Float
    let valleyFloorRadius: Float

    var triangleCount: Int {
        colorGroups.values.reduce(0) { $0 + $1.count / 3 }
    }

    var allTriangleIndices: [UInt32] {
        colorGroups.values.flatMap { $0 }
    }
}

/// Turns the fixed surface pattern into a braid whose surface is built from round
/// strands: a semi-elliptical ridge along each strand centreline, a shared valley
/// floor between neighbouring strands, and a crossing depth that sinks the strand
/// passing underneath.
enum MaruGenjiSurfaceMeshGenerator {
    static let defaultRadius: Float = 0.48
    static let defaultLength: Float = 3.4
    static let defaultPatternRepeatCount = 4

    /// Samples down one strand. Resolves the crossing dip and the wavy silhouette.
    static let defaultAlongStrandSubdivisions = 12
    /// Samples across one strand. Resolves the round cross-section.
    static let defaultAcrossStrandSubdivisions = 12
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
    /// How far past its own ends the strand passing over a crossing laps, as a
    /// fraction of its length. The lap sinks back to the valley floor and finishes
    /// buried inside the strand underneath, which is what makes a crest look like
    /// it runs on while the crest beneath it breaks off.
    static let overCrossingLap: Float = 0.16
    static let overCrossingLapSubdivisions = 3
    /// How far the lap sinks below the valley floor once it has tapered away, so
    /// its rim never lands exactly on the surface it is buried in.
    static let overCrossingLapSink: Float = 0.004

    /// Twist stripes crossing one strand segment lengthwise.
    static let fiberCount = 8
    /// Angle between the twist stripes and the strand direction.
    static let twistAngleDegrees: Float = 30
    /// Twist relief as a fraction of the nominal radius. Rendered as a normal and
    /// roughness variation rather than as displaced geometry, so the stripes stay
    /// free of the moire a mesh at this subdivision level would produce.
    static let twistReliefRatio: Float = 0.005

    static func generate(
        pattern: MaruGenjiSurfacePattern,
        radius: Float = defaultRadius,
        length: Float = defaultLength,
        patternRepeatCount: Int = defaultPatternRepeatCount,
        alongStrandSubdivisions: Int = defaultAlongStrandSubdivisions,
        acrossStrandSubdivisions: Int = defaultAcrossStrandSubdivisions
    ) -> MaruGenjiSurfaceMeshData? {
        guard
            pattern.patches.count == MaruGenjiSurfacePatternGenerator.patchCount,
            radius.isFinite,
            radius > 0,
            length.isFinite,
            length > 0,
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
            length: length,
            repeatCount: patternRepeatCount,
            twist: twistCoefficients(for: surface, radius: radius, length: length, repeatCount: patternRepeatCount)
        )
        let alongSamples = subdivisionSamples(count: alongStrandSubdivisions)
        let lappedAlongSamples = lapping(alongSamples)
        let acrossSamples = subdivisionSamples(count: acrossStrandSubdivisions)

        var builder = MeshBuilder()
        // The repeats on both sides are included because the final chevron row
        // crosses v == 1 and a lap reaches past its own strand, so both tile ends
        // need the slivers that belong to the neighbouring repeat. Anything outside
        // the requested length is clipped away below.
        for repeatIndex in -1...patternRepeatCount {
            for (segmentIndex, segment) in surface.segments.enumerated() {
                appendStrand(
                    segment,
                    segmentIndex: segmentIndex,
                    repeatIndex: repeatIndex,
                    metrics: metrics,
                    alongSamples: segment.layer == .over ? lappedAlongSamples : alongSamples,
                    acrossSamples: acrossSamples,
                    builder: &builder
                )
            }
        }

        let mesh = MaruGenjiSurfaceMeshData(
            positions: builder.positions,
            normals: builder.normals,
            tangents: builder.tangents,
            bitangents: builder.bitangents,
            textureCoordinates: builder.textureCoordinates,
            strandCoordinates: builder.strandCoordinates,
            twistPhases: builder.twistPhases,
            colorGroups: builder.colorGroups,
            vertexSegmentIndices: builder.vertexSegmentIndices,
            vertexIsCrossingWall: builder.vertexIsCrossingWall,
            triangleSegmentIndices: builder.triangleSegmentIndices,
            triangleIsCrossingWall: builder.triangleIsCrossingWall,
            seamStartVertexIndices: builder.seamStartVertexIndices,
            seamEndVertexIndices: builder.seamEndVertexIndices,
            baseRadius: radius,
            valleyFloorRadius: radius * (1 - valleyDepthRatio)
        )
        return isConsistent(mesh) ? mesh : nil
    }

    // MARK: - Strand surface

    /// Radius of the strand surface, before the twist relief is applied by the
    /// normal map. `across` is 0 on the crest and ±1 in the valley shared with the
    /// neighbouring strand, which is why neighbouring strands never leave a gap
    /// however differently their crests are scaled.
    static func strandRadius(
        layer: BraidCrossingLayer,
        along: Float,
        across: Float,
        radius: Float
    ) -> Float {
        let taper = lapTaper(along: along)
        let crest = crestHeightRatio
            * crossingCrestFactor(layer: layer, along: along)
            * crestProfile(across: across)
            * taper
        let sink = overCrossingLapSink * (1 - taper)
        return radius * (1 - valleyDepthRatio + crest - sink)
    }

    /// 1 over the strand's own span, falling to 0 at the tip of a lap.
    static func lapTaper(along: Float) -> Float {
        if along >= 0, along <= 1 { return 1 }
        let distance = along < 0 ? -along : along - 1
        return 1 - smoothstep(0, overCrossingLap, distance)
    }

    private static func smoothstep(_ edge0: Float, _ edge1: Float, _ value: Float) -> Float {
        guard edge1 > edge0 else { return value < edge0 ? 0 : 1 }
        let progress = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return progress * progress * (3 - 2 * progress)
    }

    /// Semi-elliptical cross-section: 1 on the crest, 0 at both edges.
    static func crestProfile(across: Float) -> Float {
        let clamped = min(max(across, -1), 1)
        return sqrt(max(0, 1 - clamped * clamped))
    }

    /// Peaks at both ends of a strand, where it meets the strands running the
    /// other way, and vanishes at mid-span.
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

    /// How the twist stripes run in strand-local coordinates. The stripes are
    /// defined once for every strand so a single texture can carry them; the two
    /// chevron directions are mirror images whose local shear differs slightly, so
    /// the across coefficient is the mean over all strands.
    struct TwistCoefficients: Equatable, Sendable {
        let phasePerAlong: Float
        let phasePerAcross: Float

        func phase(along: Float, across: Float) -> Float {
            phasePerAlong * along + phasePerAcross * across
        }
    }

    static func twistCoefficients(
        for surface: BraidStrandSurface,
        radius: Float,
        length: Float,
        repeatCount: Int
    ) -> TwistCoefficients {
        let angle = twistAngleDegrees * .pi / 180
        let phasePerAlong = -2 * .pi * Float(fiberCount)
        let acrossCoefficients = surface.segments.compactMap { segment -> Float? in
            let along = worldOffset(
                segment.centerlineDelta,
                radius: radius,
                length: length,
                repeatCount: repeatCount
            )
            let across = worldOffset(
                segment.meanHalfWidth,
                radius: radius,
                length: length,
                repeatCount: repeatCount
            )
            let alongLength = simd_length(along)
            guard alongLength > 0 else { return nil }
            let alongUnit = along / alongLength
            let perpendicular = across - alongUnit * simd_dot(across, alongUnit)
            let perpendicularLength = simd_length(perpendicular)
            guard perpendicularLength > 0 else { return nil }
            // Stripe normal in the strand's own orthonormal frame.
            let gradient = -sin(angle) * alongUnit
                + cos(angle) * (perpendicular / perpendicularLength)
            let period = alongLength * sin(angle) / Float(fiberCount)
            guard period > 0 else { return nil }
            return simd_dot(across, gradient) * 2 * .pi / period
        }
        guard !acrossCoefficients.isEmpty else {
            return TwistCoefficients(phasePerAlong: phasePerAlong, phasePerAcross: 0)
        }
        let mean = acrossCoefficients.reduce(0, +) / Float(acrossCoefficients.count)
        return TwistCoefficients(phasePerAlong: phasePerAlong, phasePerAcross: mean)
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
        let twist: TwistCoefficients
    }

    /// A point being assembled. `strandCoordinate` is `(along, across)`, which the
    /// surface position depends on affinely, so clipping can interpolate it
    /// exactly. `radialLevel` is 0 on the strand surface and 1 on the valley floor,
    /// so the same clipping code serves the surface and the short walls that seal a
    /// crossing step.
    private struct StrandVertex {
        let surfaceCoordinate: SIMD2<Float>
        let strandCoordinate: SIMD2<Float>
        let radialLevel: Float

        /// Strand-local texture coordinates, both 0...1.
        var textureCoordinate: SIMD2<Float> {
            SIMD2<Float>(
                min(max(strandCoordinate.x, 0), 1),
                MaruGenjiSurfaceMeshGenerator.crossSectionSample(forOffset: strandCoordinate.y)
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
        var colorGroups = [ThreadColorID: [UInt32]]()
        var vertexSegmentIndices = [Int]()
        var vertexIsCrossingWall = [Bool]()
        var triangleSegmentIndices = [Int]()
        var triangleIsCrossingWall = [Bool]()
        var seamStartVertexIndices = [Int]()
        var seamEndVertexIndices = [Int]()
    }

    private static func appendStrand(
        _ segment: BraidStrandSegment,
        segmentIndex: Int,
        repeatIndex: Int,
        metrics: SurfaceMetrics,
        alongSamples: [Float],
        acrossSamples: [Float],
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
                    vertex(segment: segment, repeatIndex: repeatIndex, sample: $0, radialLevel: 0)
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
                        isCrossingWall: false,
                        metrics: metrics,
                        builder: &builder
                    )
                }
            }
        }

        guard segment.layer == .over else { return }
        // Only the strand passing over a crossing seals the radius step there, so
        // the two sides never place coplanar walls on top of each other.
        for along in [Float(0), Float(1)] {
            for acrossIndex in 0..<(acrossSamples.count - 1) {
                let c0 = acrossSamples[acrossIndex]
                let c1 = acrossSamples[acrossIndex + 1]
                let quad = [
                    (SIMD2<Float>(along, c0), Float(0)),
                    (SIMD2<Float>(along, c1), Float(0)),
                    (SIMD2<Float>(along, c1), Float(1)),
                    (SIMD2<Float>(along, c0), Float(1)),
                ]
                // Wound so the visible face points away from the strand interior.
                let corners = (along < 0.5 ? quad : quad.reversed()).map {
                    vertex(segment: segment, repeatIndex: repeatIndex, sample: $0.0, radialLevel: $0.1)
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
                        isCrossingWall: true,
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
        isCrossingWall: Bool,
        metrics: SurfaceMetrics,
        builder: inout MeshBuilder
    ) {
        let clipped = clip(polygon: polygon, minimumV: 0, maximumV: Float(metrics.repeatCount))
        guard clipped.count >= 3 else { return }

        for index in 1..<(clipped.count - 1) {
            let triangle = [clipped[0], clipped[index], clipped[index + 1]]
            let mapped = triangle.map { position(of: $0, segment: segment, metrics: metrics) }
            guard simd_length_squared(simd_cross(mapped[1] - mapped[0], mapped[2] - mapped[0]))
                > 0.000_000_000_001 else { continue }

            let firstIndex = UInt32(builder.positions.count)
            for (vertex, mappedPosition) in zip(triangle, mapped) {
                let vertexIndex = builder.positions.count
                let frame = isCrossingWall
                    ? wallFrame(for: vertex)
                    : surfaceFrame(for: vertex, segment: segment, metrics: metrics)
                builder.positions.append(mappedPosition)
                builder.normals.append(frame.normal)
                builder.tangents.append(frame.tangent)
                builder.bitangents.append(frame.bitangent)
                builder.textureCoordinates.append(vertex.textureCoordinate)
                builder.strandCoordinates.append(vertex.strandCoordinate)
                builder.twistPhases.append(
                    metrics.twist.phase(
                        along: vertex.strandCoordinate.x,
                        across: vertex.strandCoordinate.y
                    )
                )
                builder.vertexSegmentIndices.append(segmentIndex)
                builder.vertexIsCrossingWall.append(isCrossingWall)
                if approximatelyEqual(vertex.surfaceCoordinate.x, 0) {
                    builder.seamStartVertexIndices.append(vertexIndex)
                } else if approximatelyEqual(vertex.surfaceCoordinate.x, 1) {
                    builder.seamEndVertexIndices.append(vertexIndex)
                }
            }

            builder.colorGroups[segment.colorID, default: []]
                .append(contentsOf: [firstIndex, firstIndex + 1, firstIndex + 2])
            builder.triangleSegmentIndices.append(segmentIndex)
            builder.triangleIsCrossingWall.append(isCrossingWall)
        }
    }

    private static func vertex(
        segment: BraidStrandSegment,
        repeatIndex: Int,
        sample: SIMD2<Float>,
        radialLevel: Float
    ) -> StrandVertex {
        let strandCoordinate = SIMD2<Float>(
            sample.x,
            crossSectionOffset(forSample: sample.y)
        )
        let surfaceCoordinate = segment.surfacePoint(
            along: strandCoordinate.x,
            across: strandCoordinate.y
        )
        return StrandVertex(
            surfaceCoordinate: SIMD2<Float>(
                surfaceCoordinate.x,
                surfaceCoordinate.y + Float(repeatIndex)
            ),
            strandCoordinate: strandCoordinate,
            radialLevel: radialLevel
        )
    }

    private static func position(
        of vertex: StrandVertex,
        segment: BraidStrandSegment,
        metrics: SurfaceMetrics
    ) -> SIMD3<Float> {
        let surfaceRadius = strandRadius(
            layer: segment.layer,
            along: vertex.strandCoordinate.x,
            across: vertex.strandCoordinate.y,
            radius: metrics.radius
        )
        let floorRadius = metrics.radius * (1 - valleyDepthRatio)
        let displacedRadius = surfaceRadius
            + (floorRadius - surfaceRadius) * vertex.radialLevel
        let normalizedV = vertex.surfaceCoordinate.y / Float(metrics.repeatCount)
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

    private static func surfaceFrame(
        for vertex: StrandVertex,
        segment: BraidStrandSegment,
        metrics: SurfaceMetrics
    ) -> VertexFrame {
        let radial = radialDirection(around: vertex.surfaceCoordinate.x)
        let epsilon: Float = 0.002
        let local = vertex.textureCoordinate

        func sampled(_ point: SIMD2<Float>) -> SIMD3<Float> {
            position(
                of: self.vertex(
                    segment: segment,
                    repeatIndex: 0,
                    sample: point,
                    radialLevel: 0
                ),
                segment: segment,
                metrics: metrics
            )
        }

        let alongLow = SIMD2<Float>(max(0, local.x - epsilon), local.y)
        let alongHigh = SIMD2<Float>(min(1, local.x + epsilon), local.y)
        let acrossLow = SIMD2<Float>(local.x, max(0, local.y - epsilon))
        let acrossHigh = SIMD2<Float>(local.x, min(1, local.y + epsilon))
        let alongTangent = sampled(alongHigh) - sampled(alongLow)
        let acrossTangent = sampled(acrossHigh) - sampled(acrossLow)

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

    /// A strand ends on a line of constant angle, so the wall that seals the
    /// radius step at a crossing faces along the circumference, away from the
    /// strand it belongs to.
    private static func wallFrame(for vertex: StrandVertex) -> VertexFrame {
        let radial = radialDirection(around: vertex.surfaceCoordinate.x)
        let circumferential = circumferentialDirection(around: vertex.surfaceCoordinate.x)
        let normal = vertex.strandCoordinate.x < 0.5 ? -circumferential : circumferential
        return orthonormalFrame(normal: normal, alongTangent: -radial)
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

    private static func subdivisionSamples(count: Int) -> [Float] {
        (0...count).map { Float($0) / Float(count) }
    }

    /// Extends an even sampling past both ends of the strand so the strand passing
    /// over a crossing can lap onto the one underneath.
    private static func lapping(_ samples: [Float]) -> [Float] {
        let steps = (1...overCrossingLapSubdivisions).map {
            overCrossingLap * Float($0) / Float(overCrossingLapSubdivisions)
        }
        return steps.reversed().map { -$0 } + samples + steps.map { 1 + $0 }
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
        _ first: StrandVertex,
        _ second: StrandVertex,
        atV boundaryV: Float
    ) -> StrandVertex {
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

    private static func isValid(_ patch: MaruGenjiSurfacePatch) -> Bool {
        patch.corners.count == 4 && patch.corners.allSatisfy { corner in
            corner.x.isFinite && corner.y.isFinite
                && (0...1).contains(corner.x)
                && (0...MaruGenjiSurfacePatternGenerator.maximumUnwrappedV).contains(corner.y)
        }
    }

    private static func isConsistent(_ mesh: MaruGenjiSurfaceMeshData) -> Bool {
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
            && mesh.vertexIsCrossingWall.count == vertexCount
            && mesh.triangleSegmentIndices.count == mesh.triangleIsCrossingWall.count
            && mesh.triangleSegmentIndices.count == mesh.triangleCount
            && !mesh.colorGroups.isEmpty
            && mesh.colorGroups.values.allSatisfy { !$0.isEmpty && $0.count.isMultiple(of: 3) }
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
                > 0.000_000_000_001
        }
    }

    private static func isFinite(_ vector: SIMD3<Float>) -> Bool {
        vector.x.isFinite && vector.y.isFinite && vector.z.isFinite
    }

    private static func isUnit(_ vector: SIMD3<Float>) -> Bool {
        isFinite(vector) && abs(simd_length(vector) - 1) < 0.001
    }

    private static func isFiniteStrandCoordinate(_ vector: SIMD2<Float>) -> Bool {
        vector.x.isFinite && vector.y.isFinite
            && (-overCrossingLap - 0.001...1 + overCrossingLap + 0.001).contains(vector.x)
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
