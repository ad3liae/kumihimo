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

    /// **Changed once, on purpose** (Task 030). It was
    /// `0x78b4_526d_00e7_4a38` while the stitch lean was dropped at the two ends of
    /// the tile, which left one join in every four running straight at an edge. The
    /// lean now applies at every join, so every vertex on an edge join at rows 0 and
    /// 4 moved. **The vertex count did not change** — the same surface, tipped.
    @Test func theFlatBraidsMeshIsTheShapeItWas() throws {
        let pattern = try #require(Flat16SurfacePatternGenerator.generate(
            assignments: BraidMethodCatalog.hiraGenji16Colouring))
        let mesh = try #require(Flat16SurfaceMesh.generate(pattern: pattern))
        #expect(mesh.positions.count == 366_552)
        #expect(Self.hash(mesh.positions) == 0x53c4_4c9b_835a_e598)
    }

    @Test func theRoundBraidsMeshIsTheShapeItWas() throws {
        let pattern = try #require(RoundTube16SurfacePatternGenerator.generate(
            assignments: BraidMethodCatalog.maruGenji16Colouring))
        let mesh = try #require(RoundTube16SurfaceMesh.generate(pattern: pattern))
        #expect(mesh.positions.count == 294_936)
        #expect(Self.hash(mesh.positions) == 0xe3fc_af47_ceea_d34e)
    }
}
