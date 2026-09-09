import Foundation

/// Hands a recipe to the drawer for its family.
///
/// **The recipe says what to braid; the family says who draws it.** The family is
/// read off the braid — folded or a tube, and how many threads — so nothing here
/// knows the name of a braid, and adding a braid of a family already drawn adds no
/// code at all.
///
/// The colours in the drawing come from the occupancy history, not from the
/// drawer's own reckoning (Task 025-4 step 2).
enum BraidFamilyDrawing {
    enum Drawing {
        case flat(Flat16SurfacePattern)
        case roundTube(RoundTube16SurfacePattern)

        var family: BraidFamily {
            switch self {
            case .flat: return Flat16SurfaceMesh.family
            case .roundTube: return RoundTube16SurfaceMesh.family
            }
        }
    }

    /// Every family this app can draw, and what each one rests on.
    static var families: [BraidFamilyShape] {
        [Flat16SurfaceMesh.shape, RoundTube16SurfaceMesh.shape]
    }

    static func shape(of family: BraidFamily) -> BraidFamilyShape? {
        families.first { $0.family.fits(family) }
    }

    /// `nil` when no drawer draws that family — which is the right answer for a
    /// braid this app has not been taught to draw, and better than drawing it
    /// wrong.
    static func drawing(
        for recipe: BraidRecipe, on stand: BraidStand
    ) -> Drawing? {
        guard let worked = recipe.worked(on: stand) else { return nil }
        switch BraidFamily.family(of: worked.derivation) {
        case Flat16SurfaceMesh.family:
            // **The flat drawing is wired to one braid** and says so; a second flat
            // braid has no drawer until its centring is put right (see
            // `Flat16SurfacePatternGenerator.drawsOnlyTheRecipe`). No drawer is the
            // right answer, not a drawing that is wrong.
            guard recipe.id == Flat16SurfacePatternGenerator.drawsOnlyTheRecipe
            else { return nil }
            return Flat16SurfacePatternGenerator.generate(assignments: recipe.colouring)
                .map(Drawing.flat)
        case RoundTube16SurfaceMesh.family:
            return RoundTube16SurfacePatternGenerator.generate(assignments: recipe.colouring)
                .map(Drawing.roundTube)
        default:
            return nil
        }
    }

    /// The mesh for a recipe, from the drawer its family names.
    static func mesh(for recipe: BraidRecipe, on stand: BraidStand) -> (flat: Flat16SurfaceMeshData?, tube: RoundTube16SurfaceMeshData?) {
        switch drawing(for: recipe, on: stand) {
        case let .flat(pattern): return (Flat16SurfaceMesh.generate(pattern: pattern), nil)
        case let .roundTube(pattern): return (nil, RoundTube16SurfaceMesh.generate(pattern: pattern))
        case nil: return (nil, nil)
        }
    }
}
