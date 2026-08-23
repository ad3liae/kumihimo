import SwiftUI

struct SimulationResultsBoundaryView: View {
    let state: ProjectEditorStore.SimulationResultsState

    var body: some View {
        Group {
            switch state {
            case .unavailable:
                ContentUnavailableView {
                    Label(ProjectEditorStrings.simulationPendingTitle, systemImage: "sparkles.rectangle.stack")
                } description: {
                    Text(ProjectEditorStrings.simulationPendingMessage)
                }
            case .calculating:
                ProgressView(ProjectEditorStrings.simulationCalculating)
                    .frame(maxWidth: .infinity, minHeight: 140)
            case .failed:
                ContentUnavailableView {
                    Label(ProjectEditorStrings.simulationFailedTitle, systemImage: "exclamationmark.triangle")
                } description: {
                    Text(ProjectEditorStrings.simulationFailedMessage)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
