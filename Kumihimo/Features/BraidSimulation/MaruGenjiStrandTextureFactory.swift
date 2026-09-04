import CoreGraphics
import Foundation
import simd

/// Deterministic strand detail maps, generated once and shared by every colour.
///
/// All three maps are addressed by the strand-local coordinates the mesh writes
/// out: `u` runs along the strand, `v` across it. The valley shading lives in the
/// occlusion map so the darkening between strands is a continuous falloff rather
/// than a separately coloured band, and the twist lives in the normal and
/// roughness maps so it stays finer than the mesh could resolve without moire.
///
/// One set of maps is generated per twist group rather than one for all strands.
/// Strand-local coordinates are sheared differently in the two chevron
/// directions, so a single set of stripes baked into them would meet the braid at
/// two different angles; a set per group is what keeps every strand at the one
/// twist angle. The maps depend on the strand shape alone, so the groups come
/// from a fixed reference surface and are shared by every colouring.
enum MaruGenjiStrandTextureFactory {
    /// Wider than tall because a strand segment is roughly four times as long as
    /// it is wide, which keeps the generated detail close to square on screen.
    static let width = 512
    static let height = 128

    /// How dark the valley between two strands becomes, as a linear multiplier.
    static let valleyOcclusion: Float = 0.34
    /// Fraction of the half-width the valley shading reaches across.
    static let valleyOcclusionWidth: Float = 0.55
    /// How dark the contact shadow at a crossing becomes.
    static let crossingOcclusion: Float = 0.62
    /// Fraction of the strand length the crossing shadow reaches along.
    static let crossingOcclusionLength: Float = 0.20
    /// Colour contribution of the twist. Kept small; the twist is carried by the
    /// normal and roughness maps.
    static let twistTint: Float = 0.05

    static let baseRoughness: Float = 0.86
    static let twistRoughnessAmplitude: Float = 0.12

    static func occlusionImage(twist: Twist) -> CGImage? {
        grayscaleImage { along, across in
            let offset = crossSectionOffset(forRow: across)
            let valley = mix(
                valleyOcclusion,
                1,
                smoothstep(0, valleyOcclusionWidth, 1 - abs(offset))
            )
            let crossing = mix(
                crossingOcclusion,
                1,
                smoothstep(0, crossingOcclusionLength, min(along, 1 - along))
            )
            let twistShade = 1 - twistTint
                * (1 - cos(twist.coefficients.phase(along: along, across: offset))) / 2
            return linearToSRGB(valley * crossing * twistShade)
        }
    }

    static func roughnessImage(twist: Twist) -> CGImage? {
        grayscaleImage { along, across in
            let offset = crossSectionOffset(forRow: across)
            let value = baseRoughness
                + twistRoughnessAmplitude
                * cos(twist.coefficients.phase(along: along, across: offset))
            return min(max(value, 0), 1)
        }
    }

    /// Tangent-space normals for the twist, derived from the same height field the
    /// relief ratio describes. `u` maps to the strand direction, `v` across it.
    ///
    /// The slopes are taken in world directions, along the tangent and the
    /// bitangent, rather than in strand coordinates: the two are not at right
    /// angles to each other, and differentiating in the sheared pair would tilt
    /// the relief away from the stripes it is lighting.
    static func normalImage(twist: Twist) -> CGImage? {
        let gradient = twist.normalizedPhaseGradient
        guard gradient.x.isFinite, gradient.y.isFinite else { return nil }
        // Height and gradient are both scaled by the radius, so the slope the
        // normal map stores is the same at any braid size.
        let amplitude = MaruGenjiSurfaceMeshGenerator.twistReliefRatio

        return colorImage { along, across in
            let offset = crossSectionOffset(forRow: across)
            let value = cos(twist.coefficients.phase(along: along, across: offset))
            let slope = amplitude * value * gradient
            let normal = simd_normalize(SIMD3<Float>(-slope.x, -slope.y, 1))
            return SIMD3<Float>(
                normal.x / 2 + 0.5,
                normal.y / 2 + 0.5,
                normal.z / 2 + 0.5
            )
        }
    }

    /// The cross-section offset a bitmap row stands for.
    ///
    /// The sampler reads the generated rows in the reverse of the mesh's own `v`,
    /// so the top row is the far edge of the cross-section rather than the near
    /// one. Nothing showed it until now: the valley falloff is symmetric about the
    /// crest and the crossing shadow only depends on the length, so the mirroring
    /// was invisible in every map that came before the twist had to meet the
    /// strand at a fixed angle. Confirmed by rendering — see the Task 005G
    /// screenshots.
    static func crossSectionOffset(forRow row: Float) -> Float {
        MaruGenjiSurfaceMeshGenerator.crossSectionOffset(forSample: 1 - row)
    }

    // MARK: - Shared strand metrics

    typealias Twist = MaruGenjiSurfaceMeshGenerator.TwistGroup

    /// The twist groups the maps are generated for, in the order the mesh numbers
    /// them. The strand shape is the same for every colouring and the grouping is
    /// independent of the radius, so this one grouping serves every mesh.
    static let twistGrouping = MaruGenjiSurfaceMeshGenerator.twistGrouping(
        for: referenceSurface,
        radius: MaruGenjiSurfaceMeshGenerator.defaultRadius,
        length: MaruGenjiSurfaceMeshGenerator.defaultLength,
        repeatCount: MaruGenjiSurfaceMeshGenerator.defaultPatternRepeatCount
    )

    static var twistGroups: [Twist] {
        twistGrouping.groups
    }

    /// The strand shape is the same for every colouring, so a fixed single-colour
    /// pattern is enough to read the geometry the detail maps have to match.
    private static let referenceSurface: BraidStrandSurface = {
        let assignments = (1...MaruGenjiSurfacePatternGenerator.requiredThreadCount).map {
            ThreadAssignment(position: $0, colorID: ThreadColorCatalog.defaultColor.id)
        }
        guard let pattern = MaruGenjiSurfacePatternGenerator.generate(assignments: assignments) else {
            return BraidStrandSurface(segments: [])
        }
        return BraidStrandSurfaceBuilder.surface(for: pattern)
    }()

    // MARK: - Bitmap helpers

    private static func grayscaleImage(
        _ value: (Float, Float) -> Float
    ) -> CGImage? {
        colorImage { along, across in
            SIMD3<Float>(repeating: value(along, across))
        }
    }

    private static func colorImage(
        _ value: (Float, Float) -> SIMD3<Float>
    ) -> CGImage? {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<height {
            let across = (Float(row) + 0.5) / Float(height)
            for column in 0..<width {
                let along = (Float(column) + 0.5) / Float(width)
                let color = value(along, across)
                let offset = (row * width + column) * 4
                pixels[offset] = byte(color.x)
                pixels[offset + 1] = byte(color.y)
                pixels[offset + 2] = byte(color.z)
                pixels[offset + 3] = 255
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    private static func byte(_ value: Float) -> UInt8 {
        UInt8(min(max(value, 0), 1) * 255 + 0.5)
    }

    private static func mix(_ from: Float, _ to: Float, _ progress: Float) -> Float {
        from + (to - from) * min(max(progress, 0), 1)
    }

    private static func smoothstep(_ edge0: Float, _ edge1: Float, _ value: Float) -> Float {
        guard edge1 > edge0 else { return value < edge0 ? 0 : 1 }
        let progress = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return progress * progress * (3 - 2 * progress)
    }

    private static func linearToSRGB(_ value: Float) -> Float {
        let clamped = min(max(value, 0), 1)
        return clamped <= 0.003_130_8
            ? 12.92 * clamped
            : 1.055 * pow(clamped, 1 / 2.4) - 0.055
    }
}
