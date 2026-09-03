import SwiftUI

@main
struct KumihimoApp: App {
    var body: some Scene {
        WindowGroup {
            Group {
#if DEBUG
                if CommandLine.arguments.contains(HomePreviewData.sampleLaunchArgument) {
                    HomePreview(projects: HomePreviewData.projects)
                } else if CommandLine.arguments.contains(HomePreviewData.emptyLaunchArgument) {
                    HomePreview(projects: [])
                } else if CommandLine.arguments.contains(ProjectEditorPreviewData.newEditorLaunchArgument) {
                    ProjectEditorPreview()
                } else if CommandLine.arguments.contains(ProjectEditorPreviewData.colorfulEditorLaunchArgument) {
                    ProjectEditorPreview(project: ProjectEditorPreviewData.longNameProject)
                } else if CommandLine.arguments.contains(
                    ProjectEditorPreviewData.selectedCalculatingEditorLaunchArgument
                ) {
                    ProjectEditorPreview(
                        project: ProjectEditorPreviewData.selectedProject,
                        simulationState: .calculating
                    )
                } else if CommandLine.arguments.contains(
                    ProjectEditorPreviewData.selectedFailedEditorLaunchArgument
                ) {
                    ProjectEditorPreview(
                        project: ProjectEditorPreviewData.selectedProject,
                        simulationState: .failed
                    )
                } else if CommandLine.arguments.contains(
                    ProjectEditorPreviewData.surfaceFixture1LaunchArgument
                ) {
                    MaruGenji3DPreviewView(
                        assignments: ProjectEditorPreviewData.maruGenjiSurfaceFixture1
                    )
                } else if CommandLine.arguments.contains(
                    ProjectEditorPreviewData.surfaceFixture2LaunchArgument
                ) {
                    MaruGenji3DPreviewView(
                        assignments: ProjectEditorPreviewData.maruGenjiSurfaceFixture2
                    )
                } else if CommandLine.arguments.contains(
                    ProjectEditorPreviewData.surfaceFixture3LaunchArgument
                ) {
                    MaruGenji3DPreviewView(
                        assignments: ProjectEditorPreviewData.maruGenjiSurfaceFixture3
                    )
                } else if CommandLine.arguments.contains(
                    ProjectEditorPreviewData.hiraSurfaceFixtureALaunchArgument
                ) {
                    HiraGenji3DPreviewView(
                        assignments: ProjectEditorPreviewData.hiraGenjiSurfaceFixtureA,
                        controller: MaruGenjiViewerController(),
                        isEmbedded: false
                    )
                } else if CommandLine.arguments.contains(
                    ProjectEditorPreviewData.hiraSurfaceFixtureBLaunchArgument
                ) {
                    HiraGenji3DPreviewView(
                        assignments: ProjectEditorPreviewData.hiraGenjiSurfaceFixtureB,
                        controller: MaruGenjiViewerController(),
                        isEmbedded: false
                    )
                } else if CommandLine.arguments.contains(
                    ProjectEditorPreviewData.hiraSurfaceFixtureCLaunchArgument
                ) {
                    HiraGenji3DPreviewView(
                        assignments: ProjectEditorPreviewData.hiraGenjiSurfaceFixtureC,
                        controller: MaruGenjiViewerController(),
                        isEmbedded: false
                    )
                } else {
                    AppRootView()
                }
#else
                AppRootView()
#endif
            }
#if DEBUG
            .preferredColorScheme(
                CommandLine.arguments.contains(ProjectEditorPreviewData.darkModeLaunchArgument)
                    ? .dark
                    : nil
            )
#endif
        }
    }
}
