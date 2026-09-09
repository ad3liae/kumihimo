import Foundation
import Testing
@testable import Kumihimo

/// Task 025-3: drawing the braid, and measuring what came out.
@MainActor
struct BraidPictureTests {
    struct Readings: Decodable {
        struct Section: Decodable {
            let widthMean: Double
            let thicknessMean: Double
            let thicknessMax: Double
            let ratio: Double
            let lengthwise: [Double]
            let outerDiameter: Double?

            enum CodingKeys: String, CodingKey {
                case widthMean = "width_mean"
                case thicknessMean = "thickness_mean"
                case thicknessMax = "thickness_max"
                case ratio, lengthwise
                case outerDiameter = "outer_diameter"
            }
        }
        struct Shape: Decodable { let section: Section }
        struct Hira: Decodable { let round: Shape; let ellipse: Shape }
        struct Maru: Decodable { let section: Section }
        let hira: Hira
        let maru: Maru
    }

    /// The section the braid actually came out at, held against the Python's.
    @Test(arguments: [("round", false), ("ellipse", true)])
    func theFlatBraidsSectionIsTheOneThePythonMeasures(
        name: String, flatten: Bool
    ) throws {
        let fixture = try BraidFixtures.decode(Readings.self, from: "readings")
        let wanted = name == "round" ? fixture.hira.round.section : fixture.hira.ellipse.section
        let built = try BraidCentrelineFixtureTests.built(flat: true, cycles: 3, flatten: flatten)
        let measured = try #require(BraidSectionMeasure.measure(built, tube: false))
        #expect(abs(measured.width - wanted.widthMean) < 1e-6)
        #expect(abs(measured.thickness - wanted.thicknessMean) < 1e-6)
        #expect(abs(measured.thickest - wanted.thicknessMax) < 1e-6)
        #expect(abs(measured.widthOverThickness - wanted.ratio) < 1e-6)
        #expect(measured.outerDiameter == nil)          // a flat braid has none
        #expect(abs(measured.lengthwise.lowerBound - wanted.lengthwise[0]) < 1e-9)
        #expect(abs(measured.lengthwise.upperBound - wanted.lengthwise[1]) < 1e-9)
    }

    @Test func theTubesSectionIsTheOneThePythonMeasures() throws {
        let fixture = try BraidFixtures.decode(Readings.self, from: "readings")
        let built = try BraidCentrelineFixtureTests.built(flat: false, cycles: 7, flatten: false)
        let measured = try #require(BraidSectionMeasure.measure(built, tube: true))
        #expect(abs(measured.width - fixture.maru.section.widthMean) < 1e-6)
        #expect(abs(measured.thickness - fixture.maru.section.thicknessMean) < 1e-6)
        #expect(abs(measured.widthOverThickness - fixture.maru.section.ratio) < 1e-6)
        let outer = try #require(measured.outerDiameter)
        #expect(abs(outer - (fixture.maru.section.outerDiameter ?? 0)) < 1e-6)
    }

    // MARK: the picture itself

    /// **Whichever thread is actually in front is in front.** Two threads crossing,
    /// the nearer one painted over the further, whichever order they are drawn in.
    @Test func theNearerThreadWins() throws {
        let built = try BraidCentrelineFixtureTests.built(flat: true, cycles: 2, flatten: false)
        let front = BraidPicture.paint(built, looking: SIMD3(0, -1, 0))
        let back = BraidPicture.paint(built, looking: SIMD3(0, 1, 0))
        // Looking at the two faces, the same column of the braid cannot show the
        // same thread through the braid at the same height.
        var painted = 0, same = 0
        for row in 0..<min(front.height, back.height) {
            for column in 0..<min(front.width, back.width) {
                guard let a = front.thread(atPixel: column, row: row),
                      let b = back.thread(atPixel: front.width - 1 - column, row: row)
                else { continue }
                painted += 1
                if a == b { same += 1 }
            }
        }
        #expect(painted > 1000)
        #expect(Double(same) / Double(painted) < 0.2)
    }

    /// The painted silhouette is the braid's own reach across the view plus one
    /// thread, because the points are centrelines and a thread has a body.
    @Test func thePaintedSilhouetteIsTheBraidPlusOneThread() throws {
        let built = try BraidCentrelineFixtureTests.built(flat: true, cycles: 2, flatten: false)
        let picture = BraidPicture.paint(built, looking: SIMD3(0, -1, 0))
        let columns = (0..<picture.width).filter { column in
            (0..<picture.height).contains { picture.thread(atPixel: column, row: $0) != nil }
        }
        let first = try #require(columns.first)
        let last = try #require(columns.last)
        let spanned = Double(last - first + 1) / Double(picture.pixelsPerDiameter)
        var low = Double.infinity, high = -Double.infinity
        for thread in built.threads {
            for point in built.points[thread]! {
                let at = (point * picture.u).sum()
                low = min(low, at); high = max(high, at)
            }
        }
        #expect(abs(spanned - (high - low + 1)) < 2.0 / Double(picture.pixelsPerDiameter))
    }

    /// **Each view has its own axis across the page.** The two faces of a flat
    /// braid look along opposite normals, so their `u` point opposite ways, and a
    /// place of the braid is not at the same column in both.
    @Test func eachViewHasItsOwnAxisAcrossThePage() throws {
        let built = try BraidCentrelineFixtureTests.built(flat: true, cycles: 2, flatten: false)
        let front = BraidPicture.paint(built, looking: SIMD3(0, -1, 0))
        let back = BraidPicture.paint(built, looking: SIMD3(0, 1, 0))
        #expect(abs(front.u.x + back.u.x) < 1e-12)
        let spot = SIMD3<Double>(1, 0, 0)
        #expect(front.column(ofSpot: spot) != back.column(ofSpot: spot))
    }
}
