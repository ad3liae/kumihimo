import Foundation
import Testing
@testable import Kumihimo

/// Task 025-3: the flattened braid, and where the crest's height comes from.
@MainActor
struct BraidFlattenedCentrelineTests {
    /// The whole flattened braid, point for point.
    @Test func theFlattenedCentrelinesMatchThePython() throws {
        let fixture = try BraidFixtures.decode(
            BraidCentrelineFixtureTests.Fixture.self, from: "hira-centrelines-ellipse"
        )
        let built = try BraidCentrelineFixtureTests.built(
            flat: true, cycles: fixture.cycles, flatten: true
        )
        #expect(built.crests == fixture.crests)
        var worst = 0.0
        for (thread, wanted) in fixture.threads {
            let index = try #require(Int(thread))
            let mine = try #require(built.points[index], "thread \(thread)")
            let kinds = try #require(built.kinds[index], "thread \(thread)")
            #expect(mine.count == wanted.points.count, "thread \(thread)")
            #expect(kinds.map(\.rawValue) == wanted.kinds, "thread \(thread)")
            guard mine.count == wanted.points.count else { continue }
            for (point, want) in zip(mine, wanted.points) {
                worst = max(worst, abs(point.x - want[0]))
                worst = max(worst, abs(point.y - want[1]))
                worst = max(worst, abs(point.z - want[2]))
            }
        }
        #expect(worst < 1e-6, "worst difference \(worst) d")
    }

    /// Pressing the threads together closes the gaps: six of them fill the eight
    /// diameters of the face exactly, which is what makes book A p97 come out at
    /// 100 per cent rather than 99.
    @Test func theFlattenedFaceHasNoGapsLeftInIt() throws {
        let built = try BraidCentrelineFixtureTests.built(flat: true, cycles: 3, flatten: true)
        let section = built.construction.section
        #expect(abs(section.threadWidth * 6 - 8) < 1e-9)
        #expect(abs(section.threadWidth * section.threadThickness - 1) < 1e-9)
    }

    // MARK: - where the crest's height comes from

    /// With nothing measured, the construction's own figure stands: half a
    /// diameter, and it says `.derived`.
    @Test func theDefaultCrestIsTheDerivedHalfDiameter() throws {
        let built = try BraidCentrelineFixtureTests.built(flat: true, cycles: 2, flatten: false)
        #expect(built.crestHeight.isDerived)
        #expect(built.crestHeight.value == 0.5)
    }

    /// Book A p96's 0.45 is a fraction of the half-thickness, and the half-thickness
    /// is one thread's diameter, so it can be carried across as 0.45 d.
    @Test func aMeasuredCrestInDiametersIsUsedInsteadAndSaysSo() throws {
        let measured = try #require(BraidMethodCatalog.hiraGenji16Shape.crestHeight)
        let (scale, height) = BraidCentrelines.rise(for: measured)
        #expect(height.isObserved)
        #expect(height.value == 0.45)
        #expect(abs(scale - 0.9) < 1e-12)

        let derivation = try #require(BraidDerivation.derive(
            stand: BraidMethodCatalog.stand16, method: BraidMethodCatalog.hiraGenji16,
            crossSection: BraidMethodCatalog.hiraGenji16CrossSection
        ))
        let construction = try #require(BraidConstruction.construct(
            of: derivation.method, on: derivation.stand,
            crossSection: derivation.crossSection, fold: derivation.fold, cycles: 2
        ))
        let derived = try #require(BraidCentrelines.centrelines(of: construction))
        let observed = try #require(
            BraidCentrelines.centrelines(of: construction, crestHeight: measured)
        )
        func reach(_ lines: BraidCentrelines) -> Double {
            var out = 0.0
            for thread in lines.threads {
                for (point, kind) in zip(lines.points[thread]!, lines.kinds[thread]!)
                where kind == .restingOnTheSurface {
                    out = max(out, point.y)
                }
            }
            return out
        }
        // The face stays where it is; only what stands proud of it is scaled.
        #expect(abs((reach(observed) - 0.5) - (reach(derived) - 0.5) * 0.9) < 1e-9)
    }

    /// **The round braid's 0.12 is not in diameters**, so it is not carried and the
    /// derived d/2 stands, unverified.
    @Test func aMeasurementInOtherUnitsIsNotCarried() throws {
        let measured = try #require(BraidMethodCatalog.maruGenji16Shape.crestHeight)
        #expect(!measured.isSettled)
        #expect(try #require(measured.unsettled).contains("not in thread diameters"))
        let derivation = try #require(BraidDerivation.derive(
            stand: BraidMethodCatalog.stand16, method: BraidMethodCatalog.maruGenji16,
            crossSection: BraidMethodCatalog.maruGenji16CrossSection
        ))
        let construction = try #require(BraidConstruction.construct(
            of: derivation.method, on: derivation.stand,
            crossSection: derivation.crossSection, fold: derivation.fold, cycles: 3
        ))
        let built = try #require(BraidCentrelines.centrelines(of: construction))
        #expect(built.crestHeight.isDerived)
        #expect(built.crestHeight.value == 0.5)
    }
}
