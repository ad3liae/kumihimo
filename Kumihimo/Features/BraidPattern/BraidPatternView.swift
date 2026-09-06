import SwiftUI

/// Draws a `BraidFigure`.
///
/// The figure says where every thread goes and what colour it is; this only puts
/// ink on it. Shapes are drawn in the order the figure gives them, so what the
/// face shows is laid down first and the hidden runs go over the top as thin
/// broken lines — the convention a technical drawing uses for work behind a
/// surface, and the only way to follow a thread from where it dives to where it
/// comes back.
struct BraidPatternView: View {
    let figure: BraidFigure
    var accessibilityLabel: String = BraidPatternStrings.figureAccessibilityLabel

    var body: some View {
        Canvas { context, size in
            let unit = min(size.width / figure.size.x, size.height / figure.size.y)
            let inset = CGPoint(
                x: (size.width - figure.size.x * unit) / 2,
                y: (size.height - figure.size.y * unit) / 2
            )
            func point(_ p: SIMD2<Double>) -> CGPoint {
                CGPoint(x: inset.x + p.x * unit, y: inset.y + p.y * unit)
            }

            context.fill(
                Path(CGRect(origin: point(SIMD2(0, 0)), size: CGSize(
                    width: figure.size.x * unit, height: figure.size.y * unit
                ))),
                with: .color(Color(white: 0.91))
            )

            for shape in figure.shapes {
                let colour = ThreadColorCatalog.color(for: shape.colorID)?.swiftUIColor
                    ?? Color.secondary
                var path = Path()
                path.move(to: point(shape.points[0]))
                for p in shape.points.dropFirst() { path.addLine(to: point(p)) }

                switch shape.kind {
                case .appearance:
                    path.closeSubpath()
                    context.fill(path, with: .color(colour))
                    context.stroke(
                        path, with: .color(Color.primary.opacity(0.35)), lineWidth: unit * 0.03
                    )
                case .passage where shape.isOnTheFace:
                    context.stroke(
                        path,
                        with: .color(Color.primary.opacity(0.25)),
                        style: StrokeStyle(lineWidth: unit * 0.26, lineCap: .round)
                    )
                    context.stroke(
                        path,
                        with: .color(colour),
                        style: StrokeStyle(lineWidth: unit * 0.20, lineCap: .round)
                    )
                case .passage:
                    let broken = StrokeStyle(
                        lineWidth: unit * 0.11,
                        lineCap: .round,
                        dash: [unit * 0.26, unit * 0.22]
                    )
                    context.stroke(path, with: .color(colour), style: broken)
                }
            }
        }
        .aspectRatio(figure.size.x / figure.size.y, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }
}

enum BraidPatternStrings {
    static let figureAccessibilityLabel = "組み上がりの模様図"
    static let frontFace = "表"
    static let backFace = "裏"
    /// Shown with the figure. It is the whole reason the figure can be trusted for
    /// a braid nobody has made yet.
    static let noEstimateNotice = "この図は手順表から導いた通り道・上下・位相だけで描いています。寸法の推定を含みません。"
}

#Preview {
    let derivation = BraidDerivation.derive(
        stand: BraidMethodCatalog.stand16,
        method: BraidMethodCatalog.hiraGenji16,
        crossSection: BraidMethodCatalog.hiraGenji16CrossSection
    )
    let assignments = (1...16).map { position in
        ThreadAssignment(
            position: position,
            colorID: ThreadColorID(rawValue: [15, 16, 1, 2, 10, 9, 8, 7].contains(position)
                ? "natural"
                : ([3, 6, 14, 11].contains(position) ? "yellow" : "orange"))
        )
    }
    return HStack(spacing: 16) {
        if let derivation,
           let front = BraidFigureBuilder.figure(
               from: derivation, assignments: assignments, face: .front
           ),
           let back = BraidFigureBuilder.figure(
               from: derivation, assignments: assignments, face: .back
           ) {
            BraidPatternView(figure: front)
            BraidPatternView(figure: back)
        }
    }
    .padding()
}
