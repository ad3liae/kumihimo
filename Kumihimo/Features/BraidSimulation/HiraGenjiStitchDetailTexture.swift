import CoreGraphics
import Foundation
import RealityKit
import simd
import os

/// The shading of one stitch, baked once and shared by every thread and colour.
///
/// The mesh carries each stitch's own coordinates — 0 to 1 across the lane and 0
/// to 1 along the braid — so one map covers a stitch wherever it is drawn.
///
/// It replaces the two-material painting the flat braid used to have, where the
/// band within `boundaryWidth` of a patch edge was drawn in a second, darker
/// colour. That gave the surface one hard step and nothing else; this gives it
/// the shading a valley between two yarns actually has.
///
/// **The figures are the round braid's, used for what they mean.** A stitch has a
/// valley on all four sides: two where it lies against the lanes either side of
/// it, and two where it meets the stitch before and after it along the braid.
/// All four are the trough between two yarns, so all four take `valleyOcclusion`
/// and `valleyOcclusionWidth`.
///
/// The two ends of a run carry a second shadow on top of that one, and it is a
/// different occluder: the pick tucks under the thread along exactly that line.
/// That is what `crossingOcclusion` and `crossingOcclusionLength` describe on the
/// round braid, so they are used here for the same thing.
///
/// The valley is darker than the drawn relief alone would cast, on both braids.
/// The drawn crest is a fraction of a yarn's own roundness, so the geometry
/// cannot shade itself the way real yarn does; the map carries what the yarn
/// would occlude, exactly as the round braid's does.
enum HiraGenjiStitchDetailTexture {
    /// A stitch is about twice as long as it is wide, so the map is too.
    static let width = 128
    static let height = 256

    private static let logger = Logger(
        subsystem: "com.example.Kumihimo",
        category: "HiraGenjiStitchDetailTexture"
    )

    /// The three maps one twist group needs, as the round braid has.
    struct Maps: Sendable {
        let occlusion: TextureResource?
        let roughness: TextureResource?
        let normal: TextureResource?
    }

    /// Uploading a texture is RealityKit's business and belongs to the main
    /// actor, so everything from the drawn bytes onwards is isolated to it. The
    /// round braid's `MaruGenjiStrandDetailTextures` is a `@MainActor` class for
    /// the same reason. What stays free of the actor is the arithmetic — the
    /// shading, the tint and the roughness are pure functions of a place in a
    /// stitch, and the tests read them without a renderer.
    @MainActor static let maps: Maps = {
        let twist = HiraGenjiStitchTwistGrouping.groups().first
        return Maps(
            occlusion: make(semantic: .color) { across, along in
                linearToSRGB(shading(across: across, along: along) * twistTint(twist, across, along))
            },
            roughness: make(semantic: .raw) { across, along in
                roughness(twist, across, along)
            },
            normal: twist.map { twist in
                makeNormal(twist)
            } ?? nil
        )
    }()

    @MainActor static var occlusion: TextureResource? { maps.occlusion }

    /// Shading at one place in a stitch: 0 to 1 across the lane, 0 to 1 along the
    /// braid. Exposed so a test can read it without a renderer.
    static func shading(across: Float, along: Float) -> Float {
        let valleyDepth = MaruGenjiStrandTextureFactory.valleyOcclusion
        let reach = MaruGenjiStrandTextureFactory.valleyOcclusionWidth
        // Distance from the nearest edge, in half-widths, on each axis.
        let fromTheSides = 1 - abs(2 * across - 1)
        let fromTheJoins = 1 - abs(2 * along - 1)
        let sides = mix(valleyDepth, 1, smoothstep(0, reach, fromTheSides))
        let joins = mix(valleyDepth, 1, smoothstep(0, reach, fromTheJoins))
        let underThePick = mix(
            MaruGenjiStrandTextureFactory.crossingOcclusion,
            1,
            smoothstep(
                0,
                MaruGenjiStrandTextureFactory.crossingOcclusionLength,
                min(along, 1 - along)
            )
        )
        return sides * joins * underThePick
    }

    /// How much the twist darkens the yarn where a stripe turns away. Small: the
    /// stripe is carried by the normal and roughness maps, as on the round braid.
    static func twistTint(
        _ twist: HiraGenjiStitchTwist?,
        _ across: Float,
        _ along: Float
    ) -> Float {
        guard let twist else { return 1 }
        let tint = MaruGenjiStrandTextureFactory.twistTint
        return 1 - tint * (1 - cos(twist.phase(along: along, across: across))) / 2
    }

    static func roughness(
        _ twist: HiraGenjiStitchTwist?,
        _ across: Float,
        _ along: Float
    ) -> Float {
        let base = MaruGenjiStrandTextureFactory.baseRoughness
        guard let twist else { return base }
        let value = base + MaruGenjiStrandTextureFactory.twistRoughnessAmplitude
            * cos(twist.phase(along: along, across: across))
        return min(max(value, 0), 1)
    }

    /// Tangent-space normals for the twist, from the same height field the round
    /// braid's relief ratio describes. `u` runs across the stitch and `v` along
    /// it, matching the mesh's own texture coordinates.
    @MainActor private static func makeNormal(
        _ twist: HiraGenjiStitchTwist
    ) -> TextureResource? {
        let amplitude = MaruGenjiSurfaceMeshGenerator.twistReliefRatio
        let gradient = twist.normalizedPhaseGradient
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for row in 0..<height {
            for column in 0..<width {
                let across = (Float(column) + 0.5) / Float(width)
                let along = (Float(row) + 0.5) / Float(height)
                let phase = twist.phase(along: along, across: across)
                // height = amplitude * cos(phase); slope = -amplitude * sin(phase) * dphase
                let slope = -amplitude * sin(phase)
                let alongSlope = slope * gradient.x
                let acrossSlope = slope * gradient.y
                var normal = SIMD3<Float>(-acrossSlope, -alongSlope, 1)
                normal = simd_normalize(normal)
                let offset = (row * width + column) * 4
                bytes[offset] = byte(normal.x * 0.5 + 0.5)
                bytes[offset + 1] = byte(normal.y * 0.5 + 0.5)
                bytes[offset + 2] = byte(normal.z * 0.5 + 0.5)
                bytes[offset + 3] = 255
            }
        }
        return upload(bytes, semantic: .normal, name: "twist normal")
    }

    @MainActor private static func make(
        semantic: TextureResource.Semantic,
        _ value: (Float, Float) -> Float
    ) -> TextureResource? {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for row in 0..<height {
            for column in 0..<width {
                let across = (Float(column) + 0.5) / Float(width)
                let along = (Float(row) + 0.5) / Float(height)
                let byteValue = byte(value(across, along))
                let offset = (row * width + column) * 4
                bytes[offset] = byteValue
                bytes[offset + 1] = byteValue
                bytes[offset + 2] = byteValue
                bytes[offset + 3] = 255
            }
        }
        return upload(bytes, semantic: semantic, name: "stitch detail")
    }

    @MainActor private static func upload(
        _ bytes: [UInt8],
        semantic: TextureResource.Semantic,
        name: String
    ) -> TextureResource? {
        guard
            let provider = CGDataProvider(data: Data(bytes) as CFData),
            let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )
        else {
            logger.error("Stitch \(name, privacy: .public) map could not be drawn")
            return nil
        }
        do {
            return try TextureResource.generate(from: image, options: .init(semantic: semantic))
        } catch {
            logger.error(
                "Stitch \(name, privacy: .public) map could not be uploaded: \(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    private static func mix(_ from: Float, _ to: Float, _ progress: Float) -> Float {
        from + (to - from) * progress
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

    private static func byte(_ value: Float) -> UInt8 {
        UInt8(min(max(value, 0), 1) * 255)
    }
}
