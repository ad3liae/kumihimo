import SwiftUI

struct Flat16ThumbnailView: View {
    let assignments: [ThreadAssignment]
    /// Which way the braid runs on the frame. The list's card stands it upright.
    var orientation: UnrolledPatternThumbnailLayout.Orientation = .alongTheWidth

    var body: some View {
        Canvas { context, size in
            guard
                let pattern = Flat16SurfacePatternGenerator.generate(assignments: assignments),
                let layout = UnrolledPatternThumbnailLayout(
                    size: size,
                    aspectRatio: pattern.aspectRatio,
                    orientation: orientation
                )
            else {
                return
            }
            // **The face's own width down the frame, and one repeat as long as the
            // pattern says it is.** This used to divide the frame's width by
            // sixteen repeats and never read the aspect ratio, which squeezed a
            // repeat to a fifth of its length on an iPad and a tenth on an iPhone.
            for repeatIndex in layout.repeatIndices {
                for patch in pattern.patches(in: .front) {
                    var path = Path()
                    for (index, corner) in patch.corners.enumerated() {
                        let point = layout.point(
                            surfaceCoordinate: corner,
                            repeatIndex: repeatIndex
                        )
                        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    path.closeSubpath()
                    let color = color(for: patch.colorID).swiftUIColor
                    context.fill(path, with: .color(color))
                    context.stroke(
                        path,
                        with: .color(.primary.opacity(0.24)),
                        lineWidth: 0.7
                    )

                    // The fibre's slant is taken from the patch's own corners, not
                    // from its bounding box: a leaning patch's box has corners the
                    // patch does not, and a longer repeat makes that plainer.
                    var fiber = Path()
                    let along = layout.displacement(
                        surfaceOffset: patch.corners[2] - patch.corners[1]
                    )
                    let across = layout.displacement(
                        surfaceOffset: patch.corners[1] - patch.corners[0]
                    )
                    let base = layout.point(
                        surfaceCoordinate: patch.corners[0], repeatIndex: repeatIndex
                    )
                    // Written as whole vectors rather than one component of each,
                    // so the slant is right whichever way round the braid sits on
                    // the frame.
                    func moved(_ offsets: CGVector...) -> CGPoint {
                        offsets.reduce(base) { CGPoint(x: $0.x + $1.dx, y: $0.y + $1.dy) }
                    }
                    if patch.threadRole == .outer {
                        fiber.move(to: moved(across))
                        fiber.addLine(to: moved(along))
                    } else {
                        fiber.move(to: base)
                        fiber.addLine(to: moved(across, along))
                    }
                    context.stroke(fiber, with: .color(.white.opacity(0.22)), lineWidth: 1)
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
