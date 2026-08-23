import SwiftUI

struct HomeView: View {
    let store: HomeProjectStore
    @State private var state = HomeViewState()

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    NewProjectPlaceholderView()
                } label: {
                    NewProjectRow()
                }
                .accessibilityIdentifier(HomeAccessibilityIdentifiers.createProject)

                if store.isLoading {
                    ProgressView(HomeStrings.loading)
                        .frame(maxWidth: .infinity)
                } else if store.hasLoadError {
                    ProjectLoadErrorView(retry: store.load)
                        .listRowBackground(Color.clear)
                } else if store.projects.isEmpty {
                    EmptyProjectsView()
                } else {
                    Section(HomeStrings.savedProjectsHeader) {
                        ForEach(store.projects) { project in
                            NavigationLink {
                                ProjectEditorPlaceholderView(projectID: project.id)
                            } label: {
                                ProjectRow(project: project)
                            }
                            .accessibilityIdentifier(HomeAccessibilityIdentifiers.project(project.id))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(HomeStrings.delete, role: .destructive) {
                                    state.requestDeletion(of: project)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(HomeStrings.title)
            .alert(state.deleteConfirmationTitle, isPresented: deleteConfirmationBinding) {
                Button(HomeStrings.cancel, role: .cancel) {
                    state.cancelDeletion()
                }
                Button(HomeStrings.delete, role: .destructive) {
                    state.confirmDeletion(using: store)
                }
            }
            .alert(HomeStrings.deleteErrorTitle, isPresented: $state.showsDeletionError) {
                Button(HomeStrings.dismiss) {}
            }
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { state.showsDeleteConfirmation },
            set: { isPresented in
                if !isPresented {
                    state.cancelDeletion()
                }
            }
        )
    }
}

#if DEBUG
#Preview("保存作品なし") {
    HomePreview(projects: [])
}

#Preview("保存作品3件・長い名前・サムネイルなし") {
    HomePreview(projects: HomePreviewData.projects)
}
#endif
