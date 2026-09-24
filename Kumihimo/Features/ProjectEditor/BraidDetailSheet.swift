import SwiftUI

/// A braid's detail, opened from its card: **the solid above, the figure below**,
/// in a sheet at every width (Task 058).
///
/// The title is the braid's own name — the recipe's, 「江戸八つ組」 — and the way
/// out is 閉じる at the top right, or a swipe down. **Nothing scrolls over the
/// solid**, because dragging it turns the braid. The upper part holds the solid
/// and its buttons and does not move; the lower part holds the notes and the
/// figure, and scrolls when they do not fit — at large text sizes, the notes
/// alone can be taller than the screen.
struct BraidDetailSheet: View {
    let preset: BraidPreset
    let assignments: [ThreadAssignment]
    let controller: RoundTube16ViewerController

    @Environment(\.dismiss) private var dismiss
    /// How tall the text in the lower part stands, measured, so the figure can
    /// take the rest of the part.
    @State private var notesHeight: CGFloat = 0
    @State private var figureNoticeHeight: CGFloat = 0

    /// The upper part's share of the sheet's height, under the navigation bar.
    /// Half: on an iPhone held upright it leaves the canvas about as tall as the
    /// figure below it, and the figure the room its notes do not take.
    static let solidShare: CGFloat = 0.5

    /// The figure's least height; below it the lower part scrolls instead.
    static let minimumFigureHeight: CGFloat = 160

    private static let spacing: CGFloat = 12
    private static let padding: CGFloat = 16

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let solidHeight = (geometry.size.height * Self.solidShare).rounded()
                VStack(spacing: 0) {
                    solid
                        .padding(.top, 8)
                        .frame(height: solidHeight)
                    Divider()
                    lowerPart
                }
            }
            .navigationTitle(Self.title(for: preset))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(ProjectEditorStrings.dismiss) { dismiss() }
                }
            }
        }
    }

    /// **The recipe's name**, 「江戸八つ組」, not the shorter one on the card.
    static func title(for preset: BraidPreset) -> String {
        BraidMethodCatalog.recipe(for: preset.id)?.name ?? preset.displayName
    }

    private var recipe: BraidRecipe? {
        BraidMethodCatalog.recipe(for: preset.id)
    }

    /// The drawer in its embedded form: the braid and its buttons, with no bar,
    /// dismiss button or notes of its own.
    @ViewBuilder
    private var solid: some View {
        if let recipe {
            BraidPreviewForFamily(
                recipe: recipe,
                assignments: assignments,
                controller: controller,
                isEmbedded: true,
                nothingDrawsIt: ProjectEditorStrings.nothingDrawsThisBraid,
                prototypeNotice: preset.prototypeNotice
            )
        } else {
            BraidNothingDrawsItView(text: ProjectEditorStrings.nothingDrawsThisBraid)
        }
    }

    /// The notes, then the figure, then what the figure does not estimate. The
    /// figure takes what the text leaves, down to `minimumFigureHeight`.
    private var lowerPart: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: Self.spacing) {
                    notes
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                            notesHeight = $0
                        }

                    figure
                        .frame(height: figureHeight(inPartOfHeight: geometry.size.height))
                        .frame(maxWidth: .infinity)

                    Text(BraidPatternStrings.noEstimateNotice)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                            figureNoticeHeight = $0
                        }
                }
                .padding(Self.padding)
            }
        }
    }

    private func figureHeight(inPartOfHeight height: CGFloat) -> CGFloat {
        let left = height - notesHeight - figureNoticeHeight
            - 2 * Self.spacing - 2 * Self.padding
        return max(Self.minimumFigureHeight, left.rounded(.down))
    }

    /// What the braid says about how far it has been checked, and — when there
    /// is a solid to turn — how to turn it.
    private var notes: some View {
        VStack(spacing: 4) {
            Text(preset.prototypeNotice)
                .font(.footnote.weight(.semibold))
            if drawsSolid {
                Text(ProjectEditorStrings.maruGenjiGestureHelp)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var drawsSolid: Bool {
        recipe.flatMap(BraidFamilyDrawing.drawer(for:)) != nil
    }

    @ViewBuilder
    private var figure: some View {
        if let recipe {
            BraidPatternForRecipe(
                recipe: recipe,
                assignments: assignments,
                nothingToShow: BraidPatternStrings.nothingToShow
            )
        } else {
            Text(BraidPatternStrings.nothingToShow)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

extension View {
    /// **A page-sized sheet, not a small form sheet**: on an iPad held sideways
    /// it stands as a card in the middle with the editor behind it, and still
    /// gives the solid room. iOS 17 has no sizing to ask for and keeps its
    /// default sheet.
    @ViewBuilder
    func braidDetailSheetSizing() -> some View {
        if #available(iOS 18.0, *) {
            presentationSizing(.page)
        } else {
            self
        }
    }
}
