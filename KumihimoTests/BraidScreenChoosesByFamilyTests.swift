import Foundation
import Testing
@testable import Kumihimo

/// Task 027-1: **the screens choose the drawer by the braid's family**, not by the
/// braid's name.
@MainActor
struct BraidScreenChoosesByFamilyTests {
    /// **Every shipped preset has a recipe and a stand.** A drawer is a separate
    /// question, and Task 008's eight-thread braids answer it "none" -- so what is
    /// promised here is that the braid works out, not that anything draws it.
    @Test(arguments: BraidPresetCatalog.presets)
    func everyShippedPresetHasARecipeAndAStand(preset: BraidPreset) throws {
        let recipe = try #require(BraidMethodCatalog.recipe(for: preset.id))
        #expect(recipe.id == preset.id.rawValue)
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        #expect(preset.supportedThreadCounts == [stand.positionCount])
        #expect(recipe.worked(on: stand) != nil)
    }

    /// **Only the two families with drawers get one.** The screens ask the family,
    /// so a braid of a family nobody draws reaches the empty space instead.
    @Test(arguments: BraidPresetCatalog.presets)
    func aDrawerComesOnlyFromAFamilyThatHasOne(preset: BraidPreset) throws {
        let recipe = try #require(BraidMethodCatalog.recipe(for: preset.id))
        let drawn: Set<BraidPresetID> = [.maruGenji16, .hiraGenji16]
        #expect((BraidFamilyDrawing.drawer(for: recipe) != nil) == drawn.contains(preset.id))
    }

    @Test func theFamilyChosenIsTheRightOneForEachPreset() throws {
        let flat = try #require(BraidMethodCatalog.recipe(for: .hiraGenji16))
        let tube = try #require(BraidMethodCatalog.recipe(for: .maruGenji16))
        #expect(BraidFamilyDrawing.drawer(for: flat, on: BraidMethodCatalog.stand16)
                == Flat16SurfaceMesh.family)
        #expect(BraidFamilyDrawing.drawer(for: tube, on: BraidMethodCatalog.stand16)
                == RoundTube16SurfaceMesh.family)
    }

    /// **What the screen shows is the same mesh the drawer makes.** Held against the
    /// vertex hashes pinned in `BraidMeshHashTests`, by way of the drawer the family
    /// names. The flat braid's value moved once, in Task 030, for the reason given
    /// there; this is the same number, not a second opinion about it.
    @Test func theMeshTheScreenShowsIsTheSameOne() throws {
        let flat = try #require(BraidMethodCatalog.recipe(for: .hiraGenji16))
        #expect(BraidFamilyDrawing.drawer(for: flat, on: BraidMethodCatalog.stand16)
                == Flat16SurfaceMesh.family)
        let flatPattern = try #require(Flat16SurfacePatternGenerator.generate(
            assignments: BraidMethodCatalog.hiraGenji16Colouring))
        let flatMesh = try #require(Flat16SurfaceMesh.generate(pattern: flatPattern))
        #expect(BraidMeshHashTests.hash(flatMesh.positions) == 0x53c4_4c9b_835a_e598)

        let tube = try #require(BraidMethodCatalog.recipe(for: .maruGenji16))
        #expect(BraidFamilyDrawing.drawer(for: tube, on: BraidMethodCatalog.stand16)
                == RoundTube16SurfaceMesh.family)
        let tubePattern = try #require(RoundTube16SurfacePatternGenerator.generate(
            assignments: BraidMethodCatalog.maruGenji16Colouring))
        let tubeMesh = try #require(RoundTube16SurfaceMesh.generate(pattern: tubePattern))
        #expect(BraidMeshHashTests.hash(tubeMesh.positions) == 0xe3fc_af47_ceea_d34e)
    }

    /// **A braid nothing draws gets no drawer**, and the screen shows the empty
    /// space instead. Two of them: a table the code has not seen, and a second flat
    /// braid, which waits on the centring being put right.
    @Test func abraidNothingDrawsGetsNoDrawer() throws {
        let invented = BraidRecipe(
            id: "a-table-this-code-has-not-seen", name: "架空の紐",
            notation: BraidDiskNotation(
                source: "book C Fig.32, turned a quarter round the disk",
                notchCount: 32,
                standPositionByRestingNotch: BraidMethodCatalog.diskRestingNotches,
                moves: BraidMethodCatalog.maruGenjiDisk.moves.map {
                    BraidMove(from: ($0.from - 1 + 8) % 32 + 1, to: ($0.to - 1 + 8) % 32 + 1)
                },
                threadsPerStep: 2
            ),
            colouring: BraidMethodCatalog.maruGenji16Colouring,
            shape: BraidShapeValues()
        )
        // A tube it is, and a tube has a drawer -- so this one *is* drawn.
        #expect(BraidFamilyDrawing.drawer(for: invented, on: BraidMethodCatalog.stand16)
                == RoundTube16SurfaceMesh.family)

        let secondFlat = BraidRecipe(
            id: "another-flat-braid", name: "別の平らな紐",
            notation: BraidMethodCatalog.hiraGenjiDisk,
            colouring: BraidMethodCatalog.hiraGenji16Colouring,
            shape: BraidMethodCatalog.hiraGenji16Shape,
            orderRoundTheBraid: BraidMethodCatalog.hiraGenji16CrossSection
        )
        #expect(BraidFamilyDrawing.drawer(for: secondFlat, on: BraidMethodCatalog.stand16) == nil)
        // And a preset with no recipe at all.
        #expect(BraidMethodCatalog.recipe(for: BraidPresetID(rawValue: "not-a-braid")) == nil)
    }

    /// **A full-screen preview always has a way out.** The solid drawers dismiss
    /// from a navigation bar of their own; the figure has no bar, and neither has
    /// the empty space a braid nothing draws, so the screen puts a dismiss button
    /// beside the picker for those two. Task 008's eight-thread braids are the
    /// first shipped braids that reach the second case.
    @Test(arguments: BraidPresetCatalog.presets)
    func aPreviewShownOnItsOwnCanAlwaysBeLeft(preset: BraidPreset) throws {
        let recipe = try #require(BraidMethodCatalog.recipe(for: preset.id))
        // The figure never has a bar of its own.
        #expect(BraidPreviewForFamily.needsItsOwnWayOut(recipe: recipe, showingFigure: true))
        // Solid: only when a drawer draws it does the drawer's own bar carry one.
        #expect(BraidPreviewForFamily.needsItsOwnWayOut(recipe: recipe, showingFigure: false)
                == (BraidFamilyDrawing.drawer(for: recipe) == nil))
    }

    /// The notice each braid carries moved from a branch in the view onto the
    /// preset. **The wording did not change.**
    @Test func eachPresetCarriesItsOwnNoticeAndTheWordingIsUnchanged() {
        #expect(BraidPresetCatalog.maruGenji.prototypeNotice
                == ProjectEditorStrings.maruGenjiPrototypeNotice)
        #expect(BraidPresetCatalog.hiraGenji.prototypeNotice
                == ProjectEditorStrings.hiraGenjiPrototypeNotice)
        #expect(BraidPresetCatalog.presets.allSatisfy { !$0.prototypeNotice.isEmpty })
        // The 3D label is built from the braid's own name now.
        #expect(ProjectEditorStrings.thumbnail3DLabel("丸源氏")
                == ProjectEditorStrings.maruGenjiThumbnail3DLabel)
        #expect(ProjectEditorStrings.thumbnail3DLabel("平源氏")
                == ProjectEditorStrings.hiraGenjiThumbnail3DLabel)
    }
}

extension BraidPreset: @retroactive CustomTestStringConvertible {
    public var testDescription: String { id.rawValue }
}
