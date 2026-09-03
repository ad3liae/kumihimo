import SwiftUI

struct MaruGenji3DPreviewView: View {
    let assignments: [ThreadAssignment]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller: MaruGenjiViewerController
    private let isEmbedded: Bool
    private let closeAction: (() -> Void)?

    init(assignments: [ThreadAssignment]) {
        self.assignments = assignments
        _controller = StateObject(wrappedValue: MaruGenjiViewerController())
        isEmbedded = false
        closeAction = nil
    }

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
            embeddedPreview
        } else {
            standalonePreview
        }
    }

    private var standalonePreview: some View {
        NavigationStack {
            GeometryReader { geometry in
                previewContent(
                    canvasHeight: min(max(geometry.size.height * 0.58, 300), 560)
                )
            }
            .navigationTitle(ProjectEditorStrings.maruGenjiPreviewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(ProjectEditorStrings.dismiss) {
                        closeAction?() ?? dismiss()
                    }
                }
            }
        }
    }

    private var embeddedPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(ProjectEditorStrings.maruGenjiPreviewTitle)
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(ProjectEditorStrings.backToResults) {
                    closeAction?()
                }
                .buttonStyle(.bordered)
            }

            GeometryReader { geometry in
                previewContent(
                    canvasHeight: max(300, geometry.size.height - 145),
                    allowsScrolling: false
                )
            }
        }
    }

    private func previewContent(
        canvasHeight: CGFloat,
        allowsScrolling: Bool = true
    ) -> some View {
        let content = VStack(spacing: 16) {
            GeometryReader { geometry in
                ZStack {
                    MaruGenjiRealityView(
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

        return Group {
            if allowsScrolling {
                ScrollView { content }
            } else {
                content
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
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(title)
    }
}
