import CoreGraphics
import Foundation
import simd

/// Places the unwrapped surface pattern inside a thumbnail frame without
/// distorting it.
///
/// One repeat of the pattern is only `aspectRatio` times as long as the braid's
/// circumference, so the frame cannot be filled by one repeat without shearing
/// every chevron. Instead **one frame extent carries the full turn around the
/// braid** and enough repeats are laid along the other to overhang both ends,
/// which is what the 3D view does with its tiles.
///
/// **Which extent carries which is the orientation**, and only that. The braid
/// used to be assumed to lie across a wide frame; the list's card stands it
/// upright in a frame that is taller than it is wide (Task 028-1b). The
/// arithmetic is the same either way and is written once: the two directions are
/// named for the braid, across and along, and only `point` and `displacement`
/// know which way round they sit on the frame.
struct UnrolledPatternThumbnailLayout: Equatable, Sendable {
    /// Which way the braid runs on the frame.
    enum Orientation: Equatable, Sendable {
        /// The braid lies across the frame: the turn around it goes down the
        /// height, the repeats along the width.
        case alongTheWidth
        /// The braid stands up the frame: the turn around it goes across the
        /// width, the repeats down the height.
        case alongTheHeight
    }

    /// Cap on the repeats one thumbnail draws, so an extreme frame ratio bounds the
    /// work instead of growing it without limit. A capped layout stops short of the
    /// frame edges rather than stretching to reach them.
    static let maximumRepeatCount = 64

    let orientation: Orientation
    /// Points the full turn around the braid occupies, across the frame.
    let circumference: CGFloat
    /// Points one repeat along the braid occupies, along the frame.
    let repeatLength: CGFloat
    let repeatCount: Int
    /// Frame position of the first repeat's origin, along the braid. Negative, so
    /// the pattern overhangs the leading edge instead of starting inside it.
    let originAlongTheBraid: CGFloat

    init?(
        size: CGSize,
        aspectRatio: Float,
        orientation: Orientation = .alongTheWidth
    ) {
        guard
            size.width.isFinite,
            size.height.isFinite,
            size.width > 0,
            size.height > 0,
            aspectRatio.isFinite,
            aspectRatio > 0
        else {
            return nil
        }
        // The frame's two extents, named for the braid rather than the screen.
        let across = orientation == .alongTheWidth ? size.height : size.width
        let alongTheFrame = orientation == .alongTheWidth ? size.width : size.height

        let circumference = across
        let repeatLength = circumference * CGFloat(aspectRatio)
        guard repeatLength > 0, repeatLength.isFinite else { return nil }

        // One repeat more than the frame needs, so a partial repeat overhangs each
        // end and the pattern is cropped by the frame rather than fitted to it.
        let covering = (alongTheFrame / repeatLength).rounded(.up) + 1
        guard covering.isFinite else { return nil }
        let repeatCount = min(max(Int(covering), 1), Self.maximumRepeatCount)

        self.orientation = orientation
        self.circumference = circumference
        self.repeatLength = repeatLength
        self.repeatCount = repeatCount
        self.originAlongTheBraid =
            (alongTheFrame - CGFloat(repeatCount) * repeatLength) / 2
    }

    var repeatIndices: Range<Int> {
        0..<repeatCount
    }

    /// Frame position of a surface coordinate: `x` around the braid, `y` along it.
    func point(surfaceCoordinate: SIMD2<Float>, repeatIndex: Int) -> CGPoint {
        let along = originAlongTheBraid
            + repeatLength * (CGFloat(repeatIndex) + CGFloat(surfaceCoordinate.y))
        let across = circumference * CGFloat(surfaceCoordinate.x)
        switch orientation {
        case .alongTheWidth: return CGPoint(x: along, y: across)
        case .alongTheHeight: return CGPoint(x: across, y: along)
        }
    }

    /// Frame displacement of a surface direction. Both axes use the same scale per
    /// unit of world distance, so a chevron keeps the angle it has on the braid.
    func displacement(surfaceOffset: SIMD2<Float>) -> CGVector {
        let along = repeatLength * CGFloat(surfaceOffset.y)
        let across = circumference * CGFloat(surfaceOffset.x)
        switch orientation {
        case .alongTheWidth: return CGVector(dx: along, dy: across)
        case .alongTheHeight: return CGVector(dx: across, dy: along)
        }
    }
}
