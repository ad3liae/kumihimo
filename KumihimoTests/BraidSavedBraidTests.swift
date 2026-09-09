import Foundation
import SwiftData
import Testing
@testable import Kumihimo

/// Task 027-2: **a saved project names its braid by the recipe's identifier**, and
/// one place does the reading.
@MainActor
struct BraidSavedBraidTests {
    /// The keys older builds wrote were the presets' identifiers, and a preset's
    /// identifier is its recipe's. **So the table is empty and the reading is the
    /// identity** — which is worth a test, because it is the claim the migration
    /// rests on.
    @Test func theKeysAlreadyWrittenAreTheRecipesOwn() {
        #expect(BraidSavedBraid.renamedKeys.isEmpty)
        for preset in BraidPresetCatalog.presets {
            let saved = BraidSavedBraid.savedKey(forPreset: preset.id)
            #expect(saved == preset.id.rawValue, "\(preset.id.rawValue)")
            #expect(BraidSavedBraid.recipeID(fromSaved: preset.id.rawValue)
                    == preset.id.rawValue)
        }
    }

    @Test(arguments: ["maru-genji-16", "hira-genji-16"])
    func aSavedKeyNamesARecipeAndAPreset(key: String) throws {
        let recipe = try #require(BraidSavedBraid.recipe(fromSaved: key))
        #expect(recipe.id == key)
        #expect(BraidSavedBraid.preset(fromSaved: key)?.rawValue == key)
        #expect(BraidSavedBraid.savedKey(for: recipe) == key)
    }

    /// **A braid this build does not carry is an answer, not a failure.**
    @Test func aKeyWithNoRecipeReadsAsNothingRatherThanThrowing() {
        #expect(BraidSavedBraid.recipe(fromSaved: "a-braid-from-a-later-build") == nil)
        #expect(BraidSavedBraid.preset(fromSaved: "a-braid-from-a-later-build") == nil)
        // And it still says what recipe id it would be, so a rename can find it.
        #expect(BraidSavedBraid.recipeID(fromSaved: "a-braid-from-a-later-build")
                == "a-braid-from-a-later-build")
    }

    // MARK: what is written and read back

    private func store() throws -> ModelContext {
        let container = try ModelContainer(
            for: KumihimoProject.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// **A project written by an older build** — the key in the column the older
    /// build wrote — opens with the same recipe and the same colouring.
    @Test(arguments: [("maru-genji-16", "丸源氏"), ("hira-genji-16", "平源氏")])
    func anOlderSaveOpensWithTheSameRecipeAndColouring(key: String, name: String) throws {
        let context = try store()
        let colouring = key == "hira-genji-16"
            ? BraidMethodCatalog.hiraGenji16Colouring
            : BraidMethodCatalog.maruGenji16Colouring
        let project = KumihimoProject(
            id: UUID(), name: "古い保存", braidTypeName: name,
            selectedBraidRecipeID: key, threadCount: 16,
            threadAssignments: colouring, thumbnailData: nil,
            createdAt: .now, updatedAt: .now
        )
        context.insert(project)
        try context.save()

        let service = ProjectEditorPersistenceService(context: context)
        let loaded = try #require(try service.load(id: project.id))
        #expect(try #require(loaded.braidRecipe).id == key)
        #expect(loaded.braidPresetID?.rawValue == key)
        #expect(try loaded.validatedThreadAssignments() == colouring.sorted {
            $0.position < $1.position
        })
    }

    /// Written with the new key and read back the same.
    @Test func writingAndReadingBackGivesTheSameProject() throws {
        let context = try store()
        let service = ProjectEditorPersistenceService(context: context)
        // The store writes the braid's name beside the key when a preset is
        // chosen, and a load checks the two agree, so the draft carries both.
        let draft = ProjectDraft(
            name: "新しい保存",
            selectedBraidPresetID: .hiraGenji16,
            braidTypeName: BraidPresetCatalog.hiraGenji.displayName,
            threadCount: 16,
            threadAssignments: BraidMethodCatalog.hiraGenji16Colouring
        )
        #expect(draft.savedBraidKey == "hira-genji-16")
        let saved = try service.create(from: draft, name: "新しい保存")
        #expect(saved.selectedBraidRecipeID == "hira-genji-16")
        let loaded = try #require(try service.load(id: saved.id))
        #expect(try #require(loaded.braidRecipe).id == "hira-genji-16")
        #expect(loaded.braidPresetID == .hiraGenji16)
    }

    /// **A project naming a braid this build has no recipe for still opens.** It
    /// takes the same road as a braid with no drawer: nothing is drawn, and the
    /// screen says so.
    @Test func aProjectNamingAnUnknownBraidStillOpens() throws {
        let context = try store()
        let project = KumihimoProject(
            id: UUID(), name: "知らない紐", braidTypeName: "未知の組み方",
            selectedBraidRecipeID: "a-braid-from-a-later-build", threadCount: 16,
            threadAssignments: BraidMethodCatalog.maruGenji16Colouring,
            thumbnailData: nil, createdAt: .now, updatedAt: .now
        )
        context.insert(project)
        try context.save()
        let service = ProjectEditorPersistenceService(context: context)
        let loaded = try #require(try service.load(id: project.id))   // does not throw
        #expect(loaded.braidRecipe == nil)
        #expect(loaded.braidPresetID == nil)
        #expect(loaded.braidDisplayName == "未知の組み方")
    }
}
