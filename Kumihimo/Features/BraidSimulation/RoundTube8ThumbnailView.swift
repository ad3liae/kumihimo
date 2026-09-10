import SwiftUI

/// The eight-thread tube, unrolled flat for a card.
///
/// **The same drawing the solid is built from**, laid out by the same
/// `UnrolledPatternThumbnailLayout` the sixteen-thread tube's card uses, so the
/// two cards read at the same scale. Each cell is drawn as the rectangle its
/// strand segment spans — one column wide and one cycle long, square to the
/// braid, because a cell is a thread standing still.
///
/// **The diagonal on the card is the colour and not the shape.** Every cell is
/// upright; what walks round the braid is which thread is standing where, one
/// place a cycle.
struct RoundTube8ThumbnailView: View {
    let pattern: RoundTube8SurfacePattern

    var body: some View {
        Canvas { context, size in
            guard let layout = UnrolledPatternThumbnailLayout(
                size: size,
                aspectRatio: pattern.aspectRatio
            ) else { return }

            for repeatIndex in layout.repeatIndices {
                for segment in pattern.surface.segments {
                    var path = Path()
                    for (index, corner) in corners(of: segment).enumerated() {
                        let point = layout.point(
                            surfaceCoordinate: corner,
                            repeatIndex: repeatIndex
                        )
                        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    path.closeSubpath()
                    context.fill(path, with: .color(color(for: segment.colorID).swiftUIColor))
                    context.stroke(path, with: .color(.primary.opacity(0.26)), lineWidth: 0.7)
                }
            }
        }
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }

    /// Clockwise: leading edge, then trailing edge back again.
    private func corners(of segment: BraidStrandSegment) -> [SIMD2<Float>] {
        [
            segment.surfacePoint(along: 0, across: -1),
            segment.surfacePoint(along: 0, across: 1),
            segment.surfacePoint(along: 1, across: 1),
            segment.surfacePoint(along: 1, across: -1),
        ]
    }

    private func color(for id: ThreadColorID) -> ThreadColor {
        ThreadColorCatalog.color(for: id) ?? ThreadColorCatalog.defaultColor
    }
}
