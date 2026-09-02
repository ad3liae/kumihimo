import SwiftUI

struct MaruGenji3DPreviewView: View {
    let assignments: [ThreadAssignment]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = MaruGenjiViewerController()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ZStack {
                        MaruGenjiRealityView(
                            assignments: assignments,
                            controller: controller
                        )
                        if controller.didFailToRender {
                            ContentUnavailableView(
                                ProjectEditorStrings.simulationFailedTitle,
                                systemImage: "exclamationmark.triangle",
                                description: Text(ProjectEditorStrings.simulationFailedMessage)
                            )
                        }
                    }
                    .frame(height: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .accessibilityLabel(ProjectEditorStrings.maruGenji3DAccessibilityLabel)
                    .accessibilityHint(ProjectEditorStrings.maruGenji3DAccessibilityHint)
                    .accessibilityValue(
                        controller.didRender
                            ? ProjectEditorStrings.maruGenji3DRenderComplete
                            : ProjectEditorStrings.maruGenji3DRenderPending
                    )
                    .accessibilityIdentifier("maru-genji-3d-surface")

                    HStack(spacing: 12) {
                        controlButton(
                            ProjectEditorStrings.rotateLeft,
                            systemImage: "rotate.left"
                        ) {
                            controller.rotate(horizontal: -.pi / 8)
                        }
                        controlButton(
                            ProjectEditorStrings.resetView,
                            systemImage: "arrow.counterclockwise"
                        ) {
                            controller.reset()
                        }
                        controlButton(
                            ProjectEditorStrings.rotateRight,
                            systemImage: "rotate.right"
                        ) {
                            controller.rotate(horizontal: .pi / 8)
                        }
                    }

                    VStack(spacing: 4) {
                        Text(ProjectEditorStrings.maruGenjiPrototypeNotice)
                            .font(.footnote.weight(.semibold))
                        Text(ProjectEditorStrings.maruGenjiGestureHelp)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle(ProjectEditorStrings.maruGenjiPreviewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(ProjectEditorStrings.dismiss) { dismiss() }
                }
            }
        }
    }

    private func controlButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(title)
    }
}
