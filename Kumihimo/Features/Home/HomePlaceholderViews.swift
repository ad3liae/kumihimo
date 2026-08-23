import SwiftUI

struct NewProjectPlaceholderView: View {
    var body: some View {
        Text(HomeStrings.newProjectTitle)
            .navigationTitle(HomeStrings.newProjectTitle)
    }
}

struct ProjectEditorPlaceholderView: View {
    let projectID: UUID

    var body: some View {
        VStack(spacing: 12) {
            Text(HomeStrings.projectIdentifier(projectID))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding()
        .navigationTitle(HomeStrings.editorTitle)
    }
}
