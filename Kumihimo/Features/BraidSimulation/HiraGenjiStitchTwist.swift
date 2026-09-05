import Foundation
import simd

/// How the twist stripes run across one stitch of the flat braid.
///
/// `along` is 0...1 down the stitch and `across` is 0...1 over its width, so the
/// phase is affine in both and the stripes never break inside a stitch.
struct HiraGenjiStitchTwist: Equatable, Sendable {
    let phasePerAlong: Float
    let phasePerAcross: Float
    /// Phase gradient in the stitch's own frame, in world units and multiplied by
    /// the half-thickness so it does not depend on how large the braid is drawn.
    /// The normal map needs it.
    let normalizedPhaseGradient: SIMD2<Float>

    func phase(along: Float, across: Float) -> Float {
        phasePerAlong * along + phasePerAcross * (across - 0.5)
    }
}

/// Task 005G's arrangement, applied to the flat braid: work out the stripe
/// coefficients each strand needs, gather the strands that need the same ones
/// into a group, and build one set of textures per group.
///
/// **The flat braid needs one group where the round braid needs several.** The
/// round braid's patches are chevrons, and the two chevron directions shear the
/// stripe frame opposite ways, so one pair of coefficients puts one direction
/// short of the nominal angle and the other past it. Every patch of the flat
/// braid is a rectangle of the same size — one yarn wide, because stage 2.5c
/// divides the outline by arc, and one step long, because a step is a worked
/// cycle. No frame is sheared and they are all alike, so one pair serves them
/// all. `groups` measures that rather than assuming it.
enum HiraGenjiStitchTwistGrouping {
    /// Stripes over one stitch.
    ///
    /// Not chosen. The round braid draws `fiberCount` stripes over a strand
    /// segment "roughly four times as long as it is wide" — the shape of its own
    /// texture — so its stripes stand half a yarn width apart. The flat braid's
    /// stitch is `stitchPitchPerBraidWidth` of the braid's width long, which is
    /// that many yarn widths, so the same yarn asks for that many stripes: 4.4.
    ///
    /// **Rounded to a whole number.** The map is drawn over one stitch and read
    /// again on the next, so the phase has to come back to where it started at
    /// the end of a stitch or the stripes break at every join. The round braid's
    /// own count is a whole number for the same reason. Four leaves the stripes
    /// nine per cent further apart than the round braid's, which is closer than
    /// three or five would be.
    static var stripesPerStitch: Float {
        max(1, stripesPerStitchBeforeRounding.rounded())
    }

    static var stripesPerStitchBeforeRounding: Float {
        let roundSegmentInYarns = Float(MaruGenjiStrandTextureFactory.width)
            / Float(MaruGenjiStrandTextureFactory.height)
        let perYarn = Float(MaruGenjiSurfaceMeshGenerator.fiberCount) / roundSegmentInYarns
        return perYarn * stitchLengthInYarns
    }

    /// One step along the braid, in yarn widths.
    static var stitchLengthInYarns: Float {
        HiraGenjiSurfacePatternGenerator.stitchPitchPerBraidWidth
            * Float(HiraGenjiSurfacePatternGenerator.broadFaceColumnCount)
    }

    /// Phase turned over one stitch. Fixed, so every stitch shows the same
    /// number of stripes.
    static var phasePerAlong: Float { -2 * .pi * stripesPerStitch }

    /// The coefficients one region's stitches need.
    ///
    /// Solved from the stitch's own frame so the stripes sit at
    /// `twistAngleDegrees` to the yarn's own direction — the same solve the round
    /// braid does, without the shear term, which is zero here.
    static func twist(
        in region: HiraGenjiSurfaceRegion,
        halfWidth: Float = HiraGenjiSurfaceMeshGenerator.defaultHalfWidth,
        halfThickness: Float = HiraGenjiSurfaceMeshGenerator.defaultHalfThickness
    ) -> HiraGenjiStitchTwist? {
        let angle = MaruGenjiSurfaceMeshGenerator.twistAngleDegrees * .pi / 180
        let sine = sin(angle)
        let cosine = cos(angle)
        guard sine != 0 else { return nil }

        let along = stitchLength(halfWidth: halfWidth, halfThickness: halfThickness)
        let across = laneWidth(
            in: region,
            halfWidth: halfWidth,
            halfThickness: halfThickness
        )
        guard along > 0, across > 0 else { return nil }

        // Stripes at `angle` to the stitch's own direction: a line of constant
        // phase has slope `across / along = tan(angle)` in world units.
        let phasePerAcross = -phasePerAlong * across * cosine / (along * sine)
        let gradient = SIMD2<Float>(phasePerAlong / along, phasePerAcross / across)
        guard phasePerAcross.isFinite, gradient.x.isFinite, gradient.y.isFinite else {
            return nil
        }
        return HiraGenjiStitchTwist(
            phasePerAlong: phasePerAlong,
            phasePerAcross: phasePerAcross,
            normalizedPhaseGradient: gradient * halfThickness
        )
    }

    /// The distinct coefficient sets the braid needs, rounded before grouping so
    /// a stitch lands in the same group at any size.
    static func groups(
        halfWidth: Float = HiraGenjiSurfaceMeshGenerator.defaultHalfWidth,
        halfThickness: Float = HiraGenjiSurfaceMeshGenerator.defaultHalfThickness
    ) -> [HiraGenjiStitchTwist] {
        var seen = [Int]()
        var groups = [HiraGenjiStitchTwist]()
        for region in HiraGenjiSurfaceRegion.allCases {
            guard
                let twist = twist(in: region, halfWidth: halfWidth, halfThickness: halfThickness)
            else {
                continue
            }
            let key = Int((twist.phasePerAcross * 1_000).rounded())
            if !seen.contains(key) {
                seen.append(key)
                groups.append(twist)
            }
        }
        return groups
    }

    /// The angle the stripes actually make with the yarn's own direction, read
    /// back off the coefficients. What the solve is for.
    static func stripeAngleDegrees(
        of twist: HiraGenjiStitchTwist,
        in region: HiraGenjiSurfaceRegion,
        halfWidth: Float = HiraGenjiSurfaceMeshGenerator.defaultHalfWidth,
        halfThickness: Float = HiraGenjiSurfaceMeshGenerator.defaultHalfThickness
    ) -> Float? {
        let along = stitchLength(halfWidth: halfWidth, halfThickness: halfThickness)
        let across = laneWidth(in: region, halfWidth: halfWidth, halfThickness: halfThickness)
        guard along > 0, across > 0, twist.phasePerAcross != 0 else { return nil }
        // A line of constant phase runs where the phase does not change.
        let slope = -(twist.phasePerAlong / along) / (twist.phasePerAcross / across)
        return abs(atan(slope)) * 180 / .pi
    }

    /// Which way the stripes lean. Every strand of a braid is the same yarn, so
    /// this has to be the same everywhere.
    static func hand(of twist: HiraGenjiStitchTwist) -> FloatingPointSign {
        (twist.phasePerAlong * twist.phasePerAcross).sign
    }

    /// One step along the braid, in world units.
    static func stitchLength(halfWidth: Float, halfThickness: Float) -> Float {
        2 * halfWidth * HiraGenjiSurfacePatternGenerator.stitchPitchPerBraidWidth
    }

    /// One lane of a region, measured round the outline, in world units. Every
    /// lane is one yarn wide since stage 2.5c.
    static func laneWidth(
        in region: HiraGenjiSurfaceRegion,
        halfWidth: Float,
        halfThickness: Float
    ) -> Float {
        let span = HiraGenjiSurfaceMeshGenerator.arcSpan(of: region).length
        let perimeter = HiraGenjiSurfaceMeshGenerator.perimeter(
            halfWidth: halfWidth,
            halfThickness: halfThickness
        )
        return perimeter * span / Float(HiraGenjiSurfacePatternGenerator.columnCount(in: region))
    }
}
