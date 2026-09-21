import CoreGraphics
import Foundation
import simd
import Testing
@testable import Kumihimo

/// **The card and the solid show the same thread at the same place on the
/// braid** (Task 050 §5).
///
/// The solid decides what shows by depth: of every surface on a line out of the
/// braid, the outermost is seen. This reads that off the real generated
/// triangles — a ray along the outward normal of the cross-section, every
/// triangle it crosses, the outermost hit — and holds the card's own rule
/// against it at the same place round the braid and along it.
///
/// **Nothing here compares pictures**, and nothing recomputes the product's own
/// arithmetic and calls the answer agreement: one side is the mesh's triangles,
/// the other is `Flat16SurfacePattern.runsStanding`, and they are built by
/// different code from the same pattern.
struct Flat16CardAgreesWithSolidTests {
    private static let shape = Flat16BundleShape.standard

    private static var assignments: [ThreadAssignment] {
        // Sixteen told apart, so a disagreement names a thread rather than a
        // colour two threads share.
        (1...16).map {
            ThreadAssignment(
                position: $0,
                colorID: ThreadColorCatalog.colors[$0 % ThreadColorCatalog.colors.count].id
            )
        }
    }

    /// The outermost drawn triangle on the way out of the braid, at a place.
    private struct Solid {
        let mesh: Flat16SurfaceMeshData
        let halfWidth: Float
        let halfThickness: Float
        let length: Float
        private let triangles: [SIMD3<Int>]
        private var bins: [[Int]]
        static let binsAlong = 128

        init(mesh: Flat16SurfaceMeshData, halfWidth: Float, halfThickness: Float, length: Float) {
            self.mesh = mesh
            self.halfWidth = halfWidth
            self.halfThickness = halfThickness
            self.length = length
            let indices = mesh.allTriangleIndices
            triangles = stride(from: 0, to: indices.count, by: 3).map {
                SIMD3(Int(indices[$0]), Int(indices[$0 + 1]), Int(indices[$0 + 2]))
            }
            bins = Array(repeating: [], count: Self.binsAlong)
            for (index, triangle) in triangles.enumerated() {
                let xs = [triangle.x, triangle.y, triangle.z].map { mesh.positions[$0].x }
                let low = Int(((xs.min()! + length / 2) / length * Float(Self.binsAlong))
                    .rounded(.down)) - 1
                let high = Int(((xs.max()! + length / 2) / length * Float(Self.binsAlong))
                    .rounded(.up)) + 1
                for bin in max(0, low)...min(Self.binsAlong - 1, max(0, high)) {
                    bins[bin].append(index)
                }
            }
        }

        /// The thread whose run is outermost on the ray out of the braid at
        /// `arc` round the cross-section and `x` along it, and how far out it is.
        func outermost(atArc arc: Float, x: Float) -> (patch: Int, distance: Float)? {
            let base = Flat16SurfaceMesh.crossSectionPoint(
                atArcFraction: arc, halfWidth: halfWidth, halfThickness: halfThickness
            )
            // The outward direction of the plain outline, which is the way the
            // mesh raises every run.
            let step: Float = 0.000_5
            let ahead = Flat16SurfaceMesh.crossSectionPoint(
                atArcFraction: arc + step, halfWidth: halfWidth, halfThickness: halfThickness
            )
            let behind = Flat16SurfaceMesh.crossSectionPoint(
                atArcFraction: arc - step, halfWidth: halfWidth, halfThickness: halfThickness
            )
            let along = simd_normalize(ahead - behind)
            let outward = SIMD2<Float>(along.y, -along.x)
            let turned = simd_dot(outward, base) > 0 ? outward : -outward

            // Start well inside the braid so nothing is missed, and look for the
            // furthest-out crossing.
            let origin = SIMD3<Float>(x, base.x, base.y) - SIMD3(0, turned.x, turned.y) * halfThickness
            let direction = SIMD3<Float>(0, turned.x, turned.y)

            let bin = min(max(Int(((x + length / 2) / length * Float(Self.binsAlong))
                .rounded(.down)), 0), Self.binsAlong - 1)
            var best: (patch: Int, distance: Float)?
            for index in bins[bin] {
                let triangle = triangles[index]
                guard let hit = intersect(
                    origin: origin, direction: direction,
                    a: mesh.positions[triangle.x],
                    b: mesh.positions[triangle.y],
                    c: mesh.positions[triangle.z]
                ) else { continue }
                if best == nil || hit > best!.distance {
                    best = (mesh.surfaceVertexPatchIndices[triangle.x], hit)
                }
            }
            return best
        }

        /// Möller–Trumbore, both ways round: the mesh is wound outwards, but a
        /// ray started inside it meets some triangles from behind.
        private func intersect(
            origin: SIMD3<Float>, direction: SIMD3<Float>,
            a: SIMD3<Float>, b: SIMD3<Float>, c: SIMD3<Float>
        ) -> Float? {
            let edge1 = b - a, edge2 = c - a
            let h = simd_cross(direction, edge2)
            let determinant = simd_dot(edge1, h)
            guard abs(determinant) > 1e-12 else { return nil }
            let inverse = 1 / determinant
            let s = origin - a
            let u = inverse * simd_dot(s, h)
            guard u >= -1e-6, u <= 1 + 1e-6 else { return nil }
            let q = simd_cross(s, edge1)
            let v = inverse * simd_dot(direction, q)
            guard v >= -1e-6, u + v <= 1 + 1e-6 else { return nil }
            let t = inverse * simd_dot(edge2, q)
            return t > 0 ? t : nil
        }
    }

    // MARK: - 1. The solid and the card's rule agree

    /// **What the ray finds is what the card paints.**
    ///
    /// Sampled over a whole repeat and right round the braid, at the middle of
    /// every lane and at four places along every step. Places where two runs are
    /// within a hair of each other are left out and counted: the solid cuts the
    /// surface into flat triangles and the rule does not, so exactly where two
    /// surfaces cross they can disagree by a triangle's width.
    @Test func theSolidShowsTheThreadTheCardsRuleNames() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: Self.assignments)
        )
        let repeats = 2
        let mesh = try #require(
            Flat16SurfaceMesh.generate(pattern: pattern, patternRepeatCount: repeats)
        )
        let length = Flat16SurfaceMesh.length(
            halfWidth: Flat16SurfaceMesh.defaultHalfWidth,
            aspectRatio: pattern.aspectRatio,
            patternRepeatCount: repeats
        )
        let solid = Solid(
            mesh: mesh,
            halfWidth: Flat16SurfaceMesh.defaultHalfWidth,
            halfThickness: Flat16SurfaceMesh.defaultHalfThickness,
            length: length
        )

        var asked = 0, agreed = 0, tooClose = 0, missed = 0
        for region in Flat16SurfaceRegion.allCases {
            let span = Flat16SurfacePatternGenerator.arcSpan(of: region)
            let columns = Flat16SurfacePatternGenerator.columnCount(in: region)
            for column in 0..<columns {
                let arc = span.start + span.length * (Float(column) + 0.5) / Float(columns)
                for step in 0..<(4 * pattern.rowCount) {
                    // The middle repeat of the tile, so neither end's cut is in
                    // the way.
                    let along = (Float(step) + 0.5) / Float(4 * pattern.rowCount)
                    let x = -length / 2 + length * (along + 1) / Float(repeats)
                    asked += 1

                    let standing = pattern.runsStanding(
                        atArc: arc, along: along, shape: Self.shape
                    ).filter { $0.height > 0 }
                    guard let top = standing.first else { continue }
                    // Two runs within a hundredth of a crest of each other: the
                    // triangles decide it, not the rule.
                    if standing.count > 1, standing[1].height > top.height - 0.01 {
                        tooClose += 1
                        continue
                    }
                    guard let hit = solid.outermost(atArc: arc, x: x) else {
                        missed += 1
                        continue
                    }
                    if pattern.bundles[hit.patch].threadPosition
                        == pattern.bundles[top.bundle].threadPosition {
                        agreed += 1
                    }
                }
            }
        }

        #expect(asked == 16 * 4 * pattern.rowCount)
        #expect(missed == 0)
        // Every place the two can both answer, they answer the same.
        #expect(agreed == asked - tooClose - missed,
                "\(asked - tooClose - missed - agreed) of \(asked) disagreed")
        // And the ties are a small part of it, or this is proving nothing.
        #expect(Float(tooClose) / Float(asked) < 0.2)
    }

    // MARK: - 2. The card's picture is that rule and nothing else

    /// The bitmap the card draws is `runsStanding` sampled, pixel for pixel.
    @Test func theCardsPictureIsTheRuleSampled() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: Self.assignments)
        )
        let (shown, width, height) = Flat16CardImage.shownMap(for: pattern)
        #expect(width > 100)
        #expect(height == 16 * Flat16CardImage.pixelsPerLane)
        #expect(shown.count == width * height)

        var checked = 0
        for row in stride(from: 0, to: height, by: 7) {
            for column in stride(from: 0, to: width, by: 11) {
                let arc = Flat16CardImage.arc(atRow: Float(row), rows: height)
                let along = (Float(column) + 0.5) / Float(width)
                let expected = pattern.runsStanding(
                    atArc: arc, along: along, shape: Self.shape
                ).first { $0.height > 0 }
                switch shown[row * width + column] {
                case .run(let offset, let bundle):
                    #expect(expected?.bundle == bundle)
                    #expect(expected?.repeatOffset == offset)
                case .beneath, nil:
                    #expect(expected == nil)
                }
                checked += 1
            }
        }
        #expect(checked > 100)
    }

    /// **The four regions come down the card in order** — right edge, front,
    /// left edge, back — which is what Task 029-2 settled, and every lane is
    /// `pixelsPerLane` rows of it.
    @Test func theCardShowsTheWholeTurnInOrder() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: Self.assignments)
        )
        let (_, _, height) = Flat16CardImage.shownMap(for: pattern)

        var order = [Flat16SurfaceRegion]()
        for row in stride(from: 0, to: height, by: Flat16CardImage.pixelsPerLane) {
            let arc = Flat16CardImage.arc(atRow: Float(row) + 0.5 * Float(Flat16CardImage.pixelsPerLane),
                                          rows: height)
            for region in Flat16SurfaceRegion.allCases {
                let span = Flat16SurfacePatternGenerator.arcSpan(of: region)
                var within = (arc - span.start).truncatingRemainder(dividingBy: 1)
                if within < 0 { within += 1 }
                if within < span.length {
                    if order.last != region { order.append(region) }
                    break
                }
            }
        }
        #expect(order == [.rightEdge, .front, .leftEdge, .back])
        #expect(pattern.rowCount == 4)
    }

    /// The picture really is drawn, and the loader shows it only for the
    /// colouring it was asked for (Task 045 addendum 2, carried over).
    @Test @MainActor func theLoaderShowsOnlyThePictureForWhatIsAskedFor() async throws {
        let first = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: Self.assignments)
        )
        let plain = (1...16).map {
            ThreadAssignment(position: $0, colorID: ThreadColorID(rawValue: "blue"))
        }
        let second = try #require(Flat16SurfacePatternGenerator.generate(assignments: plain))
        #expect(Flat16CardImage.Key(pattern: first) != Flat16CardImage.Key(pattern: second))

        // A drawer that answers for whatever it is given, so the loader's own
        // rule is what is under test.
        let loader = Flat16CardLoader(cache: Flat16CardImage.Cache()) { pattern in
            Flat16CardImage.draw(pattern)
        }
        await loader.load(pattern: first)
        #expect(loader.image(for: Flat16CardImage.Key(pattern: first)) != nil)
        // The picture for a colouring the card is not showing is never handed
        // out, even though it has been drawn.
        #expect(loader.image(for: Flat16CardImage.Key(pattern: second)) == nil)

        await loader.load(pattern: second)
        #expect(loader.image(for: Flat16CardImage.Key(pattern: second)) != nil)
        #expect(loader.image(for: Flat16CardImage.Key(pattern: first)) == nil)
    }
}
