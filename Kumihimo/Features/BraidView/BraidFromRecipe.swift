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
    /// What the braid's width over thickness was taken from: the recipe's measured
    /// value where it has one, and the construction's own otherwise.
    let widthOverThickness: BraidMeasurement

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
            // A tube is never pressed; a flat braid is, unless asked otherwise.
            let pressed = flatten && worked.derivation.fold != nil ? true : false,
            let first = built(worked, on: stand, cycles: cycles, flatten: pressed,
                              crestHeight: recipe.shape.crestHeight, thicknessScale: 1)
        else { return nil }

        // **The braid's thickness is a measured value where the recipe has one.**
        // Scaling the through-thickness direction leaves the width alone, so the
        // scale that meets the measurement is one division away from what the
        // construction came out at -- no search, and nothing fitted by eye.
        var lines = first
        var ratio = BraidMeasurement.derived(
            BraidSectionMeasure.measure(first, tube: worked.derivation.fold == nil)?
                .widthOverThickness ?? 0,
            by: "measured on the braid the construction came out with"
        )
        if worked.derivation.fold != nil, let measured = recipe.shape.widthOverThickness {
            var scale = 1.0
            var here = ratio.value
            for _ in 0..<BraidSection.ratioRounds {
                guard abs(here - measured.value) > BraidSection.ratioSettled,
                      let step = BraidSection.thicknessScale(toMeet: measured, from: here),
                      let again = built(worked, on: stand, cycles: cycles, flatten: pressed,
                                        crestHeight: recipe.shape.crestHeight,
                                        thicknessScale: scale * step),
                      let now = BraidSectionMeasure.measure(again, tube: false)
                else { break }
                scale *= step
                lines = again
                here = now.widthOverThickness
            }
            ratio = abs(here - measured.value) <= 1e-4 ? measured : BraidMeasurement.derived(
                here, by: "measured on the braid; the recipe's value was not reached"
            )
        }

        return BraidFromRecipe(
            recipe: recipe, lines: lines, occupancy: occupancy,
            section: BraidSectionMeasure.measure(lines, tube: worked.derivation.fold == nil),
            pitch: stacking.pitchPerBraidWidth, widthOverThickness: ratio
        )
    }

    private static func built(
        _ worked: (method: BraidMethod, section: BraidCrossSection, derivation: BraidDerivation),
        on stand: BraidStand, cycles: Int, flatten: Bool,
        crestHeight: BraidMeasurement?, thicknessScale: Double
    ) -> BraidCentrelines? {
        guard let construction = BraidConstruction.construct(
            of: worked.method, on: stand, crossSection: worked.section,
            fold: worked.derivation.fold, cycles: cycles, flatten: flatten,
            thicknessScale: thicknessScale
        ) else { return nil }
        return BraidCentrelines.centrelines(of: construction, crestHeight: crestHeight)
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
