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
        let pattern = try #require(Flat16SurfacePatternGenerator.generate(
            assignments: BraidMethodCatalog.hiraGenji16Colouring))
        let mesh = try #require(Flat16SurfaceMesh.generate(pattern: pattern))
        #expect(mesh.positions.count == 361_350)
        #expect(Self.hash(mesh.positions) == 0x2df5_8dcc_177c_b981)
    }

    /// **Changed on purpose in Task 047.** `0xe3fc_af47_ceea_d34e` over 294,936
    /// vertices until then. The rework draws every cell as a bundle of its own,
    /// every bundle alike, that reaches past its cell and overlaps its
    /// neighbours, with a floor beneath and no walls; and the repeat is 1.25 turns
    /// long rather than 0.65.
    @Test func theRoundBraidsMeshIsTheShapeItWas() throws {
        let pattern = try #require(RoundTube16SurfacePatternGenerator.generate(
            assignments: BraidMethodCatalog.maruGenji16Colouring))
        let mesh = try #require(RoundTube16SurfaceMesh.generate(pattern: pattern))
        #expect(mesh.positions.count == 303_840)
        #expect(Self.hash(mesh.positions) == 0x4bd9_d069_9c8f_9734)
    }
}
