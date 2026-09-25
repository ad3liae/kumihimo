import SwiftUI

struct Flat16PreviewView: View {
    let assignments: [ThreadAssignment]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller: RoundTube16ViewerController
    private let isEmbedded: Bool
    private let closeAction: (() -> Void)?

    init(
        assignments: [ThreadAssignment],
        controller: RoundTube16ViewerController,
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
            // Only the braid: the detail sheet brings the title, the way out and
            // the notes (Task 058), and there are no buttons under it (Task 060).
            previewContent(canvasHeight: nil, showsNotes: false)
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

    /// `canvasHeight` `nil`: the canvas fills what the rest leaves.
    private func previewContent(canvasHeight: CGFloat?, showsNotes: Bool = true) -> some View {
        VStack(spacing: 16) {
            GeometryReader { geometry in
                ZStack {
                    Flat16RealityView(
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
            .frame(
                minHeight: canvasHeight == nil ? RoundTube16PreviewView.minimumCanvasHeight : nil
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .accessibilityLabel(ProjectEditorStrings.hiraGenji3DAccessibilityLabel)
            .accessibilityHint(ProjectEditorStrings.hiraGenji3DAccessibilityHint)
            .accessibilityValue(
                controller.didRender
                    ? ProjectEditorStrings.maruGenji3DRenderComplete
                    : ProjectEditorStrings.maruGenji3DRenderPending
            )
            .accessibilityIdentifier("hira-genji-3d-surface")
            .braidViewerAccessibilityActions(controller)

            if showsNotes {
                VStack(spacing: 4) {
                    Text(ProjectEditorStrings.hiraGenjiPrototypeNotice)
                        .font(.footnote.weight(.semibold))
                    Text(ProjectEditorStrings.maruGenjiGestureHelp)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
}
