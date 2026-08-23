import SwiftUI

@main
struct KumihimoApp: App {
    var body: some Scene {
        WindowGroup {
#if DEBUG
            if CommandLine.arguments.contains(HomePreviewData.sampleLaunchArgument) {
                HomePreview(projects: HomePreviewData.projects)
            } else if CommandLine.arguments.contains(HomePreviewData.emptyLaunchArgument) {
                HomePreview(projects: [])
            } else if CommandLine.arguments.contains(ProjectEditorPreviewData.newEditorLaunchArgument) {
                ProjectEditorPreview()
            } else if CommandLine.arguments.contains(ProjectEditorPreviewData.colorfulEditorLaunchArgument) {
                ProjectEditorPreview(project: ProjectEditorPreviewData.longNameProject)
            } else {
                AppRootView()
            }
#else
            AppRootView()
#endif
        }
    }
}
