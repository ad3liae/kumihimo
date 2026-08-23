import SwiftUI

struct ProjectNameSheet: View {
    let title: String
    @Binding var name: String
    @Binding var showsSaveError: Bool
    let isSaving: Bool
    let cancel: () -> Void
    let save: () -> Void
    let retry: () -> Void

    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField(ProjectEditorStrings.projectName, text: $name)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .onSubmit {
                        if isNameValid && !isSaving {
                            save()
                        }
                    }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ProjectEditorStrings.cancel, action: cancel)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(ProjectEditorStrings.save, action: save)
                        .disabled(!isNameValid || isSaving)
                }
            }
            .onAppear { isNameFocused = true }
        }
        .interactiveDismissDisabled(isSaving)
        .alert(ProjectEditorStrings.saveErrorTitle, isPresented: $showsSaveError) {
            Button(ProjectEditorStrings.dismiss, role: .cancel) {}
            Button(ProjectEditorStrings.retry, action: retry)
        } message: {
            Text(ProjectEditorStrings.saveErrorMessage)
        }
    }

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
