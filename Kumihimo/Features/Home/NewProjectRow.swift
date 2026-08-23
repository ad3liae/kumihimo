import SwiftUI

struct NewProjectRow: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(HomeStrings.createTitle)
                    .font(.headline)
                Text(HomeStrings.createSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
