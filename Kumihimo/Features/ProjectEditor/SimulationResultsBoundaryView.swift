import SwiftUI

struct SimulationResultsBoundaryView: View {
    let state: ProjectEditorStore.SimulationResultsState
    let threadCount: Int
    let assignments: [ThreadAssignment]
    let presets: [BraidPreset]
    let selectedPresetID: BraidPresetID?
    let selectPreset: (BraidPresetID?) -> Void
    let show3DPreview: (BraidPreset) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button {
                selectPreset(nil)
            } label: {
                selectionRow(
                    title: ProjectEditorStrings.undecidedBraid,
                    isSelected: selectedPresetID == nil
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(
                ProjectEditorAccessibilityIdentifiers.undecidedPresetButton
            )

            resultsContent
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
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
                    Text(ProjectEditorStrings.noCompatiblePresetMessage)
                }
            } else {
                ForEach(presets) { preset in
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            show3DPreview(preset)
                        } label: {
                            MaruGenjiThumbnailView(assignments: assignments)
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
                        .accessibilityLabel(ProjectEditorStrings.maruGenjiThumbnail3DLabel)
                        .accessibilityHint(ProjectEditorStrings.maruGenjiThumbnail3DHint)
                        .accessibilityIdentifier(
                            ProjectEditorAccessibilityIdentifiers.thumbnail3DButton(preset.id)
                        )

                        Button {
                            selectPreset(preset.id)
                        } label: {
                            selectionRow(
                                title: preset.displayName,
                                subtitle: ProjectEditorStrings.threadCountValue(threadCount),
                                isSelected: selectedPresetID == preset.id
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(
                            ProjectEditorAccessibilityIdentifiers.presetButton(preset.id)
                        )

                        Text(ProjectEditorStrings.maruGenjiPrototypeNotice)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                selectedPresetID == preset.id ? Color.accentColor : .clear,
                                lineWidth: 2
                            )
                    }
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

    private func selectionRow(
        title: String,
        subtitle: String? = nil,
        isSelected: Bool
    ) -> some View {
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
