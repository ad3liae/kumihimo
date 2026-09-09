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
            framing: .crossing(widthAsFractionOfHeight: 1.0 / 3.0, in: Self.cardSize)
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

    /// **The braid comes out a third of the card thick, and three or more repeats
    /// of the pattern still cross it.** The thickness is what the distance is set
    /// from; the count of repeats is what follows, and is checked here rather than
    /// chosen. Task 028-1b had it the other way round and the braid came out a
    /// tenth of the card thick.
    @Test(arguments: [
        RoundTube16SurfaceMesh.family,
        Flat16SurfaceMesh.family,
    ])
    func theBraidIsAThirdOfTheCardThickAndRepeatsEnough(family: BraidFamily) throws {
        let assignments = family == Flat16SurfaceMesh.family
            ? BraidReferenceColourings.bookAP97Left
            : BraidReferenceColourings.bookAP94MaruGenji
        let installed = try #require(install(
            family: family,
            assignments: assignments,
            framing: .crossing(
                widthAsFractionOfHeight: BraidCardRealityView.widthAsFractionOfHeight,
                in: Self.cardSize
            )
        ))

        let visibleHeight = 2 * installed.placement.cameraDistance
            * tan(BraidSurfaceScene.verticalFieldOfView / 2)

        // How thick the braid is on screen, in points of the card.
        let thickness = CGFloat(installed.model.braidWidth / visibleHeight)
            * Self.cardSize.height
        let wanted = BraidCardRealityView.widthAsFractionOfHeight * Self.cardSize.height
        #expect(abs(thickness - wanted) < 1e-3)

        // How many repeats of the pattern cross it, corner to corner.
        let diagonal = visibleHeight
            * Float(hypot(Self.cardSize.width, Self.cardSize.height) / Self.cardSize.height)
        let patternRepeat = installed.model.tileLength
            / Float(installed.model.patternRepeatsPerTile)
        let repeats = diagonal / patternRepeat
        #expect(repeats >= Float(BraidCardRealityView.leastRepeatsAcrossTheCard))

        // The two the rule works out for this card, pinned so a change to either
        // braid's width or repeat length is seen rather than absorbed.
        // Measured, not calculated by hand: two rounds of pinning a value worked
        // out from a nominal radius were wrong, because the silhouette is what the
        // camera sees and a crest and a rounded edge both stand outside the
        // nominal surface.
        let expected: (distance: Float, repeats: Float) = family == Flat16SurfaceMesh.family
            ? (4.211849, 5.4664683)
            : (2.7665148, 3.8665984)
        #expect(abs(installed.placement.cameraDistance - expected.distance) < 1e-3)
        #expect(abs(repeats - expected.repeats) < 1e-3)
    }

    /// The braid runs corner to corner, so the slant is the card's own diagonal.
    @Test func theSlantIsTheCardsDiagonal() {
        let placement = BraidSurfaceScene.Framing
            .crossing(widthAsFractionOfHeight: 1.0 / 3.0, in: Self.cardSize)
            .placement(braidWidth: 1)
        #expect(abs(Double(placement.tilt) - atan2(112.0, 241.0)) < 1e-6)

        let preview = BraidSurfaceScene.Framing.preview.placement(braidWidth: 1)
        #expect(preview.tilt == 0)
        #expect(preview.cameraDistance == BraidSurfaceScene.cameraDistance)
    }

    /// A card with no width, or a braid with no width, falls back to the
    /// preview's distance rather than dividing by nothing.
    @Test func anImpossibleCardFallsBackToThePreviewsDistance() {
        for framing: BraidSurfaceScene.Framing in [
            .crossing(widthAsFractionOfHeight: 1.0 / 3.0, in: CGSize(width: 0, height: 112)),
            .crossing(widthAsFractionOfHeight: 0, in: Self.cardSize),
        ] {
            let placement = framing.placement(braidWidth: 1)
            #expect(placement.cameraDistance == BraidSurfaceScene.cameraDistance)
            #expect(placement.tilt == 0)
        }
        let noBraid = BraidSurfaceScene.Framing
            .crossing(widthAsFractionOfHeight: 1.0 / 3.0, in: Self.cardSize)
            .placement(braidWidth: 0)
        #expect(noBraid.cameraDistance == BraidSurfaceScene.cameraDistance)
    }

    /// The tiles have to fill the diagonal, because that is the way the braid
    /// runs. The preview's braid lies across the view, so its width is enough.
    @Test func theLengthToFillIsTheDiagonal() {
        let crossing = BraidSurfaceScene.Framing
            .crossing(widthAsFractionOfHeight: 1.0 / 3.0, in: Self.cardSize)
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

    /// The tile lengths and measured widths the two distances rest on, pinned so
    /// they can be read against each other.
    @Test(arguments: [
        RoundTube16SurfaceMesh.family,
        Flat16SurfaceMesh.family,
    ])
    func theNumbersTheDistancesRestOn(family: BraidFamily) throws {
        let isFlat = family == Flat16SurfaceMesh.family
        let installed = try #require(install(
            family: family,
            assignments: isFlat
                ? BraidReferenceColourings.bookAP97Left
                : BraidReferenceColourings.bookAP94MaruGenji,
            framing: .preview
        ))
        // **Measured off the mesh**, not read from a radius or a half-width. The
        // tube's crest puts it 10.9 per cent over its nominal diameter of 0.96;
        // the flat braid's rounded edges put it 12.6 per cent over twice its
        // half-width of 0.72. Neither could be worked out from the constants
        // without knowing how the drawer shapes an edge, which is why it is read
        // off the thing the drawer made.
        let expected: (tile: Float, width: Float, repeatsPerTile: Int) = isFlat
            ? (12.666241, 1.6211413, 6)
            : (7.8414145, 1.064832, 4)
        #expect(abs(installed.model.tileLength - expected.tile) < 1e-4)
        #expect(abs(installed.model.braidWidth - expected.width) < 1e-4)
        #expect(installed.model.patternRepeatsPerTile == expected.repeatsPerTile)
    }
}
