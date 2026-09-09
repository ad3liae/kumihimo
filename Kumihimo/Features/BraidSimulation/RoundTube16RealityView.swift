import RealityKit
import SwiftUI
import UIKit

@MainActor
final class RoundTube16ViewerController: ObservableObject {
    static let minimumScale: Float = 0.65
    static let maximumScale: Float = 1.8

    @Published private(set) var didFailToRender = false
    @Published private(set) var didRender = false

    private weak var modelRoot: Entity?
    private(set) var roll: Float = 0
    private(set) var scale: Float = 1

    func connect(modelRoot: Entity) {
        self.modelRoot = modelRoot
        applyTransform()
        publishRenderState(didRender: true, didFail: false)
    }

    func reportFailure() {
        modelRoot = nil
        publishRenderState(didRender: false, didFail: true)
    }

    func rotate(horizontal: Float) {
        roll += horizontal
        applyTransform()
    }

    func zoom(by factor: Float) {
        scale = min(max(scale * factor, Self.minimumScale), Self.maximumScale)
        applyTransform()
    }

    func reset() {
        roll = 0
        scale = 1
        applyTransform()
    }

    private func applyTransform() {
        guard let modelRoot else { return }
        let rollRotation = simd_quatf(angle: roll, axis: SIMD3<Float>(1, 0, 0))
        modelRoot.orientation = rollRotation
        modelRoot.scale = SIMD3<Float>(repeating: scale)
    }

    private func publishRenderState(didRender: Bool, didFail: Bool) {
        guard self.didRender != didRender || didFailToRender != didFail else { return }
        Task { @MainActor [weak self] in
            self?.didRender = didRender
            self?.didFailToRender = didFail
        }
    }
}

struct RoundTube16RealityView: UIViewRepresentable {
    let assignments: [ThreadAssignment]
    let controller: RoundTube16ViewerController
    let viewportSize: CGSize

    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(
            frame: .zero,
            cameraMode: .nonAR,
            automaticallyConfigureSession: false
        )
        updateBackground(of: view)

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        view.addGestureRecognizer(pinch)

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
        let interfaceStyle: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let traits = UITraitCollection(userInterfaceStyle: interfaceStyle)
        let color = UIColor.secondarySystemBackground.resolvedColor(with: traits)
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
                family: RoundTube16SurfaceMesh.family,
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
            let translation = gesture.translation(in: gesture.view)
            controller.rotate(horizontal: Float(translation.x) * 0.008)
            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            controller.zoom(by: Float(gesture.scale))
            gesture.scale = 1
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            controller.reset()
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
