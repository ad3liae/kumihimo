import SwiftData
import SwiftUI

struct AppRootView: View {
    @State private var containerSetup: AppModelContainerSetup

    init(containerSetup: AppModelContainerSetup = AppModelContainerSetup()) {
        _containerSetup = State(initialValue: containerSetup)
    }

    var body: some View {
        Group {
            if let container = containerSetup.container {
                HomeContainerView(container: container)
            } else if containerSetup.hasError {
                ProjectLoadErrorView(retry: containerSetup.load)
            } else {
                ProgressView(HomeStrings.loading)
            }
        }
        .task {
            containerSetup.loadIfNeeded()
        }
    }
}
