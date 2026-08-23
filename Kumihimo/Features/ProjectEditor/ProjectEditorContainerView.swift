import SwiftData
import SwiftUI

@MainActor
struct ProjectEditorContainerView: View {
    @State private var store: ProjectEditorStore

    init(context: ModelContext, projectID: UUID? = nil) {
        let persistence = ProjectEditorPersistenceService(context: context)
        _store = State(initialValue: ProjectEditorStore(
            persistence: persistence,
            projectID: projectID
        ))
    }

    var body: some View {
        ProjectEditorView(store: store)
    }
}
