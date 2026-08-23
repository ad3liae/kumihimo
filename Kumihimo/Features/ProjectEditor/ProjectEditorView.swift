import SwiftUI

struct ProjectEditorView: View {
    @Bindable var store: ProjectEditorStore

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView(ProjectEditorStrings.loading)
            } else if store.hasLoadError {
                ContentUnavailableView {
                    Label(ProjectEditorStrings.loadErrorTitle, systemImage: "exclamationmark.triangle")
                } description: {
                    Text(ProjectEditorStrings.loadErrorMessage)
                } actions: {
                    Button(ProjectEditorStrings.retry, action: store.load)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                editorContent
            }
        }
        .navigationTitle(store.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { saveToolbar }
        .sheet(item: $store.nameSheetPurpose) { purpose in
            ProjectNameSheet(
                title: purpose == .newProject
                    ? ProjectEditorStrings.saveNewTitle
                    : ProjectEditorStrings.saveAsTitle,
                name: $store.proposedName,
                showsSaveError: $store.showsSaveError,
                isSaving: store.isSaving,
                cancel: store.dismissNameSheet,
                save: store.submitNameSheet,
                retry: store.retrySave
            )
        }
        .sheet(isPresented: colorSheetBinding) {
            if let position = store.selectedThreadPosition {
                ThreadColorSelectionView(
                    position: position,
                    selectedColorID: store.draft.threadAssignments.first {
                        $0.position == position
                    }?.colorID,
                    selectColor: store.selectColor,
                    cancel: { store.selectedThreadPosition = nil }
                )
            }
        }
        .alert(
            ProjectEditorStrings.reduceThreadCountTitle,
            isPresented: $store.showsThreadCountReductionConfirmation
        ) {
            Button(ProjectEditorStrings.cancel, role: .cancel) {
                store.cancelThreadCountReduction()
            }
            Button(ProjectEditorStrings.reduce, role: .destructive) {
                store.confirmThreadCountReduction()
            }
        } message: {
            Text(ProjectEditorStrings.reduceThreadCountMessage)
        }
        .alert(ProjectEditorStrings.saveErrorTitle, isPresented: overwriteSaveErrorBinding) {
            Button(ProjectEditorStrings.dismiss, role: .cancel) {}
            Button(ProjectEditorStrings.retry, action: store.retrySave)
        } message: {
            Text(ProjectEditorStrings.saveErrorMessage)
        }
    }

    private var editorContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                section(ProjectEditorStrings.threadCountSection) {
                    Picker(
                        ProjectEditorStrings.threadCount,
                        selection: Binding(
                            get: { store.selectedThreadCount },
                            set: store.requestThreadCount
                        )
                    ) {
                        ForEach(ProjectDraft.supportedThreadCounts, id: \.self) { count in
                            Text(ProjectEditorStrings.threadCountValue(count)).tag(count)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier(
                        ProjectEditorAccessibilityIdentifiers.threadCountPicker
                    )
                    .accessibilityValue(
                        ProjectEditorStrings.threadCountValue(store.selectedThreadCount)
                    )
                }

                section(ProjectEditorStrings.colorPlacementSection) {
                    KumihimoBoardView(
                        assignments: store.draft.threadAssignments,
                        selectPosition: { store.selectedThreadPosition = $0 }
                    )
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity)
                }

                section(ProjectEditorStrings.simulationSection) {
                    SimulationResultsBoundaryView(state: store.simulationResultsState)
                }
            }
            .padding()
        }
    }

    @ToolbarContentBuilder
    private var saveToolbar: some ToolbarContent {
        if store.showsSaveToolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if store.isExistingProject {
                    Menu {
                        Button(ProjectEditorStrings.overwrite, action: store.overwrite)
                            .disabled(!store.canOverwrite)
                        Button(ProjectEditorStrings.saveAs, action: store.presentDuplicateSaveSheet)
                            .disabled(!store.canSave)
                    } label: {
                        Text(ProjectEditorStrings.save)
                    }
                    .disabled(store.isSaving)
                } else {
                    Button(ProjectEditorStrings.save, action: store.presentNewSaveSheet)
                        .disabled(!store.canSave)
                }
            }
        }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var colorSheetBinding: Binding<Bool> {
        Binding(
            get: { store.selectedThreadPosition != nil },
            set: { isPresented in
                if !isPresented { store.selectedThreadPosition = nil }
            }
        )
    }

    private var overwriteSaveErrorBinding: Binding<Bool> {
        Binding(
            get: { store.nameSheetPurpose == nil && store.showsSaveError },
            set: { isPresented in
                if !isPresented { store.showsSaveError = false }
            }
        )
    }
}
