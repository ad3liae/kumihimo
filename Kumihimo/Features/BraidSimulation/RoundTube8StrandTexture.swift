import CoreGraphics
import Foundation
import RealityKit
import simd
import os

/// The fibre stripes and the valley shading of the eight-thread tube, drawn once
/// and shared by every cell and every colour.
///
/// **Borrowed, and named so** (Task 032 stage 3). The roughness and normal maps
/// are drawn by `RoundTube16StrandTextureFactory` itself, unchanged; the valley
/// shading uses its figures for the same thing they mean there, the trough
/// between two ridges lying side by side. The shading goes into both the base
/// colour and the ambient-occlusion slot, which is Task 005J's arrangement.
/// **The sixteen-thread side is not touched**: nothing there is changed or given
/// a parameter; this only calls what it already offers.
///
/// **Two things it offers are not borrowed.**
///
/// - **The shadow at a crossing**, for the reason the mesh borrows nothing about
///   crossings: on this braid nothing crosses.
/// - **Any shading at the ends of a cell.** Where a cell ends along the braid is
///   where the next thread arrives, and when that is waits on the arrival phase
///   (Task 032). Shading the ends before then would put a dark ring round the
///   braid at every cycle, which no photograph shows.
///
/// **One set of maps serves every cell.** The sixteen-thread tube needs a set per
/// twist group because its chevrons shear the strand frame two ways; a cell here
/// stands square to the braid and every cell is the same size, so no frame is
/// sheared and one pair of coefficients serves them all — as on the flat braid
/// (`Flat16StitchTwistGrouping`).
///
/// **What is set by eye** is the stripes' slant and how close they lie
/// (`RoundTube8SurfaceMesh.fibreStripeAngleDegrees`,
/// `.fibreStripesAcrossThreadWidth`), and the borrowed figures were held against
/// the same photograph. All of it is `.declared` in `RoundTube8SurfaceMesh.shape`.
enum RoundTube8StrandTexture {
    private static let logger = Logger(
        subsystem: "com.example.Kumihimo",
        category: "RoundTube8StrandTexture"
    )

    /// The three maps every cell uses.
    struct Maps: Sendable {
        let occlusion: TextureResource?
        let roughness: TextureResource?
        let normal: TextureResource?
    }

    /// Uploading is RealityKit's business and belongs to the main actor; the
    /// arithmetic above it stays free of the actor so a test can read it.
    @MainActor static let maps: Maps = {
        guard let twist else {
            logger.error("The eight-thread stripes could not be solved")
            return Maps(occlusion: nil, roughness: nil, normal: nil)
        }
        return Maps(
            occlusion: upload(occlusionImage(twist: twist), semantic: .color, name: "occlusion"),
            roughness: upload(
                RoundTube16StrandTextureFactory.roughnessImage(twist: twist),
                semantic: .scalar, name: "roughness"
            ),
            normal: upload(
                RoundTube16StrandTextureFactory.normalImage(twist: twist),
                semantic: .normal, name: "normal"
            )
        )
    }()

    // MARK: - The stripes

    /// Stripes met going along one cell.
    ///
    /// The photograph is counted *across* a thread, because the fibre runs nearly
    /// along it. Stripes lying `s` apart across the thread meet its run every
    /// `s / tan(angle)`, so the count along one thread width is the count across
    /// it times `tan(angle)`; times how many thread widths a cell is long.
    ///
    /// **Rounded to a whole number**, as the flat braid's is and for the same
    /// reason: a column is one ridge from end to end, so the stripes have to come
    /// back to where they started at the end of a cell or they would break at
    /// every cycle.
    static var stripesPerCell: Float {
        max(1, stripesPerCellBeforeRounding.rounded())
    }

    static var stripesPerCellBeforeRounding: Float {
        let angle = abs(RoundTube8SurfaceMesh.fibreStripeAngleDegrees) * .pi / 180
        return RoundTube8SurfaceMesh.fibreStripesAcrossThreadWidth * tan(angle)
            * cellLengthInThreadWidths
    }

    /// One cycle along the braid, in thread widths. A thread is an eighth of the
    /// valley floor's circumference — the relation `crestHeightRatio` rests on —
    /// and a cycle is `pitchOverDiameter` of the braid's diameter.
    static var cellLengthInThreadWidths: Float {
        let threads = Float(RoundTube8SurfacePatternGenerator.requiredThreadCount)
        // In radii: the braid is 2 across, and the floor is below the crest.
        let threadWidth = 2 * .pi * (1 - RoundTube8SurfaceMesh.crestHeightRatio) / threads
        return 2 * RoundTube8SurfacePatternGenerator.pitchOverDiameter / threadWidth
    }

    /// The coefficients every cell uses, in the form the sixteen-thread factory
    /// reads.
    ///
    /// Solved so the stripes lie at `fibreStripeAngleDegrees` to the thread's run:
    /// the flat braid's solve, which is the round braid's without the shear term —
    /// zero here too. Lengths are in radii, so the gradient comes out already
    /// scaled the way the factory's normal map wants it.
    ///
    /// **The sign of the across term is this mesh's own, and which way it leans on
    /// screen was measured, not reasoned.** Read off a render in the simulator —
    /// the spectrum of a front lane, with everything that runs straight along the
    /// braid taken out — a positive angle gives stripes at +14.7 degrees, falling
    /// to the right with the braid lying across the view. An argument about the
    /// frame had predicted the opposite.
    ///
    /// **The photograph does not settle which way its fibre leans.** Of ten beans
    /// read the same way, five show a period the size of a fibre stripe; four of
    /// those lean this way (+12.5 to +40.8 degrees) and one the other (-11.3), and
    /// a first look by eye had it the other way too. This sign is the majority's.
    static var twist: RoundTube16SurfaceMesh.TwistGroup? {
        let angle = RoundTube8SurfaceMesh.fibreStripeAngleDegrees * .pi / 180
        let sine = sin(angle)
        let cosine = cos(angle)
        guard sine != 0 else { return nil }

        // A cell is one cycle long and an eighth of the crest's circumference
        // wide; across is read in half-widths, as the factory reads it.
        let along = 2 * RoundTube8SurfacePatternGenerator.pitchOverDiameter
        let halfWidth = Float.pi / Float(RoundTube8SurfacePatternGenerator.requiredThreadCount)
        let phasePerAlong = -2 * .pi * stripesPerCell
        let phasePerAcross = phasePerAlong * halfWidth * cosine / (along * sine)
        // **The normal map's second channel runs along the normal crossed with the
        // tangent**, which is the way the sixteen-thread solve expresses it (its
        // `acrossUnit`, the tangent turned a quarter turn). On this mesh the
        // bitangent runs the way the angle round the braid grows, which is
        // *against* that, so across is counted the other way here. Left as it
        // was, the relief lit the mirror image of the stripes the tint and the
        // roughness draw, and the two crossed into a lattice on the render.
        let gradient = SIMD2<Float>(phasePerAlong / along, -phasePerAcross / halfWidth)
        guard phasePerAcross.isFinite, gradient.x.isFinite, gradient.y.isFinite else {
            return nil
        }
        return RoundTube16SurfaceMesh.TwistGroup(
            coefficients: RoundTube16SurfaceMesh.TwistCoefficients(
                phasePerAlong: phasePerAlong,
                phasePerAcross: phasePerAcross
            ),
            normalizedPhaseGradient: gradient
        )
    }

    // MARK: - The shading

    /// The valley shading at one place across a cell, `0...1` over the bitmap's
    /// rows. **The sixteen-thread tube's figures**, for the trough between two
    /// ridges. It does not depend on where along the cell the place is: see
    /// above for why the ends are not shaded.
    static func shading(across row: Float) -> Float {
        let offset = RoundTube16StrandTextureFactory.crossSectionOffset(forRow: row)
        return mix(
            RoundTube16StrandTextureFactory.valleyOcclusion,
            1,
            smoothstep(0, RoundTube16StrandTextureFactory.valleyOcclusionWidth, 1 - abs(offset))
        )
    }

    /// The shading, darkened a little where a stripe turns away — the
    /// sixteen-thread tube's tint, which is small because the stripe is carried by
    /// the normal and roughness maps.
    static func occlusionImage(twist: RoundTube16SurfaceMesh.TwistGroup) -> CGImage? {
        image { along, row in
            let offset = RoundTube16StrandTextureFactory.crossSectionOffset(forRow: row)
            let tint = 1 - RoundTube16StrandTextureFactory.twistTint
                * (1 - cos(twist.coefficients.phase(along: along, across: offset))) / 2
            return linearToSRGB(shading(across: row) * tint)
        }
    }

    // MARK: - Bitmaps

    /// The factory's own size, so all three maps are addressed alike.
    private static func image(_ value: (Float, Float) -> Float) -> CGImage? {
        let width = RoundTube16StrandTextureFactory.width
        let height = RoundTube16StrandTextureFactory.height
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for row in 0..<height {
            let across = (Float(row) + 0.5) / Float(height)
            for column in 0..<width {
                let along = (Float(column) + 0.5) / Float(width)
                let byte = UInt8(min(max(value(along, across), 0), 1) * 255 + 0.5)
                let offset = (row * width + column) * 4
                pixels[offset] = byte
                pixels[offset + 1] = byte
                pixels[offset + 2] = byte
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

    @MainActor private static func upload(
        _ image: CGImage?,
        semantic: TextureResource.Semantic,
        name: String
    ) -> TextureResource? {
        guard let image else {
            logger.error("Eight-thread \(name, privacy: .public) map could not be drawn")
            return nil
        }
        do {
            return try TextureResource.generate(from: image, options: .init(semantic: semantic))
        } catch {
            logger.error(
                "Eight-thread \(name, privacy: .public) map could not be uploaded: \(String(describing: error), privacy: .public)"
            )
            return nil
        }
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
