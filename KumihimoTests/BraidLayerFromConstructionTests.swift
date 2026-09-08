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
/// **It does not agree: 16 cells of 64 the same, 48 different**, and different in
/// both directions rather than uniformly flipped. So the chord model is *not*
/// deleted, and no second definition was tried — trying definitions until one fits
/// is fitting. This test pins the disagreement as it stands, and the author has
/// been asked (Task 025-3's report).
///
/// The two are not measuring the same thing. The chord model asks which thread was
/// carried later; the construction asks where the thread physically sits. **The
/// second is the one that reproduced book A p97 off the picture**, and the first is
/// the one the shipped per-braid surface was checked against.
@MainActor
struct BraidLayerFromConstructionTests {
    /// Over unless this row's carry takes the thread through the belly.
    static func layer(
        ofThread thread: Int, atRow row: Int, in construction: BraidConstruction
    ) -> BraidCrossingLayer? {
        guard let way = construction.steps[thread], row + 1 < way.count else { return nil }
        guard
            let here = construction.section.places[way[row].slot],
            let there = construction.section.places[way[row + 1].slot]
        else { return nil }
        let throughTheBelly = here.kind != there.kind && here.kind != .edge && there.kind != .edge
        return throughTheBelly ? .under : .over
    }

    @Test func theConstructionAndTheChordModelDisagreeAndTheCountIsRecorded() throws {
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
            guard let mine = Self.layer(ofThread: cell.threadPosition, atRow: cell.row,
                                        in: construction)
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
        #expect(agreed == 16)
        #expect(disagreed.count == 48)
        #expect(disagreed.contains { $0.contains("construction over, chords under") })
        #expect(disagreed.contains { $0.contains("construction under, chords over") })
    }
}
