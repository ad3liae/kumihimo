import RealityKit
import SwiftUI
import UIKit
import os

struct HiraGenjiRealityView: UIViewRepresentable {
    static let cameraDistance: Float = MaruGenjiRealityView.cameraDistance
    static let verticalFieldOfView: Float = MaruGenjiRealityView.verticalFieldOfView

    let assignments: [ThreadAssignment]
    let controller: MaruGenjiViewerController
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
        let signature = Self.signature(assignments)
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

    private static func signature(_ assignments: [ThreadAssignment]) -> String {
        assignments.sorted { $0.position < $1.position }
            .map { "\($0.position):\($0.colorID.rawValue)" }
            .joined(separator: "|")
    }

    @MainActor
    final class Coordinator: NSObject {
        private static let logger = Logger(
            subsystem: "com.example.Kumihimo",
            category: "HiraGenjiRealityView"
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
            assignmentSignature = HiraGenjiRealityView.signature(assignments)
            view.scene.anchors.removeAll()
            tileRoot = nil
            sharedMesh = nil
            sharedMaterials = []
            tileCount = 0

            guard let pattern = HiraGenjiSurfacePatternGenerator.generate(assignments: assignments),
                  let surface = HiraGenjiSurfaceMeshGenerator.generate(pattern: pattern) else {
                Self.logger.error("Flat surface generation failed")
                controller.reportFailure()
                return
            }

            do {
                let colorIDs = Set(surface.colorGroups.keys)
                    .union(surface.boundaryColorGroups.keys)
                    .sorted { $0.rawValue < $1.rawValue }
                guard !colorIDs.isEmpty else { throw RenderError.emptySurface }

                var combinedIndices = [UInt32]()
                var faceMaterialIndices = [UInt32]()
                var materials = [PhysicallyBasedMaterial]()
                for colorID in colorIDs {
                    guard let threadColor = ThreadColorCatalog.color(for: colorID) else {
                        throw RenderError.unknownColor
                    }
                    // One material for the whole thread. The band round a patch
                    // used to be painted in a second, darker colour; the valley
                    // shading now comes from the stitch's own map, which varies
                    // continuously instead of stepping once.
                    appendMaterialGroup(
                        (surface.colorGroups[colorID] ?? [])
                            + (surface.boundaryColorGroups[colorID] ?? []),
                        color: threadColor.uiColor,
                        roughness: MaruGenjiStrandTextureFactory.baseRoughness,
                        combinedIndices: &combinedIndices,
                        faceMaterialIndices: &faceMaterialIndices,
                        materials: &materials
                    )
                }
                guard !combinedIndices.isEmpty else { throw RenderError.emptySurface }

                var descriptor = MeshDescriptor(name: "hira-genji-surface")
                descriptor.positions = MeshBuffer(surface.positions)
                descriptor.normals = MeshBuffer(surface.normals)
                descriptor.textureCoordinates = MeshBuffer(surface.textureCoordinates)
                descriptor.primitives = .triangles(combinedIndices)
                descriptor.materials = .perFace(faceMaterialIndices)
                let mesh = try MeshResource.generate(from: [descriptor])

                let anchor = AnchorEntity(world: .zero)
                let root = Entity()
                let instances = Entity()
                root.addChild(instances)
                anchor.addChild(root)
                tileRoot = instances
                sharedMesh = mesh
                sharedMaterials = materials

                let camera = PerspectiveCamera()
                camera.look(at: .zero, from: SIMD3<Float>(0, 0, HiraGenjiRealityView.cameraDistance), relativeTo: nil)
                camera.camera.fieldOfViewInDegrees = HiraGenjiRealityView.verticalFieldOfView * 180 / .pi
                anchor.addChild(camera)

                // The round braid's three lights, unchanged. The flat braid had a
                // key of 3,500 against a fill of 1,200; a fill that strong lifts
                // the valleys back out and leaves the surface without shadows.
                let keyLight = DirectionalLight()
                keyLight.light.intensity = MaruGenjiRealityView.keyLightIntensity
                keyLight.look(at: .zero, from: SIMD3<Float>(0.5, 2.2, 3), relativeTo: nil)
                anchor.addChild(keyLight)
                let fillLight = DirectionalLight()
                fillLight.light.intensity = MaruGenjiRealityView.fillLightIntensity
                fillLight.look(at: .zero, from: SIMD3<Float>(-1.5, -1, 2), relativeTo: nil)
                anchor.addChild(fillLight)
                let rimLight = DirectionalLight()
                rimLight.light.intensity = MaruGenjiRealityView.rimLightIntensity
                rimLight.look(at: .zero, from: SIMD3<Float>(0.2, 1, -3), relativeTo: nil)
                anchor.addChild(rimLight)

                view.scene.addAnchor(anchor)
                updateCoverage(for: view.bounds.size)
                controller.connect(modelRoot: root)
            } catch {
                Self.logger.error("RealityKit flat surface generation failed: \(String(describing: error), privacy: .public)")
                controller.reportFailure()
            }
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
            guard let tileRoot, let sharedMesh,
                  viewportSize.width > 0, viewportSize.height > 0,
                  let coverage = MaruGenjiViewportCoverageCalculator.calculate(
                    viewportSize: SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height)),
                    cameraDistance: HiraGenjiRealityView.cameraDistance,
                    verticalFieldOfView: HiraGenjiRealityView.verticalFieldOfView,
                    minimumScale: MaruGenjiViewerController.minimumScale,
                    tileLength: HiraGenjiSurfaceMeshGenerator.defaultLength
                  ),
                  coverage.tileCount != tileCount,
                  let offsets = MaruGenjiViewportCoverageCalculator.tileOffsets(
                    tileCount: coverage.tileCount,
                    tileLength: HiraGenjiSurfaceMeshGenerator.defaultLength
                  ) else { return }

            tileRoot.children.removeAll()
            for offset in offsets {
                let entity = ModelEntity(mesh: sharedMesh, materials: sharedMaterials)
                entity.position.x = offset
                tileRoot.addChild(entity)
            }
            tileCount = coverage.tileCount
        }

        private func appendMaterialGroup(
            _ indices: [UInt32]?,
            color: UIColor,
            roughness: Float,
            combinedIndices: inout [UInt32],
            faceMaterialIndices: inout [UInt32],
            materials: inout [PhysicallyBasedMaterial]
        ) {
            guard let indices, !indices.isEmpty else { return }
            combinedIndices.append(contentsOf: indices)
            faceMaterialIndices.append(contentsOf: repeatElement(
                UInt32(materials.count),
                count: indices.count / 3
            ))
            var material = PhysicallyBasedMaterial()
            let maps = HiraGenjiStitchDetailTexture.maps
            if let occlusion = maps.occlusion {
                material.baseColor = .init(tint: color, texture: .strandDetail(occlusion))
                material.ambientOcclusion = .init(texture: .strandDetail(occlusion))
            } else {
                material.baseColor = .init(tint: color)
            }
            material.metallic = .init(floatLiteral: 0)
            if let roughnessMap = maps.roughness {
                material.roughness = .init(scale: 1, texture: .strandDetail(roughnessMap))
            } else {
                material.roughness = .init(floatLiteral: roughness)
            }
            if let normal = maps.normal {
                material.normal = .init(texture: .strandDetail(normal))
            }
            materials.append(material)
        }

        private enum RenderError: Error { case unknownColor, emptySurface }
    }
}
