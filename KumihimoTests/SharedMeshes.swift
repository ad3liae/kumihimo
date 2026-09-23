import Foundation
@testable import Kumihimo

/// **The meshes the tests read, each made once a run** (Task 056).
///
/// Making a mesh is most of what a mesh test costs. In the Debug build the
/// tests run in, a round sixteen-thread mesh (419,184 vertices) takes about
/// 2.6 seconds and a flat one (361,350) about 3.6, and until Task 056 some
/// forty tests made their own copy of the same few: the two shipped colourings,
/// and the fixtures each file keeps. Here each is made the first time a test
/// asks for it and handed to every test after.
///
/// **Handing a test a shared mesh does not change what it checks.** A mesh is a
/// value, so no test can alter the one another reads; and the generators keep
/// no state between calls, so the mesh handed over is the one the test would
/// have made — `meshGenerationIsDeterministic` holds that for the round braid,
/// and the vertex hashes (`BraidMeshHashTests`) are read off these same meshes.
///
/// **Not for a test whose question is the making itself.** A test that asks
/// whether making a mesh twice gives the same mesh makes its own, twice; a
/// test that asks what a bad argument does calls the generator. Those call
/// `generate` directly and should go on doing so.
///
/// Each mesh stays in memory for the rest of the run, so reach for this where
/// the same mesh is read more than once (a loop that also holds a mesh read
/// only there is fine).
enum SharedMeshes {
    /// The round sixteen-thread mesh for a colouring, as
    /// `RoundTube16SurfaceMesh.generate(pattern:radius:patternRepeatCount:)`
    /// makes it from that colouring's pattern.
    static func tube(
        _ assignments: [ThreadAssignment],
        radius: Float = RoundTube16SurfaceMesh.defaultRadius,
        patternRepeatCount: Int = RoundTube16SurfaceMesh.defaultPatternRepeatCount
    ) -> RoundTube16SurfaceMeshData? {
        tubes.value(for: Key(assignments, radius: radius, repeats: patternRepeatCount)) {
            RoundTube16SurfacePatternGenerator.generate(assignments: assignments).flatMap {
                RoundTube16SurfaceMesh.generate(
                    pattern: $0, radius: radius, patternRepeatCount: patternRepeatCount)
            }
        }
    }

    /// The flat sixteen-thread mesh for a colouring, as
    /// `Flat16SurfaceMesh.generate(pattern:patternRepeatCount:)` makes it from
    /// that colouring's pattern.
    static func flat(
        _ assignments: [ThreadAssignment],
        patternRepeatCount: Int = Flat16SurfaceMesh.defaultPatternRepeatCount
    ) -> Flat16SurfaceMeshData? {
        flats.value(for: Key(assignments, radius: 0, repeats: patternRepeatCount)) {
            Flat16SurfacePatternGenerator.generate(assignments: assignments).flatMap {
                Flat16SurfaceMesh.generate(pattern: $0, patternRepeatCount: patternRepeatCount)
            }
        }
    }

    /// Every position and its colour, in the order given, and the size asked
    /// for: two requests share a mesh only when they would have made the same one.
    private struct Key: Hashable {
        let positions: [Int]
        let colours: [String]
        let radius: Float
        let repeats: Int

        init(_ assignments: [ThreadAssignment], radius: Float, repeats: Int) {
            positions = assignments.map(\.position)
            colours = assignments.map(\.colorID.rawValue)
            self.radius = radius
            self.repeats = repeats
        }
    }

    private static let tubes = Store<RoundTube16SurfaceMeshData>()
    private static let flats = Store<Flat16SurfaceMeshData>()

    /// Made under the lock, so two tests asking at once for the same mesh wait
    /// for one making rather than making it twice.
    private final class Store<Value: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var made = [Key: Value?]()

        func value(for key: Key, making make: () -> Value?) -> Value? {
            lock.lock()
            defer { lock.unlock() }
            if let found = made[key] { return found }
            let value = make()
            made[key] = value
            return value
        }
    }
}
