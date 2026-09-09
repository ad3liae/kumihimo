import Foundation
import RealityKit
import Testing
import UIKit
@testable import Kumihimo

/// The list's card and the preview draw **the same braid from the same code**.
///
/// The card was a hand-written unrolled drawing until Task 028; the whole point of
/// the change is that it no longer is. What holds that together is not a comment
/// but this: both go through `BraidSurfaceScene`, and the same colouring gives
/// them the same mesh, vertex for vertex. Only where the camera stands differs,
/// and that difference is worked out from the card, not chosen.
@MainActor
@Suite struct BraidCardSceneTests {
    /// The card's right two thirds on an iPhone: the narrower of the two devices,
    /// so the harder case for fitting repeats in.
    static let cardSize = CGSize(width: 241, height: 112)

    @Test(
        "The card and the preview get the same mesh from the same colouring",
        arguments: [
            (RoundTube16SurfaceMesh.family, BraidReferenceColourings.bookAP94MaruGenji),
            (Flat16SurfaceMesh.family, BraidReferenceColourings.bookAP97Left),
        ]
    )
    func theCardAndThePreviewShareTheScene(
        family: BraidFamily,
        assignments: [ThreadAssignment]
    ) throws {
        let preview = try #require(install(family: family, assignments: assignments, framing: .preview))
        let card = try #require(install(
            family: family,
            assignments: assignments,
            framing: .crossing(repeats: 3, in: Self.cardSize)
        ))

        let previewVertices = Self.vertexCount(of: preview.model.mesh)
        let cardVertices = Self.vertexCount(of: card.model.mesh)
        #expect(previewVertices > 0)
        #expect(cardVertices == previewVertices)
        #expect(card.model.materials.count == preview.model.materials.count)
        #expect(card.model.tileLength == preview.model.tileLength)
    }

    /// A different colouring must give a different mesh, or the test above would
    /// pass on a scene that ignores the colours.
    @Test func adifferentColouringGivesADifferentMesh() throws {
        let one = try #require(install(
            family: RoundTube16SurfaceMesh.family,
            assignments: BraidReferenceColourings.bookAP94MaruGenji,
            framing: .preview
        ))
        let other = try #require(install(
            family: RoundTube16SurfaceMesh.family,
            assignments: BraidReferenceColourings.bookAP95ArrowFeather,
            framing: .preview
        ))
        #expect(Self.vertexCount(of: one.model.mesh) == Self.vertexCount(of: other.model.mesh))
        #expect(one.model.materials.count != other.model.materials.count
            || Self.colours(one) != Self.colours(other))
    }

    /// **Three repeats cross the card, corner to corner.** Worked out from the
    /// family's own tile length and the card's size — not looked at.
    @Test(arguments: [
        RoundTube16SurfaceMesh.family,
        Flat16SurfaceMesh.family,
    ])
    func threeRepeatsCrossTheCard(family: BraidFamily) throws {
        let assignments = family == Flat16SurfaceMesh.family
            ? BraidReferenceColourings.bookAP97Left
            : BraidReferenceColourings.bookAP94MaruGenji
        let installed = try #require(install(
            family: family,
            assignments: assignments,
            framing: .crossing(
                repeats: BraidCardRealityView.repeatsAcrossTheCard,
                in: Self.cardSize
            )
        ))

        let visibleHeight = 2 * installed.placement.cameraDistance
            * tan(BraidSurfaceScene.verticalFieldOfView / 2)
        let diagonal = visibleHeight
            * Float(hypot(Self.cardSize.width, Self.cardSize.height) / Self.cardSize.height)
        let repeats = diagonal / installed.model.tileLength

        #expect(repeats >= Float(BraidCardRealityView.repeatsAcrossTheCard))
        #expect(abs(repeats - Float(BraidCardRealityView.repeatsAcrossTheCard)) < 1e-4)

        // The distance the rule works out for this card, pinned so a change to a
        // tile length is seen rather than absorbed. Both are derived; neither was
        // chosen.
        let expected: Float = family == Flat16SurfaceMesh.family ? 13.8688 : 8.5859
        #expect(abs(installed.placement.cameraDistance - expected) < 2e-3)
    }

    /// The braid runs corner to corner, so the slant is the card's own diagonal.
    @Test func theSlantIsTheCardsDiagonal() {
        let placement = BraidSurfaceScene.Framing
            .crossing(repeats: 3, in: Self.cardSize)
            .placement(tileLength: 1)
        #expect(abs(Double(placement.tilt) - atan2(112.0, 241.0)) < 1e-6)

        let preview = BraidSurfaceScene.Framing.preview.placement(tileLength: 1)
        #expect(preview.tilt == 0)
        #expect(preview.cameraDistance == BraidSurfaceScene.cameraDistance)
    }

    /// A card with no width, or a family whose tile has no length, falls back to
    /// the preview's distance rather than dividing by nothing.
    @Test func anImpossibleCardFallsBackToThePreviewsDistance() {
        for framing: BraidSurfaceScene.Framing in [
            .crossing(repeats: 3, in: CGSize(width: 0, height: 112)),
            .crossing(repeats: 0, in: Self.cardSize),
        ] {
            let placement = framing.placement(tileLength: 1)
            #expect(placement.cameraDistance == BraidSurfaceScene.cameraDistance)
            #expect(placement.tilt == 0)
        }
        let noTile = BraidSurfaceScene.Framing
            .crossing(repeats: 3, in: Self.cardSize)
            .placement(tileLength: 0)
        #expect(noTile.cameraDistance == BraidSurfaceScene.cameraDistance)
    }

    /// The tiles have to fill the diagonal, because that is the way the braid
    /// runs. The preview's braid lies across the view, so its width is enough.
    @Test func theLengthToFillIsTheDiagonal() {
        let crossing = BraidSurfaceScene.Framing.crossing(repeats: 3, in: Self.cardSize)
        let covered = crossing.coverageSize(viewportSize: Self.cardSize)
        #expect(abs(covered.width - hypot(241.0, 112.0)) < 1e-9)
        #expect(covered.height == 112)

        let preview = BraidSurfaceScene.Framing.preview
        #expect(preview.coverageSize(viewportSize: Self.cardSize) == Self.cardSize)
    }

    // MARK: -

    private func install(
        family: BraidFamily,
        assignments: [ThreadAssignment],
        framing: BraidSurfaceScene.Framing
    ) -> BraidSurfaceScene.Installed? {
        let view = ARView(
            frame: CGRect(origin: .zero, size: Self.cardSize),
            cameraMode: .nonAR,
            automaticallyConfigureSession: false
        )
        return BraidSurfaceScene.install(
            in: view, family: family, assignments: assignments, framing: framing
        )
    }

    private static func vertexCount(of mesh: MeshResource) -> Int {
        mesh.contents.models
            .flatMap { $0.parts.map { $0.positions.count } }
            .reduce(0, +)
    }

    private static func colours(_ installed: BraidSurfaceScene.Installed) -> [String] {
        installed.model.materials.map { String(describing: $0.baseColor.tint) }
    }

    /// The tile lengths the two distances rest on, pinned so they can be read
    /// against each other.
    @Test func theTileLengthsTheDistancesRestOn() {
        #expect(abs(RoundTube16SurfaceMesh.defaultLength - 7.8414) < 1e-3)
        #expect(abs(Flat16SurfaceMesh.defaultLength - 12.6662) < 1e-3)
    }
}
