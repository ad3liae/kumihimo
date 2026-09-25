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

    /// **Only the braid.** Whatever holds it — the detail sheet — brings the
    /// title, the way out and the notes, so there is one navigation bar and not
    /// two, and the notes can scroll where nothing turns the braid (Task 058).
    /// There are no buttons under it (Task 060), so the canvas takes the whole
    /// of the part it is given.
    private var embeddedPreview: some View {
        previewContent(canvasHeight: nil, allowsScrolling: false, showsNotes: false)
    }

    /// `canvasHeight` `nil`: the canvas fills what the rest leaves, down to
    /// `minimumCanvasHeight`.
    private func previewContent(
        canvasHeight: CGFloat?,
        allowsScrolling: Bool = true,
        showsNotes: Bool = true
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
            .frame(minHeight: canvasHeight == nil ? Self.minimumCanvasHeight : nil)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .accessibilityLabel(wording.accessibilityLabel)
            .accessibilityHint(ProjectEditorStrings.maruGenji3DAccessibilityHint)
            .accessibilityValue(
                controller.didRender
                    ? ProjectEditorStrings.maruGenji3DRenderComplete
                    : ProjectEditorStrings.maruGenji3DRenderPending
            )
            .accessibilityIdentifier(wording.accessibilityIdentifier)
            .braidViewerAccessibilityActions(controller)

            if showsNotes {
                VStack(spacing: 4) {
                    Text(wording.notice)
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

        return Group {
            if allowsScrolling {
                ScrollView { content }
            } else {
                content
            }
        }
    }

    static let minimumCanvasHeight: CGFloat = 160
}
