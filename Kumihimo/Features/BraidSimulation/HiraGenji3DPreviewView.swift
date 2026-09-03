import SwiftUI

struct HiraGenji3DPreviewView: View {
    let assignments: [ThreadAssignment]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller: MaruGenjiViewerController
    private let isEmbedded: Bool
    private let closeAction: (() -> Void)?

    init(
        assignments: [ThreadAssignment],
        controller: MaruGenjiViewerController,
        isEmbedded: Bool,
        closeAction: (() -> Void)? = nil
    ) {
        self.assignments = assignments
        _controller = StateObject(wrappedValue: controller)
        self.isEmbedded = isEmbedded
        self.closeAction = closeAction
    }

    var body: some View {
        if isEmbedded {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(ProjectEditorStrings.hiraGenjiPreviewTitle)
                        .font(.title3.bold())
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button(ProjectEditorStrings.backToResults) { closeAction?() }
                        .buttonStyle(.bordered)
                }
                GeometryReader { geometry in
                    previewContent(canvasHeight: max(300, geometry.size.height - 145))
                }
            }
        } else {
            NavigationStack {
                GeometryReader { geometry in
                    ScrollView {
                        previewContent(canvasHeight: min(max(geometry.size.height * 0.58, 300), 560))
                    }
                }
                .navigationTitle(ProjectEditorStrings.hiraGenjiPreviewTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(ProjectEditorStrings.dismiss) { closeAction?() ?? dismiss() }
                    }
                }
            }
        }
    }

    private func previewContent(canvasHeight: CGFloat) -> some View {
        VStack(spacing: 16) {
            GeometryReader { geometry in
                ZStack {
                    HiraGenjiRealityView(
                        assignments: assignments,
                        controller: controller,
                        viewportSize: geometry.size
                    )
                    if controller.didFailToRender {
                        ContentUnavailableView(
                            ProjectEditorStrings.simulationFailedTitle,
                            systemImage: "exclamationmark.triangle",
                            description: Text(ProjectEditorStrings.simulationFailedMessage)
                        )
                    }
                }
            }
            .frame(height: canvasHeight)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .accessibilityLabel(ProjectEditorStrings.hiraGenji3DAccessibilityLabel)
            .accessibilityHint(ProjectEditorStrings.hiraGenji3DAccessibilityHint)
            .accessibilityValue(
                controller.didRender
                    ? ProjectEditorStrings.maruGenji3DRenderComplete
                    : ProjectEditorStrings.maruGenji3DRenderPending
            )
            .accessibilityIdentifier("hira-genji-3d-surface")

            HStack(spacing: 12) {
                controlButton(ProjectEditorStrings.rotateLeft, systemImage: "rotate.left") {
                    controller.rotate(horizontal: -.pi / 8)
                }
                controlButton(ProjectEditorStrings.resetView, systemImage: "arrow.counterclockwise") {
                    controller.reset()
                }
                controlButton(ProjectEditorStrings.rotateRight, systemImage: "rotate.right") {
                    controller.rotate(horizontal: .pi / 8)
                }
            }

            VStack(spacing: 4) {
                Text(ProjectEditorStrings.hiraGenjiPrototypeNotice)
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

    private func controlButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(title)
    }
}
