import SwiftUI

struct ProjectEditorView: View {
    @Bindable var store: ProjectEditorStore
    @State private var previewPreset: BraidPreset?
    @State private var compactPreviewPreset: BraidPreset?
    @State private var currentLayout = ProjectEditorLayout.singleColumn
    @StateObject private var previewController = MaruGenjiViewerController()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
        .fullScreenCover(item: $compactPreviewPreset) { preset in
            if preset.id == .maruGenji16 {
                MaruGenji3DPreviewView(
                    assignments: store.draft.threadAssignments,
                    controller: previewController,
                    isEmbedded: false,
                    closeAction: closePreview
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
        GeometryReader { geometry in
            let layout = ProjectEditorLayoutCalculator.layout(
                width: geometry.size.width,
                hasRegularHorizontalSizeClass: horizontalSizeClass == .regular,
                dynamicTypeSize: dynamicTypeSize
            )

            Group {
                switch layout {
                case .singleColumn:
                    singleColumnContent
                case .twoColumn:
                    twoColumnContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { currentLayout = layout }
            .onChange(of: layout) { _, newLayout in
                currentLayout = newLayout
                switch newLayout {
                case .singleColumn:
                    if let previewPreset {
                        compactPreviewPreset = previewPreset
                        self.previewPreset = nil
                    }
                case .twoColumn:
                    if let compactPreviewPreset {
                        previewPreset = compactPreviewPreset
                        self.compactPreviewPreset = nil
                    }
                }
            }
        }
    }

    private var singleColumnContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                threadCountSection
                colorPlacementSection
                simulationSection
            }
            .padding()
        }
    }

    private var twoColumnContent: some View {
        HStack(alignment: .top, spacing: 24) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    threadCountSection
                    colorPlacementSection
                }
                .padding(.vertical)
            }
            .frame(minWidth: 360, idealWidth: 420, maxWidth: 460)

            Divider()

            Group {
                if previewPreset?.id == .maruGenji16 {
                    MaruGenji3DPreviewView(
                        assignments: store.draft.threadAssignments,
                        controller: previewController,
                        isEmbedded: true,
                        closeAction: closePreview
                    )
                    .padding(.vertical)
                } else {
                    ScrollView {
                        simulationSection
                            .padding(.vertical)
                    }
                }
            }
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 1_220, maxHeight: .infinity)
    }

    private var threadCountSection: some View {
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
    }

    private var colorPlacementSection: some View {
        section(ProjectEditorStrings.colorPlacementSection) {
            KumihimoBoardView(
                assignments: store.draft.threadAssignments,
                selectPosition: { store.selectedThreadPosition = $0 }
            )
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
        }
    }

    private var simulationSection: some View {
        section(ProjectEditorStrings.simulationSection) {
            SimulationResultsBoundaryView(
                state: store.simulationResultsState,
                threadCount: store.draft.threadCount,
                assignments: store.draft.threadAssignments,
                presets: store.availableBraidPresets,
                selectedPresetID: store.draft.selectedBraidPresetID,
                selectPreset: store.selectBraidPreset,
                show3DPreview: openPreview
            )
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

    private func openPreview(_ preset: BraidPreset) {
        if currentLayout == .singleColumn {
            compactPreviewPreset = preset
        } else {
            previewPreset = preset
        }
    }

    private func closePreview() {
        previewPreset = nil
        compactPreviewPreset = nil
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
