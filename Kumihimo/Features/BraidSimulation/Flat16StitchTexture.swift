import CoreGraphics
import Foundation
import RealityKit
import simd
import os

/// The shading of one run, baked once and shared by every thread and colour.
///
/// The mesh carries each run's own coordinates — 0 to 1 across the bundle and 0
/// to 1 along its whole run, the buried tips included — so one map covers a run
/// wherever it is drawn.
///
/// **The shading follows the run's own shape, not the edges of a rectangle**
/// (Task 050). It used to darken all four sides of a stitch and both of its ends
/// by their distance from the edge, which was the right thing when a cell was a
/// ridge filling exactly its own cell: the edge of the rectangle *was* the
/// valley. A bundle's rim is not: it lies past the groove, under the run beside
/// it, where nothing can be seen — so that shading darkened what is hidden and
/// left the groove bare, and the face lost the very partings the new shape gives
/// it.
///
/// What it reads instead is `Flat16BundleShape.standing`, the height of the run
/// at that place: **a place that sits low is a place in a groove**, and it is
/// dark for that reason and no other. The two figures are the round braid's and
/// are used for what they mean — `valleyOcclusion` for the trough between two
/// yarns, and `crossingOcclusion` for the contact shadow where a run goes under
/// the next, which on this braid is its trailing end.
///
/// The valley is darker than the drawn relief alone would cast, on both braids.
/// The drawn crest is a fraction of a yarn's own roundness, so the geometry
/// cannot shade itself the way real yarn does; the map carries what the yarn
/// would occlude, exactly as the round braid's does.
enum Flat16StitchTexture {
    /// A stitch is about twice as long as it is wide, so the map is too.
    static let width = 128
    static let height = 256

    private static let logger = Logger(
        subsystem: "com.example.Kumihimo",
        category: "Flat16StitchTexture"
    )

    /// The three maps one twist group needs, as the round braid has.
    struct Maps: Sendable {
        let occlusion: TextureResource?
        let roughness: TextureResource?
        let normal: TextureResource?
    }

    /// Uploading a texture is RealityKit's business and belongs to the main
    /// actor, so everything from the drawn bytes onwards is isolated to it. The
    /// round braid's `RoundTube16StrandTextures` is a `@MainActor` class for
    /// the same reason. What stays free of the actor is the arithmetic — the
    /// shading, the tint and the roughness are pure functions of a place in a
    /// stitch, and the tests read them without a renderer.
    @MainActor static let maps: Maps = {
        let twist = Flat16StitchTwistGrouping.groups().first
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

    /// Shading at one place on a run: 0 to 1 across the bundle, 0 to 1 along its
    /// whole run. Exposed so a test can read it without a renderer.
    static func shading(across: Float, along: Float) -> Float {
        let shape = Flat16SurfaceMesh.bundleShape
        let span = shape.runEnd - shape.runStart
        let runAlong = shape.runStart + span * along
        let runAcross = 2 * across - 1

        // How high the run stands here, as a fraction of its own crest. Zero in
        // the groove it shares with the run beside it, and below zero where its
        // tip is buried.
        // **Read straight off the height, not stepped at a width.** The round
        // braid's `valleyOcclusionWidth` says how far in from a rim the shading
        // reaches, which is a figure for a rim that is the valley; a bundle's is
        // not. Taking the height itself shades the whole dome, and a dome shaded
        // only at its very edge is what read as a flat tile.
        let standing = shape.standing(atAlong: runAlong, across: runAcross)
        let valley = mix(
            RoundTube16StrandTextureFactory.valleyOcclusion,
            1,
            min(max(standing, 0), 1)
        )
        // And the contact shadow where the run goes under the next one, which is
        // the end past its cell's trailing edge.
        let past = max(0, runAlong - 1) / max(0.000_1, shape.runEnd - 1)
        let underTheNext = mix(
            RoundTube16StrandTextureFactory.crossingOcclusion,
            1,
            smoothstep(0, 1, 1 - past)
        )
        return valley * underTheNext
    }

    /// How much the twist darkens the yarn where a stripe turns away. Small: the
    /// stripe is carried by the normal and roughness maps, as on the round braid.
    static func twistTint(
        _ twist: Flat16StitchTwist?,
        _ across: Float,
        _ along: Float
    ) -> Float {
        guard let twist else { return 1 }
        let tint = RoundTube16StrandTextureFactory.twistTint
        return 1 - tint * (1 - cos(twist.phase(along: along, across: across))) / 2
    }

    static func roughness(
        _ twist: Flat16StitchTwist?,
        _ across: Float,
        _ along: Float
    ) -> Float {
        let base = RoundTube16StrandTextureFactory.baseRoughness
        guard let twist else { return base }
        let value = base + RoundTube16StrandTextureFactory.twistRoughnessAmplitude
            * cos(twist.phase(along: along, across: across))
        return min(max(value, 0), 1)
    }

    /// Tangent-space normals for the twist, from the same height field the round
    /// braid's relief ratio describes. `u` runs across the stitch and `v` along
    /// it, matching the mesh's own texture coordinates.
    @MainActor private static func makeNormal(
        _ twist: Flat16StitchTwist
    ) -> TextureResource? {
        let amplitude = RoundTube16SurfaceMesh.twistReliefRatio
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
