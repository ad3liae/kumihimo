import SwiftUI

struct ThreadColorSelectionView: View {
    let position: Int
    let selectedColorID: ThreadColorID?
    let selectColor: (ThreadColorID) -> Void
    let cancel: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ThreadColorCatalog.colors) { threadColor in
                        Button {
                            selectColor(threadColor.id)
                        } label: {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(threadColor.swiftUIColor)
                                    .frame(width: 48, height: 48)
                                    .overlay {
                                        Circle().stroke(.primary.opacity(0.45), lineWidth: 1)
                                    }
                                Text(threadColor.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(threadColor.code)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "checkmark.circle.fill")
                                    .opacity(isSelected(threadColor) ? 1 : 0)
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 126)
                            .padding(8)
                            .background(Color.secondary.opacity(0.08), in: .rect(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isSelected(threadColor) ? Color.accentColor : .clear,
                                        lineWidth: 2
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(ProjectEditorStrings.threadColorAccessibilityLabel(threadColor))
                        .accessibilityAddTraits(
                            isSelected(threadColor) ? .isSelected : []
                        )
                    }
                }
                .padding()
            }
            .navigationTitle(ProjectEditorStrings.threadColorTitle(position: position))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ProjectEditorStrings.cancel, action: cancel)
                }
            }
        }
    }

    /// A thread saved with one of the former IDs is shown on the colour it is
    /// read as.
    private func isSelected(_ threadColor: ThreadColor) -> Bool {
        selectedColorID.map(ThreadColorCatalog.currentID(for:)) == threadColor.id
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 260 : 104), spacing: 12)]
    }
}
