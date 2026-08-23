#if DEBUG
import SwiftData
import SwiftUI

enum HomePreviewData {
    static let sampleLaunchArgument = "--ui-testing-sample-projects"
    static let emptyLaunchArgument = "--ui-testing-empty-projects"

    static let firstProjectID = UUID(
        uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
    )

    static var projects: [KumihimoProject] {
        let now = Date()
        return [
            KumihimoProject(
                id: firstProjectID,
                name: "丸源氏・青と白",
                braidTypeName: BraidPresetCatalog.maruGenji.displayName,
                selectedBraidPresetID: BraidPresetID.maruGenji16.rawValue,
                threadCount: 16,
                updatedAt: now
            ),
            KumihimoProject(
                name: "秋色の配色案",
                threadCount: 8,
                updatedAt: now.addingTimeInterval(-3_600)
            ),
            KumihimoProject(
                name: "若草と生成りを組み合わせた長い名前の制作案",
                threadCount: 8,
                updatedAt: now.addingTimeInterval(-86_400)
            ),
        ]
    }
}

struct HomePreview: View {
    private let container: ModelContainer?

    init(projects: [KumihimoProject]) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try? ModelContainer(
            for: KumihimoProject.self,
            configurations: configuration
        )
        projects.forEach { container?.mainContext.insert($0) }
    }

    var body: some View {
        if let container {
            HomeContainerView(container: container)
        } else {
            ContentUnavailableView(HomeStrings.deleteErrorTitle, systemImage: "exclamationmark.triangle")
        }
    }
}
#endif
