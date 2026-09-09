import Foundation
import SwiftData

@MainActor
struct ProjectEditorPersistenceService {
    typealias DateProvider = @MainActor () -> Date
    typealias IdentifierProvider = @MainActor () -> UUID

    private let context: ModelContext
    private let now: DateProvider
    private let makeIdentifier: IdentifierProvider

    init(
        context: ModelContext,
        now: @escaping DateProvider = { .now },
        makeIdentifier: @escaping IdentifierProvider = { UUID() }
    ) {
        self.context = context
        self.now = now
        self.makeIdentifier = makeIdentifier
    }

    func load(id: UUID) throws -> KumihimoProject? {
        var descriptor = FetchDescriptor<KumihimoProject>(
            predicate: #Predicate { project in
                project.id == id
            }
        )
        descriptor.fetchLimit = 1
        guard let project = try context.fetch(descriptor).first else {
            return nil
        }
        try validate(project)
        return project
    }

    func create(from draft: ProjectDraft, name: String) throws -> KumihimoProject {
        try validate(draft)
        let timestamp = now()
        let project = KumihimoProject(
            id: makeIdentifier(),
            name: name,
            braidTypeName: draft.braidTypeName,
            selectedBraidRecipeID: draft.savedBraidKey,
            threadCount: draft.threadCount,
            threadAssignments: draft.threadAssignments,
            thumbnailData: draft.thumbnailData,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        context.insert(project)
        try saveOrRollback()
        return project
    }

    func overwrite(id: UUID, from draft: ProjectDraft) throws -> KumihimoProject {
        try validate(draft)
        guard let project = try load(id: id) else {
            throw ProjectEditorPersistenceError.projectNotFound
        }

        project.name = draft.trimmedName
        project.braidTypeName = draft.braidTypeName
        project.selectedBraidRecipeID = draft.savedBraidKey
        project.threadCount = draft.threadCount
        project.threadAssignments = draft.threadAssignments
        project.thumbnailData = draft.thumbnailData
        project.updatedAt = now()
        try saveOrRollback()
        return project
    }

    private func validate(_ project: KumihimoProject) throws {
        guard ProjectDraft.supportedThreadCounts.contains(project.threadCount) else {
            throw ProjectEditorPersistenceError.invalidProjectData
        }
        // **A braid this build does not carry does not make the project invalid.**
        // The project opens, and the screen shows that nothing draws it -- the same
        // road a braid with no drawer takes. Only a braid this build *does* carry
        // has to agree with what was saved beside it.
        if let presetID = project.braidPresetID {
            guard
                let preset = BraidPresetCatalog.preset(for: presetID),
                preset.supports(threadCount: project.threadCount),
                project.braidTypeName == preset.displayName
            else {
                throw ProjectEditorPersistenceError.invalidProjectData
            }
        }
        do {
            _ = try project.validatedThreadAssignments()
        } catch {
            throw ProjectEditorPersistenceError.invalidProjectData
        }
    }

    private func validate(_ draft: ProjectDraft) throws {
        guard
            ProjectDraft.supportedThreadCounts.contains(draft.threadCount),
            draft.hasValidAssignments
        else {
            throw ProjectEditorPersistenceError.invalidProjectData
        }
    }

    private func saveOrRollback() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

enum ProjectEditorPersistenceError: Error, Equatable {
    case projectNotFound
    case invalidProjectData
}
