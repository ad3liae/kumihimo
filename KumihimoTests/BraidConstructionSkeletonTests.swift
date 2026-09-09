import Foundation
import Testing
@testable import Kumihimo

/// Task 025-3: the construction's bookkeeping, before any geometry of the thread
/// itself. Held against the Python step by step.
@MainActor
struct BraidConstructionSkeletonTests {
    private struct Skeleton: Decodable {
        struct Step: Decodable {
            let slot: Int
            let arrivedAt: Double
            let leftAt: Double
            let arrivesNextAt: Double

            enum CodingKeys: String, CodingKey {
                case slot
                case arrivedAt = "arrived_at"
                case leftAt = "left_at"
                case arrivesNextAt = "arrives_next_at"
            }
        }
        let cycles: Int
        let layersPerCycleK: Int
        let handOversRaisedALayer: Int
        let steps: [String: [Step]]
        let sideSteps: [String: Double]
        let weftsSharingAHeight: [[Double]]

        enum CodingKeys: String, CodingKey {
            case cycles, steps
            case layersPerCycleK = "layers_per_cycle_k"
            case handOversRaisedALayer = "hand_overs_raised_a_layer"
            case sideSteps = "side_steps"
            case weftsSharingAHeight = "wefts_crossing_one_column_at_one_height"
        }
    }

    private func construction(flat: Bool, cycles: Int, flatten: Bool) throws -> BraidConstruction {
        let derivation = try #require(BraidDerivation.derive(
            stand: BraidMethodCatalog.stand16,
            method: flat ? BraidMethodCatalog.hiraGenji16 : BraidMethodCatalog.maruGenji16,
            crossSection: flat ? BraidMethodCatalog.hiraGenji16CrossSection
                               : BraidMethodCatalog.maruGenji16CrossSection
        ))
        return try #require(BraidConstruction.construct(
            of: derivation.method, on: derivation.stand,
            crossSection: derivation.crossSection, fold: derivation.fold,
            cycles: cycles, flatten: flatten
        ))
    }

    @Test(arguments: [
        ("hira-skeleton-round", true, false),
        ("hira-skeleton-ellipse", true, true),
        ("maru-skeleton-round", false, false),
    ])
    func everyThreadStandsWhereAndWhenThePythonSays(
        name: String, flat: Bool, flatten: Bool
    ) throws {
        let fixture = try BraidFixtures.decode(Skeleton.self, from: name)
        let built = try construction(flat: flat, cycles: fixture.cycles, flatten: flatten)
        #expect(built.layersPerCycle == fixture.layersPerCycleK)
        #expect(built.handOversRaisedALayer == fixture.handOversRaisedALayer)
        #expect(built.steps.count == fixture.steps.count)
        for (thread, way) in fixture.steps {
            let index = try #require(Int(thread))
            let mine = try #require(built.steps[index], "thread \(thread)")
            #expect(mine.count == way.count, "thread \(thread)")
            for (step, wanted) in zip(mine, way) {
                #expect(step.slot == wanted.slot, "thread \(thread)")
                #expect(abs(step.arrivedAt - wanted.arrivedAt) < 1e-6, "thread \(thread)")
                #expect(abs(step.leftAt - wanted.leftAt) < 1e-6, "thread \(thread)")
                #expect(abs(step.arrivesNextAt - wanted.arrivesNextAt) < 1e-6,
                        "thread \(thread)")
            }
        }
    }

    /// Which way round each face swap passes. **A promise**, and it has to be the
    /// same promise on both sides.
    @Test(arguments: [
        ("hira-skeleton-round", true, false), ("maru-skeleton-round", false, false),
    ])
    func theFaceSwapsPassTheSameWayRoundAsThePython(
        name: String, flat: Bool, flatten: Bool
    ) throws {
        let fixture = try BraidFixtures.decode(Skeleton.self, from: name)
        let built = try construction(flat: flat, cycles: fixture.cycles, flatten: flatten)
        #expect(built.sideSteps.count == fixture.sideSteps.count)
        for (key, way) in fixture.sideSteps {
            let parts = key.split(separator: ",").compactMap { Int($0) }
            #expect(parts.count == 2)
            let mine = try #require(built.sideSteps[
                BraidConstruction.SideStep(thread: parts[0], step: parts[1])
            ], "\(key)")
            #expect(mine == way, "\(key)")
        }
        // Every pair parts, one each way.
        #expect(built.sideSteps.values.filter { $0 > 0 }.count
                == built.sideSteps.values.filter { $0 < 0 }.count)
    }

    /// A tube has no belly to pass through, so nothing swaps sideways on one.
    @Test func aTubeHasNoFaceSwaps() throws {
        let built = try construction(flat: false, cycles: 7, flatten: false)
        #expect(built.sideSteps.isEmpty)
        #expect(built.weftsSharingAHeight.isEmpty)
    }

    /// **Listed, not mended.** The twelve the Python reports are reported here too.
    @Test func theWeftsThatShareAHeightAreTheSameOnes() throws {
        let fixture = try BraidFixtures.decode(Skeleton.self, from: "hira-skeleton-round")
        let built = try construction(flat: true, cycles: fixture.cycles, flatten: false)
        #expect(built.weftsSharingAHeight.count == fixture.weftsSharingAHeight.count)
        let mine = Set(built.weftsSharingAHeight.map {
            [Double($0.column), $0.height, Double($0.threads.0), Double($0.threads.1)]
        })
        #expect(mine == Set(fixture.weftsSharingAHeight))
    }
}
