import CoreGraphics
import Metal
import RealityKit
import os

/// RealityKit resources for the shared strand detail maps.
///
/// The maps depend only on the strand shape, never on the colouring, so they are
/// generated once and reused by every material and every rebuild of the scene.
/// There is one set per twist group, because the stripe angle a strand needs
/// depends on how its own frame is sheared; the sets are indexed the way the mesh
/// numbers its twist groups.
@MainActor
final class MaruGenjiStrandDetailTextures {
    static let shared = MaruGenjiStrandDetailTextures()

    /// The three maps one twist group needs.
    struct Maps {
        let occlusion: TextureResource?
        let roughness: TextureResource?
        let normal: TextureResource?
    }

    private static let logger = Logger(
        subsystem: "com.example.Kumihimo",
        category: "MaruGenjiStrandDetailTextures"
    )

    let mapsByTwistGroup: [Maps]

    private init() {
        mapsByTwistGroup = MaruGenjiStrandTextureFactory.twistGroups.enumerated().map { index, twist in
            Maps(
                occlusion: Self.texture(
                    MaruGenjiStrandTextureFactory.occlusionImage(twist: twist),
                    semantic: .color,
                    name: "occlusion \(index)"
                ),
                roughness: Self.texture(
                    MaruGenjiStrandTextureFactory.roughnessImage(twist: twist),
                    semantic: .scalar,
                    name: "roughness \(index)"
                ),
                normal: Self.texture(
                    MaruGenjiStrandTextureFactory.normalImage(twist: twist),
                    semantic: .normal,
                    name: "normal \(index)"
                )
            )
        }
    }

    /// The maps for one twist group. A mesh built from a pattern the factory has
    /// no group for falls back to the first set rather than losing its detail.
    func maps(forTwistGroup index: Int) -> Maps? {
        mapsByTwistGroup.indices.contains(index)
            ? mapsByTwistGroup[index]
            : mapsByTwistGroup.first
    }

    private static func texture(
        _ image: CGImage?,
        semantic: TextureResource.Semantic,
        name: String
    ) -> TextureResource? {
        guard let image else {
            logger.error("Strand \(name, privacy: .public) map could not be drawn")
            return nil
        }
        do {
            return try TextureResource.generate(
                from: image,
                options: .init(semantic: semantic)
            )
        } catch {
            logger.error(
                "Strand \(name, privacy: .public) map could not be uploaded: \(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }
}

extension MaterialParameters.Texture {
    /// Strand maps are addressed by strand-local coordinates that stop at the
    /// strand edge, so they must clamp rather than wrap.
    static func strandDetail(_ resource: TextureResource) -> MaterialParameters.Texture {
        let descriptor = MTLSamplerDescriptor()
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        descriptor.mipFilter = .linear
        return MaterialParameters.Texture(resource, sampler: .init(descriptor))
    }
}
