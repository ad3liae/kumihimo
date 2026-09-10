import CoreGraphics
import Foundation
import Testing
@testable import Kumihimo

/// Task 025-3, the last step: the new path end to end, from a recipe to a picture.
///
/// **Not the shipping path.** The frozen generators are untouched; this is here so
/// the two can be put side by side, which is Task 025-4's job.
@MainActor
struct BraidFromRecipeTests {
    @Test(arguments: BraidMethodCatalog.recipes)
    func everyShippedRecipeBuildsAndDraws(recipe: BraidRecipe) throws {
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        let built = try #require(BraidFromRecipe.build(recipe, on: stand))
        let pictures = built.pictures(slotCount: stand.positionCount)
        #expect(!pictures.isEmpty)
        for picture in pictures {
            #expect(picture.image.width > 8)
            #expect(picture.image.height > 8)
        }
    }

    /// A flat braid has two faces to show; a tube has one view a column, and its
    /// columns are the occupancy history's, not eight even angles.
    @Test func theViewsWorthShowingAreDerivedRatherThanListed() throws {
        let flat = try #require(BraidFromRecipe.build(
            BraidMethodCatalog.hiraGenji16Recipe, on: BraidMethodCatalog.stand16
        ))
        #expect(flat.pictures(slotCount: 16).map(\.name) == ["front", "back"])

        let tube = try #require(BraidFromRecipe.build(
            BraidMethodCatalog.maruGenji16Recipe, on: BraidMethodCatalog.stand16
        ))
        let names = tube.pictures(slotCount: 16).map(\.name)
        #expect(names.count == 8)
        #expect(names == ["slot 0", "slot 3", "slot 4", "slot 7",
                          "slot 8", "slot 11", "slot 12", "slot 15"])
    }

    /// The measured crest is used where it is in diameters, and not where it is not.
    @Test func theCrestComesFromTheRecipeOnlyWhenItIsInDiameters() throws {
        let flat = try #require(BraidFromRecipe.build(
            BraidMethodCatalog.hiraGenji16Recipe, on: BraidMethodCatalog.stand16
        ))
        #expect(flat.lines.crestHeight.isObserved)
        #expect(flat.lines.crestHeight.value == 0.45)

        let tube = try #require(BraidFromRecipe.build(
            BraidMethodCatalog.maruGenji16Recipe, on: BraidMethodCatalog.stand16
        ))
        // Its measured crest is a fraction of the nominal radius, so it is not a
        // length this construction can use, and the derived d/2 stands.
        #expect(tube.lines.crestHeight.isDerived)
        #expect(tube.lines.crestHeight.value == 0.5)
        #expect(tube.lines.crestHeight.isInThreadDiameters)
    }

    /// A tube is never pressed, however it is asked for.
    @Test func aTubeIsNeverPressed() throws {
        let tube = try #require(BraidFromRecipe.build(
            BraidMethodCatalog.maruGenji16Recipe, on: BraidMethodCatalog.stand16, flatten: true
        ))
        #expect(tube.lines.construction.section.threadWidth == 1)
        #expect(tube.lines.construction.section.threadThickness == 1)
    }

    /// What the new path says about each braid's shape, beside what was measured.
    /// **Neither is adjusted to meet the other**; Task 025-4 is where they are
    /// judged against the photographs.
    @Test func theNewPathReportsItsOwnShapeBesideTheMeasuredOne() throws {
        let flat = try #require(BraidFromRecipe.build(
            BraidMethodCatalog.hiraGenji16Recipe, on: BraidMethodCatalog.stand16
        ))
        let section = try #require(flat.section)
        let measured = try #require(BraidMethodCatalog.hiraGenji16Shape.widthOverThickness)
        #expect(section.widthOverThickness > 2)
        #expect(section.widthOverThickness < measured.value)   // still too thick
        #expect(flat.pitch.isDerived)
        #expect(abs(flat.pitch.value - 0.375) < 1e-12)

        let tube = try #require(BraidFromRecipe.build(
            BraidMethodCatalog.maruGenji16Recipe, on: BraidMethodCatalog.stand16
        ))
        let band = try #require(BraidMethodCatalog.maruGenji16Shape.chevronsPerBraidWidth)
        let spread = try #require(band.spread)
        #expect(((1 / spread.upperBound)...(1 / spread.lowerBound)) ~= tube.pitch.value)
    }

    /// Draws the new path for the author to look at. **Decides nothing.**
    @Test func theNewPathIsDrawnForTheAuthorToLookAt() throws {
        for recipe in BraidMethodCatalog.recipes {
            let stand = try #require(BraidMethodCatalog.stand(for: recipe))
            let built = try #require(BraidFromRecipe.build(recipe, on: stand))
            for picture in built.pictures(slotCount: stand.positionCount) {
                let name = "\(recipe.id)-\(picture.name.replacingOccurrences(of: " ", with: "-"))"
                let url = try BraidFigureDrawing.write(picture.image, named: name)
                #expect(FileManager.default.fileExists(atPath: url.path))
            }
        }
    }
}
