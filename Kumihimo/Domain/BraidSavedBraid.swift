import Foundation

/// The one place that reads the braid a saved project names.
///
/// **A saved project names its braid by the recipe's identifier.** Everything that
/// reads or writes that key goes through here, so a rename lands in one place
/// instead of in every reader.
///
/// **The table below is empty, and that is the honest state.** The keys that were
/// already written are the presets' identifiers, and a preset's identifier *is* its
/// recipe's — `"maru-genji-16"`, `"hira-genji-16"` — so nothing needs renaming
/// today. The table exists because the next rename has to have somewhere to go, and
/// a reading that goes through nothing is a reading nobody can change.
enum BraidSavedBraid {
    /// Old key → the recipe identifier it became.
    static let renamedKeys: [String: String] = [:]

    /// The recipe identifier a saved key means.
    static func recipeID(fromSaved key: String) -> String {
        renamedKeys[key] ?? key
    }

    /// The recipe a saved key names, or `nil` when this app has no such recipe.
    ///
    /// **`nil` is an answer, not a failure.** A project saved naming a braid this
    /// build does not carry still opens; it simply has nothing to draw, and the
    /// screen says so — the same road a braid with no drawer takes.
    static func recipe(fromSaved key: String) -> BraidRecipe? {
        let id = recipeID(fromSaved: key)
        return BraidMethodCatalog.recipes.first { $0.id == id }
    }

    /// What to write for a recipe.
    static func savedKey(for recipe: BraidRecipe) -> String { recipe.id }

    /// What to write for a preset the screens offer. `nil` when the preset has no
    /// recipe, which is a preset this app cannot braid.
    static func savedKey(forPreset presetID: BraidPresetID) -> String? {
        BraidMethodCatalog.recipe(for: presetID).map(savedKey(for:))
    }

    /// The preset a saved key picks out on the screens, if any.
    static func preset(fromSaved key: String) -> BraidPresetID? {
        guard let recipe = recipe(fromSaved: key) else { return nil }
        return BraidPresetCatalog.presets.first { $0.id.rawValue == recipe.id }?.id
    }
}
