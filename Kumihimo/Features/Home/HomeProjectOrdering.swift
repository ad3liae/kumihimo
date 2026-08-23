import Foundation

enum HomeProjectOrdering {
    static func sorted(_ projects: [KumihimoProject]) -> [KumihimoProject] {
        projects.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
