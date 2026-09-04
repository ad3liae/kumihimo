import CoreGraphics
import Foundation
import simd

/// Places the unwrapped surface pattern inside a thumbnail frame without
/// distorting it.
///
/// The frame is wider than it is tall, and one repeat of the pattern is only
/// `aspectRatio` times as long as the braid's circumference, so the frame cannot
/// be filled by one repeat without shearing every chevron. Instead the height
/// carries the full circumference and enough repeats are laid along the width to
/// overhang both ends, which is what the 3D view does with its tiles.
struct MaruGenjiThumbnailLayout: Equatable, Sendable {
    /// Cap on the repeats one thumbnail draws, so an extreme frame ratio bounds the
    /// work instead of growing it without limit. A capped layout stops short of the
    /// frame edges rather than stretching to reach them.
    static let maximumRepeatCount = 64

    /// Points the full turn around the braid occupies, down the frame.
    let circumference: CGFloat
    /// Points one repeat along the braid occupies, across the frame.
    let repeatLength: CGFloat
    let repeatCount: Int
    /// Frame position of the first repeat's origin. Negative, so the pattern
    /// overhangs the leading edge instead of starting inside it.
    let originX: CGFloat

    init?(size: CGSize, aspectRatio: Float) {
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
        let circumference = size.height
        let repeatLength = circumference * CGFloat(aspectRatio)
        guard repeatLength > 0, repeatLength.isFinite else { return nil }

        // One repeat more than the width needs, so a partial repeat overhangs each
        // end and the pattern is cropped by the frame rather than fitted to it.
        let covering = (size.width / repeatLength).rounded(.up) + 1
        guard covering.isFinite else { return nil }
        let repeatCount = min(max(Int(covering), 1), Self.maximumRepeatCount)

        self.circumference = circumference
        self.repeatLength = repeatLength
        self.repeatCount = repeatCount
        self.originX = (size.width - CGFloat(repeatCount) * repeatLength) / 2
    }

    var repeatIndices: Range<Int> {
        0..<repeatCount
    }

    /// Frame position of a surface coordinate: `x` around the braid, `y` along it.
    func point(surfaceCoordinate: SIMD2<Float>, repeatIndex: Int) -> CGPoint {
        CGPoint(
            x: originX + repeatLength * (CGFloat(repeatIndex) + CGFloat(surfaceCoordinate.y)),
            y: circumference * CGFloat(surfaceCoordinate.x)
        )
    }

    /// Frame displacement of a surface direction. Both axes use the same scale per
    /// unit of world distance, so a chevron keeps the angle it has on the braid.
    func displacement(surfaceOffset: SIMD2<Float>) -> CGVector {
        CGVector(
            dx: repeatLength * CGFloat(surfaceOffset.y),
            dy: circumference * CGFloat(surfaceOffset.x)
        )
    }
}
