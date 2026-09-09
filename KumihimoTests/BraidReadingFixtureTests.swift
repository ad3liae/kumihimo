import Foundation
import Testing
@testable import Kumihimo

/// Task 025-3: reading the face off the picture, held against the Python.
///
/// The rasterizers are not the same program, so the painted pixel counts are not
/// expected to agree exactly. **The percentages are, to within a point** — and the
/// agreement with Task 004 is a count of cells, so that is expected exactly.
@MainActor
struct BraidReadingFixtureTests {
    // MARK: book A p97, as the Python sets it up

    /// The three colourings of `Scripts/task021/occupancy.py`'s `P97`, and the two
    /// colours it counts as worked lengthwise.
    static let plain: Set<String> = ["natural", "white"]
    static let p97: [String: [String: [String]]] = [
        "weft-only": ["north": ["natural", "natural", "natural", "natural"],
                      "east": ["yellow", "red", "red", "yellow"],
                      "south": ["natural", "natural", "natural", "natural"],
                      "west": ["green", "light-blue", "light-blue", "green"]],
        "arrow-feather": ["north": ["white", "white", "white", "white"],
                          "east": ["brown", "yellow", "yellow", "brown"],
                          "south": ["white", "white", "white", "white"],
                          "west": ["brown", "yellow", "yellow", "brown"]],
        "ladder": ["north": ["brown", "brown", "brown", "brown"],
                   "east": ["white", "white", "white", "white"],
                   "south": ["yellow", "yellow", "yellow", "yellow"],
                   "west": ["white", "white", "white", "white"]],
    ]

    private struct Readings: Decodable {
        struct Count: Decodable { let lengthwise: Int; let painted: Int; let percent: Double }
        struct Shape: Decodable { let p97ByFace: [String: Count]
            enum CodingKeys: String, CodingKey { case p97ByFace = "p97_by_face" } }
        struct Hira: Decodable { let round: Shape; let ellipse: Shape }
        struct Rows: Decodable {
            let readFromRest: Int
            enum CodingKeys: String, CodingKey { case readFromRest = "read_from_rest" }
        }
        struct Agreement: Decodable { let same: Int; let mirror: Bool }
        struct View: Decodable {
            let viewAnglesDegrees: [Double]
            let grid: [[Int]]
            let agreement: Agreement
            let aThreadTwiceInARow: [Int]
            enum CodingKeys: String, CodingKey {
                case grid, agreement
                case viewAnglesDegrees = "view_angles_degrees"
                case aThreadTwiceInARow = "a_thread_twice_in_a_row"
            }
        }
        struct Maru: Decodable { let landing: View; let middle: View; let rows: Rows }
        let hira: Hira
        let maru: Maru
    }

    static func colouring(_ trial: String) throws -> [Int: String] {
        let named = try #require(Self.p97[trial])
        var out = [Int: String]()
        for group in BraidMethodCatalog.stand16.groups {
            guard let names = named[group.name] else { continue }
            for (position, name) in zip(group.positions, names) { out[position] = name }
        }
        return out
    }

    /// **Book A p97's three experiments, read off the picture, on both faces.**
    @Test(arguments: [("round", false), ("ellipse", true)])
    func bookAsThreeExperimentsComeOutOnBothFaces(name: String, flatten: Bool) throws {
        let fixture = try BraidFixtures.decode(Readings.self, from: "readings")
        let wanted = name == "round" ? fixture.hira.round : fixture.hira.ellipse
        let built = try BraidCentrelineFixtureTests.built(flat: true, cycles: 3, flatten: flatten)
        let section = built.construction.section

        for (face, direction) in [("front", SIMD3<Double>(0, -1, 0)),
                                  ("back", SIMD3<Double>(0, 1, 0))] {
            let picture = BraidPicture.paint(built, looking: direction)
            for trial in Self.p97.keys.sorted() {
                let colours = try Self.colouring(trial)
                let count = BraidReading.face(
                    picture, section: section, widths: [1, 2, 3, 4],
                    workedLengthwise: { Self.plain.contains(colours[$0] ?? "") }
                )
                let theirs = try #require(wanted.p97ByFace["\(face)/\(trial)"])
                #expect(abs(count.percent - theirs.percent) < 1.0,
                        "\(name) \(face) \(trial): \(count.percent) against \(theirs.percent)")
            }
        }
    }

    /// Flattened, the face has no gaps left in it, so the claims come out whole.
    @Test func theFlattenedFaceGivesTheWholeHundredAndTheWholeNought() throws {
        let built = try BraidCentrelineFixtureTests.built(flat: true, cycles: 3, flatten: true)
        for direction in [SIMD3<Double>(0, -1, 0), SIMD3<Double>(0, 1, 0)] {
            let picture = BraidPicture.paint(built, looking: direction)
            for (trial, wanted) in [("weft-only", 100.0), ("arrow-feather", 100.0),
                                    ("ladder", 0.0)] {
                let colours = try Self.colouring(trial)
                let count = BraidReading.face(
                    picture, section: built.construction.section, widths: [1, 2, 3, 4],
                    workedLengthwise: { Self.plain.contains(colours[$0] ?? "") }
                )
                #expect(abs(count.percent - wanted) < 1.0, "\(trial)")
            }
        }
    }

    @Test func theTwoFacesAreBuiltAlike() throws {
        for flatten in [false, true] {
            let built = try BraidCentrelineFixtureTests.built(flat: true, cycles: 3, flatten: flatten)
            #expect(BraidReading.facesBuiltAlike(built).isEmpty)
        }
    }

    // MARK: the round braid

    private func tube() throws -> (BraidCentrelines, BraidOccupancy) {
        let built = try BraidCentrelineFixtureTests.built(flat: false, cycles: 7, flatten: false)
        let occupancy = try #require(BraidOccupancy.history(
            of: BraidMethodCatalog.maruGenji16, on: BraidMethodCatalog.stand16,
            crossSection: BraidMethodCatalog.maruGenji16CrossSection, cycles: 4
        ))
        return (built, occupancy)
    }

    private func read(
        _ built: BraidCentrelines, columns: [Int], slotCount: Int, rows: Int
    ) throws -> [[Int]] {
        let found = try #require(BraidReading.rows(of: built.construction, atColumns: columns))
        var pictures = [BraidPicture]()
        for slot in columns {
            let angle = 2 * Double.pi * Double(slot) / Double(slotCount)
            // From outside the braid, looking in.
            pictures.append(BraidPicture.paint(built, looking: SIMD3(-cos(angle), -sin(angle), 0)))
        }
        var grid = [[Int]]()
        for row in 0..<rows {
            var line = [Int]()
            for (index, picture) in pictures.enumerated() {
                let height = found.heights[index][found.settled + row]
                line.append(BraidReading.middleOfSilhouette(picture, atHeight: height) ?? 0)
            }
            grid.append(line)
        }
        return grid
    }

    /// **Thirty-two of thirty-two, off the picture.** The views are aimed at the
    /// slots a hand lands on, and each column is read at its own rest.
    @Test func theTubeReadsThirtyTwoOfThirtyTwoOffThePicture() throws {
        let fixture = try BraidFixtures.decode(Readings.self, from: "readings")
        let target = try BraidFixtures.decode(BraidTubeFigureTests.MaruFixture.self,
                                              from: "maru-occupancy")
        let (built, occupancy) = try tube()
        let columns = try #require(occupancy.columns(.landing))
        let found = try #require(BraidReading.rows(of: built.construction, atColumns: columns))
        #expect(found.settled == fixture.maru.rows.readFromRest)

        let grid = try read(built, columns: columns, slotCount: 16, rows: 4)
        #expect(grid == fixture.maru.landing.grid)
        let best = try #require(BraidGridAgreement.best(of: grid, against: target.task004))
        #expect(best.same == 32)
        #expect(best.mirrored == fixture.maru.landing.agreement.mirror)
        // No thread comes out twice in one row.
        #expect(grid.allSatisfy { Set($0).count == $0.count })
        #expect(fixture.maru.landing.aThreadTwiceInARow.isEmpty)
    }

    /// **The other angle is worse, and it is worse in the way it was said to be.**
    /// Aimed at the seam between two slots, the same thread comes out twice in a
    /// row and the agreement falls away.
    @Test func aimingAtTheSeamReadsTheSameThreadTwice() throws {
        let fixture = try BraidFixtures.decode(Readings.self, from: "readings")
        let target = try BraidFixtures.decode(BraidTubeFigureTests.MaruFixture.self,
                                              from: "maru-occupancy")
        let (built, occupancy) = try tube()
        let landing = try #require(occupancy.columns(.landing))
        // Halfway between each closing pair's two slots.
        let seams = occupancy.closingPairs.map { Double($0.lead) + 0.5 }
        let found = try #require(BraidReading.rows(of: built.construction, atColumns: landing))
        var pictures = [BraidPicture]()
        for seam in seams {
            let angle = 2 * Double.pi * seam / 16
            pictures.append(BraidPicture.paint(built, looking: SIMD3(-cos(angle), -sin(angle), 0)))
        }
        var grid = [[Int]]()
        for row in 0..<4 {
            grid.append(pictures.enumerated().map { index, picture in
                BraidReading.middleOfSilhouette(
                    picture, atHeight: found.heights[index][found.settled + row]
                ) ?? 0
            })
        }
        let best = try #require(BraidGridAgreement.best(of: grid, against: target.task004))
        #expect(best.same < 32)
        #expect(grid.contains { Set($0).count < $0.count })
        #expect(!fixture.maru.middle.aThreadTwiceInARow.isEmpty)
    }
}
