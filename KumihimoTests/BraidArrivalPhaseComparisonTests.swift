import Foundation
import Testing
@testable import Kumihimo

/// Task 025-4 step 4: do the two working-outs give the same arrival phases?
///
/// **They do not, and the difference is a clock.** The per-braid derivation counts
/// book A's printed steps, two moves at a time, and gets sevenths; the general
/// working-out counts book C's instants, one move each, and gets thirteenths. Both
/// are "where along a row a place takes its new appearance"; they are told by
/// different clocks, and book C is the source of record.
///
/// **So this replacement is not made.** The phases feed the stitch boundaries, so
/// substituting would move the mesh, and step 4 says to stop and report when
/// anything moves. Pinned here so the two sets are on the record.
@MainActor
struct BraidArrivalPhaseComparisonTests {
    @Test func theTwoWorkingOutsCountOnDifferentClocks() throws {
        let derivation = try #require(Flat16SurfacePatternGenerator.working)
        // Book A's clock: sevenths. The drawing that ships is built on these.
        #expect(HiraGenjiWeaveDerivation.arrivalPhase(atWidthPosition: -1) == 1.0 / 7)
        #expect(HiraGenjiWeaveDerivation.arrivalPhase(atWidthPosition: 1) == 0.5)
        // Book C's clock: thirteenths.
        let edge = try #require(derivation.arrivalPhase(atWidth: -1))
        let body = try #require(derivation.arrivalPhase(atWidth: 1))
        #expect(abs(edge - 1.5 / 13) < 1e-12)
        #expect(abs(body - 7.0 / 13) < 1e-12)
        // The two agree only where a place takes its appearance at the closing.
        #expect(HiraGenjiWeaveDerivation.arrivalPhase(atWidthPosition: 0) == 1.0)
        #expect(derivation.arrivalPhase(atWidth: 0) == 1.0)
    }

    @Test func whatEachSaysAboutTheArrivalPhases() throws {
        let derivation = try #require(Flat16SurfacePatternGenerator.working)
        var lines = ["width: per-braid, general"]
        for width in -1...Flat16SurfacePatternGenerator.broadFaceColumnCount {
            let old = HiraGenjiWeaveDerivation.arrivalPhase(atWidthPosition: width)
            let new = derivation.arrivalPhase(atWidth: width)
            lines.append("\(width): \(old.map { String($0) } ?? "-"), "
                         + (new.map { String($0) } ?? "-"))
        }
        try BraidSideBySideTests.record(lines.joined(separator: "\n"),
                                        named: "arrival-phases")
        #expect(!lines.isEmpty)
    }
}

/// Task 025-4, the author's ruling (b): **the phases stay on book A's clock**, and
/// until the centring is put right a second flat braid has no drawer.
@MainActor
struct BraidFlatDrawerIsWiredToOneBraidTests {
    @Test func theFlatDrawerSaysWhichBraidItIsWiredTo() {
        #expect(Flat16SurfacePatternGenerator.drawsOnlyTheRecipe
                == BraidMethodCatalog.hiraGenji16Recipe.id)
    }

    /// A second flat braid — the same table with a different id — gets no drawer.
    /// **No drawer is the answer, not a drawing that is wrong.**
    @Test func aSecondFlatBraidHasNoDrawerYet() throws {
        let another = BraidRecipe(
            id: "another-flat-braid", name: "別の平らな紐",
            notation: BraidMethodCatalog.hiraGenjiDisk,
            colouring: BraidMethodCatalog.hiraGenji16Colouring,
            shape: BraidMethodCatalog.hiraGenji16Shape,
            orderRoundTheBraid: BraidMethodCatalog.hiraGenji16CrossSection
        )
        let worked = try #require(another.worked(on: BraidMethodCatalog.stand16))
        #expect(BraidFamily.family(of: worked.derivation) == Flat16SurfaceMesh.family)
        #expect(BraidFamilyDrawing.drawing(for: another, on: BraidMethodCatalog.stand16) == nil)
        // The one it is wired to still draws.
        #expect(BraidFamilyDrawing.drawing(
            for: BraidMethodCatalog.hiraGenji16Recipe, on: BraidMethodCatalog.stand16
        ) != nil)
    }
}
