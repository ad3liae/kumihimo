import Foundation
import Testing
@testable import Kumihimo

/// Task 025-4: what the chord model used to answer, and what answers it now.
///
/// The chord model was retired here. Before it went, its over and under was held
/// against the construction's — "a carry that passes places other than the one it
/// lands on passes them inside, so it is under whatever rests there" — and the two
/// agreed **64 cells of 64**. (An earlier attempt reported 16 of 64 and was wrong:
/// it asked whether the carry crossed *the belly*, when what matters is whether it
/// runs *across the braid* at all. A weft that stays on one face still passes the
/// columns between its ends.) That comparison went with the model it was checking;
/// what is left is the claim that stands on its own.

/// Task 025-4: the stacking model's own claim about the body, which is the one
/// piece of independent support the construction's over and under has.
///
/// **The top of every pile in the body is a thread running lengthwise** — forty of
/// forty, which is what makes book A p97's first experiment come out: colour only
/// what is worked sideways and the body stays plain.
@MainActor
struct BraidStackingBodyTests {
    @Test func theTopOfEveryPileInTheBodyIsAThreadRunningLengthwise() throws {
        let derivation = try #require(BraidDerivation.derive(
            stand: BraidMethodCatalog.stand16, method: BraidMethodCatalog.hiraGenji16,
            crossSection: BraidMethodCatalog.hiraGenji16CrossSection
        ))
        let fold = try #require(derivation.fold)
        let stacking = try #require(BraidStacking.stacking(
            of: derivation.method, on: derivation.stand,
            crossSection: derivation.crossSection, fold: fold, cycles: 6
        ))
        let lengthwise = Set(derivation.threadsRunningAlongTheBraid)
        // The body is the occupancy history's: widths one to four, on both faces.
        let body = (0..<derivation.crossSection.slotCount).filter { slot in
            guard let width = fold.width(ofSlot: slot), fold.face(ofSlot: slot) != nil
            else { return false }
            return (1...4).contains(width)
        }
        #expect(body.count == 8)

        var onTop = 0, cells = 0
        for slot in body {
            for cycle in 0..<5 {
                guard let pile = stacking.layersBySlot[slot]?[cycle], let top = pile.last
                else { continue }
                cells += 1
                if lengthwise.contains(top.thread) { onTop += 1 }
            }
        }
        #expect(cells == 40)
        #expect(onTop == 40)
    }
}
