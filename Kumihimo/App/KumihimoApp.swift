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
                    RoundTube16PreviewView(
                        assignments: ProjectEditorPreviewData.maruGenjiSurfaceFixture1
                    )
                } else if CommandLine.arguments.contains(
                    ProjectEditorPreviewData.surfaceFixture2LaunchArgument
                ) {
                    RoundTube16PreviewView(
                        assignments: ProjectEditorPreviewData.maruGenjiSurfaceFixture2
                    )
                } else if CommandLine.arguments.contains(
                    ProjectEditorPreviewData.surfaceFixture3LaunchArgument
                ) {
                    RoundTube16PreviewView(
                        assignments: ProjectEditorPreviewData.maruGenjiSurfaceFixture3
                    )
                } else if CommandLine.arguments.contains(
                    ProjectEditorPreviewData.maruSurfacePlainLaunchArgument
                ) {
                    RoundTube16PreviewView(
                        assignments: ProjectEditorPreviewData.maruGenjiSurfacePlain
                    )
                } else if CommandLine.arguments.contains(
                    ProjectEditorPreviewData.hiraSurfaceFixtureALaunchArgument
                ) {
                    Flat16PreviewView(
                        assignments: ProjectEditorPreviewData.hiraGenjiSurfaceFixtureA,
                        controller: RoundTube16ViewerController(),
                        isEmbedded: false
                    )
                } else if CommandLine.arguments.contains(
                    ProjectEditorPreviewData.hiraSurfaceFixtureBLaunchArgument
                ) {
                    Flat16PreviewView(
                        assignments: ProjectEditorPreviewData.hiraGenjiSurfaceFixtureB,
                        controller: RoundTube16ViewerController(),
                        isEmbedded: false
                    )
                } else if CommandLine.arguments.contains(
                    ProjectEditorPreviewData.hiraSurfaceFixtureCLaunchArgument
                ) {
                    Flat16PreviewView(
                        assignments: ProjectEditorPreviewData.hiraGenjiSurfaceFixtureC,
                        controller: RoundTube16ViewerController(),
                        isEmbedded: false
                    )
                } else if CommandLine.arguments.contains(
                    ProjectEditorPreviewData.hiraSurfaceArrowFeatherLaunchArgument
                ) {
                    Flat16PreviewView(
                        assignments: ProjectEditorPreviewData.hiraGenjiSurfaceArrowFeather,
                        controller: RoundTube16ViewerController(),
                        isEmbedded: false
                    )
                } else if CommandLine.arguments.contains(
                    ProjectEditorPreviewData.hiraSurfaceLadderLaunchArgument
                ) {
                    Flat16PreviewView(
                        assignments: ProjectEditorPreviewData.hiraGenjiSurfaceLadder,
                        controller: RoundTube16ViewerController(),
                        isEmbedded: false
                    )
                } else if CommandLine.arguments.contains(
                    ProjectEditorPreviewData.hiraSurfacePlainLaunchArgument
                ) {
                    Flat16PreviewView(
                        assignments: ProjectEditorPreviewData.hiraGenjiSurfacePlain,
                        controller: RoundTube16ViewerController(),
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
