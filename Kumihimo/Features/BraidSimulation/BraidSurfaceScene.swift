import RealityKit
import UIKit
import os

/// The scene a braid is drawn in: the mesh and its materials, the camera, the
/// lights, and the tiles that carry the braid off both ends of the view.
///
/// **Moved here whole from the two reality views** (Task 028-1a). Both of them
/// built the same scene from two copies of the same code, and the list's thumbnail
/// is about to want that scene as well. One copy means the thumbnail cannot drift
/// away from the preview: **they are the same picture because they are the same
/// code**, not because two pieces of code happen to agree today.
///
/// Nothing about the shape lives here. The mesh comes from the family's own
/// drawer, the colours from the pattern the occupancy history gives it; this only
/// puts what they made in front of a camera.
enum BraidSurfaceScene {
    private static let logger = Logger(
        subsystem: "com.example.Kumihimo",
        category: "BraidSurfaceScene"
    )

    static let cameraDistance: Float = 4.4
    static let verticalFieldOfView: Float = .pi / 3
    /// Neutral three-point lighting, exposed low enough that a strand crest keeps
    /// the catalogue colour instead of washing out to a pale tint.
    static let keyLightIntensity: Float = 1_500
    static let fillLightIntensity: Float = 520
    static let rimLightIntensity: Float = 380

    /// Where the camera stands, and how far the braid is turned about the
    /// viewing axis.
    struct Placement: Equatable {
        let cameraDistance: Float
        /// About the viewing axis. Zero leaves the braid lying across the view.
        let tilt: Float
    }

    /// What the picture is for.
    ///
    /// **The distance follows from this; it is not chosen.** Nothing here is a
    /// shape: the shape is the mesh's, and this only decides where to stand.
    enum Framing: Equatable {
        /// The preview. The distance the braid has been drawn at since Task 019,
        /// the braid lying across the view, and the viewer free to turn and zoom.
        case preview
        /// The list's card. Far enough back that **the braid comes out as thick on
        /// screen as `widthAsFractionOfHeight` of the card's height**, and turned
        /// to run along the card's diagonal — in at the bottom left, out at the top
        /// right.
        ///
        /// **How thick the braid looks is the thing that decides the distance.**
        /// Task 028-1b set the distance from a count of repeats instead, and the
        /// braid came out about a tenth of the card's height — a thin line whose
        /// pattern could not be read. How many repeats then cross the card follows
        /// from the distance; it is checked, not chosen.
        case crossing(widthAsFractionOfHeight: CGFloat, in: CGSize)

        /// At distance `d` the view is `2 d tan(fov/2)` world units tall, and a
        /// braid `braidWidth` wide therefore covers
        ///
        ///     braidWidth / (2 d tan(fov/2))
        ///
        /// of the picture's height. Setting that to the fraction asked for and
        /// solving for `d` gives
        ///
        ///     d = braidWidth / (2 tan(fov/2) * fraction)
        ///
        /// which **does not depend on the card's size** — the fraction is of the
        /// height, and so is the braid. The card's size decides only the angle:
        /// the picture's own diagonal, the one angle at which the braid's run
        /// across it is longest.
        func placement(braidWidth: Float) -> Placement {
            switch self {
            case .preview:
                return Placement(cameraDistance: BraidSurfaceScene.cameraDistance, tilt: 0)
            case let .crossing(fraction, size):
                guard
                    size.width > 0,
                    size.height > 0,
                    braidWidth > 0,
                    fraction > 0
                else {
                    return Placement(cameraDistance: BraidSurfaceScene.cameraDistance, tilt: 0)
                }
                let distance = braidWidth
                    / (2 * tan(BraidSurfaceScene.verticalFieldOfView / 2) * Float(fraction))
                return Placement(
                    cameraDistance: distance,
                    tilt: Float(atan2(Double(size.height), Double(size.width)))
                )
            }
        }

        /// The length the tiles have to fill. When the braid runs along the
        /// diagonal, that is the diagonal — the same question the coverage
        /// calculator always answers, put for the direction the braid is in.
        func coverageSize(viewportSize: CGSize) -> CGSize {
            switch self {
            case .preview:
                return viewportSize
            case .crossing:
                guard viewportSize.width > 0, viewportSize.height > 0 else {
                    return viewportSize
                }
                return CGSize(
                    width: hypot(viewportSize.width, viewportSize.height),
                    height: viewportSize.height
                )
            }
        }
    }

    /// One repeat of a braid, ready to be placed: the mesh, one material per
    /// colour-and-twist group, and how long that repeat is along the braid.
    struct Model {
        let mesh: MeshResource
        let materials: [PhysicallyBasedMaterial]
        /// Taken from the generated mesh, which derives it from the radius and the
        /// aspect ratio the pattern declares.
        let tileLength: Float
        /// How wide the braid is across the view, **measured off the mesh the
        /// drawer made** rather than read from a radius: a crest stands above the
        /// nominal surface, and it is the silhouette that decides how thick the
        /// braid looks.
        let braidWidth: Float
        /// Repeats of the surface pattern in one tile. A tile is the mesh's unit;
        /// **a repeat is what an eye counts.**
        let patternRepeatsPerTile: Int
    }

    /// A scene standing in an `ARView`: the root the viewer turns, and the parent
    /// the tiles hang from.
    struct Installed {
        /// Turned by the viewer, when there is one.
        let modelRoot: Entity
        let tileRoot: Entity
        let model: Model
        let framing: Framing
        let placement: Placement
    }

    enum SceneError: Error {
        case patternGenerationFailed
        case meshDataGenerationFailed
        case unknownColor
        case emptySurface
    }

    /// Builds the braid and stands it in the view, or `nil` when the family's
    /// drawer will not draw it. Failure is logged here, once.
    @MainActor
    static func install(
        in view: ARView,
        family: BraidFamily,
        assignments: [ThreadAssignment],
        framing: Framing = .preview
    ) -> Installed? {
        view.scene.anchors.removeAll()

        let model: Model
        do {
            model = try self.model(for: family, assignments: assignments)
        } catch {
            let positions = assignments.map(\.position).map(String.init).joined(separator: ",")
            logger.error(
                """
                Surface scene failed for \(String(describing: family), privacy: .public): \
                \(String(describing: error), privacy: .public) \
                (\(assignments.count) assignments at \(positions, privacy: .public))
                """
            )
            return nil
        }

        let placement = framing.placement(braidWidth: model.braidWidth)

        let anchor = AnchorEntity(world: .zero)
        let root = Entity()
        // The tilt hangs below the root the viewer turns, so a viewer's roll and
        // the card's slant do not fight over one orientation.
        let tilted = Entity()
        tilted.orientation = simd_quatf(angle: placement.tilt, axis: SIMD3<Float>(0, 0, 1))
        let instances = Entity()
        tilted.addChild(instances)
        root.addChild(tilted)
        anchor.addChild(root)

        let camera = PerspectiveCamera()
        camera.look(
            at: .zero,
            from: SIMD3<Float>(0, 0, placement.cameraDistance),
            relativeTo: nil
        )
        camera.camera.fieldOfViewInDegrees = verticalFieldOfView * 180 / .pi
        anchor.addChild(camera)

        // The round braid's three lights, used for the flat braid too. The flat
        // braid had a key of 3,500 against a fill of 1,200; a fill that strong
        // lifts the valleys back out and leaves the surface without shadows.
        let keyLight = DirectionalLight()
        keyLight.light.intensity = keyLightIntensity
        keyLight.look(at: .zero, from: SIMD3<Float>(0.5, 2.2, 3), relativeTo: nil)
        anchor.addChild(keyLight)

        let fillLight = DirectionalLight()
        fillLight.light.intensity = fillLightIntensity
        fillLight.look(at: .zero, from: SIMD3<Float>(-1.5, -1, 2), relativeTo: nil)
        anchor.addChild(fillLight)

        let rimLight = DirectionalLight()
        rimLight.light.intensity = rimLightIntensity
        rimLight.look(at: .zero, from: SIMD3<Float>(0.2, 1, -3), relativeTo: nil)
        anchor.addChild(rimLight)

        view.scene.addAnchor(anchor)
        return Installed(
            modelRoot: root,
            tileRoot: instances,
            model: model,
            framing: framing,
            placement: placement
        )
    }

    /// Lays enough repeats end to end to fill the viewport, and returns the new
    /// count. `nil` when the count would not change, or cannot be worked out.
    @MainActor
    static func retile(
        _ installed: Installed,
        viewportSize: CGSize,
        tileCount: Int
    ) -> Int? {
        let covered = installed.framing.coverageSize(viewportSize: viewportSize)
        guard
            covered.width > 0,
            covered.height > 0,
            let coverage = RoundTube16ViewportCoverageCalculator.calculate(
                viewportSize: SIMD2<Float>(
                    Float(covered.width),
                    Float(covered.height)
                ),
                cameraDistance: installed.placement.cameraDistance,
                verticalFieldOfView: verticalFieldOfView,
                minimumScale: RoundTube16ViewerController.minimumScale,
                tileLength: installed.model.tileLength
            ),
            coverage.tileCount != tileCount,
            let offsets = RoundTube16ViewportCoverageCalculator.tileOffsets(
                tileCount: coverage.tileCount,
                tileLength: installed.model.tileLength
            )
        else {
            return nil
        }

        installed.tileRoot.children.removeAll()
        for offset in offsets {
            let entity = ModelEntity(
                mesh: installed.model.mesh,
                materials: installed.model.materials
            )
            entity.position.x = offset
            installed.tileRoot.addChild(entity)
        }
        return coverage.tileCount
    }

    /// The mesh and materials for a family. **The family chooses the drawer**; no
    /// braid's name is asked for.
    @MainActor
    static func model(
        for family: BraidFamily,
        assignments: [ThreadAssignment]
    ) throws -> Model {
        switch family {
        case Flat16SurfaceMesh.family:
            return try flatModel(assignments: assignments)
        case RoundTube16SurfaceMesh.family:
            return try roundTubeModel(assignments: assignments)
        default:
            throw SceneError.patternGenerationFailed
        }
    }

    @MainActor
    private static func roundTubeModel(assignments: [ThreadAssignment]) throws -> Model {
        guard let pattern = RoundTube16SurfacePatternGenerator.generate(assignments: assignments)
        else { throw SceneError.patternGenerationFailed }
        guard let surface = RoundTube16SurfaceMesh.generate(pattern: pattern)
        else { throw SceneError.meshDataGenerationFailed }

        let drawGroups = surface.sortedMaterialGroups
        guard
            !drawGroups.isEmpty,
            drawGroups.allSatisfy({ ThreadColorCatalog.color(for: $0.key.colorID) != nil })
        else { throw SceneError.emptySurface }

        let detail = RoundTube16StrandTextures.shared
        var combinedIndices = [UInt32]()
        var faceMaterialIndices = [UInt32]()
        var materials = [PhysicallyBasedMaterial]()
        // One material per thread colour and twist group: the colour comes from
        // the catalogue, the stripe angle from the group's own maps.
        for (key, indices) in drawGroups where !indices.isEmpty {
            guard let threadColor = ThreadColorCatalog.color(for: key.colorID) else {
                throw SceneError.unknownColor
            }
            combinedIndices.append(contentsOf: indices)
            faceMaterialIndices.append(
                contentsOf: repeatElement(
                    UInt32(materials.count),
                    count: indices.count / 3
                )
            )
            let maps = detail.maps(forTwistGroup: key.twistGroupIndex)
            materials.append(
                material(
                    color: threadColor.uiColor,
                    occlusion: maps?.occlusion,
                    roughness: maps?.roughness,
                    normal: maps?.normal
                )
            )
        }
        guard
            !combinedIndices.isEmpty,
            combinedIndices.count / 3 == faceMaterialIndices.count,
            !materials.isEmpty
        else { throw SceneError.emptySurface }

        var descriptor = MeshDescriptor(name: "maru-genji-surface")
        descriptor.positions = MeshBuffer(surface.positions)
        descriptor.normals = MeshBuffer(surface.normals)
        descriptor.tangents = MeshBuffer(surface.tangents)
        descriptor.bitangents = MeshBuffer(surface.bitangents)
        descriptor.textureCoordinates = MeshBuffer(surface.textureCoordinates)
        descriptor.primitives = .triangles(combinedIndices)
        descriptor.materials = .perFace(faceMaterialIndices)

        return Model(
            mesh: try MeshResource.generate(from: [descriptor]),
            materials: materials,
            tileLength: surface.length,
            braidWidth: widthAcrossTheView(of: surface.positions),
            patternRepeatsPerTile: RoundTube16SurfaceMesh.defaultPatternRepeatCount
        )
    }

    @MainActor
    private static func flatModel(assignments: [ThreadAssignment]) throws -> Model {
        guard let pattern = Flat16SurfacePatternGenerator.generate(assignments: assignments),
              let surface = Flat16SurfaceMesh.generate(pattern: pattern)
        else { throw SceneError.patternGenerationFailed }

        let colorIDs = Set(surface.colorGroups.keys)
            .union(surface.boundaryColorGroups.keys)
            .sorted { $0.rawValue < $1.rawValue }
        guard !colorIDs.isEmpty else { throw SceneError.emptySurface }

        var combinedIndices = [UInt32]()
        var faceMaterialIndices = [UInt32]()
        var materials = [PhysicallyBasedMaterial]()
        for colorID in colorIDs {
            guard let threadColor = ThreadColorCatalog.color(for: colorID) else {
                throw SceneError.unknownColor
            }
            // One material for the whole thread. The band round a patch used to be
            // painted in a second, darker colour; the valley shading now comes from
            // the stitch's own map, which varies continuously instead of stepping
            // once.
            let indices = (surface.colorGroups[colorID] ?? [])
                + (surface.boundaryColorGroups[colorID] ?? [])
            guard !indices.isEmpty else { continue }
            combinedIndices.append(contentsOf: indices)
            faceMaterialIndices.append(
                contentsOf: repeatElement(
                    UInt32(materials.count),
                    count: indices.count / 3
                )
            )
            let maps = Flat16StitchTexture.maps
            materials.append(
                material(
                    color: threadColor.uiColor,
                    occlusion: maps.occlusion,
                    roughness: maps.roughness,
                    normal: maps.normal
                )
            )
        }
        guard !combinedIndices.isEmpty else { throw SceneError.emptySurface }

        var descriptor = MeshDescriptor(name: "hira-genji-surface")
        descriptor.positions = MeshBuffer(surface.positions)
        descriptor.normals = MeshBuffer(surface.normals)
        descriptor.textureCoordinates = MeshBuffer(surface.textureCoordinates)
        descriptor.primitives = .triangles(combinedIndices)
        descriptor.materials = .perFace(faceMaterialIndices)

        return Model(
            mesh: try MeshResource.generate(from: [descriptor]),
            materials: materials,
            tileLength: Flat16SurfaceMesh.defaultLength,
            braidWidth: widthAcrossTheView(of: surface.positions),
            patternRepeatsPerTile: Flat16SurfaceMesh.defaultPatternRepeatCount
        )
    }

    /// The braid runs along x and is looked at down z, so what decides how thick
    /// it looks is **its extent along y**. Measured, so a crest counts.
    static func widthAcrossTheView(of positions: [SIMD3<Float>]) -> Float {
        guard let first = positions.first else { return 0 }
        var lowest = first.y
        var highest = first.y
        for position in positions.dropFirst() {
            lowest = min(lowest, position.y)
            highest = max(highest, position.y)
        }
        return highest - lowest
    }

    /// The valley shading and the twist come from maps that depend on the strand
    /// shape alone, so the catalogue value stays the only source of the colour
    /// itself.
    /// The two families keep their own `Maps` types, so the three textures are
    /// passed one by one rather than as a struct one family would have to borrow
    /// from the other.
    @MainActor
    private static func material(
        color: UIColor,
        occlusion: TextureResource?,
        roughness: TextureResource?,
        normal: TextureResource?
    ) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        if let occlusion {
            material.baseColor = .init(tint: color, texture: .strandDetail(occlusion))
            material.ambientOcclusion = .init(texture: .strandDetail(occlusion))
        } else {
            material.baseColor = .init(tint: color)
        }
        material.metallic = .init(floatLiteral: 0)
        if let roughness {
            material.roughness = .init(scale: 1, texture: .strandDetail(roughness))
        } else {
            material.roughness = .init(floatLiteral: RoundTube16StrandTextureFactory.baseRoughness)
        }
        if let normal {
            material.normal = .init(texture: .strandDetail(normal))
        }
        return material
    }

    /// The signature a view compares to decide whether the colours changed.
    static func signature(_ assignments: [ThreadAssignment]) -> String {
        assignments
            .sorted { $0.position < $1.position }
            .map { "\($0.position):\($0.colorID.rawValue)" }
            .joined(separator: "|")
    }
}
