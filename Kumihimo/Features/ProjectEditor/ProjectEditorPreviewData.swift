#if DEBUG
import SwiftData
import SwiftUI

@MainActor
enum ProjectEditorPreviewData {
    static let newEditorLaunchArgument = "--ui-testing-new-editor"
    static let colorfulEditorLaunchArgument = "--ui-testing-colorful-editor"

    static var colorfulAssignments: [ThreadAssignment] {
        (1...16).map { position in
            let color = ThreadColorCatalog.colors[(position - 1) % ThreadColorCatalog.colors.count]
            return ThreadAssignment(position: position, colorID: color.id)
        }
    }

    static var undecidedProject: KumihimoProject {
        KumihimoProject(
            name: "春の配色案",
            threadCount: 8,
            threadAssignments: (1...8).map {
                ThreadAssignment(
                    position: $0,
                    colorID: $0.isMultiple(of: 2)
                        ? ThreadColorID(rawValue: "light-blue")
                        : ThreadColorID(rawValue: "white")
                )
            }
        )
    }

    static var selectedProject: KumihimoProject {
        KumihimoProject(
            name: "丸四つ組・青と白",
            braidTypeName: "丸四つ組",
            selectedBraidPresetID: "preview-maru-yotsu",
            threadCount: 4
        )
    }

    static var longNameProject: KumihimoProject {
        KumihimoProject(
            name: "祖母への贈り物にする若草色と生成り色のとても長い作品名",
            threadCount: 16,
            threadAssignments: colorfulAssignments
        )
    }
}

@MainActor
struct ProjectEditorPreview: View {
    private let store: ProjectEditorStore?

    init(
        project: KumihimoProject? = nil,
        simulationState: ProjectEditorStore.SimulationResultsState = .unavailable,
        showsNameSheet: Bool = false
    ) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(
            for: KumihimoProject.self,
            configurations: configuration
        ) else {
            store = nil
            return
        }

        if let project {
            container.mainContext.insert(project)
        }
        let previewStore = ProjectEditorStore(
            persistence: ProjectEditorPersistenceService(context: container.mainContext),
            projectID: project?.id,
            simulationResultsState: simulationState
        )
        if showsNameSheet {
            previewStore.presentNewSaveSheet()
        }
        store = previewStore
    }

    var body: some View {
        NavigationStack {
            if let store {
                ProjectEditorView(store: store)
            } else {
                ContentUnavailableView(
                    ProjectEditorStrings.loadErrorTitle,
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
    }
}

#Preview("4本の新規作品・ライト") {
    ProjectEditorPreview()
        .preferredColorScheme(.light)
}

#Preview("16本・多色・ダーク") {
    ProjectEditorPreview(project: ProjectEditorPreviewData.longNameProject)
        .preferredColorScheme(.dark)
}

#Preview("組み方未選択の既存作品") {
    ProjectEditorPreview(project: ProjectEditorPreviewData.undecidedProject)
}

#Preview("組み方選択済み・最大文字") {
    ProjectEditorPreview(project: ProjectEditorPreviewData.selectedProject)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("保存名入力シート") {
    ProjectEditorPreview(showsNameSheet: true)
}

#Preview("シミュレーション計算中") {
    ProjectEditorPreview(simulationState: .calculating)
}

#Preview("シミュレーション失敗") {
    ProjectEditorPreview(simulationState: .failed)
}
#endif
