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

    static func occlusionImage() -> CGImage? {
        grayscaleImage { along, across in
            let offset = MaruGenjiSurfaceMeshGenerator.crossSectionOffset(forSample: across)
            let crestDistance = 1 - abs(offset)
            let valley = mix(
                valleyOcclusion,
                1,
                smoothstep(0, valleyOcclusionWidth, crestDistance)
            )
            let crossing = mix(
                crossingOcclusion,
                1,
                smoothstep(0, crossingOcclusionLength, min(along, 1 - along))
            )
            let twist = 1 - twistTint * (1 - cos(phase(along: along, across: offset))) / 2
            return linearToSRGB(valley * crossing * twist)
        }
    }

    static func roughnessImage() -> CGImage? {
        grayscaleImage { along, across in
            let offset = MaruGenjiSurfaceMeshGenerator.crossSectionOffset(forSample: across)
            let value = baseRoughness
                + twistRoughnessAmplitude * cos(phase(along: along, across: offset))
            return min(max(value, 0), 1)
        }
    }

    /// Tangent-space normals for the twist, derived from the same height field the
    /// relief ratio describes. `u` maps to the strand direction, `v` across it.
    static func normalImage(
        radius: Float = MaruGenjiSurfaceMeshGenerator.defaultRadius,
        length: Float = MaruGenjiSurfaceMeshGenerator.defaultLength,
        repeatCount: Int = MaruGenjiSurfaceMeshGenerator.defaultPatternRepeatCount
    ) -> CGImage? {
        let coefficients = twist
        let amplitude = radius * MaruGenjiSurfaceMeshGenerator.twistReliefRatio
        let alongWorld = strandLength(radius: radius, length: length, repeatCount: repeatCount)
        let acrossWorld = strandWidth(radius: radius, length: length, repeatCount: repeatCount)
        guard alongWorld > 0, acrossWorld > 0 else { return nil }

        return colorImage { along, across in
            let offset = MaruGenjiSurfaceMeshGenerator.crossSectionOffset(forSample: across)
            let value = cos(coefficients.phase(along: along, across: offset))
            // d(offset)/d(across sample) for the warped cross-section sampling.
            let warp = .pi * cos(.pi / 2 * (2 * across - 1))
            let slopeAlong = amplitude * value * coefficients.phasePerAlong / alongWorld
            let slopeAcross = amplitude * value * coefficients.phasePerAcross * warp / acrossWorld
            let normal = simd_normalize(SIMD3<Float>(-slopeAlong, -slopeAcross, 1))
            return SIMD3<Float>(
                normal.x / 2 + 0.5,
                normal.y / 2 + 0.5,
                normal.z / 2 + 0.5
            )
        }
    }

    // MARK: - Shared strand metrics

    static let twist = MaruGenjiSurfaceMeshGenerator.twistCoefficients(
        for: referenceSurface,
        radius: MaruGenjiSurfaceMeshGenerator.defaultRadius,
        length: MaruGenjiSurfaceMeshGenerator.defaultLength,
        repeatCount: MaruGenjiSurfaceMeshGenerator.defaultPatternRepeatCount
    )

    static func phase(along: Float, across: Float) -> Float {
        twist.phase(along: along, across: across)
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

    /// Mean world length of one strand segment along its centreline.
    private static func strandLength(radius: Float, length: Float, repeatCount: Int) -> Float {
        mean(
            referenceSurface.segments.map { segment in
                simd_length(
                    MaruGenjiSurfaceMeshGenerator.worldOffset(
                        segment.centerlineDelta,
                        radius: radius,
                        length: length,
                        repeatCount: repeatCount
                    )
                )
            }
        )
    }

    /// Mean world width of one strand segment, measured across its centreline.
    private static func strandWidth(radius: Float, length: Float, repeatCount: Int) -> Float {
        mean(
            referenceSurface.segments.map { segment in
                let along = MaruGenjiSurfaceMeshGenerator.worldOffset(
                    segment.centerlineDelta,
                    radius: radius,
                    length: length,
                    repeatCount: repeatCount
                )
                let across = MaruGenjiSurfaceMeshGenerator.worldOffset(
                    segment.meanHalfWidth,
                    radius: radius,
                    length: length,
                    repeatCount: repeatCount
                )
                let alongLength = simd_length(along)
                guard alongLength > 0 else { return 2 * simd_length(across) }
                let alongUnit = along / alongLength
                return 2 * simd_length(across - alongUnit * simd_dot(across, alongUnit))
            }
        )
    }

    private static func mean(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Float(values.count)
    }

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
