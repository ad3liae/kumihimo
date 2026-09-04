import Foundation
import simd

/// Which side of a crossing one run of thread takes.
///
/// The assignment is a deterministic simulation of the braid, not a verified
/// reading of a real braid. It guarantees only that the two strands meeting at a
/// crossing take opposite sides, and that a single thread alternates along its
/// length.
enum BraidCrossingLayer: String, Equatable, Sendable, CaseIterable {
    case over
    case under

    var opposite: BraidCrossingLayer {
        self == .over ? .under : .over
    }
}

/// One visible run of a single thread across the braid surface, expressed as a
/// centreline with a width and a crossing layer.
///
/// The renderer consumes only this representation: centreline, width,
/// cross-section parameter and layer. The fixed 64-patch table is the current way
/// to build these segments; a future move-rule simulation can produce the same
/// segments without touching the mesh generator.
struct BraidStrandSegment: Equatable, Sendable {
    let threadPosition: Int
    let colorID: ThreadColorID
    let layer: BraidCrossingLayer
    /// Centreline endpoints in normalized surface coordinates
    /// (`x` around the braid, `y` along it).
    let centerlineStart: SIMD2<Float>
    let centerlineEnd: SIMD2<Float>
    /// Offset from the centreline to the `across == 1` edge at each end.
    let startHalfWidth: SIMD2<Float>
    let endHalfWidth: SIMD2<Float>

    /// Surface point at `along` ∈ 0...1 down the centreline and `across` ∈ -1...1
    /// over the width, where 0 is the crest of the strand.
    func surfacePoint(along: Float, across: Float) -> SIMD2<Float> {
        let progress = SIMD2<Float>(repeating: along)
        let center = simd_mix(centerlineStart, centerlineEnd, progress)
        let halfWidth = simd_mix(startHalfWidth, endHalfWidth, progress)
        return center + halfWidth * across
    }

    /// Centreline displacement from the leading edge to the trailing edge.
    var centerlineDelta: SIMD2<Float> {
        centerlineEnd - centerlineStart
    }

    /// Half-width offset at mid-span, the direction the cross-section runs in.
    var meanHalfWidth: SIMD2<Float> {
        (startHalfWidth + endHalfWidth) / 2
    }
}

struct BraidStrandSurface: Equatable, Sendable {
    let segments: [BraidStrandSegment]
}

enum BraidStrandSurfaceBuilder {
    /// Rewrites the fixed surface pattern as strand segments. Patch corners are
    /// arranged clockwise as leading/top, leading/bottom, trailing/bottom,
    /// trailing/top, so the two leading corners span the width at `along == 0`.
    static func surface(for pattern: MaruGenjiSurfacePattern) -> BraidStrandSurface {
        BraidStrandSurface(segments: pattern.patches.compactMap(segment(for:)))
    }

    static func segment(for patch: MaruGenjiSurfacePatch) -> BraidStrandSegment? {
        guard
            patch.corners.count == 4,
            patch.corners.allSatisfy({ $0.x.isFinite && $0.y.isFinite })
        else {
            return nil
        }
        let leadingLow = patch.corners[0]
        let leadingHigh = patch.corners[1]
        let trailingHigh = patch.corners[2]
        let trailingLow = patch.corners[3]

        return BraidStrandSegment(
            threadPosition: patch.threadPosition,
            colorID: patch.colorID,
            layer: patch.layer,
            centerlineStart: (leadingLow + leadingHigh) / 2,
            centerlineEnd: (trailingLow + trailingHigh) / 2,
            startHalfWidth: (leadingHigh - leadingLow) / 2,
            endHalfWidth: (trailingHigh - trailingLow) / 2
        )
    }
}
