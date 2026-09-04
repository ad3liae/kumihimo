import RealityKit
import SwiftUI
import UIKit
import os

@MainActor
final class MaruGenjiViewerController: ObservableObject {
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

struct MaruGenjiRealityView: UIViewRepresentable {
    static let cameraDistance: Float = 4.4
    static let verticalFieldOfView: Float = .pi / 3
    /// Neutral three-point lighting, exposed low enough that a strand crest keeps
    /// the catalogue colour instead of washing out to a pale tint.
    static let keyLightIntensity: Float = 1_500
    static let fillLightIntensity: Float = 520
    static let rimLightIntensity: Float = 380

    let assignments: [ThreadAssignment]
    let controller: MaruGenjiViewerController
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
        private var tileRoot: Entity?
        private var sharedMesh: MeshResource?
        private var sharedMaterials = [PhysicallyBasedMaterial]()
        private var tileCount = 0

        init(controller: MaruGenjiViewerController) {
            self.controller = controller
        }

        func buildScene(in view: ARView, assignments: [ThreadAssignment]) {
            assignmentSignature = assignments
                .sorted { $0.position < $1.position }
                .map { "\($0.position):\($0.colorID.rawValue)" }
                .joined(separator: "|")
            view.scene.anchors.removeAll()
            tileRoot = nil
            sharedMesh = nil
            sharedMaterials = []
            tileCount = 0

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
                let colorIDs = surface.colorGroups.keys.sorted { $0.rawValue < $1.rawValue }
                guard
                    !colorIDs.isEmpty,
                    colorIDs.allSatisfy({ ThreadColorCatalog.color(for: $0) != nil })
                else {
                    Self.logger.error("Surface contains an empty or unknown color group")
                    controller.reportFailure()
                    return
                }

                let detail = MaruGenjiStrandDetailTextures.shared
                var combinedIndices = [UInt32]()
                var faceMaterialIndices = [UInt32]()
                var materials = [PhysicallyBasedMaterial]()
                for colorID in colorIDs {
                    guard let threadColor = ThreadColorCatalog.color(for: colorID) else {
                        throw SurfaceRenderError.unknownColor
                    }
                    guard let indices = surface.colorGroups[colorID], !indices.isEmpty else {
                        continue
                    }
                    combinedIndices.append(contentsOf: indices)
                    faceMaterialIndices.append(
                        contentsOf: repeatElement(
                            UInt32(materials.count),
                            count: indices.count / 3
                        )
                    )
                    materials.append(material(color: threadColor.uiColor, detail: detail))
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
                let instances = Entity()
                root.addChild(instances)
                tileRoot = instances
                sharedMesh = mesh
                sharedMaterials = materials

                anchor.addChild(root)

                let camera = PerspectiveCamera()
                camera.look(
                    at: .zero,
                    from: SIMD3<Float>(0, 0, MaruGenjiRealityView.cameraDistance),
                    relativeTo: nil
                )
                camera.camera.fieldOfViewInDegrees = MaruGenjiRealityView.verticalFieldOfView
                    * 180 / .pi
                anchor.addChild(camera)

                let keyLight = DirectionalLight()
                keyLight.light.intensity = MaruGenjiRealityView.keyLightIntensity
                keyLight.look(
                    at: .zero,
                    from: SIMD3<Float>(0.5, 2.2, 3),
                    relativeTo: nil
                )
                anchor.addChild(keyLight)

                let fillLight = DirectionalLight()
                fillLight.light.intensity = MaruGenjiRealityView.fillLightIntensity
                fillLight.look(
                    at: .zero,
                    from: SIMD3<Float>(-1.5, -1, 2),
                    relativeTo: nil
                )
                anchor.addChild(fillLight)

                let rimLight = DirectionalLight()
                rimLight.light.intensity = MaruGenjiRealityView.rimLightIntensity
                rimLight.look(
                    at: .zero,
                    from: SIMD3<Float>(0.2, 1, -3),
                    relativeTo: nil
                )
                anchor.addChild(rimLight)

                view.scene.addAnchor(anchor)
                updateCoverage(for: view.bounds.size)
                controller.connect(modelRoot: root)
            } catch {
                Self.logger.error("RealityKit surface generation failed: \(String(describing: error), privacy: .public)")
                controller.reportFailure()
            }
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
            guard
                let tileRoot,
                let sharedMesh,
                viewportSize.width > 0,
                viewportSize.height > 0,
                let coverage = MaruGenjiViewportCoverageCalculator.calculate(
                    viewportSize: SIMD2<Float>(
                        Float(viewportSize.width),
                        Float(viewportSize.height)
                    ),
                    cameraDistance: MaruGenjiRealityView.cameraDistance,
                    verticalFieldOfView: MaruGenjiRealityView.verticalFieldOfView,
                    minimumScale: MaruGenjiViewerController.minimumScale,
                    tileLength: MaruGenjiSurfaceMeshGenerator.defaultLength
                ),
                coverage.tileCount != tileCount,
                let offsets = MaruGenjiViewportCoverageCalculator.tileOffsets(
                    tileCount: coverage.tileCount,
                    tileLength: MaruGenjiSurfaceMeshGenerator.defaultLength
                )
            else {
                return
            }

            tileRoot.children.removeAll()
            for offset in offsets {
                let entity = ModelEntity(mesh: sharedMesh, materials: sharedMaterials)
                entity.position.x = offset
                tileRoot.addChild(entity)
            }
            tileCount = coverage.tileCount
        }

        private func descriptor(
            indices: [UInt32],
            faceMaterialIndices: [UInt32],
            surface: MaruGenjiSurfaceMeshData
        ) -> MeshDescriptor {
            var descriptor = MeshDescriptor(name: "maru-genji-surface")
            descriptor.positions = MeshBuffer(surface.positions)
            descriptor.normals = MeshBuffer(surface.normals)
            descriptor.tangents = MeshBuffer(surface.tangents)
            descriptor.bitangents = MeshBuffer(surface.bitangents)
            descriptor.textureCoordinates = MeshBuffer(surface.textureCoordinates)
            descriptor.primitives = .triangles(indices)
            descriptor.materials = .perFace(faceMaterialIndices)
            return descriptor
        }

        /// One material per thread colour. The valley shading and the twist come
        /// from maps shared by every colour, so the catalogue value stays the only
        /// source of the colour itself.
        private func material(
            color: UIColor,
            detail: MaruGenjiStrandDetailTextures
        ) -> PhysicallyBasedMaterial {
            var material = PhysicallyBasedMaterial()
            if let occlusion = detail.occlusion {
                material.baseColor = .init(tint: color, texture: .strandDetail(occlusion))
            } else {
                material.baseColor = .init(tint: color)
            }
            material.metallic = .init(floatLiteral: 0)
            if let roughness = detail.roughness {
                material.roughness = .init(scale: 1, texture: .strandDetail(roughness))
            } else {
                material.roughness = .init(floatLiteral: MaruGenjiStrandTextureFactory.baseRoughness)
            }
            if let normal = detail.normal {
                material.normal = .init(texture: .strandDetail(normal))
            }
            return material
        }

        private enum SurfaceRenderError: Error {
            case unknownColor
            case emptySurface
        }
    }
}
