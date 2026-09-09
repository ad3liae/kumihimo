import SwiftUI

/// The braid's face, drawn flat, from a recipe.
///
/// **Which figure a braid has follows from the braid**: one whose courses fold it
/// has two faces, and one whose threads all travel is a tube and has one surface
/// folded into columns. **This works for a braid no drawer will take**, because a
/// figure needs no drawer — only the move table and a colouring.
struct BraidPatternForRecipe: View {
    let recipe: BraidRecipe
    let assignments: [ThreadAssignment]
    /// What to say when the figure cannot be worked out at all.
    let nothingToShow: String

    var body: some View {
        switch Self.figure(for: recipe, assignments: assignments) {
        case let .faces(figures):
            HStack(alignment: .top, spacing: 16) {
                ForEach(Array(figures.enumerated()), id: \.offset) { _, pair in
                    VStack(spacing: 4) {
                        BraidPatternView(figure: pair.figure)
                        Text(pair.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case let .tube(figure):
            BraidTubePatternView(figure: figure)
        case .nothing:
            Text(nothingToShow)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    enum Drawing {
        case faces([(name: String, figure: BraidFigure)])
        case tube(BraidTubeFigure)
        case nothing
    }

    /// **Read off the braid, not declared.**
    static func figure(
        for recipe: BraidRecipe, assignments: [ThreadAssignment], repeats: Int = 3
    ) -> Drawing {
        guard
            let worked = recipe.worked(on: BraidMethodCatalog.stand16),
            assignments.count == worked.derivation.threadCount
        else { return .nothing }

        if worked.derivation.fold != nil {
            let faces: [(name: String, figure: BraidFigure)] = [
                (BraidPatternStrings.frontFace, BraidFace.front),
                (BraidPatternStrings.backFace, BraidFace.back),
            ].compactMap { named in
                BraidFigureBuilder.figure(
                    from: worked.derivation, assignments: assignments,
                    face: named.1, repeats: repeats
                ).map { (named.0, $0) }
            }
            return faces.isEmpty ? .nothing : .faces(faces)
        }
        guard let tube = BraidFigureBuilder.tube(
            from: worked.derivation, assignments: assignments, repeats: repeats
        ) else { return .nothing }
        return .tube(tube)
    }
}
