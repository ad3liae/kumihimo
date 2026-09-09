import Foundation
@testable import Kumihimo

/// Rebuilds the shipped flat-braid surface out of the general working-out, so the
/// two can be compared object for object.
///
/// **This exists to make a difference visible, not to ship.** Every value it fills
/// in is one the working-out already has — the fold says which face and which
/// column, the courses say which thread, and **which side of a crossing a thread
/// takes comes from the construction**: a carry that runs across the braid passes
/// the columns between its ends, and it passes them inside.
///
/// It used to take that last one from the chord model. The author's ruling of
/// 2026-09-09 made the construction the source, and the two agree cell for cell
/// (`BraidLayerFromConstructionTests`), so nothing about this comparison moved.
/// The comparison the product path is held to.
///
/// **The rebuilding itself moved into the product** at Task 025-4 step 4 -- it is
/// `Flat16WeaveFromWorking` now -- so this is a thin call onto it. Keeping the name
/// keeps the agreement tests pointing at the same thing they always did, and they
/// now exercise the shipping path rather than a copy of it.
enum BraidPatternBridge {
    static func hiraStylePattern(
        from derivation: BraidDerivation,
        assignments: [ThreadAssignment]
    ) -> HiraGenjiWeavePattern? {
        guard let construction = BraidConstruction.construct(
            of: derivation.method, on: derivation.stand,
            crossSection: derivation.crossSection, fold: derivation.fold,
            cycles: derivation.repeatCycleCount + 1
        ) else { return nil }
        return Flat16WeaveFromWorking.pattern(
            from: derivation, construction: construction, assignments: assignments
        )
    }

    static func hiraStylePattern(
        from derivation: BraidDerivation,
        construction: BraidConstruction,
        assignments: [ThreadAssignment]
    ) -> HiraGenjiWeavePattern? {
        Flat16WeaveFromWorking.pattern(
            from: derivation, construction: construction, assignments: assignments
        )
    }
}

/// The colourings the books set up as controlled experiments, written the way the
/// books write them: by group of the stand.
@MainActor
enum HiraGenjiReferenceColourings {
    /// Book A p97, left: everything worked lengthwise plain, everything worked
    /// sideways in colour.
    static var weftOnly: [ThreadAssignment] {
        colouring(north: .init(repeating: "white", count: 4),
                  south: .init(repeating: "white", count: 4),
                  east: ["yellow", "red", "red", "yellow"],
                  west: ["green", "light-blue", "light-blue", "green"])
    }

    /// Book A p97's arrow feather: the middle two of each side one colour, the far
    /// and near two another.
    static var arrowFeather: [ThreadAssignment] {
        ProjectEditorPreviewData.hiraGenjiSurfaceArrowFeather
    }

    /// Book A p97's ladder: the far group and the near group in two colours.
    static var ladder: [ThreadAssignment] {
        ProjectEditorPreviewData.hiraGenjiSurfaceLadder
    }

    /// The colouring drawn in book A p96's starting diagram, whose finished braid
    /// is the photograph the cross-section's order is read from.
    static var bookAP96: [ThreadAssignment] {
        colouring(north: ["purple", "purple", "black", "orange"],
                  south: ["purple", "purple", "black", "orange"],
                  east: .init(repeating: "pink", count: 4),
                  west: .init(repeating: "pink", count: 4))
    }

    static var all: [(String, [ThreadAssignment])] {
        [("weft only", weftOnly), ("arrow feather", arrowFeather),
         ("ladder", ladder), ("book A p96", bookAP96)]
    }

    private static func colouring(
        north: [String], south: [String], east: [String], west: [String]
    ) -> [ThreadAssignment] {
        var colours = [Int: String]()
        for (group, names) in [
            (HiraGenjiBoardState.initial.north, north),
            (HiraGenjiBoardState.initial.east, east),
            (HiraGenjiBoardState.initial.south, south),
            (HiraGenjiBoardState.initial.west, west),
        ] {
            for (position, name) in zip(group, names) { colours[position] = name }
        }
        return (1...16).map {
            ThreadAssignment(position: $0, colorID: ThreadColorID(rawValue: colours[$0] ?? "white"))
        }
    }
}
