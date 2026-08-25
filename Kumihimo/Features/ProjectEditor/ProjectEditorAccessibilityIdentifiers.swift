enum ProjectEditorAccessibilityIdentifiers {
    static let threadCountPicker = "project-editor.thread-count-picker"
    static let undecidedPresetButton = "project-editor.preset-undecided"

    static func presetButton(_ id: BraidPresetID) -> String {
        "project-editor.preset-\(id.rawValue)"
    }

    static func thumbnail3DButton(_ id: BraidPresetID) -> String {
        "project-editor.preset-\(id.rawValue)-thumbnail-3d"
    }
}
