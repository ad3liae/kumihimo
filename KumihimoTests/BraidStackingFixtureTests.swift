import Foundation
import Testing
@testable import Kumihimo

/// Task 025-2: the lengthwise growth, counted rather than written down.
@MainActor
struct BraidStackingFixtureTests {
    private struct Centrelines: Decodable {
        let layersPerCycleK: Int
        let pitchPerCycle: Double

        enum CodingKeys: String, CodingKey {
            case layersPerCycleK = "layers_per_cycle_k"
            case pitchPerCycle = "pitch_per_cycle"
        }
    }

    private func stacking(
        method: BraidMethod, section: BraidCrossSection, cycles: Int
    ) throws -> BraidStacking {
        let derivation = try #require(BraidDerivation.derive(
            stand: BraidMethodCatalog.stand16, method: method, crossSection: section
        ))
        return try #require(BraidStacking.stacking(
            of: method, on: BraidMethodCatalog.stand16, crossSection: section,
            fold: derivation.fold, cycles: cycles
        ))
    }

    @Test(arguments: [
        ("hira-centrelines-round", false), ("maru-centrelines-round", true),
    ])
    func kIsCountedAndAgreesWithTheFixture(name: String, tube: Bool) throws {
        let fixture = try BraidFixtures.decode(Centrelines.self, from: name)
        let stacking = try stacking(
            method: tube ? BraidMethodCatalog.maruGenji16 : BraidMethodCatalog.hiraGenji16,
            section: tube ? BraidMethodCatalog.maruGenji16CrossSection
                          : BraidMethodCatalog.hiraGenji16CrossSection,
            cycles: 5
        )
        #expect(stacking.layersPerCycle == fixture.layersPerCycleK)
        #expect(stacking.pitchPerCycle.value == fixture.pitchPerCycle)
        #expect(stacking.pitchPerCycle.isDerived)
    }

    /// Counting the landings alone would give one layer a cycle and a pitch a third
    /// of what the books measure. The passings are the point.
    @Test func aCarryTakesUpRoomAtEverySlotItPasses() throws {
        let stacking = try stacking(method: BraidMethodCatalog.hiraGenji16,
                                    section: BraidMethodCatalog.hiraGenji16CrossSection,
                                    cycles: 5)
        #expect(stacking.layersPerCycle > 1)
        let piles = stacking.layersBySlot.values.flatMap(\.values)
        #expect(piles.contains { $0.count == stacking.layersPerCycle })
    }

    /// The flat braid: half the ring laid out side by side, so eight diameters
    /// across. Three of sixteen, against book A p96 / book B p23's 0.3665.
    @Test func theFlatBraidsPitchLandsNextToTheMeasuredOne() throws {
        let stacking = try stacking(method: BraidMethodCatalog.hiraGenji16,
                                    section: BraidMethodCatalog.hiraGenji16CrossSection,
                                    cycles: 5)
        #expect(stacking.braidWidth == 8.0)
        #expect(abs(stacking.pitchPerBraidWidth.value - 0.375) < 1e-12)
        let measured = BraidMeasurement.observed(0.3665, from: "book A p96 / book B p23")
        #expect(abs(stacking.pitchPerBraidWidth.value - measured.value) / measured.value < 0.03)
    }

    /// The tube: sixteen slots on a regular sixteen-sided figure of side d, so
    /// `d / sin(pi/16) + d` across. The chevron count the photographs give,
    /// 1.8 to 2.15 a braid width, is this pitch upside down.
    @Test func theTubesPitchLandsInsideTheBandThePhotographsGive() throws {
        let stacking = try stacking(method: BraidMethodCatalog.maruGenji16,
                                    section: BraidMethodCatalog.maruGenji16CrossSection,
                                    cycles: 5)
        #expect(abs(stacking.braidWidth - 6.1259) < 1e-3)
        let band = BraidMeasurement.observed(
            2.0, spread: 1.8...2.15, from: "photographs, Task 005I"
        )
        let spread = try #require(band.spread)
        let pitch = stacking.pitchPerBraidWidth.value
        #expect(abs(pitch - 0.4897) < 1e-3)
        #expect((1 / spread.upperBound)...(1 / spread.lowerBound) ~= pitch)
    }
}
