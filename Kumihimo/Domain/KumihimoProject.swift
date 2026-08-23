import Foundation
import SwiftData

@Model
final class KumihimoProject {
    static let defaultName = "名称未設定"

    @Attribute(.unique) var id: UUID
    var name: String
    var braidTypeName: String
    var threadCount: Int
    var thumbnailData: Data?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        braidTypeName: String,
        threadCount: Int,
        thumbnailData: Data? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = Self.validName(name)
        self.braidTypeName = braidTypeName
        self.threadCount = max(1, threadCount)
        self.thumbnailData = thumbnailData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private static func validName(_ name: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? defaultName : trimmedName
    }
}
