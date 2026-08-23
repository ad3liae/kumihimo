import SwiftData

@MainActor
struct HomeProjectDeletionService {
    func delete(_ project: KumihimoProject, from context: ModelContext) throws {
        context.delete(project)

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
