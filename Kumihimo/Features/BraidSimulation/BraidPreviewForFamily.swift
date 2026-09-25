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
    /// Used only when shown on its own (`isEmbedded` false), where the drawer
    /// brings its own navigation bar and dismiss button.
    var closeAction: (() -> Void)? = nil
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
        case let family? where family == RoundTube8SurfaceMesh.family
            || family == RoundTube8SurfaceMesh.familyTurningBothWays
            || family == RoundTube4SurfaceMesh.family:
            // **The same view**: a tube is a tube, and what differs is the family,
            // the table its cells are worked out from, and what the braid is
            // called.
            RoundTube16PreviewView(
                assignments: assignments,
                controller: controller,
                isEmbedded: isEmbedded,
                closeAction: closeAction,
                family: family,
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
        case RoundTube8SurfaceMesh.family, RoundTube8SurfaceMesh.familyTurningBothWays:
            if let pattern = BraidSurfaceScene.table(for: recipe).flatMap({ table in
                RoundTube8SurfacePatternGenerator.generate(
                    stand: table.stand, rounds: table.rounds,
                    crossSection: table.crossSection, assignments: assignments
                )
            }) {
                RoundTube8ThumbnailView(pattern: pattern)
            } else {
                BraidNothingDrawsItView(text: nothingDrawsIt)
            }
        case RoundTube4SurfaceMesh.family:
            if let pattern = BraidSurfaceScene.table(for: recipe).flatMap({ table in
                RoundTube4SurfacePatternGenerator.generate(
                    stand: table.stand, rounds: table.rounds,
                    crossSection: table.crossSection, assignments: assignments
                )
            }) {
                RoundTube4ThumbnailView(pattern: pattern)
            } else {
                BraidNothingDrawsItView(text: nothingDrawsIt)
            }
        default:
            BraidNothingDrawsItView(text: nothingDrawsIt)
        }
    }
}
