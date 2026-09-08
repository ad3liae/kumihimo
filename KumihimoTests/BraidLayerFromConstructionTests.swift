import Foundation
import Testing
@testable import Kumihimo

/// Task 025-3: can the construction say which side of a crossing a thread takes,
/// as the chord model does?
///
/// The construction's answer is not a rule added on top: **a thread carried through
/// the belly is under the threads resting on the faces**, and that is where the
/// carry is actually drawn. If it agreed with the chord model everywhere, the chord
/// model would have nothing left to say and could go.
///
/// **They agree, 64 cells of 64.**
///
/// A first attempt at this reported 16 of 64 and was wrong: it asked whether the
/// carry crossed *the belly*, when what matters is whether the carry runs *across
/// the braid* at all. A weft that stays on one face still passes the columns
/// between its ends, and it passes them inside. The reported disagreement was that
/// mistake and nothing else (Task 025-3's report; corrected in 025-4).
@MainActor
struct BraidLayerFromConstructionTests {
    @Test func theConstructionAndTheChordModelSayTheSameThing() throws {
        let derivation = try #require(BraidDerivation.derive(
            stand: BraidMethodCatalog.stand16, method: BraidMethodCatalog.hiraGenji16,
            crossSection: BraidMethodCatalog.hiraGenji16CrossSection
        ))
        let construction = try #require(BraidConstruction.construct(
            of: derivation.method, on: derivation.stand,
            crossSection: derivation.crossSection, fold: derivation.fold,
            cycles: derivation.repeatCycleCount + 1
        ))
        var agreed = 0
        var disagreed = [String]()
        for cell in derivation.cells {
            guard let theirs = cell.layer else { continue }
            guard let mine = construction.layer(ofThread: cell.threadPosition,
                                                atRow: cell.row)
            else {
                disagreed.append("row \(cell.row) thread \(cell.threadPosition): "
                                 + "the construction has nothing to say")
                continue
            }
            if mine == theirs {
                agreed += 1
            } else {
                disagreed.append("row \(cell.row) thread \(cell.threadPosition): "
                                 + "construction \(mine.rawValue), chords \(theirs.rawValue)")
            }
        }
        // Recorded, not accepted. If either side moves, this is where it shows.
        let report = "agreed \(agreed), disagreed \(disagreed.count); first few: "
            + disagreed.prefix(4).joined(separator: "; ")
        #expect(agreed == 64, Comment(rawValue: report))
        #expect(disagreed.isEmpty, Comment(rawValue: report))
    }
}

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
