import Observation

@MainActor
@Observable
final class HomeViewState {
    var projectPendingDeletion: KumihimoProject?
    var showsDeletionError = false

    var showsDeleteConfirmation: Bool {
        projectPendingDeletion != nil
    }

    var deleteConfirmationTitle: String {
        guard let projectPendingDeletion else { return "" }
        return HomeStrings.deleteConfirmationTitle(projectName: projectPendingDeletion.name)
    }

    func requestDeletion(of project: KumihimoProject) {
        projectPendingDeletion = project
    }

    func cancelDeletion() {
        projectPendingDeletion = nil
    }

    func confirmDeletion(using store: HomeProjectStore) {
        guard let project = projectPendingDeletion else { return }

        do {
            try store.delete(project)
        } catch {
            showsDeletionError = true
        }

        projectPendingDeletion = nil
    }
}
