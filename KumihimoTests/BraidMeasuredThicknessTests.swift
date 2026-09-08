import Foundation
import Testing
@testable import Kumihimo

/// Task 025-4, the author's ruling (d): **the flat braid's width over thickness is
/// a measured value, like the crest's height.**
///
/// The recipe carries it, and the construction takes its thickness to meet it. The
/// width does not move — the face is still eight diameters across six threads — and
/// the crest as a fraction of the half-thickness, which is the form book A gives it
/// in, does not move either, because the faces and the crests scale together.
///
/// **The construction's own figure is kept as the default** for a braid with no
/// measurement, which is what a braid somebody invents will be.
@MainActor
struct BraidMeasuredThicknessTests {
    private func flat() throws -> BraidFromRecipe {
        try #require(BraidFromRecipe.build(
            BraidMethodCatalog.hiraGenji16Recipe, on: BraidMethodCatalog.stand16
        ))
    }

    @Test func theBraidComesOutAtTheMeasuredRatio() throws {
        let built = try flat()
        let measured = try #require(BraidMethodCatalog.hiraGenji16Shape.widthOverThickness)
        #expect(measured.value == 3.3359)
        #expect(measured.isObserved)
        let section = try #require(built.section)
        #expect(abs(section.widthOverThickness - 3.3359) < 1e-3)
        #expect(built.widthOverThickness.isObserved)
    }

    /// **The width the construction lays out does not move**: six threads still
    /// fill the eight diameters of the face, exactly.
    ///
    /// The width the *section measure* reports moves a little all the same, by
    /// under two per cent — it is taken along the section's own principal axis, and
    /// that axis turns as the braid thins. That is why the scale is divided again
    /// rather than once.
    @Test func theWidthTheConstructionLaysOutDoesNotMove() throws {
        let built = try flat()
        let section = built.lines.construction.section
        #expect(abs(section.threadWidth * 6 - 8) < 1e-9)
        let measured = try #require(built.section)
        let plain = try BraidCentrelineFixtureTests.built(flat: true, cycles: 3, flatten: true)
        let before = try #require(BraidSectionMeasure.measure(plain, tube: false))
        #expect(abs(measured.width - before.width) / before.width < 0.02)
        #expect(measured.thickness < before.thickness)
    }

    /// The scale is one division: the ratio the construction came out at, over the
    /// one measured. Nothing is searched for and nothing is fitted by eye.
    @Test func theScaleIsOneDivisionFromWhatWasBuilt() throws {
        let plain = try BraidCentrelineFixtureTests.built(flat: true, cycles: 3, flatten: true)
        let before = try #require(BraidSectionMeasure.measure(plain, tube: false))
        let measured = try #require(BraidMethodCatalog.hiraGenji16Shape.widthOverThickness)
        let scale = try #require(BraidSection.thicknessScale(toMeet: measured,
                                                             from: before.widthOverThickness))
        #expect(abs(scale - before.widthOverThickness / 3.3359) < 1e-12)
        #expect(scale < 1)      // the construction came out too thick
    }

    /// **A braid with nothing measured keeps the construction's own figure**, and
    /// says where it came from.
    @Test func aBraidWithNothingMeasuredKeepsTheDerivedThickness() throws {
        let bare = BraidRecipe(
            id: "nothing-measured", name: "測っていない紐",
            notation: BraidMethodCatalog.hiraGenjiDisk,
            colouring: BraidMethodCatalog.hiraGenji16Colouring,
            shape: BraidShapeValues(),
            orderRoundTheBraid: BraidMethodCatalog.hiraGenji16CrossSection
        )
        let built = try #require(BraidFromRecipe.build(bare, on: BraidMethodCatalog.stand16))
        #expect(built.widthOverThickness.isDerived)
        let section = try #require(built.section)
        #expect(abs(section.widthOverThickness - built.widthOverThickness.value) < 1e-9)
        // Well short of the measured 3.3359: the construction is too thick without
        // the local flattening at crossings, which Task 024 holds over.
        #expect(section.widthOverThickness < 3.0)
    }

    /// **The tube is not touched.** It has no measured ratio and never presses.
    @Test func theTubeIsUnchanged() throws {
        let tube = try #require(BraidFromRecipe.build(
            BraidMethodCatalog.maruGenji16Recipe, on: BraidMethodCatalog.stand16
        ))
        #expect(tube.widthOverThickness.isDerived)
        #expect(tube.lines.construction.section.threadThickness == 1)
        let section = try #require(tube.section)
        #expect(abs((section.outerDiameter ?? 0) - 8.034024) < 1e-5)
    }

    /// Book A p97's three experiments still come out, on both faces, with the
    /// thickness taken to the measurement.
    @Test func bookAsThreeExperimentsStillComeOut() throws {
        let derivation = try #require(BraidDerivation.derive(
            stand: BraidMethodCatalog.stand16, method: BraidMethodCatalog.hiraGenji16,
            crossSection: BraidMethodCatalog.hiraGenji16CrossSection
        ))
        let measured = try #require(BraidMethodCatalog.hiraGenji16Shape.widthOverThickness)
        let plain = try BraidCentrelineFixtureTests.built(flat: true, cycles: 3, flatten: true)
        let before = try #require(BraidSectionMeasure.measure(plain, tube: false))
        let scale = try #require(BraidSection.thicknessScale(toMeet: measured,
                                                             from: before.widthOverThickness))
        let construction = try #require(BraidConstruction.construct(
            of: derivation.method, on: derivation.stand,
            crossSection: derivation.crossSection, fold: derivation.fold,
            cycles: 3, flatten: true, thicknessScale: scale
        ))
        let lines = try #require(BraidCentrelines.centrelines(
            of: construction, crestHeight: BraidMethodCatalog.hiraGenji16Shape.crestHeight
        ))
        for direction in [SIMD3<Double>(0, -1, 0), SIMD3<Double>(0, 1, 0)] {
            let picture = BraidPicture.paint(lines, looking: direction)
            for (trial, wanted) in [("weft-only", 100.0), ("arrow-feather", 100.0),
                                    ("ladder", 0.0)] {
                let colours = try BraidReadingFixtureTests.colouring(trial)
                let count = BraidReading.face(
                    picture, section: construction.section, widths: [1, 2, 3, 4],
                    workedLengthwise: { BraidReadingFixtureTests.plain.contains(colours[$0] ?? "") }
                )
                #expect(abs(count.percent - wanted) < 1.0, "\(trial)")
            }
        }
    }
}
