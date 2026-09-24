import SwiftUI

struct SimulationResultsBoundaryView: View {
    let state: ProjectEditorStore.SimulationResultsState
    let standKind: BraidStandKind
    let threadCount: Int
    let assignments: [ThreadAssignment]
    let presets: [BraidPreset]
    let selectedPresetID: BraidPresetID?
    let selectPreset: (BraidPresetID?) -> Void
    let showDetail: (BraidPreset) -> Void

    /// **Only braids.** Choosing no braid is a card of its own above this
    /// section's heading (`NoBraidCard`, Task 058 追補1).
    var body: some View {
        VStack(spacing: 12) {
            resultsContent
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    static func isSelected(_ preset: BraidPreset, selectedPresetID: BraidPresetID?) -> Bool {
        selectedPresetID == preset.id
    }

    @ViewBuilder
    private var resultsContent: some View {
        switch state {
        case .available:
            if presets.isEmpty {
                ContentUnavailableView {
                    Label(
                        ProjectEditorStrings.noCompatiblePresetTitle,
                        systemImage: "circle.grid.cross"
                    )
                } description: {
                    Text(ProjectEditorStrings.noCompatiblePresetMessage(standKind: standKind))
                }
            } else {
                ForEach(presets) { preset in
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            showDetail(preset)
                        } label: {
                            thumbnail(for: preset)
                                .frame(height: 112)
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "view.3d")
                                        .font(.body.weight(.semibold))
                                        .padding(8)
                                        .background(.regularMaterial, in: Circle())
                                        .padding(8)
                                }
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(thumbnailAccessibilityLabel(for: preset))
                        .accessibilityHint(ProjectEditorStrings.maruGenjiThumbnail3DHint)
                        .accessibilityIdentifier(
                            ProjectEditorAccessibilityIdentifiers.thumbnail3DButton(preset.id)
                        )

                        Button {
                            selectPreset(preset.id)
                        } label: {
                            BraidSelectionRow(
                                title: preset.displayName,
                                subtitle: ProjectEditorStrings.threadCountValue(threadCount),
                                isSelected: Self.isSelected(preset, selectedPresetID: selectedPresetID)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(
                            ProjectEditorAccessibilityIdentifiers.presetButton(preset.id)
                        )

                        Text(prototypeNotice(for: preset))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .braidChoiceCard(
                        isSelected: Self.isSelected(preset, selectedPresetID: selectedPresetID)
                    )
                }
            }
        case .calculating:
            ProgressView(ProjectEditorStrings.simulationCalculating)
                .frame(maxWidth: .infinity, minHeight: 140)
        case .failed:
            ContentUnavailableView {
                Label(ProjectEditorStrings.simulationFailedTitle, systemImage: "exclamationmark.triangle")
            } description: {
                Text(ProjectEditorStrings.simulationFailedMessage)
            }
        }
    }

    /// **The family decides which drawer makes the thumbnail**, not the braid's
    /// name.
    @ViewBuilder
    private func thumbnail(for preset: BraidPreset) -> some View {
        if let recipe = BraidMethodCatalog.recipe(for: preset.id) {
            BraidThumbnailForFamily(
                recipe: recipe,
                assignments: assignments,
                nothingDrawsIt: ProjectEditorStrings.nothingDrawsThisBraid
            )
        } else {
            BraidNothingDrawsItView(text: ProjectEditorStrings.nothingDrawsThisBraid)
        }
    }

    private func thumbnailAccessibilityLabel(for preset: BraidPreset) -> String {
        ProjectEditorStrings.thumbnail3DLabel(preset.displayName)
    }

    /// The preset carries its own notice, so this reads it rather than choosing it.
    private func prototypeNotice(for preset: BraidPreset) -> String {
        preset.prototypeNotice
    }
}

/// A choice's name, what it means, and whether it is the one chosen — **a check
/// as well as the border**, so being chosen is not told by colour alone.
struct BraidSelectionRow: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .imageScale(.large)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(
            isSelected
                ? ProjectEditorStrings.selectionSelected
                : ProjectEditorStrings.selectionNotSelected
        )
    }
}

extension View {
    /// The card a choice sits on. **The same for a braid and for no braid**, so
    /// being chosen looks the same on both: an accent border.
    func braidChoiceCard(isSelected: Bool) -> some View {
        padding()
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            }
    }
}
