import SwiftUI

/// A braid that is a tube, shown solid. **One copy, whichever tube** — the
/// wording and the family are handed in, so a second round braid is a call and
/// not a second view. The name still says sixteen; renaming it is a tidy of its
/// own.
struct RoundTube16PreviewView: View {
    /// What this braid is called on screen and what it says about itself.
    struct Wording {
        let title: String
        let notice: String
        let accessibilityLabel: String
        let accessibilityIdentifier: String

        static let maruGenji = Wording(
            title: ProjectEditorStrings.maruGenjiPreviewTitle,
            notice: ProjectEditorStrings.maruGenjiPrototypeNotice,
            accessibilityLabel: ProjectEditorStrings.maruGenji3DAccessibilityLabel,
            accessibilityIdentifier: "maru-genji-3d-surface"
        )
    }

    let assignments: [ThreadAssignment]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller: RoundTube16ViewerController
    private let isEmbedded: Bool
    private let closeAction: (() -> Void)?
    private let family: BraidFamily
    private let table: BraidSurfaceScene.Table?
    private let wording: Wording

    init(assignments: [ThreadAssignment]) {
        self.assignments = assignments
        _controller = StateObject(wrappedValue: RoundTube16ViewerController())
        isEmbedded = false
        closeAction = nil
        family = RoundTube16SurfaceMesh.family
        table = nil
        wording = .maruGenji
    }

    init(
        assignments: [ThreadAssignment],
        controller: RoundTube16ViewerController,
        isEmbedded: Bool,
        closeAction: (() -> Void)? = nil,
        family: BraidFamily = RoundTube16SurfaceMesh.family,
        table: BraidSurfaceScene.Table? = nil,
        wording: Wording = .maruGenji
    ) {
        self.assignments = assignments
        _controller = StateObject(wrappedValue: controller)
        self.isEmbedded = isEmbedded
        self.closeAction = closeAction
        self.family = family
        self.table = table
        self.wording = wording
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
            .navigationTitle(wording.title)
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
                Text(wording.title)
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
                    RoundTube16RealityView(
                        assignments: assignments,
                        controller: controller,
                        viewportSize: geometry.size,
                        family: family,
                        table: table
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
            .accessibilityLabel(wording.accessibilityLabel)
            .accessibilityHint(ProjectEditorStrings.maruGenji3DAccessibilityHint)
            .accessibilityValue(
                controller.didRender
                    ? ProjectEditorStrings.maruGenji3DRenderComplete
                    : ProjectEditorStrings.maruGenji3DRenderPending
            )
            .accessibilityIdentifier(wording.accessibilityIdentifier)

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
                Text(wording.notice)
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
