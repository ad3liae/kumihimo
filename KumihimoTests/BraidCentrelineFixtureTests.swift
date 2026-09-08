import Foundation
import Testing
@testable import Kumihimo

/// Task 025-3: the finished centrelines, held against the Python within 1e-6 d.
@MainActor
struct BraidCentrelineFixtureTests {
    struct Fixture: Decodable {
        struct Thread: Decodable {
            let points: [[Double]]
            let kinds: [Int]
        }
        let cycles: Int
        let crests: Int
        let threads: [String: Thread]
        let crestHeight: Double

        enum CodingKeys: String, CodingKey {
            case cycles, crests, threads
            case crestHeight = "crest_height"
        }
    }

    static func built(flat: Bool, cycles: Int, flatten: Bool) throws -> BraidCentrelines {
        let derivation = try #require(BraidDerivation.derive(
            stand: BraidMethodCatalog.stand16,
            method: flat ? BraidMethodCatalog.hiraGenji16 : BraidMethodCatalog.maruGenji16,
            crossSection: flat ? BraidMethodCatalog.hiraGenji16CrossSection
                               : BraidMethodCatalog.maruGenji16CrossSection
        ))
        let construction = try #require(BraidConstruction.construct(
            of: derivation.method, on: derivation.stand,
            crossSection: derivation.crossSection, fold: derivation.fold,
            cycles: cycles, flatten: flatten
        ))
        return try #require(BraidCentrelines.centrelines(of: construction))
    }

    @Test(arguments: [("hira-centrelines-round", true, false),
                      ("maru-centrelines-round", false, false)])
    func everyPointIsWhereThePythonPutsIt(name: String, flat: Bool, flatten: Bool) throws {
        let fixture = try BraidFixtures.decode(Fixture.self, from: name)
        let built = try Self.built(flat: flat, cycles: fixture.cycles, flatten: flatten)
        #expect(built.points.count == fixture.threads.count)
        var worst = 0.0
        for (thread, wanted) in fixture.threads {
            let index = try #require(Int(thread))
            let mine = try #require(built.points[index], "thread \(thread)")
            let kinds = try #require(built.kinds[index], "thread \(thread)")
            #expect(mine.count == wanted.points.count, "thread \(thread) point count")
            #expect(kinds.map(\.rawValue) == wanted.kinds, "thread \(thread) kinds")
            guard mine.count == wanted.points.count else { continue }
            for (point, want) in zip(mine, wanted.points) {
                worst = max(worst, abs(point.x - want[0]))
                worst = max(worst, abs(point.y - want[1]))
                worst = max(worst, abs(point.z - want[2]))
            }
        }
        #expect(worst < 1e-6, "worst difference \(worst) d")
    }

    @Test func theSameNumberOfCrestsAreRaised() throws {
        let fixture = try BraidFixtures.decode(Fixture.self, from: "hira-centrelines-round")
        let built = try Self.built(flat: true, cycles: fixture.cycles, flatten: false)
        #expect(built.crests == fixture.crests)
    }

    /// **The crest goes out and never in.** No resting point of a thread on a face
    /// is on the wrong side of that face's own plane.
    @Test func noCrestGoesInwards() throws {
        let built = try Self.built(flat: true, cycles: 3, flatten: false)
        for thread in built.threads {
            let points = built.points[thread]!, kinds = built.kinds[thread]!
            for (point, kind) in zip(points, kinds) where kind == .restingOnTheSurface {
                #expect(abs(point.y) >= 0.5 - 1e-9, "thread \(thread)")
            }
        }
    }

    /// **The crest is the thread's own thickness and no more**, and the two faces
    /// reach equally far. A thread meeting one whose centre is on its own line
    /// rises the whole thickness; the ordinary case, a weft crossing the belly half
    /// a thickness below, rises half of it -- which is book A's 0.45 within a
    /// tenth.
    @Test(arguments: [(false, 1.0), (true, 0.75)])
    func theCrestRisesTheThreadsOwnThicknessAtMostAndReachesBothWaysAlike(
        flatten: Bool, thickness: Double
    ) throws {
        let built = try Self.built(flat: true, cycles: 3, flatten: flatten)
        var out = 0.0, back = 0.0
        for thread in built.threads {
            let points = built.points[thread]!, kinds = built.kinds[thread]!
            for (point, kind) in zip(points, kinds) where kind == .restingOnTheSurface {
                out = max(out, point.y)
                back = min(back, point.y)
            }
        }
        #expect(abs(out + back) < 1e-9)                       // the same both ways
        #expect(abs(out - (thickness / 2 + thickness)) < 1e-9)
        #expect(abs(built.construction.section.threadThickness - thickness) < 1e-9)
    }
}
