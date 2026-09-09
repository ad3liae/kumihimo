import SwiftUI

/// Draws a `BraidTubeFigure`: the face of a braid that is a tube, unrolled.
///
/// One cell a column a row, in the columns' own order — **the slots a hand lands
/// on**, which do not stand at even angles round the braid. Under it, each column's
/// angle, and **that the figure is unsure of something**, in small type: a figure
/// that is not sure of something should say so where it is looked at.
///
/// **The figure's own `unsettled` notes are not shown.** They are written for
/// whoever reads the code — in English, and `BraidCrossSection.unsettled` says
/// itself that it is not display text — so the screen says the same thing in its
/// own words. What is not settled is fixed, not open-ended: the mirror counts as
/// agreement, and the order of the columns round the braid is undecided.
struct BraidTubePatternView: View {
    let figure: BraidTubeFigure
    var accessibilityLabel: String = BraidPatternStrings.figureAccessibilityLabel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Canvas { context, size in
                let across = Double(figure.columns.count)
                let along = Double(figure.rowsDrawn)
                let unit = min(size.width / across, size.height / along)
                let inset = CGPoint(
                    x: (size.width - across * unit) / 2,
                    y: (size.height - along * unit) / 2
                )
                context.fill(
                    Path(CGRect(x: inset.x, y: inset.y,
                                width: across * unit, height: along * unit)),
                    with: .color(Color(white: 0.91))
                )
                for shape in figure.shapes where shape.isOnTheFace {
                    guard let place = shape.place else { continue }
                    let colour = ThreadColorCatalog.color(for: shape.colorID)?.swiftUIColor
                        ?? Color.secondary
                    // Row 0 at the bottom: the braid grows upwards.
                    let cell = CGRect(
                        x: inset.x + Double(place.width) * unit + unit * 0.04,
                        y: inset.y + Double(figure.rowsDrawn - 1 - place.row) * unit
                            + unit * 0.04,
                        width: unit * 0.92, height: unit * 0.92
                    )
                    context.fill(Path(roundedRect: cell, cornerRadius: unit * 0.12),
                                 with: .color(colour))
                    context.stroke(
                        Path(roundedRect: cell, cornerRadius: unit * 0.12),
                        with: .color(Color.primary.opacity(0.35)), lineWidth: unit * 0.03
                    )
                }
            }
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel)

            Text(columnAngles)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            if !figure.unsettled.isEmpty {
                Text(BraidPatternStrings.tubeUnsettled)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The angle each column stands at, which is the thing most easily mistaken
    /// for even spacing.
    private var columnAngles: String {
        figure.columns
            .map { String(format: "%.1f°", $0.angleInTurns * 360) }
            .joined(separator: "  ")
    }
}
