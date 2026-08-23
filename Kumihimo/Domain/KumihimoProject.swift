import Foundation
import SwiftData

@Model
final class KumihimoProject {
    static let defaultName = "名称未設定"
    static let undecidedBraidName = "組み方未選択"

    @Attribute(.unique) var id: UUID
    var name: String
    var braidTypeName: String
    var selectedBraidPresetID: String?
    var threadCount: Int
    private var threadAssignmentsData: Data = Data()
    var thumbnailData: Data?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        braidTypeName: String = undecidedBraidName,
        selectedBraidPresetID: String? = nil,
        threadCount: Int,
        threadAssignments: [ThreadAssignment]? = nil,
        thumbnailData: Data? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = Self.validName(name)
        self.braidTypeName = braidTypeName
        self.selectedBraidPresetID = selectedBraidPresetID
        self.threadCount = max(1, threadCount)
        self.threadAssignmentsData = Self.encodeAssignments(
            threadAssignments ?? Self.defaultAssignments(count: max(1, threadCount))
        )
        self.thumbnailData = thumbnailData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var threadAssignments: [ThreadAssignment] {
        get {
            (try? validatedThreadAssignments()) ?? []
        }
        set {
            threadAssignmentsData = Self.encodeAssignments(newValue)
        }
    }

    func validatedThreadAssignments() throws -> [ThreadAssignment] {
        guard threadCount > 0 else {
            throw KumihimoProjectDataError.invalidThreadAssignments
        }

        let assignments: [ThreadAssignment]
        do {
            assignments = try JSONDecoder().decode(
                [ThreadAssignment].self,
                from: threadAssignmentsData
            )
        } catch {
            throw KumihimoProjectDataError.invalidThreadAssignments
        }

        let sortedAssignments = assignments.sorted { $0.position < $1.position }
        guard
            sortedAssignments.count == threadCount,
            sortedAssignments.map(\.position) == Array(1...threadCount),
            sortedAssignments.allSatisfy({ ThreadColorCatalog.contains($0.colorID) })
        else {
            throw KumihimoProjectDataError.invalidThreadAssignments
        }
        return sortedAssignments
    }

    var braidPresetID: BraidPresetID? {
        selectedBraidPresetID.map(BraidPresetID.init(rawValue:))
    }

    var braidDisplayName: String {
        selectedBraidPresetID == nil ? Self.undecidedBraidName : braidTypeName
    }

    private static func validName(_ name: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? defaultName : trimmedName
    }

    private static func defaultAssignments(count: Int) -> [ThreadAssignment] {
        (1...count).map {
            ThreadAssignment(position: $0, colorID: ThreadColorCatalog.defaultColor.id)
        }
    }

    private static func encodeAssignments(_ assignments: [ThreadAssignment]) -> Data {
        (try? JSONEncoder().encode(assignments)) ?? Data()
    }
}

enum KumihimoProjectDataError: Error, Equatable {
    case invalidThreadAssignments
}
