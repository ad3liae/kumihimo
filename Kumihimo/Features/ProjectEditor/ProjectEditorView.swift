import SwiftUI

struct ProjectEditorView: View {
    @Bindable var store: ProjectEditorStore
    /// The braid whose detail is open. **A sheet at every width** (Task 058), so
    /// turning the device or resizing the window neither closes it nor moves it.
    @State private var detailPreset: BraidPreset?
    @StateObject private var previewController = RoundTube16ViewerController()

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
        .sheet(item: $detailPreset) { preset in
            BraidDetailSheet(
                preset: preset,
                assignments: store.draft.threadAssignments,
                controller: previewController
            )
            .braidDetailSheetSizing()
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
        }
    }

    private var singleColumnContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                standSection
                threadCountSection
                colorPlacementSection
                noBraidCard
                simulationSection
            }
            .padding()
        }
    }

    private var twoColumnContent: some View {
        HStack(alignment: .top, spacing: 24) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    standSection
                    threadCountSection
                    colorPlacementSection
                }
                .padding(.vertical)
            }
            .frame(minWidth: 360, idealWidth: 420, maxWidth: 460)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    noBraidCard
                    simulationSection
                }
                .padding(.vertical)
            }
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 1_220, maxHeight: .infinity)
    }

    /// Round or square (Task 058). **The board below stays round for either**;
    /// the square stand's picture comes with its first braid.
    private var standSection: some View {
        section(ProjectEditorStrings.standSection) {
            Picker(
                ProjectEditorStrings.stand,
                selection: Binding(
                    get: { store.draft.standKind },
                    set: store.selectStandKind
                )
            ) {
                ForEach(BraidStandKind.allCases, id: \.self) { kind in
                    Text(ProjectEditorStrings.standName(kind)).tag(kind)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier(ProjectEditorAccessibilityIdentifiers.standPicker)
            .accessibilityValue(ProjectEditorStrings.standName(store.draft.standKind))
        }
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

    /// Choosing no braid: **above the results' heading**, not in the section
    /// (Task 058 追補1).
    private var noBraidCard: some View {
        NoBraidCard(
            isSelected: NoBraidCard.isSelected(
                selectedPresetID: store.draft.selectedBraidPresetID
            ),
            select: { store.selectBraidPreset(nil) }
        )
    }

    private var simulationSection: some View {
        section(ProjectEditorStrings.simulationSection) {
            SimulationResultsBoundaryView(
                state: store.simulationResultsState,
                standKind: store.draft.standKind,
                threadCount: store.draft.threadCount,
                assignments: store.draft.threadAssignments,
                presets: store.availableBraidPresets,
                selectedPresetID: store.draft.selectedBraidPresetID,
                selectPreset: store.selectBraidPreset,
                showDetail: { detailPreset = $0 }
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
