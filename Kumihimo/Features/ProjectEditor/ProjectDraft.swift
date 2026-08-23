import Foundation

struct ProjectDraft: Equatable, Sendable {
    static let supportedThreadCounts = [4, 8, 12, 16]

    var name: String
    var selectedBraidPresetID: BraidPresetID?
    var braidTypeName: String
    var threadCount: Int
    var threadAssignments: [ThreadAssignment]
    var thumbnailData: Data?

    init(
        name: String = "",
        selectedBraidPresetID: BraidPresetID? = nil,
        braidTypeName: String = KumihimoProject.undecidedBraidName,
        threadCount: Int = 4,
        threadAssignments: [ThreadAssignment]? = nil,
        thumbnailData: Data? = nil
    ) {
        self.name = name
        self.selectedBraidPresetID = selectedBraidPresetID
        self.braidTypeName = braidTypeName
        self.threadCount = threadCount
        self.threadAssignments = threadAssignments
            ?? Self.defaultAssignments(count: threadCount)
        self.thumbnailData = thumbnailData
        normalizeAssignments()
    }

    init(project: KumihimoProject) {
        self.init(
            name: project.name,
            selectedBraidPresetID: project.braidPresetID,
            braidTypeName: project.braidTypeName,
            threadCount: project.threadCount,
            threadAssignments: project.threadAssignments,
            thumbnailData: project.thumbnailData
        )
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasValidAssignments: Bool {
        guard Self.supportedThreadCounts.contains(threadCount) else { return false }
        let expectedPositions = Array(1...threadCount)
        let positions = threadAssignments.map(\.position).sorted()
        return positions == expectedPositions
            && threadAssignments.allSatisfy { ThreadColorCatalog.contains($0.colorID) }
    }

    mutating func setThreadCount(_ newCount: Int) {
        guard Self.supportedThreadCounts.contains(newCount) else { return }
        threadCount = newCount
        normalizeAssignments()
    }

    mutating func setColor(_ colorID: ThreadColorID, at position: Int) {
        guard ThreadColorCatalog.contains(colorID) else { return }
        guard let index = threadAssignments.firstIndex(where: { $0.position == position }) else {
            return
        }
        threadAssignments[index].colorID = colorID
    }

    mutating func normalizeAssignments() {
        let existing = Dictionary(
            threadAssignments.map { ($0.position, $0.colorID) },
            uniquingKeysWith: { first, _ in first }
        )
        threadAssignments = Self.defaultAssignments(count: threadCount).map { assignment in
            guard
                let existingColor = existing[assignment.position],
                ThreadColorCatalog.contains(existingColor)
            else {
                return assignment
            }
            return ThreadAssignment(position: assignment.position, colorID: existingColor)
        }
    }

    private static func defaultAssignments(count: Int) -> [ThreadAssignment] {
        guard count > 0 else { return [] }
        return (1...count).map {
            ThreadAssignment(position: $0, colorID: ThreadColorCatalog.defaultColor.id)
        }
    }
}
