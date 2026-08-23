import Foundation
import Testing
@testable import Kumihimo

struct HomeProjectOrderingTests {
    @Test func sortsNewestFirstAndUsesIdentifierAsTieBreaker() throws {
        let olderDate = Date(timeIntervalSince1970: 1_000)
        let newerDate = Date(timeIntervalSince1970: 2_000)
        let firstID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let secondID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let olderID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000003"))

        let older = makeProject(id: olderID, name: "古い作品", updatedAt: olderDate)
        let tiedSecond = makeProject(id: secondID, name: "同時刻2", updatedAt: newerDate)
        let tiedFirst = makeProject(id: firstID, name: "同時刻1", updatedAt: newerDate)

        let result = HomeProjectOrdering.sorted([older, tiedSecond, tiedFirst])

        #expect(result.map(\.id) == [firstID, secondID, olderID])
        #expect(result.map(\.name) == ["同時刻1", "同時刻2", "古い作品"])
    }

    private func makeProject(id: UUID, name: String, updatedAt: Date) -> KumihimoProject {
        KumihimoProject(
            id: id,
            name: name,
            braidTypeName: "テスト組み",
            threadCount: 4,
            updatedAt: updatedAt
        )
    }
}
