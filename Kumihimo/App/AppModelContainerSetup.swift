import Observation
import SwiftData

@MainActor
@Observable
final class AppModelContainerSetup {
    typealias ContainerFactory = @MainActor () throws -> ModelContainer

    private(set) var container: ModelContainer?
    private(set) var isLoading = true
    private(set) var hasError = false

    private let makeContainer: ContainerFactory
    private var hasAttemptedLoad = false

    init(
        makeContainer: @escaping ContainerFactory = {
            try ModelContainer(for: KumihimoProject.self)
        }
    ) {
        self.makeContainer = makeContainer
    }

    func loadIfNeeded() {
        guard !hasAttemptedLoad else { return }
        load()
    }

    func load() {
        hasAttemptedLoad = true
        isLoading = true
        hasError = false

        do {
            container = try makeContainer()
        } catch {
            container = nil
            hasError = true
        }

        isLoading = false
    }
}
