import SwiftUI

struct ProjectLoadErrorView: View {
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(HomeStrings.loadErrorTitle, systemImage: "exclamationmark.triangle")
        } description: {
            Text(HomeStrings.loadErrorMessage)
        } actions: {
            Button(HomeStrings.retry, action: retry)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(HomeAccessibilityIdentifiers.retryLoad)
        }
    }
}
