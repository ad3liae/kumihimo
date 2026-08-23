import SwiftUI

struct EmptyProjectsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "scribble")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(HomeStrings.emptyTitle)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(HomeStrings.emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .accessibilityElement(children: .combine)
    }
}
