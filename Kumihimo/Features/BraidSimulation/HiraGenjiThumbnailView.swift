import SwiftUI

struct HiraGenjiThumbnailView: View {
    let assignments: [ThreadAssignment]

    var body: some View {
        Canvas { context, size in
            guard let pattern = HiraGenjiSurfacePatternGenerator.generate(assignments: assignments) else {
                return
            }
            // Keep one stitch close to one lane width at the card's usual aspect
            // ratio. A small repeat count makes the braid look like colored panels.
            let repeats = 16
            let frontPatches = pattern.patches(in: .front)
            for repeatIndex in 0..<repeats {
                for patch in frontPatches {
                    var path = Path()
                    for (index, corner) in patch.corners.enumerated() {
                        let point = CGPoint(
                            x: size.width * CGFloat(
                                (Float(repeatIndex) + corner.y) / Float(repeats)
                            ),
                            y: size.height * CGFloat(corner.x)
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

                    var fiber = Path()
                    let bounds = path.boundingRect
                    if patch.threadRole == .outer {
                        fiber.move(to: CGPoint(x: bounds.minX, y: bounds.maxY))
                        fiber.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
                    } else {
                        fiber.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
                        fiber.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
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
