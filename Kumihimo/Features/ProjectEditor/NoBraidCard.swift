import SwiftUI

/// 「組み方を選ばない」: choosing no braid, as a card of its own (Task 058 追補1).
///
/// **Above the results' heading, not among the results**: that section holds only
/// braids. It is chosen the way a braid's card is — a check and a border — and
/// with the braids' cards exactly one is chosen at a time. It has no thumbnail and
/// no detail, because there is nothing to draw.
struct NoBraidCard: View {
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            BraidSelectionRow(
                title: ProjectEditorStrings.noBraidTitle,
                subtitle: ProjectEditorStrings.noBraidMessage,
                isSelected: isSelected
            )
            .braidChoiceCard(isSelected: isSelected)
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        // VoiceOver names it by its title and says what it means as the hint.
        .accessibilityLabel(ProjectEditorStrings.noBraidTitle)
        .accessibilityHint(ProjectEditorStrings.noBraidMessage)
        .accessibilityIdentifier(ProjectEditorAccessibilityIdentifiers.undecidedPresetButton)
    }

    /// No braid is chosen exactly when the draft names none.
    static func isSelected(selectedPresetID: BraidPresetID?) -> Bool {
        selectedPresetID == nil
    }
}
