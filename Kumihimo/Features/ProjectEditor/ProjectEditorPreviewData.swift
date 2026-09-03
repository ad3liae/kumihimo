#if DEBUG
import SwiftData
import SwiftUI

@MainActor
enum ProjectEditorPreviewData {
    static let newEditorLaunchArgument = "--ui-testing-new-editor"
    static let colorfulEditorLaunchArgument = "--ui-testing-colorful-editor"
    static let selectedCalculatingEditorLaunchArgument = "--ui-testing-selected-calculating-editor"
    static let selectedFailedEditorLaunchArgument = "--ui-testing-selected-failed-editor"
    static let surfaceFixture1LaunchArgument = "--ui-testing-surface-fixture-1"
    static let surfaceFixture2LaunchArgument = "--ui-testing-surface-fixture-2"
    static let surfaceFixture3LaunchArgument = "--ui-testing-surface-fixture-3"
    static let hiraSurfaceFixtureALaunchArgument = "--ui-testing-hira-surface-fixture-a"
    static let hiraSurfaceFixtureBLaunchArgument = "--ui-testing-hira-surface-fixture-b"
    static let hiraSurfaceFixtureCLaunchArgument = "--ui-testing-hira-surface-fixture-c"
    static let darkModeLaunchArgument = "--ui-testing-dark-mode"

    static var colorfulAssignments: [ThreadAssignment] {
        (1...16).map { position in
            let color = ThreadColorCatalog.colors[(position - 1) % ThreadColorCatalog.colors.count]
            return ThreadAssignment(position: position, colorID: color.id)
        }
    }

    static var maruGenjiSurfaceFixture1: [ThreadAssignment] {
        fixtureAssignments([
            "blue", "pink", "pink", "blue",
            "blue", "pink", "pink", "blue",
            "blue", "pink", "pink", "blue",
            "blue", "pink", "pink", "blue",
        ])
    }

    static var maruGenjiSurfaceFixture2: [ThreadAssignment] {
        fixtureAssignments([
            "blue", "blue",
            "pink", "pink", "pink", "pink",
            "blue", "blue", "blue", "blue",
            "pink", "pink", "pink", "pink",
            "blue", "blue",
        ])
    }

    static var maruGenjiSurfaceFixture3: [ThreadAssignment] {
        fixtureAssignments([
            "blue", "blue", "blue", "blue",
            "pink", "pink", "pink", "pink",
            "blue", "blue", "blue", "blue",
            "pink", "pink", "pink", "pink",
        ])
    }

    static var hiraGenjiSurfaceFixtureA: [ThreadAssignment] {
        let inner = Set([15, 16, 1, 2, 10, 9, 8, 7])
        return (1...16).map { position in
            let colorID: String
            if inner.contains(position) {
                colorID = position.isMultiple(of: 2) ? "blue" : "light-blue"
            } else {
                colorID = position.isMultiple(of: 2) ? "white" : "black"
            }
            return ThreadAssignment(position: position, colorID: ThreadColorID(rawValue: colorID))
        }
    }

    static var hiraGenjiSurfaceFixtureB: [ThreadAssignment] {
        let center = Set([4, 5, 13, 12])
        return (1...16).map { position in
            ThreadAssignment(
                position: position,
                colorID: ThreadColorID(rawValue: center.contains(position) ? "blue" : "pink")
            )
        }
    }

    static var hiraGenjiSurfaceFixtureC: [ThreadAssignment] {
        let far = Set([3, 4, 14, 13])
        let near = Set([5, 6, 12, 11])
        return (1...16).map { position in
            let colorID = far.contains(position) ? "blue" : near.contains(position) ? "pink" : "white"
            return ThreadAssignment(position: position, colorID: ThreadColorID(rawValue: colorID))
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
            name: "丸源氏・青と白",
            braidTypeName: BraidPresetCatalog.maruGenji.displayName,
            selectedBraidPresetID: BraidPresetID.maruGenji16.rawValue,
            threadCount: 16,
            threadAssignments: colorfulAssignments
        )
    }

    static var longNameProject: KumihimoProject {
        KumihimoProject(
            name: "祖母への贈り物にする若草色と生成り色のとても長い作品名",
            threadCount: 16,
            threadAssignments: colorfulAssignments
        )
    }

    private static func fixtureAssignments(_ colorIDs: [String]) -> [ThreadAssignment] {
        colorIDs.enumerated().map { index, colorID in
            ThreadAssignment(
                position: index + 1,
                colorID: ThreadColorID(rawValue: colorID)
            )
        }
    }
}

@MainActor
struct ProjectEditorPreview: View {
    private let store: ProjectEditorStore?

    init(
        project: KumihimoProject? = nil,
        simulationState: ProjectEditorStore.SimulationResultsState = .available,
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

#Preview("4本・互換プリセットなし・最大文字・ライト") {
    ProjectEditorPreview()
        .preferredColorScheme(.light)
        .environment(\.dynamicTypeSize, .accessibility5)
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

#Preview("選択済み・シミュレーション計算中・最大文字") {
    ProjectEditorPreview(
        project: ProjectEditorPreviewData.selectedProject,
        simulationState: .calculating
    )
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("選択済み・シミュレーション失敗・最大文字") {
    ProjectEditorPreview(
        project: ProjectEditorPreviewData.selectedProject,
        simulationState: .failed
    )
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("丸源氏表面 Fixture 1・細かな山形") {
    MaruGenji3DPreviewView(assignments: ProjectEditorPreviewData.maruGenjiSurfaceFixture1)
}

#Preview("丸源氏表面 Fixture 2・長手方向の色分け") {
    MaruGenji3DPreviewView(assignments: ProjectEditorPreviewData.maruGenjiSurfaceFixture2)
}

#Preview("丸源氏表面 Fixture 3・位相のずれた山形") {
    MaruGenji3DPreviewView(assignments: ProjectEditorPreviewData.maruGenjiSurfaceFixture3)
}

#Preview("平源氏 Fixture A・水色系と白黒") {
    HiraGenji3DPreviewView(
        assignments: ProjectEditorPreviewData.hiraGenjiSurfaceFixtureA,
        controller: MaruGenjiViewerController(),
        isEmbedded: false
    )
}

#Preview("平源氏 Fixture B・矢絣状の縁取り") {
    HiraGenji3DPreviewView(
        assignments: ProjectEditorPreviewData.hiraGenjiSurfaceFixtureB,
        controller: MaruGenjiViewerController(),
        isEmbedded: false
    )
}

#Preview("平源氏 Fixture C・表裏反転する梯子状模様") {
    HiraGenji3DPreviewView(
        assignments: ProjectEditorPreviewData.hiraGenjiSurfaceFixtureC,
        controller: MaruGenjiViewerController(),
        isEmbedded: false
    )
}
#endif
