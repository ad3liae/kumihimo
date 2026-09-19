import CoreGraphics
import Metal
import RealityKit
import os

/// RealityKit resources for the shared strand detail maps.
///
/// The maps depend only on the strand shape, never on the colouring, so they are
/// generated once and reused by every material and every rebuild of the scene.
/// There is one set per twist group and layer, because the stripe angle a strand needs
/// depends on how its own frame is sheared; the sets are indexed the way the mesh
/// numbers its twist groups.
@MainActor
final class RoundTube16StrandTextures {
    static let shared = RoundTube16StrandTextures()

    /// The three maps one twist group needs.
    struct Maps {
        let occlusion: TextureResource?
        let roughness: TextureResource?
        let normal: TextureResource?
    }

    private static let logger = Logger(
        subsystem: "com.example.Kumihimo",
        category: "RoundTube16StrandTextures"
    )

    /// One set per twist group, for each layer (Task 047).
    let mapsByLayer: [BraidCrossingLayer: [Maps]]

    private init() {
        var mapsByLayer = [BraidCrossingLayer: [Maps]]()
        for layer in BraidCrossingLayer.allCases {
            mapsByLayer[layer] = RoundTube16StrandTextureFactory.twistGroups.enumerated().map { index, twist in
                Maps(
                    occlusion: Self.texture(
                        RoundTube16StrandTextureFactory.occlusionImage(twist: twist, layer: layer),
                        semantic: .color,
                        name: "occlusion \(index) \(layer.rawValue)"
                    ),
                    roughness: Self.texture(
                        RoundTube16StrandTextureFactory.roughnessImage(
                            twist: twist,
                            layer: layer,
                            amplitude: RoundTube16StrandTextureFactory.strandTwistRoughnessAmplitude
                        ),
                        semantic: .scalar,
                        name: "roughness \(index) \(layer.rawValue)"
                    ),
                    normal: Self.texture(
                        RoundTube16StrandTextureFactory.normalImage(
                            twist: twist,
                            layer: layer,
                            relief: RoundTube16SurfaceMesh.strandTwistReliefRatio
                        ),
                        semantic: .normal,
                        name: "normal \(index) \(layer.rawValue)"
                    )
                )
            }
        }
        self.mapsByLayer = mapsByLayer
    }

    /// The maps for one twist group and layer. A mesh built from a pattern the
    /// factory has no group for falls back to the first set rather than losing
    /// its detail.
    func maps(forTwistGroup index: Int, layer: BraidCrossingLayer) -> Maps? {
        guard let sets = mapsByLayer[layer] else { return nil }
        return sets.indices.contains(index) ? sets[index] : sets.first
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
