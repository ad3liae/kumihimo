import RealityKit
import SwiftUI
import UIKit

/// The braid standing still in a list card: the same scene the preview turns,
/// seen from a fixed place, with nothing to take hold of.
///
/// **A live view, not a picture of one.** A still would have been cheaper, but an
/// `ARView` that is not in a window never runs its render loop, so the snapshot it
/// is asked for never arrives — measured in Task 028-1b, step 1. The card
/// therefore holds the view itself. Nothing is cached, because there is nothing to
/// cache: when the colours change the scene is rebuilt, by the same path the
/// preview rebuilds on.
struct BraidCardRealityView: UIViewRepresentable {
    /// How many repeats of the braid have to cross the card. **The camera
    /// distance follows from this and the card's size**; see
    /// `BraidSurfaceScene.Framing.crossing`.
    static let repeatsAcrossTheCard = 3

    let family: BraidFamily
    let assignments: [ThreadAssignment]
    /// The card's own frame, which is what the camera distance is worked out from.
    let size: CGSize

    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(
            frame: CGRect(origin: .zero, size: size),
            cameraMode: .nonAR,
            automaticallyConfigureSession: false
        )
        updateBackground(of: view)
        context.coordinator.buildScene(
            in: view, family: family, assignments: assignments, size: size
        )
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        updateBackground(of: uiView)
        let signature = BraidSurfaceScene.signature(assignments)
        if signature == context.coordinator.assignmentSignature,
           size == context.coordinator.size {
            context.coordinator.updateCoverage(for: size)
            return
        }
        context.coordinator.buildScene(
            in: uiView, family: family, assignments: assignments, size: size
        )
    }

    private func updateBackground(of view: ARView) {
        let style: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let color = UIColor.secondarySystemBackground.resolvedColor(
            with: UITraitCollection(userInterfaceStyle: style)
        )
        view.environment.background = .color(color)
    }

    @MainActor
    final class Coordinator {
        var assignmentSignature = ""
        var size = CGSize.zero
        private var installed: BraidSurfaceScene.Installed?
        private var tileCount = 0

        func buildScene(
            in view: ARView,
            family: BraidFamily,
            assignments: [ThreadAssignment],
            size: CGSize
        ) {
            assignmentSignature = BraidSurfaceScene.signature(assignments)
            self.size = size
            installed = nil
            tileCount = 0

            guard size.width > 0, size.height > 0 else { return }
            guard let installed = BraidSurfaceScene.install(
                in: view,
                family: family,
                assignments: assignments,
                framing: .crossing(
                    repeats: BraidCardRealityView.repeatsAcrossTheCard,
                    in: size
                )
            ) else { return }
            self.installed = installed
            updateCoverage(for: size)
        }

        func updateCoverage(for viewportSize: CGSize) {
            guard let installed else { return }
            guard let newCount = BraidSurfaceScene.retile(
                installed,
                viewportSize: viewportSize,
                tileCount: tileCount
            ) else { return }
            tileCount = newCount
        }
    }
}
