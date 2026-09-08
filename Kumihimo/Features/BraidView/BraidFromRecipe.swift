import CoreGraphics
import Foundation

/// A braid built from a recipe and drawn, ready to be put beside the shipped one.
///
/// **This is the new path end to end**: the move table gives the working-out, the
/// working-out gives the construction, the construction gives the centrelines, and
/// the centrelines are drawn with a depth buffer. **Nothing in it is fitted to a
/// picture**, and the one measured value it takes — the crest's height — says
/// `.observed` and is only used when it is in thread diameters.
///
/// It is not the shipping path yet. Task 025-4 decides whether the frozen
/// generators retire, by putting these pictures beside the photographs.
struct BraidFromRecipe {
    let recipe: BraidRecipe
    let lines: BraidCentrelines
    let occupancy: BraidOccupancy
    let section: BraidSectionMeasure?
    let pitch: BraidMeasurement

    /// `cycles` is how much of the braid to build; three shows a repeat with a
    /// cycle spare at each end.
    static func build(
        _ recipe: BraidRecipe, on stand: BraidStand, cycles: Int = 3, flatten: Bool = true
    ) -> BraidFromRecipe? {
        guard
            let worked = recipe.worked(on: stand),
            let occupancy = BraidOccupancy.history(
                of: worked.method, on: stand, crossSection: worked.section, cycles: cycles
            ),
            let stacking = BraidStacking.stacking(
                of: worked.method, on: stand, crossSection: worked.section,
                fold: worked.derivation.fold, cycles: cycles + 2
            ),
            let construction = BraidConstruction.construct(
                of: worked.method, on: stand, crossSection: worked.section,
                fold: worked.derivation.fold, cycles: cycles,
                // A tube is never pressed; a flat braid is, unless asked otherwise.
                flatten: flatten && worked.derivation.fold != nil
            ),
            let lines = BraidCentrelines.centrelines(
                of: construction, crestHeight: recipe.shape.crestHeight
            )
        else { return nil }
        return BraidFromRecipe(
            recipe: recipe, lines: lines, occupancy: occupancy,
            section: BraidSectionMeasure.measure(lines, tube: worked.derivation.fold == nil),
            pitch: stacking.pitchPerBraidWidth
        )
    }

    /// The braid drawn from every view worth showing, with the recipe's colouring.
    func pictures(slotCount: Int) -> [(name: String, image: CGImage)] {
        var colours = [Int: ThreadColorValue]()
        for assignment in recipe.colouring {
            let colour = ThreadColorCatalog.colors.first { $0.id == assignment.colorID }
                ?? ThreadColorCatalog.defaultColor
            colours[assignment.position] = colour.value
        }
        var out = [(name: String, image: CGImage)]()
        for view in BraidDrawing.views(of: lines, occupancy: occupancy, slotCount: slotCount) {
            let picture = BraidPicture.paint(lines, looking: view.direction)
            guard let image = BraidDrawing.image(of: picture, colours: colours) else { continue }
            out.append((view.name, image))
        }
        return out
    }
}
