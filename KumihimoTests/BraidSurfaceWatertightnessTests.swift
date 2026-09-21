import Foundation
import simd
import Testing
@testable import Kumihimo

/// Checks that a braid surface is closed, which is what the first attempt at
/// Task 007E broke: neighbouring strands stopped sharing the valley between them
/// and the background showed through the face.
///
/// Two invariants are checked, and they are not the same strength, because the
/// two braids are not built the same way.
///
/// The round braid's mesh is a shell of overlapping strand patches plus short
/// walls that plug the step at a crossing. It is deliberately not a closed
/// manifold: measured on the current mesh, 10,760 of its edges belong to one
/// triangle rather than two, 3,072 belong to more than two, and 667 of 4,000
/// sampled strand rims lie up to 0.058 away from any other strand's surface.
/// Those are the laps, the walls, and the T-junctions where two strands
/// subdivide the valley they share by different steps. None of them is a hole.
/// So the round braid is held to the weaker invariant, which is the one the
/// reported fault actually breaks: **no line of sight inside the braid's own
/// outline reaches the background.**
///
/// **The flat braid's mesh was a conforming grid and is not one any more**
/// (Task 050). Each cell is now drawn as a bundle wider than its lane and longer
/// than its step, lying over its neighbours' flanks and diving under them where
/// a thread leaves the face, with the floor of each cell beneath. So it is the
/// same kind of thing the round braid's is, and it is held to the same weaker
/// invariant. The two strong ones — every interior edge used twice, every rim a
/// vertex of the neighbour — were true of the grid and say nothing about a shell
/// of overlapping runs; they are not weakened here but replaced by the one they
/// were standing in for.
///
/// **And the line of sight is taken inside the braid's own plain outline, not
/// out to the furthest thing the mesh draws.** A finished braid's silhouette
/// ripples once a stitch as each yarn rises and falls — that ripple is what
/// `crestHeightRatio` was measured from (Task 007E) — so a ray passing between
/// two crests really does see the background, and requiring otherwise would be
/// requiring the braid not to have the shape it was measured to have.
struct BraidSurfaceWatertightnessTests {
    @Test func maruGenjiSurfaceIsOpaqueFromEveryLineOfSight() throws {
        let pattern = try #require(
            RoundTube16SurfacePatternGenerator.generate(assignments: fixture)
        )
        let mesh = try #require(RoundTube16SurfaceMesh.generate(pattern: pattern))

        for axis in SurfaceOpacityAudit.Axis.allCases {
            let audit = SurfaceOpacityAudit(
                positions: mesh.positions,
                indices: mesh.allTriangleIndices,
                tileEndX: mesh.length / 2,
                axis: axis
            )
            #expect(audit.rays > 1_000)
            #expect(audit.raysReachingTheBackground == 0)
            #expect(audit.raysMeetingOneSurfaceOnly == 0)
        }
    }

    @Test func hiraGenjiSurfaceIsOpaqueInsideItsOwnOutline() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: fixture)
        )
        let mesh = try #require(Flat16SurfaceMesh.generate(pattern: pattern))
        // The plain cross-section the cells are laid on: everything inside it is
        // braid, and the crests stand out of it.
        let halfWidth = Flat16SurfaceMesh.defaultHalfWidth
        let halfThickness = Flat16SurfaceMesh.defaultHalfThickness

        for axis in SurfaceOpacityAudit.Axis.allCases {
            let reach = axis == .faceOn ? halfWidth : halfThickness
            let audit = SurfaceOpacityAudit(
                positions: mesh.positions,
                indices: mesh.allTriangleIndices,
                tileEndX: Flat16SurfaceMesh.defaultLength / 2,
                axis: axis,
                bounds: (low: -reach, high: reach)
            )
            #expect(audit.rays > 1_000)
            #expect(audit.raysReachingTheBackground == 0,
                    "first gap at \(String(describing: audit.firstGap))")
            #expect(audit.raysMeetingOneSurfaceOnly == 0,
                    "first gap at \(String(describing: audit.firstGap))")
        }
    }

    /// **And the crests outside that outline are what the ripple is**, so the
    /// mesh does reach further than the plain section right round: the check
    /// above is about the braid's inside, not a looser version of one about its
    /// silhouette.
    @Test func hiraGenjiStandsProudOfThePlainOutlineRightRound() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: fixture)
        )
        let mesh = try #require(Flat16SurfaceMesh.generate(pattern: pattern))
        let crest = Flat16SurfaceMesh.defaultHalfThickness
            * Flat16SurfaceMesh.crestHeightRatio

        let widest = mesh.positions.map { abs($0.y) }.max() ?? 0
        let thickest = mesh.positions.map { abs($0.z) }.max() ?? 0
        #expect(widest > Flat16SurfaceMesh.defaultHalfWidth + crest * 0.8)
        #expect(thickest > Flat16SurfaceMesh.defaultHalfThickness + crest * 0.8)
    }

    private var fixture: [ThreadAssignment] {
        (1...16).map {
            ThreadAssignment(
                position: $0,
                colorID: ThreadColorCatalog.colors[$0 % ThreadColorCatalog.colors.count].id
            )
        }
    }
}

/// Looks along one axis across the braid. Every line of sight that falls inside
/// the braid's own outline has to meet the surface twice, once on the way in and
/// once on the way out; one crossing or none is a hole.
///
/// Both axes across the braid are used. The face-on rays are pulled in from the
/// outline so a grazing ray tells us nothing, which leaves the last few per cent
/// at either edge unsampled; the rays from the side pass straight through that
/// band, and through anything only an oblique view would show.
struct SurfaceOpacityAudit {
    enum Axis: CaseIterable {
        /// Along the braid's thickness, the way the camera looks at it.
        case faceOn
        /// Across the braid's width, from one edge to the other.
        case fromTheSide

        func across(of point: SIMD3<Float>) -> Float {
            self == .faceOn ? point.y : point.z
        }
    }

    /// Lines of sight across the braid and down its length. The outline is pulled
    /// in by `inset` so the rim itself is never sampled — a ray grazing the
    /// silhouette tells us nothing.
    static let acrossSteps = 36
    static let alongSteps = 60
    static let inset: Float = 0.04

    let axis: Axis
    let rays: Int
    let raysReachingTheBackground: Int
    let raysMeetingOneSurfaceOnly: Int
    let firstGap: SIMD2<Float>?

    /// `bounds` fixes how far across the braid the rays are spread. Given, they
    /// are the caller's — the braid's own plain outline, say; left out, they are
    /// taken from the triangles the column holds, inset by `inset`.
    init(
        positions: [SIMD3<Float>],
        indices: [UInt32],
        tileEndX: Float,
        axis: Axis,
        bounds: (low: Float, high: Float)? = nil
    ) {
        self.axis = axis
        // The two ends of the tile are open by design, so stay clear of them.
        let low = -tileEndX + tileEndX * 0.15
        let high = tileEndX - tileEndX * 0.15
        var columns = [[Triangle]](repeating: [], count: Self.alongSteps)
        let span = high - low

        for offset in stride(from: 0, to: indices.count - 2, by: 3) {
            let triangle = Triangle(
                a: positions[Int(indices[offset])],
                b: positions[Int(indices[offset + 1])],
                c: positions[Int(indices[offset + 2])],
                axis: axis
            )
            let first = Int(((triangle.minimumX - low) / span * Float(Self.alongSteps))
                .rounded(.down))
            let last = Int(((triangle.maximumX - low) / span * Float(Self.alongSteps))
                .rounded(.down))
            let lowColumn = max(0, first)
            let highColumn = min(Self.alongSteps - 1, last)
            guard lowColumn <= highColumn else { continue }
            for column in lowColumn...highColumn {
                columns[column].append(triangle)
            }
        }

        var rayCount = 0, missed = 0, single = 0
        var gap: SIMD2<Float>?
        for column in 0..<Self.alongSteps {
            // Offset by an irrational fraction so a ray never lands on a shared edge.
            let x = low + span * (Float(column) + 0.381_966) / Float(Self.alongSteps)
            let crossing = columns[column].filter { $0.minimumX <= x && $0.maximumX >= x }
            guard !crossing.isEmpty else { continue }
            let corners = crossing.flatMap {
                [axis.across(of: $0.a), axis.across(of: $0.b), axis.across(of: $0.c)]
            }
            let bottom = bounds?.low ?? (corners.min() ?? 0)
            let top = bounds?.high ?? (corners.max() ?? 0)
            let margin = bounds == nil ? (top - bottom) * Self.inset : 0
            guard top - bottom > 2 * margin else { continue }

            for step in 0..<Self.acrossSteps {
                let y = bottom + margin + (top - bottom - 2 * margin)
                    * (Float(step) + 0.618_034) / Float(Self.acrossSteps)
                let hits = crossing.count { $0.isCrossedByRay(x: x, across: y) }
                rayCount += 1
                if hits == 0 {
                    missed += 1
                    if gap == nil { gap = SIMD2<Float>(x, y) }
                } else if hits == 1 {
                    single += 1
                    if gap == nil { gap = SIMD2<Float>(x, y) }
                }
            }
        }
        rays = rayCount
        raysReachingTheBackground = missed
        raysMeetingOneSurfaceOnly = single
        firstGap = gap
    }

    struct Triangle {
        let a: SIMD3<Float>
        let b: SIMD3<Float>
        let c: SIMD3<Float>
        let axis: Axis

        var minimumX: Float { min(a.x, b.x, c.x) }
        var maximumX: Float { max(a.x, b.x, c.x) }

        /// A ray parallel to the chosen axis passes through this triangle when the
        /// point lands inside its shadow on the plane the axis looks along.
        func isCrossedByRay(x: Float, across: Float) -> Bool {
            let first = SIMD2<Float>(b.x - a.x, axis.across(of: b) - axis.across(of: a))
            let second = SIMD2<Float>(c.x - a.x, axis.across(of: c) - axis.across(of: a))
            let point = SIMD2<Float>(x - a.x, across - axis.across(of: a))
            let denominator = first.x * second.y - second.x * first.y
            guard abs(denominator) > 1e-12 else { return false }
            let u = (point.x * second.y - second.x * point.y) / denominator
            let v = (first.x * point.y - point.x * first.y) / denominator
            return u >= 0 && v >= 0 && u + v <= 1
        }
    }
}

/// Counts how many triangles use each edge. The generators write a fresh vertex
/// per triangle corner, so points are merged by position first.
struct SurfaceEdgeAudit {
    static let tolerance: Float = 0.000_1

    let mergedPointCount: Int
    let triangleCount: Int
    let trianglesWithARepeatedCorner: Int
    let edgesUsedOnce: Int
    let edgesUsedTwice: Int
    let edgesUsedMoreThanTwice: Int
    let tileEndBoundaryEdges: Int
    let interiorBoundaryEdges: Int

    init(positions: [SIMD3<Float>], indices: [UInt32], tileEndX: Float) {
        let merger = PointMerger(tolerance: Self.tolerance)
        let canonical = positions.map(merger.index(of:))
        var uses = [Edge: Int]()
        var repeatedCorners = 0

        for offset in stride(from: 0, to: indices.count - 2, by: 3) {
            let corners = (0..<3).map { canonical[Int(indices[offset + $0])] }
            guard Set(corners).count == 3 else {
                repeatedCorners += 1
                continue
            }
            for side in 0..<3 {
                uses[Edge(corners[side], corners[(side + 1) % 3]), default: 0] += 1
            }
        }

        mergedPointCount = merger.pointCount
        triangleCount = indices.count / 3
        trianglesWithARepeatedCorner = repeatedCorners
        edgesUsedOnce = uses.values.count { $0 == 1 }
        edgesUsedTwice = uses.values.count { $0 == 2 }
        edgesUsedMoreThanTwice = uses.values.count { $0 > 2 }

        let boundary = uses.filter { $0.value == 1 }.keys
        let onTileEnd = boundary.count { edge in
            [edge.low, edge.high].allSatisfy {
                abs(abs(merger.point(at: $0).x) - tileEndX) < 0.001
            }
        }
        tileEndBoundaryEdges = onTileEnd
        interiorBoundaryEdges = boundary.count - onTileEnd
    }

    private struct Edge: Hashable {
        let low: Int
        let high: Int

        init(_ first: Int, _ second: Int) {
            low = min(first, second)
            high = max(first, second)
        }
    }
}

/// Checks that a vertex on the rim of one group of triangles is a vertex of some
/// other group too, so the two meet rather than merely abut.
struct SharedRimAudit {
    let checkedVertices: Int
    let verticesWithNoNeighbour: Int

    init(
        positions: [SIMD3<Float>],
        groupOfVertex: [Int],
        isOnARim: [Bool],
        tileEndX: Float
    ) {
        let merger = PointMerger(tolerance: SurfaceEdgeAudit.tolerance)
        let canonical = positions.map(merger.index(of:))
        var groupsAtPoint = [Int: Set<Int>]()
        for index in positions.indices {
            groupsAtPoint[canonical[index], default: []].insert(groupOfVertex[index])
        }

        var checked = 0
        var alone = 0
        for index in positions.indices where isOnARim[index] {
            // A rim cut off by the end of the tile has no neighbour inside it.
            guard abs(abs(positions[index].x) - tileEndX) >= 0.001 else { continue }
            checked += 1
            if (groupsAtPoint[canonical[index]] ?? []).count < 2 {
                alone += 1
            }
        }
        checkedVertices = checked
        verticesWithNoNeighbour = alone
    }
}

/// Merges points standing in the same place: a hash of integer cells, checking
/// the neighbouring cells too so a pair straddling a cell edge still merges.
final class PointMerger {
    private let tolerance: Float
    private var cells = [SIMD3<Int32>: [Int]]()
    private var points = [SIMD3<Float>]()

    init(tolerance: Float) {
        self.tolerance = tolerance
    }

    var pointCount: Int { points.count }

    func point(at index: Int) -> SIMD3<Float> { points[index] }

    func index(of position: SIMD3<Float>) -> Int {
        let cell = self.cell(of: position)
        for dx in -1...1 {
            for dy in -1...1 {
                for dz in -1...1 {
                    let neighbour = cell &+ SIMD3<Int32>(Int32(dx), Int32(dy), Int32(dz))
                    for candidate in cells[neighbour] ?? []
                    where simd_distance(points[candidate], position) <= tolerance {
                        return candidate
                    }
                }
            }
        }
        points.append(position)
        cells[cell, default: []].append(points.count - 1)
        return points.count - 1
    }

    private func cell(of position: SIMD3<Float>) -> SIMD3<Int32> {
        SIMD3<Int32>(
            Int32((position.x / tolerance).rounded(.down)),
            Int32((position.y / tolerance).rounded(.down)),
            Int32((position.z / tolerance).rounded(.down))
        )
    }
}
