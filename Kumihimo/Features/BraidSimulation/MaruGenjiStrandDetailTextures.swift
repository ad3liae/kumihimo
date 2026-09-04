import CoreGraphics
import Metal
import RealityKit
import os

/// RealityKit resources for the shared strand detail maps.
///
/// The maps depend only on the strand shape, never on the colouring, so they are
/// generated once and reused by every material and every rebuild of the scene.
@MainActor
final class MaruGenjiStrandDetailTextures {
    static let shared = MaruGenjiStrandDetailTextures()

    private static let logger = Logger(
        subsystem: "com.example.Kumihimo",
        category: "MaruGenjiStrandDetailTextures"
    )

    let occlusion: TextureResource?
    let roughness: TextureResource?
    let normal: TextureResource?

    private init() {
        occlusion = Self.texture(
            MaruGenjiStrandTextureFactory.occlusionImage(),
            semantic: .color,
            name: "occlusion"
        )
        roughness = Self.texture(
            MaruGenjiStrandTextureFactory.roughnessImage(),
            semantic: .scalar,
            name: "roughness"
        )
        normal = Self.texture(
            MaruGenjiStrandTextureFactory.normalImage(),
            semantic: .normal,
            name: "normal"
        )
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
