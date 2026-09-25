import SwiftUI

extension View {
    /// **What turns the solid when a drag is not to hand**: VoiceOver's custom
    /// actions on the canvas, 「左へ回転」「右へ回転」「正面に戻す」, doing what
    /// the buttons under it did. The author took the buttons away (Task 060);
    /// the drag, the pinch and the double tap are unchanged.
    ///
    /// **Applied in reverse.** SwiftUI hands VoiceOver the action applied last
    /// first (read off the tree on iOS 18.5; an `accessibilityActions` list
    /// comes out reversed the same way), so 「正面に戻す」 goes on first to be
    /// read last. One copy for both drawers, the tube and the flat braid.
    func braidViewerAccessibilityActions(
        _ controller: RoundTube16ViewerController
    ) -> some View {
        accessibilityAction(named: ProjectEditorStrings.resetView) {
            controller.reset()
        }
        .accessibilityAction(named: ProjectEditorStrings.rotateRight) {
            controller.rotate(horizontal: .pi / 8)
        }
        .accessibilityAction(named: ProjectEditorStrings.rotateLeft) {
            controller.rotate(horizontal: -.pi / 8)
        }
    }
}
