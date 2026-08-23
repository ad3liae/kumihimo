import Foundation
import SwiftData
import Testing
@testable import Kumihimo

struct ProjectDraftTests {
    @Test func increasingThreadCountPreservesExistingPositionsAndAddsDefaultColor() {
        var draft = ProjectDraft()
        let blue = ThreadColorID(rawValue: "blue")
        draft.setColor(blue, at: 2)

        draft.setThreadCount(8)

        #expect(draft.threadCount == 8)
        #expect(draft.threadAssignments.count == 8)
        #expect(draft.threadAssignments.first { $0.position == 2 }?.colorID == blue)
        #expect(
            draft.threadAssignments.first { $0.position == 8 }?.colorID
                == ThreadColorCatalog.defaultColor.id
        )
        #expect(draft.hasValidAssignments)
    }

    @Test func reducingThreadCountRemovesOnlyLostPositions() {
        var draft = ProjectDraft(threadCount: 8)
        let red = ThreadColorID(rawValue: "red")
        draft.setColor(red, at: 4)
        draft.setColor(ThreadColorID(rawValue: "purple"), at: 8)

        draft.setThreadCount(4)

        #expect(draft.threadAssignments.map(\.position) == [1, 2, 3, 4])
        #expect(draft.threadAssignments.last?.colorID == red)
        #expect(draft.hasValidAssignments)
    }
}

@MainActor
struct ProjectEditorPresentationStateTests {
    @Test func confirmingReductionClearsPresentationBeforeApplyingCount() throws {
        let store = try makeStore()
        store.requestThreadCount(8)
        store.requestThreadCount(4)

        #expect(store.pendingThreadCount == 4)
        #expect(store.showsThreadCountReductionConfirmation)
        #expect(store.draft.threadCount == 8)
        #expect(store.selectedThreadCount == 4)

        store.confirmThreadCountReduction()

        #expect(store.pendingThreadCount == nil)
        #expect(!store.showsThreadCountReductionConfirmation)
        #expect(store.draft.threadCount == 4)
        #expect(store.selectedThreadCount == 4)
    }

    @Test func cancellingReductionClearsPresentationAndKeepsCount() throws {
        let store = try makeStore()
        store.requestThreadCount(8)
        store.requestThreadCount(4)

        store.cancelThreadCountReduction()

        #expect(store.pendingThreadCount == nil)
        #expect(!store.showsThreadCountReductionConfirmation)
        #expect(store.draft.threadCount == 8)
        #expect(store.selectedThreadCount == 8)
    }

    @Test func pendingReductionKeepsPickerSelectionInSync() throws {
        let store = try makeStore()
        store.requestThreadCount(8)
        store.requestThreadCount(4)

        store.requestThreadCount(4)

        #expect(store.pendingThreadCount == 4)
        #expect(store.showsThreadCountReductionConfirmation)
        #expect(store.draft.threadCount == 8)
        #expect(store.selectedThreadCount == 4)
    }

    @Test func selectingColorClearsSheetSelectionAndAppliesColor() throws {
        let store = try makeStore()
        let blue = ThreadColorID(rawValue: "blue")
        store.selectedThreadPosition = 1

        store.selectColor(blue)

        #expect(store.selectedThreadPosition == nil)
        #expect(store.draft.threadAssignments.first?.colorID == blue)
    }

    @Test func loadFailureKeepsExistingProjectModeAndHidesSaveToolbar() throws {
        let container = try ModelContainer(
            for: KumihimoProject.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let missingProjectID = UUID()

        let store = ProjectEditorStore(
            persistence: ProjectEditorPersistenceService(context: container.mainContext),
            projectID: missingProjectID
        )

        #expect(store.currentProjectID == missingProjectID)
        #expect(store.isExistingProject)
        #expect(store.hasLoadError)
        #expect(store.navigationTitle == ProjectEditorStrings.loadErrorTitle)
        #expect(!store.showsSaveToolbar)
        #expect(!store.canSave)
    }

    private func makeStore() throws -> ProjectEditorStore {
        let container = try ModelContainer(
            for: KumihimoProject.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ProjectEditorStore(
            persistence: ProjectEditorPersistenceService(context: container.mainContext)
        )
    }
}
