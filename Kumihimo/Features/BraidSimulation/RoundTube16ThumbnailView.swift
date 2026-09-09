import SwiftUI

struct RoundTube16ThumbnailView: View {
    let assignments: [ThreadAssignment]
    /// Which way the braid runs on the frame. The list's card stands it upright.
    var orientation: UnrolledPatternThumbnailLayout.Orientation = .alongTheWidth

    var body: some View {
        Canvas { context, size in
            guard
                let pattern = RoundTube16SurfacePatternGenerator.generate(assignments: assignments),
                let layout = UnrolledPatternThumbnailLayout(
                    size: size,
                    aspectRatio: pattern.aspectRatio,
                    orientation: orientation
                )
            else {
                return
            }
            for repeatIndex in layout.repeatIndices {
                for patch in pattern.patches {
                    var path = Path()
                    for (cornerIndex, corner) in patch.corners.enumerated() {
                        let point = layout.point(
                            surfaceCoordinate: corner,
                            repeatIndex: repeatIndex
                        )
                        if cornerIndex == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                    path.closeSubpath()
                    context.fill(path, with: .color(color(for: patch.colorID).swiftUIColor))
                    context.stroke(
                        path,
                        with: .color(.primary.opacity(0.26)),
                        lineWidth: 0.7
                    )
                }
            }
        }
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }

    private func color(for id: ThreadColorID) -> ThreadColor {
        ThreadColorCatalog.color(for: id) ?? ThreadColorCatalog.defaultColor
    }

}
