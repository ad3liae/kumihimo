import RealityKit
import SwiftUI
import UIKit

@MainActor
final class MaruGenjiViewerController: ObservableObject {
    @Published private(set) var didFailToRender = false

    private weak var modelRoot: Entity?
    private var roll: Float = 0
    private var pitch: Float = -0.12
    private var scale: Float = 1

    func connect(modelRoot: Entity) {
        self.modelRoot = modelRoot
        applyTransform()
        publishRenderFailure(false)
    }

    func reportFailure() {
        modelRoot = nil
        publishRenderFailure(true)
    }

    func rotate(horizontal: Float, vertical: Float = 0) {
        roll += horizontal
        pitch = min(max(pitch + vertical, -0.85), 0.85)
        applyTransform()
    }

    func zoom(by factor: Float) {
        scale = min(max(scale * factor, 0.65), 1.8)
        applyTransform()
    }

    func reset() {
        roll = 0
        pitch = -0.12
        scale = 1
        applyTransform()
    }

    private func applyTransform() {
        guard let modelRoot else { return }
        let rollRotation = simd_quatf(angle: roll, axis: SIMD3<Float>(1, 0, 0))
        let pitchRotation = simd_quatf(angle: pitch, axis: SIMD3<Float>(0, 1, 0))
        modelRoot.orientation = pitchRotation * rollRotation
        modelRoot.scale = SIMD3<Float>(repeating: scale)
    }

    private func publishRenderFailure(_ failed: Bool) {
        guard didFailToRender != failed else { return }
        Task { @MainActor [weak self] in
            self?.didFailToRender = failed
        }
    }
}

struct MaruGenjiRealityView: UIViewRepresentable {
    let assignments: [ThreadAssignment]
    let controller: MaruGenjiViewerController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(
            frame: .zero,
            cameraMode: .nonAR,
            automaticallyConfigureSession: false
        )
        view.environment.background = .color(.secondarySystemBackground)

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
        let signature = assignments
            .sorted { $0.position < $1.position }
            .map { "\($0.position):\($0.colorID.rawValue)" }
            .joined(separator: "|")
        guard signature != context.coordinator.assignmentSignature else { return }
        context.coordinator.buildScene(in: uiView, assignments: assignments)
    }

    @MainActor
    final class Coordinator: NSObject {
        let controller: MaruGenjiViewerController
        var assignmentSignature = ""

        init(controller: MaruGenjiViewerController) {
            self.controller = controller
        }

        func buildScene(in view: ARView, assignments: [ThreadAssignment]) {
            assignmentSignature = assignments
                .sorted { $0.position < $1.position }
                .map { "\($0.position):\($0.colorID.rawValue)" }
                .joined(separator: "|")
            view.scene.anchors.removeAll()

            let strands = MaruGenjiPathGenerator.generate(assignments: assignments)
            guard strands.count == MaruGenjiSimulation.requiredThreadCount else {
                controller.reportFailure()
                return
            }

            do {
                let anchor = AnchorEntity(world: .zero)
                let root = Entity()

                for strand in strands {
                    guard let tube = MaruGenjiTubeMeshGenerator.generate(points: strand.points) else {
                        continue
                    }
                    var descriptor = MeshDescriptor(name: "thread-\(strand.threadPosition)")
                    descriptor.positions = MeshBuffer(tube.positions)
                    descriptor.normals = MeshBuffer(tube.normals)
                    descriptor.primitives = .triangles(tube.triangleIndices)
                    descriptor.materials = .allFaces(0)

                    let mesh = try MeshResource.generate(from: [descriptor])
                    let threadColor = ThreadColorCatalog.color(for: strand.colorID)
                        ?? ThreadColorCatalog.defaultColor
                    let color = UIColor(
                        red: threadColor.value.red,
                        green: threadColor.value.green,
                        blue: threadColor.value.blue,
                        alpha: 1
                    )
                    let material = SimpleMaterial(
                        color: color,
                        roughness: 0.72,
                        isMetallic: false
                    )
                    root.addChild(ModelEntity(mesh: mesh, materials: [material]))
                }

                guard root.children.count == MaruGenjiSimulation.requiredThreadCount else {
                    controller.reportFailure()
                    return
                }

                anchor.addChild(root)

                let camera = PerspectiveCamera()
                camera.look(
                    at: .zero,
                    from: SIMD3<Float>(0, 0.15, 4.4),
                    relativeTo: nil
                )
                anchor.addChild(camera)

                let keyLight = DirectionalLight()
                keyLight.light.intensity = 18_000
                keyLight.look(
                    at: .zero,
                    from: SIMD3<Float>(0.5, 2.2, 3),
                    relativeTo: nil
                )
                anchor.addChild(keyLight)

                let fillLight = DirectionalLight()
                fillLight.light.intensity = 7_000
                fillLight.look(
                    at: .zero,
                    from: SIMD3<Float>(-1.5, -1, 2),
                    relativeTo: nil
                )
                anchor.addChild(fillLight)

                view.scene.addAnchor(anchor)
                controller.connect(modelRoot: root)
            } catch {
                controller.reportFailure()
            }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            controller.rotate(
                horizontal: Float(translation.x) * 0.008,
                vertical: Float(translation.y) * 0.004
            )
            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            controller.zoom(by: Float(gesture.scale))
            gesture.scale = 1
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            controller.reset()
        }
    }
}
