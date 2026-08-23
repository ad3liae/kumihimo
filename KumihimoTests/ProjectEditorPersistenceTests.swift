import Foundation
import SwiftData
import Testing
@testable import Kumihimo

@MainActor
struct ProjectEditorPersistenceTests {
    @Test func newSaveUsesNewIdentityAndTransitionsEditorToExistingProject() throws {
        let container = try makeContainer()
        let identifier = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000101"))
        let timestamp = Date(timeIntervalSince1970: 10_000)
        let service = ProjectEditorPersistenceService(
            context: container.mainContext,
            now: { timestamp },
            makeIdentifier: { identifier }
        )
        let store = ProjectEditorStore(persistence: service)

        store.presentNewSaveSheet()
        store.proposedName = "  夏の配色  "
        store.submitNameSheet()

        let projects = try container.mainContext.fetch(FetchDescriptor<KumihimoProject>())
        let project = try #require(projects.first)
        #expect(projects.count == 1)
        #expect(project.id == identifier)
        #expect(project.name == "夏の配色")
        #expect(project.createdAt == timestamp)
        #expect(project.updatedAt == timestamp)
        #expect(project.selectedBraidPresetID == nil)
        #expect(project.threadAssignments.count == 4)
        #expect(store.currentProjectID == identifier)
        #expect(store.isExistingProject)
        #expect(!store.hasUnsavedChanges)
    }

    @Test func overwritePreservesIdentityAndCreationDateWhileUpdatingDraft() throws {
        let container = try makeContainer()
        let identifier = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let previousUpdate = Date(timeIntervalSince1970: 2_000)
        let newUpdate = Date(timeIntervalSince1970: 3_000)
        let original = KumihimoProject(
            id: identifier,
            name: "元の作品",
            threadCount: 4,
            createdAt: createdAt,
            updatedAt: previousUpdate
        )
        container.mainContext.insert(original)
        try container.mainContext.save()
        let store = ProjectEditorStore(
            persistence: ProjectEditorPersistenceService(
                context: container.mainContext,
                now: { newUpdate }
            ),
            projectID: identifier
        )

        store.requestThreadCount(8)
        store.selectedThreadPosition = 8
        store.selectColor(ThreadColorID(rawValue: "blue"))
        store.overwrite()

        let saved = try #require(try fetch(id: identifier, from: container))
        #expect(saved.id == identifier)
        #expect(saved.createdAt == createdAt)
        #expect(saved.updatedAt == newUpdate)
        #expect(saved.threadCount == 8)
        #expect(saved.threadAssignments.first { $0.position == 8 }?.colorID.rawValue == "blue")
        #expect(!store.hasUnsavedChanges)
    }

    @Test func duplicateLeavesOriginalUntouchedAndAdoptsNewProject() throws {
        let container = try makeContainer()
        let originalID = UUID()
        let duplicateID = UUID()
        let originalCreatedAt = Date(timeIntervalSince1970: 1_000)
        let duplicateDate = Date(timeIntervalSince1970: 5_000)
        let original = KumihimoProject(
            id: originalID,
            name: "原案",
            threadCount: 4,
            createdAt: originalCreatedAt,
            updatedAt: originalCreatedAt
        )
        container.mainContext.insert(original)
        try container.mainContext.save()
        let store = ProjectEditorStore(
            persistence: ProjectEditorPersistenceService(
                context: container.mainContext,
                now: { duplicateDate },
                makeIdentifier: { duplicateID }
            ),
            projectID: originalID
        )
        store.requestThreadCount(8)

        store.presentDuplicateSaveSheet()
        #expect(store.proposedName == "原案のコピー")
        store.proposedName = "別案"
        store.submitNameSheet()

        let unchangedOriginal = try #require(try fetch(id: originalID, from: container))
        let duplicate = try #require(try fetch(id: duplicateID, from: container))
        #expect(unchangedOriginal.name == "原案")
        #expect(unchangedOriginal.threadCount == 4)
        #expect(unchangedOriginal.createdAt == originalCreatedAt)
        #expect(duplicate.name == "別案")
        #expect(duplicate.threadCount == 8)
        #expect(duplicate.createdAt == duplicateDate)
        #expect(duplicate.updatedAt == duplicateDate)
        #expect(store.currentProjectID == duplicateID)
        #expect(store.navigationTitle == "別案")
    }

    @Test func undecidedBraidAndPositionColorsRoundTrip() throws {
        let container = try makeContainer()
        let service = ProjectEditorPersistenceService(context: container.mainContext)
        var draft = ProjectDraft(threadCount: 8)
        draft.setColor(ThreadColorID(rawValue: "red"), at: 1)
        draft.setColor(ThreadColorID(rawValue: "white"), at: 8)

        let project = try service.create(from: draft, name: "未選択案")
        container.mainContext.rollback()
        let reloaded = try #require(try service.load(id: project.id))

        #expect(reloaded.selectedBraidPresetID == nil)
        #expect(reloaded.braidDisplayName == KumihimoProject.undecidedBraidName)
        #expect(reloaded.threadCount == 8)
        #expect(reloaded.threadAssignments.first?.position == 1)
        #expect(reloaded.threadAssignments.first?.colorID.rawValue == "red")
        #expect(reloaded.threadAssignments.last?.position == 8)
        #expect(reloaded.threadAssignments.last?.colorID.rawValue == "white")
    }

    @Test func loadRejectsMalformedThreadAssignments() throws {
        let container = try makeContainer()
        let service = ProjectEditorPersistenceService(context: container.mainContext)
        let defaultColor = ThreadColorCatalog.defaultColor.id
        let malformedProjects = [
            KumihimoProject(
                name: "配置不足",
                threadCount: 4,
                threadAssignments: [
                    ThreadAssignment(position: 1, colorID: defaultColor),
                ]
            ),
            KumihimoProject(
                name: "位置重複",
                threadCount: 4,
                threadAssignments: [
                    ThreadAssignment(position: 1, colorID: defaultColor),
                    ThreadAssignment(position: 1, colorID: defaultColor),
                    ThreadAssignment(position: 3, colorID: defaultColor),
                    ThreadAssignment(position: 4, colorID: defaultColor),
                ]
            ),
            KumihimoProject(
                name: "未知色",
                threadCount: 4,
                threadAssignments: (1...4).map {
                    ThreadAssignment(
                        position: $0,
                        colorID: $0 == 4
                            ? ThreadColorID(rawValue: "unknown")
                            : defaultColor
                    )
                }
            ),
            KumihimoProject(
                name: "未対応本数",
                threadCount: 6
            ),
        ]

        for project in malformedProjects {
            container.mainContext.insert(project)
        }
        try container.mainContext.save()

        for project in malformedProjects {
            #expect(throws: ProjectEditorPersistenceError.invalidProjectData) {
                try service.load(id: project.id)
            }
        }
    }

    @Test func createRejectsInvalidDraftAssignments() throws {
        let container = try makeContainer()
        let service = ProjectEditorPersistenceService(context: container.mainContext)
        var draft = ProjectDraft()
        draft.threadAssignments.removeLast()

        #expect(throws: ProjectEditorPersistenceError.invalidProjectData) {
            try service.create(from: draft, name: "不正な作品")
        }
        #expect(try container.mainContext.fetch(FetchDescriptor<KumihimoProject>()).isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: KumihimoProject.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func fetch(id: UUID, from container: ModelContainer) throws -> KumihimoProject? {
        try ProjectEditorPersistenceService(context: container.mainContext).load(id: id)
    }
}
