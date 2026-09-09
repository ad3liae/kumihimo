import SwiftUI

/// Shows a braid in three dimensions, choosing the drawer by the braid's family.
///
/// **The screen no longer names a braid to decide what to show.** The family is
/// read off the braid — folded, or a tube, and how many threads — and whichever
/// drawer says it draws that family draws it. **A braid no drawer will take is not
/// drawn**, and the space says so instead; drawing it with the wrong drawer would
/// be worse than not drawing it.
struct BraidPreviewForFamily: View {
    let recipe: BraidRecipe
    let assignments: [ThreadAssignment]
    let controller: RoundTube16ViewerController
    let isEmbedded: Bool
    let closeAction: () -> Void
    /// What to say when nothing draws this braid. **Passed in**, so the wording
    /// lives with the screen's other wording and not in here.
    let nothingDrawsIt: String

    var body: some View {
        switch BraidFamilyDrawing.drawer(for: recipe, on: BraidMethodCatalog.stand16) {
        case Flat16SurfaceMesh.family:
            Flat16PreviewView(
                assignments: assignments,
                controller: controller,
                isEmbedded: isEmbedded,
                closeAction: closeAction
            )
        case RoundTube16SurfaceMesh.family:
            RoundTube16PreviewView(
                assignments: assignments,
                controller: controller,
                isEmbedded: isEmbedded,
                closeAction: closeAction
            )
        default:
            BraidNothingDrawsItView(text: nothingDrawsIt)
        }
    }
}

/// The empty space where a braid would be drawn if anything drew it.
struct BraidNothingDrawsItView: View {
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.dashed")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// The list's card: the braid's face drawn flat on the left, the braid itself on
/// the right.
///
/// **One third and two thirds.** The flat figure says what the colours repeat
/// into, which is what the list is being read for; the solid says what it will
/// look like. **They are the same two drawings the detail screen shows** — the
/// same `BraidFigure` from `BraidPatternForRecipe`, the same scene from
/// `BraidSurfaceScene` — so a card cannot show one thing and the screen behind it
/// another.
///
/// The figure drops the column angles and the note about what is not settled.
/// Both belong where the figure is read closely, and neither is legible at a
/// third of a card.
struct BraidThumbnailForFamily: View {
    let recipe: BraidRecipe
    let assignments: [ThreadAssignment]
    let nothingDrawsIt: String
    let nothingToShow: String

    /// The figure's share of the width. The rest is the braid.
    static let figureShare: CGFloat = 1.0 / 3.0
    private static let gap: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let figureWidth = max((geometry.size.width - Self.gap) * Self.figureShare, 0)
            let solidSize = CGSize(
                width: max(geometry.size.width - Self.gap - figureWidth, 0),
                height: geometry.size.height
            )
            HStack(spacing: Self.gap) {
                figure
                    .frame(width: figureWidth)
                solid(size: solidSize)
                    .frame(width: solidSize.width)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    /// **The face, front only.** A card has room for one face, and the front is
    /// the one the braid is looked at from.
    @ViewBuilder
    private var figure: some View {
        switch BraidPatternForRecipe.figure(for: recipe, assignments: assignments) {
        case let .faces(faces):
            if let front = faces.first {
                BraidPatternView(figure: front.figure)
            } else {
                nothing(nothingToShow)
            }
        case let .tube(tube):
            BraidTubeFigureCanvas(figure: tube)
        case .nothing:
            nothing(nothingToShow)
        }
    }

    @ViewBuilder
    private func solid(size: CGSize) -> some View {
        if let family = BraidFamilyDrawing.drawer(for: recipe, on: BraidMethodCatalog.stand16) {
            BraidCardRealityView(family: family, assignments: assignments, size: size)
        } else {
            BraidNothingDrawsItView(text: nothingDrawsIt)
        }
    }

    private func nothing(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
