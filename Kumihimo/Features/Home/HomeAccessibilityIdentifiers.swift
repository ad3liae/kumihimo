import Foundation

enum HomeAccessibilityIdentifiers {
    static let createProject = "home.create-project"
    static let retryLoad = "home.retry-load"

    static func project(_ id: UUID) -> String {
        "home.project.\(id.uuidString)"
    }
}
