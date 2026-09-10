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

/// The same choice, for a thumbnail.
struct BraidThumbnailForFamily: View {
    let recipe: BraidRecipe
    let assignments: [ThreadAssignment]
    let nothingDrawsIt: String

    var body: some View {
        switch BraidFamilyDrawing.drawer(for: recipe, on: BraidMethodCatalog.stand16) {
        case Flat16SurfaceMesh.family:
            Flat16ThumbnailView(assignments: assignments)
        case RoundTube16SurfaceMesh.family:
            RoundTube16ThumbnailView(assignments: assignments)
        default:
            BraidNothingDrawsItView(text: nothingDrawsIt)
        }
    }
}
