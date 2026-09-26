import CoreGraphics
import Foundation
import Testing
@testable import Kumihimo

/// Task 025-4 step 3: **the shape must not move while the names change.**
///
/// A hash of every vertex of each frozen mesh, taken before the renaming and held
/// against it after. It says nothing about whether the shape is right — only that
/// it is the same shape.
@MainActor
struct BraidMeshHashTests {
    /// FNV-1a over the bit patterns, so a single vertex moving anywhere shows.
    static func hash(_ points: [SIMD3<Float>]) -> UInt64 {
        var out: UInt64 = 0xcbf2_9ce4_8422_2325
        for point in points {
            for part in [point.x, point.y, point.z] {
                var bits = part.bitPattern
                for _ in 0..<4 {
                    out = (out ^ UInt64(bits & 0xff)) &* 0x100_0000_01b3
                    bits >>= 8
                }
            }
        }
        return out
    }

    /// **Changed twice, on purpose.**
    ///
    /// It was `0x78b4_526d_00e7_4a38` while the stitch lean was dropped at the
    /// two ends of the tile, which left one join in every four running straight
    /// at an edge; Task 030 let the lean out at every join and it became
    /// `0x53c4_4c9b_835a_e598`, with the vertex count unchanged — the same
    /// surface, tipped.
    ///
    /// **Task 050 drew a different surface**, so both moved: each cell is now a
    /// bundle wider than its lane and longer than its step, with the floor of
    /// its own cell beneath it. 366,552 vertices became 361,350 — about the same
    /// count for three times the surface, because a bundle is drawn at a third
    /// of the old density along its own length.
    ///
    /// **What this pins and what it does not.** It says the shape has not
    /// changed since it was last looked at; it says nothing about whether the
    /// shape is right. What the old value was holding — the lean at every join,
    /// the tile's ends meeting — is held by the tests that state those things,
    /// not by the digits here.
    @Test func theFlatBraidsMeshIsTheShapeItWas() throws {
        let mesh = try #require(SharedMeshes.flat(BraidMethodCatalog.hiraGenji16Colouring))
        #expect(mesh.positions.count == 361_350)
        #expect(Self.hash(mesh.positions) == 0x2df5_8dcc_177c_b981)
    }

    /// **Changed on purpose in Task 047.** `0xe3fc_af47_ceea_d34e` over 294,936
    /// vertices until then. The rework draws every cell as a bundle of its own,
    /// every bundle alike, that reaches past its cell and overlaps its
    /// neighbours, with a floor beneath and no walls; and the repeat is 1.25 turns
    /// long rather than 0.65.
    ///
    /// **Changed on purpose again in Task 052.** `0x4bd9_d069_9c8f_9734` until
    /// then, over the same 303,840 vertices: the crest was raised from 0.12 to
    /// 0.20 and the valley lowered from 0.03 to 0.11, so a bundle's face turns
    /// into its shoulder and the outline stays where it was; the cross-section
    /// lies down again at its rim (`crestRimSoftness` 1.5); each row rests on the
    /// previous one (`shingleRimHeight`); and the end lying over the other arm of
    /// a V comes to a point, sampled three times as finely (`lapRefinement`),
    /// which is why there are 419,184 vertices now.
    @Test func theRoundBraidsMeshIsTheShapeItWas() throws {
        let mesh = try #require(SharedMeshes.tube(BraidMethodCatalog.maruGenji16Colouring))
        #expect(mesh.positions.count == 419_184)
        #expect(Self.hash(mesh.positions) == 0x13ed_1478_75ce_cc9e)
    }

    /// FNV-1a over a picture's bytes.
    static func hash(_ image: CGImage) -> UInt64? {
        guard let data = image.dataProvider?.data as Data? else { return nil }
        var out: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in data { out = (out ^ UInt64(byte)) &* 0x100_0000_01b3 }
        return out
    }

    /// **The cards of the braids carried one way round are the pictures they
    /// were before Task 059** gave the braids carried both ways a shape of their
    /// own. Taken on the drawer before the change (yatsu-kongo S, Z and 返し組
    /// under their own colouring, eight colours and the author's 桃白青緑; 丸四つ組
    /// under its own and four colours) and held after it, pixel for pixel.
    ///
    /// **Changed on purpose in Task 063, in colour only.** The catalogue became
    /// the 38, the twelve former IDs are drawn as the colours they are read as,
    /// and the recipes' own colourings were chosen afresh from the books'
    /// photographs. Checked before the values were taken again: each card's map
    /// of which segment shows at each pixel is the one the former colouring gives,
    /// segment for segment, and the drawers and the generators were not touched.
    ///
    /// **Changed on purpose in Task 065, in colour only**, the same way: the
    /// catalogue became the 30, and the former IDs are drawn as the colours they
    /// are read as, and the recipes' own colourings were chosen afresh from the
    /// books' photographs among the 30. Checked before the values were taken
    /// again: each card's map of which segment shows at each pixel is the one
    /// the colouring in the 38 gives, segment for segment, with one colour of
    /// the 30 for each colour of the 38; the eight and four colours written in
    /// the twelve former IDs are the same patterns drawn in the colours they are
    /// read as.
    @Test func theOneWayCardsAreThePicturesTheyWere() throws {
        let eight = ["red", "orange", "yellow", "green", "light-blue", "blue", "purple", "pink"]
        let fourColours = ["pink", "white", "blue", "green", "pink", "white", "blue", "green"]
        func byPlace(_ names: [String]) -> [ThreadAssignment] {
            names.enumerated().map { ThreadAssignment(position: $0.offset + 1, colorID: ThreadColorID(rawValue: $0.element)) }
        }
        let stand8 = BraidMethodCatalog.stand8
        let wanted: [(BraidRecipe, [[UInt64]])] = [
            (BraidMethodCatalog.yatsuKongoS8Recipe, [[0x51e3_a183_f144_ac91], [0x1ec7_26ed_0c36_f1f3], [0xde18_b909_3438_c99d]]),
            (BraidMethodCatalog.yatsuKongoZ8Recipe, [[0x8637_cdab_d731_39ed], [0x52c2_e9c6_6d09_9340], [0x5aa5_de39_dfd1_04d1]]),
            (BraidMethodCatalog.yatsuKongoGaeshi8Recipe, [[0xe0d5_b357_56d7_4fad], [0x8b24_04a4_7723_923d], [0x4e5e_d52e_17ca_9105]]),
        ]
        for (recipe, hashes) in wanted {
            let worked = try #require(recipe.worked(on: stand8))
            for (colouring, hash) in zip([recipe.colouring, byPlace(eight), byPlace(fourColours)], hashes) {
                let pattern = try #require(RoundTube8SurfacePatternGenerator.generate(
                    stand: stand8, rounds: worked.derivation.rounds, crossSection: worked.section,
                    assignments: colouring))
                #expect(pattern.bundle == .standard)
                let image = try #require(RoundTube8CardImage.draw(pattern, bundle: pattern.bundle))
                #expect(Self.hash(image) == hash[0], "\(recipe.id)")
            }
        }
        let recipe4 = BraidMethodCatalog.maruYotsu4Recipe
        let stand4 = BraidMethodCatalog.stand4
        let worked4 = try #require(recipe4.worked(on: stand4))
        for (colouring, hash) in zip([recipe4.colouring, byPlace(["red", "white", "blue", "yellow"])],
                                     [UInt64(0x425e_124a_664d_4645), 0x5302_de1f_13ce_04a1]) {
            let pattern = try #require(RoundTube4SurfacePatternGenerator.generate(
                stand: stand4, rounds: worked4.derivation.rounds, crossSection: worked4.section,
                assignments: colouring))
            let image = try #require(RoundTube4CardImage.draw(pattern, bundle: .standard))
            #expect(Self.hash(image) == hash, "\(recipe4.id)")
        }
    }
}
