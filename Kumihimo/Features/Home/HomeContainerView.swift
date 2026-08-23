import SwiftData
import SwiftUI

struct HomeContainerView: View {
    private let container: ModelContainer
    @State private var store: HomeProjectStore

    init(container: ModelContainer) {
        self.container = container
        _store = State(initialValue: HomeProjectStore(context: container.mainContext))
    }

    var body: some View {
        HomeView(store: store, modelContext: container.mainContext)
            .modelContainer(container)
            .task {
                store.loadIfNeeded()
            }
    }
}
