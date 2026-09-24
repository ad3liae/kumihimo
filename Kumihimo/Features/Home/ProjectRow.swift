import SwiftUI

struct ProjectRow: View {
    let project: KumihimoProject

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                ProjectThumbnailView(thumbnailData: project.thumbnailData)
                projectDetails
            }

            VStack(alignment: .leading, spacing: 10) {
                ProjectThumbnailView(thumbnailData: project.thumbnailData)
                projectDetails
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(HomeStrings.openProjectHint)
        .accessibilityAddTraits(.isButton)
    }

    private var projectDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.name)
                .font(.headline)

            Text(Self.summary(of: project))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(project.updatedAt, format: .dateTime.year().month().day().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessibilityLabel: String {
        Self.accessibilityLabel(of: project)
    }

    static func summary(of project: KumihimoProject) -> String {
        HomeStrings.projectSummary(
            braidTypeName: project.braidDisplayName,
            standName: ProjectEditorStrings.standName(project.standKind),
            threadCount: project.threadCount
        )
    }

    static func accessibilityLabel(of project: KumihimoProject) -> String {
        HomeStrings.projectAccessibilityLabel(
            name: project.name,
            braidTypeName: project.braidDisplayName,
            standName: ProjectEditorStrings.standName(project.standKind),
            threadCount: project.threadCount,
            updatedAt: project.updatedAt.formatted(
                .dateTime.year().month().day().hour().minute()
            )
        )
    }
}
