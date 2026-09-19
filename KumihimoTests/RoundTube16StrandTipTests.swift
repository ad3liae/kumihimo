import Foundation
import simd
import Testing
@testable import Kumihimo

/// Task 047: every cell is drawn as a bundle that reaches past its cell; one
/// passing over goes on across the crossing over the end of the one passing
/// under, its texture spans all of it, and it is shaded only where it goes under.
/// These hold what that changed; the look itself was judged against the
/// author's sketch and the photographs, not here.
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

    // MARK: - Who covers whom at a crossing, on the drawn triangles

    /// On the drawn mesh, by the triangles themselves (Task 047 review, addendum
    /// 1): at a place on a bundle, a line out from the braid's axis through that
    /// place is followed and **every triangle it crosses** is found. Whatever
    /// crosses it further out covers the place. Nothing here reads a nearby
    /// vertex's height as cover.
    ///
    /// At every crossing in the middle of the tile, on the crest and about 0.6 of
    /// the way to each rim:
    /// - the end of a bundle passing under is covered, by a bundle of **another
    ///   thread** passing over;
    /// - the end of a bundle passing over has nothing over it;
    /// - the tip of the lap a bundle passing over runs on into is covered, by
    ///   another bundle.
    /// These are claims at those points only, not over the whole width or path.
    @Test func atEveryCrossingTheBundleGoingOnCoversTheEndOfTheOneGoingUnder() throws {
        let pattern = try #require(RoundTube16SurfacePatternGenerator.generate(assignments: fixture))
        let mesh = try #require(RoundTube16SurfaceMesh.generate(pattern: pattern))
        let lines = RadialLines(mesh: mesh)
        let lap = RoundTube16SurfaceMesh.overCrossingLap
        let inner = Float(0.3) * mesh.length
        // The crest, and a sample about 0.6 of the way to each rim.
        let across = [Float(0), RoundTube16SurfaceMesh.crossSectionOffset(forSample: 0.3),
                      RoundTube16SurfaceMesh.crossSectionOffset(forSample: 0.7)]

        var underEnds = 0, overEnds = 0, lapTips = 0
        for index in mesh.positions.indices
        where !mesh.vertexIsBeneath[index] && abs(mesh.positions[index].x) < inner {
            let coordinate = mesh.strandCoordinates[index]
            guard across.contains(where: { abs(coordinate.y - $0) < 0.001 }) else { continue }
            let segment = mesh.vertexSegmentIndices[index]
            let patch = pattern.patches[segment]
            let own = radius(mesh.positions[index])
            let isEnd = abs(coordinate.x) < 0.001 || abs(coordinate.x - 1) < 0.001
            let isLapTip = abs(RoundTube16SurfaceMesh.pastTheEnd(coordinate.x) - lap) < 0.001
            guard isEnd || (isLapTip && patch.layer == .over) else { continue }

            let covering = lines.crossings(at: mesh.positions[index])
                .filter { $0.radius > own + 0.000_5 && $0.segment != segment }
            if patch.layer == .under {
                let cover = covering.max { $0.radius < $1.radius }
                #expect(cover != nil)
                if let cover {
                    #expect(!cover.isBeneath)
                    #expect(pattern.patches[cover.segment].layer == .over)
                    #expect(pattern.patches[cover.segment].threadPosition != patch.threadPosition)
                }
                underEnds += 1
            } else if isEnd {
                #expect(covering.isEmpty)
                overEnds += 1
            } else {
                #expect(!covering.isEmpty)
                lapTips += 1
            }
        }
        #expect(underEnds >= 24)
        #expect(overEnds >= 24)
        #expect(lapTips >= 24)
    }

    /// The line test itself, on two made-up triangles. A triangle whose corners
    /// stand high beside the line but which does not reach it does not cover;
    /// one whose corners are all far away but whose inside the line passes
    /// through does.
    @Test func aTriangleCoversALineOnlyWhereTheLineCrossesIt() {
        let through = SIMD3<Float>(0, 0.5, 0)       // x 0, angle 0, radius 0.5
        let beside = [                                  // tall, but off to one side
            SIMD3<Float>(0.02, 0.9, 0.05), SIMD3<Float>(0.06, 0.9, 0.05),
            SIMD3<Float>(0.04, 0.9, 0.09),
        ]
        let across = [                                  // corners far, inside on the line
            SIMD3<Float>(-0.4, 0.6, -0.4), SIMD3<Float>(0.4, 0.6, -0.4),
            SIMD3<Float>(0, 0.6, 0.5),
        ]
        #expect(RadialLines.crossing(at: through, triangle: beside) == nil)
        let hit = RadialLines.crossing(at: through, triangle: across)
        #expect(hit != nil)
        #expect(abs((hit ?? 0) - 0.6) < 0.000_1)
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

    @Test func aBundlesTextureSpansAllOfItPastItsCellsEnds() throws {
        for layer in BraidCrossingLayer.allCases {
            let reach = RoundTube16SurfaceMesh.pastTheEnds(layer: layer)
            #expect(RoundTube16SurfaceMesh.textureAlong(-reach, layer: layer) == 0)
            #expect(abs(RoundTube16SurfaceMesh.textureAlong(1 + reach, layer: layer) - 1) < 0.000_1)
            for along in stride(from: -reach, through: 1 + reach, by: 0.125) {
                let back = RoundTube16SurfaceMesh.strandAlong(
                    forTextureAlong: RoundTube16SurfaceMesh.textureAlong(along, layer: layer),
                    layer: layer
                )
                #expect(abs(back - along) < 0.000_1)
            }
        }
        #expect(RoundTube16SurfaceMesh.pastTheEnds(layer: .over)
            > RoundTube16SurfaceMesh.pastTheEnds(layer: .under))

        // On the mesh: the texture column every vertex reads stands for the place
        // along the bundle the vertex is at, past the ends included. Were it
        // clamped, every vertex past an end would read the last column.
        let pattern = try #require(RoundTube16SurfacePatternGenerator.generate(assignments: fixture))
        let mesh = try #require(RoundTube16SurfaceMesh.generate(pattern: pattern))
        var lapVertices = 0
        for index in mesh.positions.indices where !mesh.vertexIsBeneath[index] {
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

    private func radius(_ point: SIMD3<Float>) -> Float {
        simd_length(SIMD2<Float>(point.y, point.z))
    }
}

/// Lines out from the braid's axis, and the drawn triangles they cross. The
/// triangles are sorted into cells of length and angle once, so each question
/// looks at a few of them rather than all.
struct RadialLines {
    struct Crossing {
        let radius: Float
        let segment: Int
        let isBeneath: Bool
    }

    private let positions: [SIMD3<Float>]
    private let triangles: [Int]            // first vertex of each triangle
    private let segments: [Int]
    private let beneath: [Bool]
    private var cells = [SIMD2<Int32>: [Int]]()
    private static let cellLength: Float = 0.05
    private static let cellAngle: Float = 0.05

    init(mesh: RoundTube16SurfaceMeshData) {
        positions = mesh.positions
        segments = mesh.vertexSegmentIndices
        beneath = mesh.vertexIsBeneath
        let indices = mesh.allTriangleIndices
        triangles = stride(from: 0, to: indices.count, by: 3).map { Int(indices[$0]) }
        for (number, first) in triangles.enumerated() {
            let corners = (0..<3).map { mesh.positions[first + $0] }
            var angles = corners.map { atan2($0.z, $0.y) }
            if (angles.max() ?? 0) - (angles.min() ?? 0) > .pi {
                angles = angles.map { $0 < 0 ? $0 + 2 * .pi : $0 }
            }
            let xs = corners.map(\.x)
            for shift in [Float(0), -2 * .pi] {
                let low = Self.key(x: xs.min() ?? 0, angle: (angles.min() ?? 0) + shift)
                let high = Self.key(x: xs.max() ?? 0, angle: (angles.max() ?? 0) + shift)
                for x in low.x...high.x {
                    for a in low.y...high.y { cells[SIMD2(x, a), default: []].append(number) }
                }
            }
        }
    }

    private static func key(x: Float, angle: Float) -> SIMD2<Int32> {
        SIMD2(Int32((x / cellLength).rounded(.down)), Int32((angle / cellAngle).rounded(.down)))
    }

    /// Every drawn triangle the line out through `point` crosses.
    func crossings(at point: SIMD3<Float>) -> [Crossing] {
        let key = Self.key(x: point.x, angle: atan2(point.z, point.y))
        var seen = Set<Int>()
        var out = [Crossing]()
        for number in cells[key] ?? [] where seen.insert(number).inserted {
            let first = triangles[number]
            let corners = (0..<3).map { positions[first + $0] }
            if let radius = Self.crossing(at: point, triangle: corners) {
                out.append(Crossing(radius: radius, segment: segments[first],
                                    isBeneath: beneath[first]))
            }
        }
        return out
    }

    /// Where the line from the axis out through `point` crosses a triangle, as
    /// a radius, or `nil` if it does not. Möller–Trumbore.
    static func crossing(at point: SIMD3<Float>, triangle: [SIMD3<Float>]) -> Float? {
        let out = simd_normalize(SIMD3<Float>(0, point.y, point.z))
        let origin = SIMD3<Float>(point.x, 0, 0)
        let edge1 = triangle[1] - triangle[0]
        let edge2 = triangle[2] - triangle[0]
        let p = simd_cross(out, edge2)
        let determinant = simd_dot(edge1, p)
        guard abs(determinant) > 1e-12 else { return nil }
        let t0 = origin - triangle[0]
        // A hair of slack, so a line running exactly along the edge two
        // triangles share is not missed by both of them to rounding. Points on a
        // column's edge are exactly that.
        let slack: Float = 0.000_01
        let u = simd_dot(t0, p) / determinant
        guard u >= -slack, u <= 1 + slack else { return nil }
        let q = simd_cross(t0, edge1)
        let v = simd_dot(out, q) / determinant
        guard v >= -slack, u + v <= 1 + slack else { return nil }
        let distance = simd_dot(edge2, q) / determinant
        return distance > 0 ? distance : nil
    }
}
