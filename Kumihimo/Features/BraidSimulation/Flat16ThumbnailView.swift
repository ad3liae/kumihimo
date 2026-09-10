import SwiftUI

struct Flat16ThumbnailView: View {
    let assignments: [ThreadAssignment]

    var body: some View {
        Canvas { context, size in
            guard
                let pattern = Flat16SurfacePatternGenerator.generate(assignments: assignments),
                let roundTheBraid = Flat16SurfacePatternGenerator.patternAspectRatioRoundTheBraid,
                let layout = UnrolledPatternThumbnailLayout(
                    size: size,
                    aspectRatio: roundTheBraid
                )
            else {
                return
            }
            // **The frame's height is one turn round the braid**, not one face of
            // it (Task 029). The round braid's thumbnail already opened its whole
            // circumference; this one showed six columns of sixteen and called it
            // the braid. The ratio handed to the layout is therefore over the turn,
            // not over the width — with the width's ratio the drawing would be
            // squashed along the braid by the same 16/6.
            //
            // Nothing here is a scale: a cell keeps the proportion it had. What
            // changed is how much of the braid the frame holds.
            for repeatIndex in layout.repeatIndices {
                for patch in pattern.patches {
                    let span = Flat16SurfaceMesh.arcSpan(of: patch.region)
                    // A region whose span runs past the wrap is drawn twice, once
                    // on each side of the seam, and the frame crops it. Which
                    // region that is comes from the span, not from a name.
                    let wraps = span.start + span.length > 1
                    for turn in (wraps ? [Float(0), -1] : [0]) {
                        draw(
                            patch: patch,
                            corners: patch.corners.map {
                                SIMD2<Float>(span.start + $0.x * span.length + turn, $0.y)
                            },
                            layout: layout,
                            repeatIndex: repeatIndex,
                            in: &context
                        )
                    }
                }
            }
        }
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }

    /// One patch, already carried from its region's own coordinates to the turn
    /// round the braid. **Everything the layout is asked about is asked in those
    /// coordinates** — the fibre included, so a narrow region's slant is drawn at
    /// the same scale as a broad one's instead of three times steeper.
    private func draw(
        patch: Flat16SurfacePatch,
        corners: [SIMD2<Float>],
        layout: UnrolledPatternThumbnailLayout,
        repeatIndex: Int,
        in context: inout GraphicsContext
    ) {
        var path = Path()
        for (index, corner) in corners.enumerated() {
            let point = layout.point(surfaceCoordinate: corner, repeatIndex: repeatIndex)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        context.fill(path, with: .color(color(for: patch.colorID).swiftUIColor))
        context.stroke(path, with: .color(.primary.opacity(0.24)), lineWidth: 0.7)

        // The fibre's slant is taken from the patch's own corners, not from its
        // bounding box: a leaning patch's box has corners the patch does not, and
        // a longer repeat makes that plainer.
        var fiber = Path()
        let along = layout.displacement(surfaceOffset: corners[2] - corners[1])
        let across = layout.displacement(surfaceOffset: corners[1] - corners[0])
        let base = layout.point(surfaceCoordinate: corners[0], repeatIndex: repeatIndex)
        if patch.threadRole == .outer {
            fiber.move(to: CGPoint(x: base.x, y: base.y + across.dy))
            fiber.addLine(to: CGPoint(x: base.x + along.dx, y: base.y))
        } else {
            fiber.move(to: base)
            fiber.addLine(to: CGPoint(x: base.x + along.dx, y: base.y + across.dy))
        }
        context.stroke(fiber, with: .color(.white.opacity(0.22)), lineWidth: 1)
    }

    private func color(for id: ThreadColorID) -> ThreadColor {
        ThreadColorCatalog.color(for: id) ?? ThreadColorCatalog.defaultColor
    }
}
