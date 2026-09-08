import Foundation
import Testing
@testable import Kumihimo

/// Task 025-2: the flat braid's figure now takes what shows on the face from the
/// occupancy history. **The figure itself must not have moved** — the existing
/// `BraidPatternFigureTests` pin book A p96 and all three of p97's experiments —
/// so this checks the new source directly against the fixture.
@MainActor
struct BraidFigureFromOccupancyTests {
    private struct HiraFixture: Decodable {
        let lanes: [String: [Int]]
        let widthOfPlace: [String: Int]
        let faceOfPlace: [String: String?]

        enum CodingKeys: String, CodingKey {
            case lanes
            case widthOfPlace = "width_of_place"
            case faceOfPlace = "face_of_place"
        }
    }

    private var derivation: BraidDerivation {
        get throws {
            try #require(BraidDerivation.derive(
                stand: BraidMethodCatalog.stand16,
                method: BraidMethodCatalog.hiraGenji16,
                crossSection: BraidMethodCatalog.hiraGenji16CrossSection
            ))
        }
    }

    /// Every cell of the figure holds the thread the Python says rests at that
    /// slot, on both faces, for every row of the repeat.
    @Test(arguments: [BraidFace.front, BraidFace.back])
    func everyCellHoldsTheThreadThePythonSaysRestsThere(face: BraidFace) throws {
        let fixture = try BraidFixtures.decode(HiraFixture.self, from: "hira-occupancy")
        let derivation = try derivation
        let figure = try #require(BraidFigureBuilder.figure(
            from: derivation,
            assignments: BraidMethodCatalog.hiraGenji16Colouring,
            face: face,
            repeats: 1
        ))

        // The slot each width of this face stands at, out of the fold.
        let wanted = face == .front ? "F" : "B"
        var slotOfWidth = [Int: Int]()
        for (slot, name) in fixture.faceOfPlace where name == wanted {
            let slot = try #require(Int(slot))
            slotOfWidth[try #require(fixture.widthOfPlace[String(slot)])] = slot
        }
        #expect(slotOfWidth.count == 6)

        for row in 0..<figure.rowCount {
            for (width, slot) in slotOfWidth {
                let shape = try #require(figure.appearance(atWidth: width, row: row),
                                         "face \(face) row \(row) width \(width)")
                let resting = try #require(fixture.lanes[String(slot)])[row]
                #expect(shape.threadPosition == resting,
                        "face \(face) row \(row) width \(width)")
            }
        }
    }
}
