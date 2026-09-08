import Foundation
import Testing
@testable import Kumihimo

/// Task 025-2: the occupancy history in Swift has to give what the Python gives.
///
/// **Every expected value here comes out of `KumihimoTests/Fixtures`**, which
/// `Scripts/task025/fixtures.py` wrote from the scripts Task 024 read against book
/// A p97 and Task 004. These are integers, so there is no tolerance to argue about:
/// they agree or they do not.
@MainActor
struct BraidOccupancyFixtureTests {
    private struct MaruFixture: Decodable {
        struct Agreement: Decodable {
            let same: Int
            let of: Int
            let mirror: Bool
            let rotation: Int
            let upwards: Bool
            let shift: Int
            let laidOn: [[Int]]

            enum CodingKeys: String, CodingKey {
                case same, of, mirror, rotation, upwards, shift
                case laidOn = "laid_on"
            }
        }
        let closingPairs: [[Int]]
        let columns: [Int]
        let grid: [[Int]]
        let task004: [[Int]]
        let agreement: Agreement

        enum CodingKeys: String, CodingKey {
            case closingPairs = "closing_pairs"
            case columns, grid, task004, agreement
        }
    }

    private struct HiraFixture: Decodable {
        let ring: [Int]
        let lanes: [String: [Int]]
        let widthOfPlace: [String: Int]
        let faceOfPlace: [String: String?]

        enum CodingKeys: String, CodingKey {
            case ring, lanes
            case widthOfPlace = "width_of_place"
            case faceOfPlace = "face_of_place"
        }
    }

    private func occupancy(
        method: BraidMethod, section: BraidCrossSection, cycles: Int
    ) throws -> BraidOccupancy {
        try #require(BraidOccupancy.history(
            of: method, on: BraidMethodCatalog.stand16,
            crossSection: section, cycles: cycles
        ))
    }

    // MARK: the round braid

    @Test func theClosingFoldsTheRingIntoTheSamePairs() throws {
        let fixture = try BraidFixtures.decode(MaruFixture.self, from: "maru-occupancy")
        let history = try occupancy(method: BraidMethodCatalog.maruGenji16,
                                    section: BraidMethodCatalog.maruGenji16CrossSection,
                                    cycles: 5)
        #expect(history.closingPairs.map { [$0.lead, $0.trail] } == fixture.closingPairs)
    }

    @Test func theColumnsAreTheSlotsAHandLandsOn() throws {
        let fixture = try BraidFixtures.decode(MaruFixture.self, from: "maru-occupancy")
        let history = try occupancy(method: BraidMethodCatalog.maruGenji16,
                                    section: BraidMethodCatalog.maruGenji16CrossSection,
                                    cycles: 5)
        #expect(try #require(history.columns(.landing)) == fixture.columns)
        // The other slot of each pair is the one only the closing reaches, so the
        // two readings never name the same slot.
        let closing = try #require(history.columns(.closing))
        #expect(Set(closing).isDisjoint(with: Set(fixture.columns)))
    }

    @Test func theOccupancyGridIsTheSame() throws {
        let fixture = try BraidFixtures.decode(MaruFixture.self, from: "maru-occupancy")
        let history = try occupancy(method: BraidMethodCatalog.maruGenji16,
                                    section: BraidMethodCatalog.maruGenji16CrossSection,
                                    cycles: 5)
        let columns = try #require(history.columns(.landing))
        #expect(try #require(history.grid(atColumns: columns, rows: 4)) == fixture.grid)
    }

    /// Thirty-two of thirty-two, mirrored. **The mirror is allowed and the E/W
    /// column order is still undecided** — see `docs/tasks/020-…` and the note on
    /// `maruGenji16CrossSection`.
    @Test func theGridAgreesWithTaskZeroZeroFourCellForCell() throws {
        let fixture = try BraidFixtures.decode(MaruFixture.self, from: "maru-occupancy")
        let history = try occupancy(method: BraidMethodCatalog.maruGenji16,
                                    section: BraidMethodCatalog.maruGenji16CrossSection,
                                    cycles: 5)
        let columns = try #require(history.columns(.landing))
        let grid = try #require(history.grid(atColumns: columns, rows: 4))
        let best = try #require(BraidGridAgreement.best(of: grid, against: fixture.task004))
        #expect(best.same == fixture.agreement.same)
        #expect(best.of == fixture.agreement.of)
        #expect(best.same == 32)
        #expect(best.mirrored == fixture.agreement.mirror)
        #expect(best.rotation == fixture.agreement.rotation)
        #expect(best.upwards == fixture.agreement.upwards)
        #expect(best.shift == fixture.agreement.shift)
        #expect(best.laidOn == fixture.agreement.laidOn)
    }

    // MARK: the flat braid

    @Test func everySlotRunsTheSameThreadsAsThePython() throws {
        let fixture = try BraidFixtures.decode(HiraFixture.self, from: "hira-occupancy")
        #expect(BraidMethodCatalog.hiraGenji16CrossSection.order == fixture.ring)
        let history = try occupancy(method: BraidMethodCatalog.hiraGenji16,
                                    section: BraidMethodCatalog.hiraGenji16CrossSection,
                                    cycles: 5)
        let lanes = try #require(history.lanes(rows: 4))
        #expect(lanes.count == fixture.lanes.count)
        for (slot, run) in fixture.lanes {
            #expect(lanes[try #require(Int(slot))] == run)
        }
    }

    /// The author's ruling of 2026-09-09: **`BraidFold` is right and the Python's
    /// hand-written tables are the ones on trial.** So this checks the tables
    /// against the derivation rather than the other way round, and the tables stay
    /// in Python.
    @Test func theFoldDerivesWhatThePythonHoldsAsATable() throws {
        let fixture = try BraidFixtures.decode(HiraFixture.self, from: "hira-occupancy")
        let derivation = try #require(BraidDerivation.derive(
            stand: BraidMethodCatalog.stand16,
            method: BraidMethodCatalog.hiraGenji16,
            crossSection: BraidMethodCatalog.hiraGenji16CrossSection
        ))
        let fold = try #require(derivation.fold)
        for (slot, width) in fixture.widthOfPlace {
            #expect(fold.width(ofSlot: try #require(Int(slot))) == width)
        }
        for (slot, face) in fixture.faceOfPlace {
            let derived = fold.face(ofSlot: try #require(Int(slot)))
            switch face {
            case "F": #expect(derived == .front)
            case "B": #expect(derived == .back)
            default: #expect(derived == nil)      // a turning slot, on neither face
            }
        }
    }
}
