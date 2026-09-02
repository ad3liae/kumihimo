import RealityKit
import SwiftUI
import UIKit
import os

@MainActor
final class MaruGenjiViewerController: ObservableObject {
    @Published private(set) var didFailToRender = false
    @Published private(set) var didRender = false

    private weak var modelRoot: Entity?
    private var roll: Float = 0
    private var pitch: Float = -0.12
    private var scale: Float = 1

    func connect(modelRoot: Entity) {
        self.modelRoot = modelRoot
        applyTransform()
        publishRenderState(didRender: true, didFail: false)
    }

    func reportFailure() {
        modelRoot = nil
        publishRenderState(didRender: false, didFail: true)
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

    private func publishRenderState(didRender: Bool, didFail: Bool) {
        guard self.didRender != didRender || didFailToRender != didFail else { return }
        Task { @MainActor [weak self] in
            self?.didRender = didRender
            self?.didFailToRender = didFail
        }
    }
}

struct MaruGenjiRealityView: UIViewRepresentable {
    let assignments: [ThreadAssignment]
    let controller: MaruGenjiViewerController

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
        let signature = assignments
            .sorted { $0.position < $1.position }
            .map { "\($0.position):\($0.colorID.rawValue)" }
            .joined(separator: "|")
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
        private static let logger = Logger(
            subsystem: "com.example.Kumihimo",
            category: "MaruGenjiRealityView"
        )

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

            guard let pattern = MaruGenjiSurfacePatternGenerator.generate(assignments: assignments) else {
                let positions = assignments.map(\.position).map(String.init).joined(separator: ",")
                Self.logger.error(
                    "Surface pattern generation failed for \(assignments.count) assignments at \(positions, privacy: .public)"
                )
                controller.reportFailure()
                return
            }
            guard let surface = MaruGenjiSurfaceMeshGenerator.generate(pattern: pattern) else {
                Self.logger.error("Surface mesh data generation failed")
                controller.reportFailure()
                return
            }

            do {
                let anchor = AnchorEntity(world: .zero)
                let root = Entity()
                let colorIDs = Set(surface.colorGroups.keys)
                    .union(surface.boundaryColorGroups.keys)
                    .sorted { $0.rawValue < $1.rawValue }
                guard
                    !colorIDs.isEmpty,
                    colorIDs.allSatisfy({ ThreadColorCatalog.color(for: $0) != nil })
                else {
                    Self.logger.error("Surface contains an empty or unknown color group")
                    controller.reportFailure()
                    return
                }

                var combinedIndices = [UInt32]()
                var faceMaterialIndices = [UInt32]()
                var materials = [PhysicallyBasedMaterial]()
                for colorID in colorIDs {
                    guard let threadColor = ThreadColorCatalog.color(for: colorID) else {
                        throw SurfaceRenderError.unknownColor
                    }
                    if let indices = surface.colorGroups[colorID], !indices.isEmpty {
                        combinedIndices.append(contentsOf: indices)
                        faceMaterialIndices.append(
                            contentsOf: repeatElement(
                                UInt32(materials.count),
                                count: indices.count / 3
                            )
                        )
                        materials.append(material(color: threadColor.uiColor, roughness: 0.84))
                    }
                    if let indices = surface.boundaryColorGroups[colorID], !indices.isEmpty {
                        combinedIndices.append(contentsOf: indices)
                        faceMaterialIndices.append(
                            contentsOf: repeatElement(
                                UInt32(materials.count),
                                count: indices.count / 3
                            )
                        )
                        materials.append(material(color: threadColor.boundaryUIColor, roughness: 0.92))
                    }
                }
                guard
                    !combinedIndices.isEmpty,
                    combinedIndices.count / 3 == faceMaterialIndices.count,
                    !materials.isEmpty
                else {
                    throw SurfaceRenderError.emptySurface
                }
                let mesh = try MeshResource.generate(from: [
                    descriptor(
                        indices: combinedIndices,
                        faceMaterialIndices: faceMaterialIndices,
                        surface: surface
                    ),
                ])
                root.addChild(ModelEntity(mesh: mesh, materials: materials))

                anchor.addChild(root)

                let camera = PerspectiveCamera()
                camera.look(
                    at: .zero,
                    from: SIMD3<Float>(0, 0.15, 4.4),
                    relativeTo: nil
                )
                anchor.addChild(camera)

                let keyLight = DirectionalLight()
                keyLight.light.intensity = 3_500
                keyLight.look(
                    at: .zero,
                    from: SIMD3<Float>(0.5, 2.2, 3),
                    relativeTo: nil
                )
                anchor.addChild(keyLight)

                let fillLight = DirectionalLight()
                fillLight.light.intensity = 1_200
                fillLight.look(
                    at: .zero,
                    from: SIMD3<Float>(-1.5, -1, 2),
                    relativeTo: nil
                )
                anchor.addChild(fillLight)

                let rimLight = DirectionalLight()
                rimLight.light.intensity = 700
                rimLight.look(
                    at: .zero,
                    from: SIMD3<Float>(0.2, 1, -3),
                    relativeTo: nil
                )
                anchor.addChild(rimLight)

                view.scene.addAnchor(anchor)
                controller.connect(modelRoot: root)
            } catch {
                Self.logger.error("RealityKit surface generation failed: \(String(describing: error), privacy: .public)")
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

        private func descriptor(
            indices: [UInt32],
            faceMaterialIndices: [UInt32],
            surface: MaruGenjiSurfaceMeshData
        ) -> MeshDescriptor {
            var descriptor = MeshDescriptor(name: "maru-genji-surface")
            descriptor.positions = MeshBuffer(surface.positions)
            descriptor.normals = MeshBuffer(surface.normals)
            descriptor.textureCoordinates = MeshBuffer(surface.textureCoordinates)
            descriptor.primitives = .triangles(indices)
            descriptor.materials = .perFace(faceMaterialIndices)
            return descriptor
        }

        private func material(
            color: UIColor,
            roughness: Float
        ) -> PhysicallyBasedMaterial {
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(tint: color)
            material.metallic = .init(floatLiteral: 0)
            material.roughness = .init(floatLiteral: roughness)
            return material
        }

        private enum SurfaceRenderError: Error {
            case unknownColor
            case emptySurface
        }
    }
}
