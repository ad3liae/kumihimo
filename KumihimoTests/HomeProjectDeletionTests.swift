import SwiftData
import Testing
@testable import Kumihimo

@MainActor
struct HomeProjectDeletionTests {
    @Test func cancelKeepsProjectInStore() throws {
        let (container, project) = try makeContainerWithProject()
        let state = HomeViewState()

        state.requestDeletion(of: project)
        state.cancelDeletion()

        #expect(try container.mainContext.fetchCount(FetchDescriptor<KumihimoProject>()) == 1)
        #expect(state.projectPendingDeletion == nil)
    }

    @Test func confirmationRemovesProjectFromStore() throws {
        let (container, project) = try makeContainerWithProject()
        let store = HomeProjectStore(context: container.mainContext)
        let state = HomeViewState()

        store.load()
        state.requestDeletion(of: project)
        state.confirmDeletion(using: store)

        #expect(try container.mainContext.fetchCount(FetchDescriptor<KumihimoProject>()) == 0)
        #expect(state.projectPendingDeletion == nil)
        #expect(!state.showsDeletionError)
        #expect(store.projects.isEmpty)
    }

    private func makeContainerWithProject() throws -> (ModelContainer, KumihimoProject) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: KumihimoProject.self,
            configurations: configuration
        )
        let project = KumihimoProject(
            name: "削除テスト",
            braidTypeName: "テスト組み",
            threadCount: 4
        )
        container.mainContext.insert(project)
        try container.mainContext.save()
        return (container, project)
    }
}
