import Foundation
import SwiftData
import Testing
@testable import Kumihimo

/// Task 058: **a project is braided on a round or a square stand**, the editor
/// offers only the braids that stand and thread count take, and a braid's detail
/// opens in a sheet titled with the braid's own name.
@MainActor
struct BraidStandAndDetailTests {
    // MARK: which braids a stand offers

    /// **On a round stand, every thread count offers what it offered before
    /// there was a choice**, and a square stand offers nothing yet.
    @Test(arguments: ProjectDraft.supportedThreadCounts)
    func aRoundStandOffersWhatItDidAndASquareStandNothing(threadCount: Int) {
        #expect(BraidPresetCatalog.availablePresets(threadCount: threadCount, standKind: .round)
                == BraidPresetCatalog.availablePresets(threadCount: threadCount))
        #expect(BraidPresetCatalog.availablePresets(threadCount: threadCount, standKind: .square)
            .isEmpty)
    }

    /// The same, written out, so a braid moving stand shows up here by name.
    @Test func theRoundStandsBraidsByThreadCount() {
        func ids(_ count: Int) -> [BraidPresetID] {
            BraidPresetCatalog.availablePresets(threadCount: count, standKind: .round).map(\.id)
        }
        #expect(ids(4) == [.maruYotsu4])
        #expect(ids(8) == [.yatsuKongoS8, .yatsuKongoZ8, .yatsuKongoGaeshi8, .edoYatsu8])
        #expect(ids(12).isEmpty)
        #expect(ids(16) == [.maruGenji16, .hiraGenji16])
    }

    /// **The stand is read off the recipe's stand**, not written on the preset.
    /// Every shipped recipe — the disk ones too — is set up on a round stand.
    @Test(arguments: BraidPresetCatalog.presets)
    func aPresetsStandIsItsRecipesStand(preset: BraidPreset) throws {
        let recipe = try #require(BraidMethodCatalog.recipe(for: preset.id))
        let stand = try #require(BraidMethodCatalog.stand(for: recipe))
        #expect(preset.standKind == stand.kind)
        #expect(preset.standKind == .round)
    }

    @Test func aPresetWithNoRecipeHasNoStandAndIsNotOffered() {
        let orphan = BraidPreset(
            id: BraidPresetID(rawValue: "not-a-braid"), displayName: "架空",
            supportedThreadCounts: [16], crossSectionProfile: .round,
            verificationLevel: .movementRules, prototypeNotice: "架空"
        )
        #expect(orphan.standKind == nil)
        #expect(!orphan.supports(standKind: .round))
        #expect(!orphan.supports(standKind: .square))
    }

    // MARK: changing the stand in the editor

    /// **A braid the new stand does not offer is unselected, and the colours
    /// stay** — the same as changing the thread count.
    @Test func changingTheStandUnselectsTheBraidAndKeepsTheColours() throws {
        let store = try makeStore()
        store.requestThreadCount(16)
        store.selectedThreadPosition = 3
        store.selectColor(ThreadColorID(rawValue: "blue"))
        store.selectBraidPreset(.maruGenji16)
        let colours = store.draft.threadAssignments

        store.selectStandKind(.square)

        #expect(store.draft.standKind == .square)
        #expect(store.draft.selectedBraidPresetID == nil)
        #expect(store.draft.braidTypeName == KumihimoProject.undecidedBraidName)
        #expect(store.draft.threadAssignments == colours)
        #expect(store.draft.threadCount == 16)
        #expect(store.availableBraidPresets.isEmpty)
        // Nothing can be chosen on a square stand, even by asking directly.
        store.selectBraidPreset(.maruGenji16)
        #expect(store.draft.selectedBraidPresetID == nil)

        // Back to round: the braids return, and the choice does not come back by
        // itself.
        store.selectStandKind(.round)
        #expect(store.availableBraidPresets.map(\.id) == [.maruGenji16, .hiraGenji16])
        #expect(store.draft.selectedBraidPresetID == nil)
        #expect(store.draft.threadAssignments == colours)
    }

    @Test func aNewProjectStartsOnARoundStand() throws {
        let store = try makeStore()
        #expect(store.draft.standKind == .round)
        #expect(ProjectDraft().standKind == .round)
    }

    /// A braid on a stand it is not set up on is not a valid draft, so it cannot
    /// be saved that way.
    @Test func aDraftNamingABraidOffTheStandIsNotValid() {
        let draft = ProjectDraft(
            selectedBraidPresetID: .maruGenji16,
            braidTypeName: BraidPresetCatalog.maruGenji.displayName,
            standKind: .square,
            threadCount: 16
        )
        #expect(!draft.hasValidAssignments)
        var round = draft
        round.standKind = .round
        #expect(round.hasValidAssignments)
    }

    // MARK: what is saved

    /// Saved, overwritten, saved under a new name: **the stand goes with the
    /// project each time.**
    @Test func theStandSurvivesSavingOverwritingAndSavingAs() throws {
        let container = try makeContainer()
        let firstID = UUID()
        let copyID = UUID()
        var identifiers = [firstID, copyID]
        let store = ProjectEditorStore(
            persistence: ProjectEditorPersistenceService(
                context: container.mainContext,
                makeIdentifier: { identifiers.removeFirst() }
            )
        )

        store.selectStandKind(.square)
        store.presentNewSaveSheet()
        store.proposedName = "角台の案"
        store.submitNameSheet()
        container.mainContext.rollback()
        #expect(try load(firstID, from: container).standKind == .square)
        #expect(!store.hasUnsavedChanges)

        store.selectStandKind(.round)
        #expect(store.hasUnsavedChanges)
        store.overwrite()
        container.mainContext.rollback()
        #expect(try load(firstID, from: container).standKind == .round)

        store.selectStandKind(.square)
        store.presentDuplicateSaveSheet()
        store.proposedName = "角台の複製"
        store.submitNameSheet()
        container.mainContext.rollback()
        #expect(try load(copyID, from: container).standKind == .square)
        // Saving as leaves the original as it was.
        #expect(try load(firstID, from: container).standKind == .round)
        #expect(store.currentProjectID == copyID)
        #expect(store.draft.standKind == .square)
    }

    /// **A save written before there was a stand to choose opens on a round
    /// stand.** The store is written to disk by the schema as it stood before
    /// Task 058 — no stand column — and opened by the one the app has now, the
    /// way the app opens it.
    @Test func aSaveWrittenBeforeStandsOpensOnARoundStand() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "task058-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "before-stands.store")
        let id = UUID()
        let colouring = BraidMethodCatalog.edoYatsu8Colouring.sorted { $0.position < $1.position }

        try autoreleasepool {
            let old = try ModelContainer(
                for: Schema(versionedSchema: KumihimoSchemaBeforeStands.self),
                configurations: ModelConfiguration(url: url)
            )
            let context = ModelContext(old)
            context.insert(KumihimoSchemaBeforeStands.KumihimoProject(
                id: id, name: "古い保存",
                braidTypeName: BraidPresetCatalog.edoYatsu.displayName,
                selectedBraidRecipeID: BraidPresetID.edoYatsu8.rawValue,
                threadCount: 8,
                threadAssignmentsData: try JSONEncoder().encode(colouring)
            ))
            try context.save()
        }

        let current = try ModelContainer(
            for: KumihimoProject.self,
            configurations: ModelConfiguration(url: url)
        )
        let loaded = try #require(
            try ProjectEditorPersistenceService(context: current.mainContext).load(id: id)
        )
        #expect(loaded.standKind == .round)
        #expect(loaded.braidPresetID == .edoYatsu8)
        #expect(try loaded.validatedThreadAssignments() == colouring)
        let draft = ProjectDraft(project: loaded)
        #expect(draft.standKind == .round)
        #expect(draft.hasValidAssignments)
        #expect(ProjectRow.summary(of: loaded) == "江戸八つ ・ 丸台 ・ 糸 8本")
    }

    // MARK: what the home screen says

    @Test func theHomeRowNamesTheBraidTheStandAndTheThreads() {
        let updatedAt = Date(timeIntervalSince1970: 1_790_000_000)
        let round = KumihimoProject(
            name: "江戸八つの案",
            braidTypeName: BraidPresetCatalog.edoYatsu.displayName,
            selectedBraidRecipeID: BraidPresetID.edoYatsu8.rawValue,
            threadCount: 8,
            updatedAt: updatedAt
        )
        let square = KumihimoProject(
            name: "角台の案", threadCount: 16, standKind: .square, updatedAt: updatedAt
        )
        #expect(ProjectRow.summary(of: round) == "江戸八つ ・ 丸台 ・ 糸 8本")
        #expect(ProjectRow.summary(of: square) == "組み方未選択 ・ 角台 ・ 糸 16本")

        let date = updatedAt.formatted(.dateTime.year().month().day().hour().minute())
        #expect(ProjectRow.accessibilityLabel(of: round)
                == "江戸八つの案、江戸八つ、丸台、糸8本、最終更新 \(date)")
        #expect(ProjectRow.accessibilityLabel(of: square)
                == "角台の案、組み方未選択、角台、糸16本、最終更新 \(date)")
    }

    @Test func eachStandHasItsName() {
        #expect(ProjectEditorStrings.standName(.round) == "丸台")
        #expect(ProjectEditorStrings.standName(.square) == "角台")
        #expect(ProjectEditorStrings.noCompatiblePresetTitle == "この台と本数の組み方はまだありません")
    }

    // MARK: the detail sheet

    /// **The sheet is titled with the recipe's name**, 「江戸八つ組」, not the
    /// card's shorter one.
    @Test(arguments: BraidPresetCatalog.presets)
    func theDetailIsTitledWithTheRecipesName(preset: BraidPreset) throws {
        let recipe = try #require(BraidMethodCatalog.recipe(for: preset.id))
        #expect(BraidDetailSheet.title(for: preset) == recipe.name)
    }

    @Test func theDetailTitlesByExample() {
        #expect(BraidDetailSheet.title(for: BraidPresetCatalog.edoYatsu) == "江戸八つ組")
        #expect(BraidDetailSheet.title(for: BraidPresetCatalog.maruGenji) == "丸源氏組")
    }

    // MARK: helpers

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: KumihimoProject.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeStore() throws -> ProjectEditorStore {
        ProjectEditorStore(
            persistence: ProjectEditorPersistenceService(context: try makeContainer().mainContext)
        )
    }

    private func load(_ id: UUID, from container: ModelContainer) throws -> KumihimoProject {
        try #require(
            try ProjectEditorPersistenceService(context: container.mainContext).load(id: id)
        )
    }
}

/// **The saved project as it stood before Task 058**, with no stand. Copied from
/// `KumihimoProject` at `0d38578`, stored properties only; kept here so the test
/// above can write a store the way an older build did.
enum KumihimoSchemaBeforeStands: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [KumihimoProject.self] }

    @Model
    final class KumihimoProject {
        @Attribute(.unique) var id: UUID
        var name: String
        var braidTypeName: String
        @Attribute(originalName: "selectedBraidPresetID") var selectedBraidRecipeID: String?
        var threadCount: Int
        var threadAssignmentsData: Data = Data()
        var thumbnailData: Data?
        var createdAt: Date
        var updatedAt: Date

        init(
            id: UUID,
            name: String,
            braidTypeName: String,
            selectedBraidRecipeID: String?,
            threadCount: Int,
            threadAssignmentsData: Data
        ) {
            self.id = id
            self.name = name
            self.braidTypeName = braidTypeName
            self.selectedBraidRecipeID = selectedBraidRecipeID
            self.threadCount = threadCount
            self.threadAssignmentsData = threadAssignmentsData
            self.thumbnailData = nil
            self.createdAt = .now
            self.updatedAt = .now
        }
    }
}
