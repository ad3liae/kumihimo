import Observation
import SwiftData

@MainActor
@Observable
final class HomeProjectStore {
    typealias ProjectFetcher = @MainActor (ModelContext) throws -> [KumihimoProject]

    private(set) var projects: [KumihimoProject] = []
    private(set) var isLoading = true
    private(set) var hasLoadError = false

    private let context: ModelContext
    private let fetchProjects: ProjectFetcher
    private let deletionService: HomeProjectDeletionService
    private var hasAttemptedLoad = false

    init(
        context: ModelContext,
        fetchProjects: @escaping ProjectFetcher = { context in
            try context.fetch(FetchDescriptor<KumihimoProject>())
        },
        deletionService: HomeProjectDeletionService = HomeProjectDeletionService()
    ) {
        self.context = context
        self.fetchProjects = fetchProjects
        self.deletionService = deletionService
    }

    func loadIfNeeded() {
        guard !hasAttemptedLoad else { return }
        load()
    }

    func load() {
        hasAttemptedLoad = true
        isLoading = true
        hasLoadError = false

        do {
            projects = HomeProjectOrdering.sorted(try fetchProjects(context))
        } catch {
            projects = []
            hasLoadError = true
        }

        isLoading = false
    }

    func delete(_ project: KumihimoProject) throws {
        try deletionService.delete(project, from: context)
        load()
    }
}
