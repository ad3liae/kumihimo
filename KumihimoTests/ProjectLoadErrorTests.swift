import SwiftData
import Testing
@testable import Kumihimo

@MainActor
struct ProjectLoadErrorTests {
    private enum InjectedError: Error {
        case loadFailed
    }

    @Test func containerFailureCanBeRetried() throws {
        var attempts = 0
        let setup = AppModelContainerSetup {
            attempts += 1
            if attempts == 1 {
                throw InjectedError.loadFailed
            }
            return try Self.makeContainer()
        }

        setup.load()

        #expect(setup.container == nil)
        #expect(setup.hasError)
        #expect(!setup.isLoading)

        setup.load()

        #expect(setup.container != nil)
        #expect(!setup.hasError)
        #expect(attempts == 2)
    }

    @Test func fetchFailureIsNotTreatedAsEmptyAndCanBeRetried() throws {
        let container = try Self.makeContainer()
        var attempts = 0
        let store = HomeProjectStore(
            context: container.mainContext,
            fetchProjects: { _ in
                attempts += 1
                if attempts == 1 {
                    throw InjectedError.loadFailed
                }
                return []
            }
        )

        store.load()

        #expect(store.projects.isEmpty)
        #expect(store.hasLoadError)
        #expect(!store.isLoading)

        store.load()

        #expect(store.projects.isEmpty)
        #expect(!store.hasLoadError)
        #expect(attempts == 2)
    }

    private static func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: KumihimoProject.self,
            configurations: configuration
        )
    }
}
