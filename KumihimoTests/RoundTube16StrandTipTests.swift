import Foundation
import simd
import Testing
@testable import Kumihimo

/// Task 047: a maru-genji strand passing over now laps twice as far and slides
/// under the next strand gently, its texture spans the laps, and it is shaded only
/// where it goes under. These hold what that changed; the look itself was judged
/// against the photograph, not here.
struct RoundTube16StrandTipTests {
    // MARK: - Colour does not move the shape

    @Test func aColouringMovesNoVertexAndOnePositionRecoloursOnlyItsOwnThread() throws {
        let plain = (1...16).map { ThreadAssignment(position: $0, colorID: blue) }
        var one = plain
        one[2] = ThreadAssignment(position: 3, colorID: pink)

        let plainPattern = try #require(RoundTube16SurfacePatternGenerator.generate(assignments: plain))
        let onePattern = try #require(RoundTube16SurfacePatternGenerator.generate(assignments: one))
        let plainMesh = try #require(RoundTube16SurfaceMesh.generate(pattern: plainPattern))
        let oneMesh = try #require(RoundTube16SurfaceMesh.generate(pattern: onePattern))

        #expect(plainMesh.positions == oneMesh.positions)
        #expect(plainMesh.normals == oneMesh.normals)
        #expect(plainMesh.textureCoordinates == oneMesh.textureCoordinates)

        // The pink is exactly thread 3's strands: none of anyone else's, and
        // every one of its own.
        let pinkVertices = Set((oneMesh.colorGroups[pink] ?? []).map(Int.init))
        #expect(!pinkVertices.isEmpty)
        let threeSegments = Set(onePattern.patches.indices.filter {
            onePattern.patches[$0].threadPosition == 3
        })
        let pinkVertexSegments = Set(pinkVertices.map { oneMesh.vertexSegmentIndices[$0] })
        #expect(pinkVertexSegments == threeSegments)
    }

    // MARK: - The tip goes under

    /// On the drawn mesh, not on the centreline: near the tip of every lap, some
    /// other strand stands higher at the same place, so the tip is hidden; at the
    /// strand's own end, where it crosses, nothing stands higher, so it is on top.
    @Test func everyLapTipEndsBeneathAnotherStrandWhileItsEndStaysOnTop() throws {
        let pattern = try #require(RoundTube16SurfacePatternGenerator.generate(assignments: fixture))
        let mesh = try #require(RoundTube16SurfaceMesh.generate(pattern: pattern))
        let lap = RoundTube16SurfaceMesh.overCrossingLap
        let radius = mesh.baseRadius

        // Surface points laid flat: along the braid, and round it as arc length.
        let flat = mesh.positions.map { point -> SIMD2<Float> in
            let angle = atan2(point.z, point.y)
            return SIMD2<Float>(point.x, angle * radius)
        }
        let radii = mesh.positions.map { simd_length(SIMD2<Float>($0.y, $0.z)) }
        let circumference = 2 * Float.pi * radius

        // Bucketed so each question looks at a few hundred vertices, not all.
        let cell: Float = 0.03
        func key(_ point: SIMD2<Float>) -> SIMD2<Int32> {
            SIMD2<Int32>(Int32((point.x / cell).rounded(.down)),
                         Int32((point.y / cell).rounded(.down)))
        }
        var buckets = [SIMD2<Int32>: [Int]]()
        for index in mesh.positions.indices where !mesh.vertexIsCrossingWall[index] {
            buckets[key(flat[index]), default: []].append(index)
        }
        let wrap = Int32((circumference / cell).rounded(.up))

        func highestOther(than segment: Int, near index: Int, within reach: Float) -> Float {
            var highest = -Float.infinity
            let centre = key(flat[index])
            for dx in Int32(-1)...1 {
                for dy in Int32(-1)...1 {
                    for shift in [Int32(0), wrap, -wrap] {
                        let bucket = SIMD2<Int32>(centre.x + dx, centre.y + dy + shift)
                        for other in buckets[bucket] ?? []
                        where mesh.vertexSegmentIndices[other] != segment {
                            var offset = flat[other] - flat[index]
                            offset.y = remainder(offset.y, circumference)
                            guard simd_length(offset) < reach else { continue }
                            highest = max(highest, radii[other])
                        }
                    }
                }
            }
            return highest
        }

        var tipsChecked = 0
        var endsChecked = 0
        // Away from the tile ends, where the neighbouring repeat is clipped away.
        let inner = Float(0.3) * mesh.length
        for index in mesh.positions.indices
        where !mesh.vertexIsCrossingWall[index]
            && abs(mesh.strandCoordinates[index].y) < 0.001
            && abs(mesh.positions[index].x) < inner {
            let segment = mesh.vertexSegmentIndices[index]
            guard pattern.patches[segment].layer == .over else { continue }
            let along = mesh.strandCoordinates[index].x
            let pastTheEnd = max(-along, along - 1)
            if abs(pastTheEnd - lap) < 0.001 {
                #expect(highestOther(than: segment, near: index, within: 0.03) > radii[index])
                tipsChecked += 1
            } else if abs(pastTheEnd) < 0.001 {
                #expect(highestOther(than: segment, near: index, within: 0.01) <= radii[index] + 0.000_1)
                endsChecked += 1
            }
        }
        #expect(tipsChecked >= 8)
        #expect(endsChecked >= 8)
    }

    // MARK: - Shading follows what is hidden

    @Test func aStrandIsShadedWhereItGoesUnderAndNotWhereItLiesOnTop() {
        let dark = RoundTube16StrandTextureFactory.crossingOcclusion
        let lap = RoundTube16SurfaceMesh.overCrossingLap
        typealias Factory = RoundTube16StrandTextureFactory

        for along in stride(from: Float(0), through: 1, by: 0.05) {
            #expect(Factory.crossingShade(along: along, layer: .over) == 1)
        }
        #expect(abs(Factory.crossingShade(along: 1 + lap, layer: .over) - dark) < 0.000_1)
        #expect(abs(Factory.crossingShade(along: -lap, layer: .over) - dark) < 0.000_1)

        #expect(abs(Factory.crossingShade(along: 0, layer: .under) - dark) < 0.000_1)
        #expect(abs(Factory.crossingShade(along: 1, layer: .under) - dark) < 0.000_1)
        #expect(Factory.crossingShade(along: 0.5, layer: .under) == 1)
    }

    // MARK: - The stripes run on into the lap

    @Test func aLappingStrandsTextureSpansItsLapsAndNoOtherStrandsDoes() throws {
        let lap = RoundTube16SurfaceMesh.overCrossingLap
        #expect(RoundTube16SurfaceMesh.textureAlong(-lap, layer: .over) == 0)
        #expect(abs(RoundTube16SurfaceMesh.textureAlong(1 + lap, layer: .over) - 1) < 0.000_1)
        for along in stride(from: Float(0), through: 1, by: 0.125) {
            #expect(RoundTube16SurfaceMesh.textureAlong(along, layer: .under) == along)
            let back = RoundTube16SurfaceMesh.strandAlong(
                forTextureAlong: RoundTube16SurfaceMesh.textureAlong(along, layer: .over),
                layer: .over
            )
            #expect(abs(back - along) < 0.000_1)
        }

        // On the mesh: the texture column every vertex reads stands for the place
        // along the strand the vertex is at, laps included. Were the lap clamped,
        // every vertex on it would read the last column.
        let pattern = try #require(RoundTube16SurfacePatternGenerator.generate(assignments: fixture))
        let mesh = try #require(RoundTube16SurfaceMesh.generate(pattern: pattern))
        var lapVertices = 0
        for index in mesh.positions.indices where !mesh.vertexIsCrossingWall[index] {
            let layer = pattern.patches[mesh.vertexSegmentIndices[index]].layer
            let along = mesh.strandCoordinates[index].x
            let read = RoundTube16SurfaceMesh.strandAlong(
                forTextureAlong: mesh.textureCoordinates[index].x, layer: layer
            )
            #expect(abs(read - along) < 0.001)
            if along > 1.001 || along < -0.001 { lapVertices += 1 }
        }
        #expect(lapVertices > 1_000)
    }

    // MARK: - Fixtures

    private let blue = ThreadColorID(rawValue: "blue")
    private let pink = ThreadColorID(rawValue: "pink")

    private var fixture: [ThreadAssignment] {
        (1...16).map {
            ThreadAssignment(position: $0, colorID: ($0 % 4 < 2) ? blue : pink)
        }
    }
}
