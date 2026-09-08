import Foundation
import Testing
@testable import Kumihimo

/// Task 025-3: where each slot stands, held against the Python's own section.
@MainActor
struct BraidSectionFixtureTests {
    private struct Centrelines: Decodable {
        struct Place: Decodable {
            let spot: [Double]
            let outward: [Double]
            let face: String
        }
        struct Flattened: Decodable {
            let width: Double
            let thickness: Double
        }
        let places: [String: Place]
        let flattened: Flattened
    }

    private func section(flat: Bool, flatten: Bool) throws -> BraidSection {
        let derivation = try #require(BraidDerivation.derive(
            stand: BraidMethodCatalog.stand16,
            method: flat ? BraidMethodCatalog.hiraGenji16 : BraidMethodCatalog.maruGenji16,
            crossSection: flat ? BraidMethodCatalog.hiraGenji16CrossSection
                               : BraidMethodCatalog.maruGenji16CrossSection
        ))
        return try #require(BraidSection.section(
            slotCount: derivation.crossSection.slotCount,
            fold: derivation.fold, flatten: flatten
        ))
    }

    @Test(arguments: [
        ("hira-centrelines-round", true, false),
        ("hira-centrelines-ellipse", true, true),
        ("maru-centrelines-round", false, false),
    ])
    func everyPlaceStandsWhereThePythonPutsIt(
        name: String, flat: Bool, flatten: Bool
    ) throws {
        let fixture = try BraidFixtures.decode(Centrelines.self, from: name)
        let section = try section(flat: flat, flatten: flatten)
        #expect(section.places.count == fixture.places.count)
        for (slot, place) in fixture.places {
            let index = try #require(Int(slot))
            let mine = try #require(section.places[index], "slot \(slot)")
            #expect(abs(mine.spot.x - place.spot[0]) < 1e-6, "slot \(slot) across")
            #expect(abs(mine.spot.y - place.spot[1]) < 1e-6, "slot \(slot) through")
            #expect(abs(mine.outward.x - place.outward[0]) < 1e-6, "slot \(slot)")
            #expect(abs(mine.outward.y - place.outward[1]) < 1e-6, "slot \(slot)")
            #expect(abs(mine.outward.z - place.outward[2]) < 1e-6, "slot \(slot)")
            #expect(mine.kind.rawValue == place.face, "slot \(slot)")
        }
    }

    /// The flattening is the section keeping its area: eight diameters across six
    /// threads is 1.3333 wide, and `d^2 / w` is 0.75 thick.
    @Test func theFlatteningIsTheSectionKeepingItsArea() throws {
        let fixture = try BraidFixtures.decode(Centrelines.self, from: "hira-centrelines-ellipse")
        let section = try section(flat: true, flatten: true)
        #expect(abs(section.threadWidth - fixture.flattened.width) < 1e-6)
        #expect(abs(section.threadThickness - fixture.flattened.thickness) < 1e-6)
        #expect(abs(section.threadWidth * section.threadThickness - 1) < 1e-12)
    }

    /// The tube's threads stand on a regular polygon of side d, so its radius is
    /// the polygon's and not a circumference divided by two pi.
    @Test func theTubeStandsOnAPolygonOfSideOneDiameter() throws {
        let section = try section(flat: false, flatten: false)
        let radius = 1 / (2 * sin(Double.pi / 16))
        #expect(abs(radius - 2.5629) < 1e-4)
        for place in section.places.values {
            #expect(abs((place.spot * place.spot).sum().squareRoot() - radius) < 1e-9)
            #expect(place.kind == .round)
        }
        #expect(section.threadWidth == 1 && section.threadThickness == 1)
    }
}
