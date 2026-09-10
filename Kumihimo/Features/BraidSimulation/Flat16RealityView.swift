import RealityKit
import SwiftUI
import UIKit

struct Flat16RealityView: UIViewRepresentable {
    let assignments: [ThreadAssignment]
    let controller: RoundTube16ViewerController
    let viewportSize: CGSize

    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        updateBackground(of: view)

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        ))
        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)

        context.coordinator.buildScene(in: view, assignments: assignments)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        updateBackground(of: uiView)
        context.coordinator.updateCoverage(for: viewportSize)
        let signature = BraidSurfaceScene.signature(assignments)
        guard signature != context.coordinator.assignmentSignature else { return }
        context.coordinator.buildScene(in: uiView, assignments: assignments)
    }

    private func updateBackground(of view: ARView) {
        let style: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let color = UIColor.secondarySystemBackground.resolvedColor(
            with: UITraitCollection(userInterfaceStyle: style)
        )
        view.environment.background = .color(color)
    }

    @MainActor
    final class Coordinator: NSObject {
        let controller: RoundTube16ViewerController
        var assignmentSignature = ""
        private var installed: BraidSurfaceScene.Installed?
        private var tileCount = 0

        init(controller: RoundTube16ViewerController) {
            self.controller = controller
        }

        func buildScene(in view: ARView, assignments: [ThreadAssignment]) {
            assignmentSignature = BraidSurfaceScene.signature(assignments)
            installed = nil
            tileCount = 0

            guard let installed = BraidSurfaceScene.install(
                in: view,
                family: Flat16SurfaceMesh.family,
                assignments: assignments
            ) else {
                controller.reportFailure()
                return
            }
            self.installed = installed
            updateCoverage(for: view.bounds.size)
            controller.connect(modelRoot: installed.modelRoot)
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            controller.rotate(horizontal: Float(gesture.translation(in: gesture.view).x) * 0.008)
            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            controller.zoom(by: Float(gesture.scale))
            gesture.scale = 1
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) { controller.reset() }

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
