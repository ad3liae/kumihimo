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
                name: "丸四つ組・青と白",
                braidTypeName: "丸四つ組",
                selectedBraidPresetID: "preview-maru-yotsu",
                threadCount: 4,
                updatedAt: now
            ),
            KumihimoProject(
                name: "八つ組・秋色",
                braidTypeName: "八つ組",
                selectedBraidPresetID: "preview-yatsu",
                threadCount: 8,
                updatedAt: now.addingTimeInterval(-3_600)
            ),
            KumihimoProject(
                name: "江戸打ち・若草と生成りを組み合わせた長い名前の制作案",
                braidTypeName: "江戸打ち",
                selectedBraidPresetID: "preview-edo",
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
