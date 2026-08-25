import Foundation
import Observation

@MainActor
@Observable
final class ProjectEditorStore {
    enum SimulationResultsState: Equatable {
        case available
        case calculating
        case failed
    }

    enum NameSheetPurpose: Hashable, Identifiable {
        case newProject
        case duplicate

        var id: Self { self }
    }

    enum PendingSave {
        case newProject(String)
        case overwrite
        case duplicate(String)
    }

    private(set) var draft: ProjectDraft
    private(set) var currentProjectID: UUID?
    private(set) var currentCreatedAt: Date?
    private(set) var isLoading = false
    private(set) var hasLoadError = false
    private(set) var isSaving = false
    private(set) var baseline: ProjectDraft?
    private(set) var selectedThreadCount: Int

    var nameSheetPurpose: NameSheetPurpose?
    var proposedName = ""
    var selectedThreadPosition: Int?
    var pendingThreadCount: Int?
    var showsThreadCountReductionConfirmation = false
    var showsSaveError = false
    var simulationResultsState: SimulationResultsState

    private let persistence: ProjectEditorPersistenceService
    private var pendingSave: PendingSave?

    init(
        persistence: ProjectEditorPersistenceService,
        projectID: UUID? = nil,
        simulationResultsState: SimulationResultsState = .available
    ) {
        let initialDraft = ProjectDraft()
        self.persistence = persistence
        self.draft = initialDraft
        self.selectedThreadCount = initialDraft.threadCount
        self.simulationResultsState = simulationResultsState
        currentProjectID = projectID

        if projectID != nil {
            load()
        }
    }

    var isExistingProject: Bool { currentProjectID != nil }

    var navigationTitle: String {
        if hasLoadError {
            return ProjectEditorStrings.loadErrorTitle
        }
        return isExistingProject ? draft.name : ProjectEditorStrings.newProjectTitle
    }

    var showsSaveToolbar: Bool {
        !isLoading && !hasLoadError
    }

    var hasUnsavedChanges: Bool {
        guard let baseline else { return true }
        return draft != baseline
    }

    var canSave: Bool {
        draft.hasValidAssignments && !isSaving && !hasLoadError
    }

    var canOverwrite: Bool {
        canSave && isExistingProject && hasUnsavedChanges
    }

    var availableBraidPresets: [BraidPreset] {
        BraidPresetCatalog.availablePresets(threadCount: draft.threadCount)
    }

    var isProposedNameValid: Bool {
        !proposedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func load() {
        guard let currentProjectID else { return }
        isLoading = true
        hasLoadError = false
        do {
            guard let project = try persistence.load(id: currentProjectID) else {
                throw ProjectEditorPersistenceError.projectNotFound
            }
            adopt(project)
        } catch {
            hasLoadError = true
        }
        isLoading = false
    }

    func presentNewSaveSheet() {
        proposedName = draft.trimmedName
        nameSheetPurpose = .newProject
    }

    func presentDuplicateSaveSheet() {
        proposedName = ProjectEditorStrings.copyName(from: draft.name)
        nameSheetPurpose = .duplicate
    }

    func dismissNameSheet() {
        nameSheetPurpose = nil
    }

    func submitNameSheet() {
        guard isProposedNameValid, let purpose = nameSheetPurpose else { return }
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        switch purpose {
        case .newProject:
            perform(.newProject(trimmedName))
        case .duplicate:
            perform(.duplicate(trimmedName))
        }
    }

    func overwrite() {
        perform(.overwrite)
    }

    func retrySave() {
        guard let pendingSave else { return }
        showsSaveError = false
        perform(pendingSave)
    }

    func requestThreadCount(_ count: Int) {
        guard ProjectDraft.supportedThreadCounts.contains(count), count != selectedThreadCount else {
            return
        }
        selectedThreadCount = count
        if count < draft.threadCount {
            pendingThreadCount = count
            showsThreadCountReductionConfirmation = true
        } else {
            applyThreadCount(count)
        }
    }

    func confirmThreadCountReduction() {
        guard let pendingThreadCount else {
            showsThreadCountReductionConfirmation = false
            selectedThreadCount = draft.threadCount
            return
        }
        showsThreadCountReductionConfirmation = false
        self.pendingThreadCount = nil
        applyThreadCount(pendingThreadCount)
    }

    func cancelThreadCountReduction() {
        pendingThreadCount = nil
        selectedThreadCount = draft.threadCount
        showsThreadCountReductionConfirmation = false
    }

    func selectColor(_ colorID: ThreadColorID) {
        guard let selectedThreadPosition else { return }
        self.selectedThreadPosition = nil
        draft.setColor(colorID, at: selectedThreadPosition)
    }

    func selectBraidPreset(_ id: BraidPresetID?) {
        guard let id else {
            draft.selectedBraidPresetID = nil
            draft.braidTypeName = KumihimoProject.undecidedBraidName
            return
        }
        guard
            let preset = BraidPresetCatalog.preset(for: id),
            preset.supports(threadCount: draft.threadCount)
        else {
            return
        }
        draft.selectedBraidPresetID = preset.id
        draft.braidTypeName = preset.displayName
    }

    private func applyThreadCount(_ count: Int) {
        selectedThreadCount = count
        draft.setThreadCount(count)
        if
            let selectedBraidPresetID = draft.selectedBraidPresetID,
            BraidPresetCatalog.preset(for: selectedBraidPresetID)?.supports(threadCount: count) != true
        {
            selectBraidPreset(nil)
        }
    }

    private func perform(_ save: PendingSave) {
        guard canSave else { return }
        pendingSave = save
        isSaving = true
        defer { isSaving = false }

        do {
            let project: KumihimoProject
            switch save {
            case .newProject(let name), .duplicate(let name):
                project = try persistence.create(from: draft, name: name)
            case .overwrite:
                guard let currentProjectID else {
                    throw ProjectEditorPersistenceError.projectNotFound
                }
                project = try persistence.overwrite(id: currentProjectID, from: draft)
            }
            adopt(project)
            nameSheetPurpose = nil
            pendingSave = nil
            showsSaveError = false
        } catch {
            showsSaveError = true
        }
    }

    private func adopt(_ project: KumihimoProject) {
        let savedDraft = ProjectDraft(project: project)
        currentProjectID = project.id
        currentCreatedAt = project.createdAt
        draft = savedDraft
        selectedThreadCount = savedDraft.threadCount
        baseline = savedDraft
    }
}
