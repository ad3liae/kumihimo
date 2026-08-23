import Foundation

struct ThreadAssignment: Codable, Equatable, Identifiable, Sendable {
    let position: Int
    var colorID: ThreadColorID

    var id: Int { position }
}
