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
    /// What the braid says about how far it has been checked. **Passed in** for
    /// the same reason; the preset carries it.
    var prototypeNotice: String = ""

    var body: some View {
        switch BraidFamilyDrawing.drawer(for: recipe) {
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
        case RoundTube8SurfaceMesh.family:
            // **The same view**: a tube is a tube, and what differs is the family,
            // the table its cells are worked out from, and what the braid is
            // called.
            RoundTube16PreviewView(
                assignments: assignments,
                controller: controller,
                isEmbedded: isEmbedded,
                closeAction: closeAction,
                family: RoundTube8SurfaceMesh.family,
                table: BraidSurfaceScene.table(for: recipe),
                wording: RoundTube16PreviewView.Wording(
                    title: ProjectEditorStrings.previewTitle(recipe.name),
                    notice: prototypeNotice,
                    accessibilityLabel:
                        ProjectEditorStrings.surfaceAccessibilityLabel(recipe.name),
                    accessibilityIdentifier: "\(recipe.id)-3d-surface"
                )
            )
        default:
            BraidNothingDrawsItView(text: nothingDrawsIt)
        }
    }
}

extension BraidPreviewForFamily {
    /// Whether a preview shown on its own has to be given a way out.
    ///
    /// **The two solid drawers each put a dismiss button in a navigation bar of
    /// their own.** The figure has no bar, and neither has the empty space a braid
    /// nothing draws — so those two have to be given one from outside, or a
    /// full-screen preview of either cannot be left at all.
    static func needsItsOwnWayOut(recipe: BraidRecipe, showingFigure: Bool) -> Bool {
        showingFigure || drawer(for: recipe) == nil
    }

    private static func drawer(for recipe: BraidRecipe) -> BraidFamily? {
        BraidFamilyDrawing.drawer(for: recipe)
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
        switch BraidFamilyDrawing.drawer(for: recipe) {
        case Flat16SurfaceMesh.family:
            Flat16ThumbnailView(assignments: assignments)
        case RoundTube16SurfaceMesh.family:
            RoundTube16ThumbnailView(assignments: assignments)
        case RoundTube8SurfaceMesh.family:
            if let pattern = BraidSurfaceScene.table(for: recipe).flatMap({ table in
                RoundTube8SurfacePatternGenerator.generate(
                    stand: table.stand, method: table.method,
                    crossSection: table.crossSection, assignments: assignments
                )
            }) {
                RoundTube8ThumbnailView(pattern: pattern)
            } else {
                BraidNothingDrawsItView(text: nothingDrawsIt)
            }
        default:
            BraidNothingDrawsItView(text: nothingDrawsIt)
        }
    }
}
