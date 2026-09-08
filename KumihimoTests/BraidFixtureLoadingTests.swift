import Foundation
import Testing
@testable import Kumihimo

/// Task 025-2, the first commit: **can the tests read the fixtures at all?**
///
/// This asserts nothing about braids. It exists because everything after it does,
/// and because the inventory (025-1) left the question open on purpose rather than
/// assuming an answer.
struct BraidFixtureLoadingTests {
    private struct Occupancy: Decodable {
        let braid: String
        let bodyWidths: [Int]
        let lanes: [String: [Int]]
        let madeBy: String

        enum CodingKeys: String, CodingKey {
            case braid
            case bodyWidths = "body_widths"
            case lanes
            case madeBy = "made_by"
        }
    }

    @Test func aFixtureCanBeFound() throws {
        let found = try BraidFixtures.locate("hira-occupancy")
        #expect(FileManager.default.fileExists(atPath: found.url.path))
    }

    @Test func aFixtureDecodes() throws {
        let occupancy = try BraidFixtures.decode(Occupancy.self, from: "hira-occupancy")
        #expect(occupancy.braid == "hira-genji-16")
        // The body is the occupancy history's, not the picture's: widths one to
        // four (docs/architecture.md, the reading of the flat braid's widths).
        #expect(occupancy.bodyWidths == [1, 2, 3, 4])
        // Sixteen places on the ring, each with its four cycles.
        #expect(occupancy.lanes.count == 16)
        #expect(occupancy.lanes.values.allSatisfy { $0.count == 4 })
        #expect(occupancy.madeBy.contains("hira_lanes"))
    }

    /// Every fixture the later commits read, present and non-empty.
    @Test(arguments: [
        "hira-occupancy", "maru-occupancy", "readings", "observed",
        "hira-centrelines-round", "hira-centrelines-ellipse", "maru-centrelines-round",
    ])
    func everyFixtureIsThere(name: String) throws {
        #expect(try BraidFixtures.data(name).count > 0)
    }
}
