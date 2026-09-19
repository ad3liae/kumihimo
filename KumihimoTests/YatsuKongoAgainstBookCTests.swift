import Foundation
import Testing
@testable import Kumihimo

/// Task 035, carried out under Task 049: **book C Fig.129 "ハツ金剛Z組 / Yatsu
/// Kongo Z-spiral", transcribed and held against the table the app braids
/// with.**
///
/// The table in the app was raised from book A p.54's picture and the author's
/// ruling, because book C was thought to have no figure for this braid; Fig.129
/// is that figure. **This transcription is not blind**: the app's table was
/// already known when it was made, and it is written down here so the difference
/// can be seen, not to prove independence.
///
/// **What the figure prints** (`.build/bookC-yatsu-kongo/bookC-fig129-130-yatsu-kongo-z.png`,
/// read at 3x):
///
/// - a disk of 32 notches, numbered clockwise from the top;
/// - marks at notches 1, 2, 9, 10, 17, 18, 25, 26 — eight threads in four pairs,
///   at twelve, three, six and nine o'clock. The marks on 9 and 10 are drawn in
///   red, the rest in pencil; nothing else tells them apart;
/// - `method: 02-16  18-32 / turn the disk ccw 15 minutes / 10-24  26-08 / turn
///   the disk ccw 15 minutes / 17-31  01-15 / and so on.`;
/// - `right thread down left up. and turn the disk ccw.`;
/// - and in Japanese: 基本の金剛組。ディスクを90°ずつ左回転させながら組む。
///   スロットの番号は順にずれていく。
///
/// **What had to be read into it.** The figure prints three lines and "and so
/// on"; the rest of a cycle is inferred from the rule the three lines follow —
/// each line works the two *opposite* pairs, moving the clockwise-later thread
/// of each fourteen notches clockwise, and the two groups of pairs alternate.
/// That rule reproduces all six printed moves. **Turning the disk is the
/// braider's own movement**: the numbers are on the disk and turn with it, which
/// is why the worked notches differ line by line and why the pairs drift a notch
/// at a time ("スロットの番号は順にずれていく"). **This is not the drawing's
/// one-column-a-cycle turn of the finished braid** (Task 048), and says nothing
/// about its size.
@MainActor
struct YatsuKongoAgainstBookCTests {

    /// The eight threads at rest, in the order the figure numbers them: notch,
    /// and the place 1-8 it stands for.
    static let restingNotches = [1, 2, 9, 10, 17, 18, 25, 26]
    /// The six moves book C prints, in the printed order.
    static let printedMoves = [(2, 16), (18, 32), (10, 24), (26, 8), (17, 31), (1, 15)]

    /// One cycle of Fig.129, worked from the figure's own rule.
    ///
    /// Returns the moves it makes and, for each thread, the place it began at
    /// and the place it ends at. Places are the four pairs of the starting
    /// diagram, each holding two threads in clockwise order; a pair keeps its
    /// identity as it drifts round the disk.
    static func cycle() -> (moves: [(Int, Int)], endsAt: [Int: Int]) {
        // Thread 1-8 at its notch.
        var atNotch = [Int: Int]()
        for (index, notch) in restingNotches.enumerated() { atNotch[notch] = index + 1 }
        // The four pairs, each as the notches it holds in clockwise order, kept
        // in the order twelve, three, six, nine o'clock — the places 1-2, 3-4,
        // 5-6, 7-8 of the starting diagram. A pair keeps its identity as it
        // drifts round the disk.
        var pairs = [[1, 2], [9, 10], [17, 18], [25, 26]]
        var moves = [(Int, Int)]()

        // The clockwise-later notch of two that sit side by side.
        func later(_ pair: [Int]) -> Int { (pair[1] - pair[0] + 32) % 32 == 1 ? pair[1] : pair[0] }
        func isJustBefore(_ one: Int, _ other: Int) -> Bool { (other - one + 32) % 32 == 1 }

        for line in 0..<4 {
            // Each line works the two opposite pairs, and the two groups
            // alternate: twelve and six o'clock, then three and nine.
            let worked = line.isMultiple(of: 2) ? [0, 2] : [1, 3]
            var arrivals = [Int]()
            for index in worked {
                let from = later(pairs[index])
                let to = (from + 14 - 1) % 32 + 1
                moves.append((from, to))
                atNotch[to] = atNotch.removeValue(forKey: from)
                pairs[index] = pairs[index].filter { $0 != from }
                arrivals.append(to)
            }
            // Each thread joins the pair it lands beside, on the outside.
            for arrival in arrivals {
                for index in pairs.indices where pairs[index].count == 1 {
                    let held = pairs[index][0]
                    if isJustBefore(arrival, held) { pairs[index] = [arrival, held] }
                }
            }
        }
        // Where each thread ended, as a place of the starting diagram: which
        // pair it is in now, and which of that pair's two it is.
        var endsAt = [Int: Int]()
        for (index, pair) in pairs.enumerated() {
            for (inside, notch) in pair.enumerated() {
                guard let thread = atNotch[notch] else { continue }
                endsAt[thread] = 2 * index + inside + 1
            }
        }
        return (moves, endsAt)
    }

    /// **The rule reproduces every move book C prints**, in the order it prints
    /// them save one: the third line's two moves come out the other way round
    /// (the figure prints `17-31 01-15`; the rule works twelve o'clock before
    /// six). The two are different pairs, so the figure is not saying which
    /// thread of one pair goes first.
    @Test func theRuleGivesTheMovesBookCPrints() {
        let (moves, _) = Self.cycle()
        let printed = Set(Self.printedMoves.map { "\($0.0)-\($0.1)" })
        let mine = Set(moves.prefix(6).map { "\($0.0)-\($0.1)" })
        #expect(mine == printed, "\(moves.prefix(6))")
        // The first four are in the printed order as well.
        #expect(moves.prefix(4).map { "\($0.0)-\($0.1)" }
                == Self.printedMoves.prefix(4).map { "\($0.0)-\($0.1)" })
    }

    /// **Book C's braid carries a thread to the opposite pair — four places a
    /// cycle — and the app's table carries it three.** The transcription and the
    /// implementation disagree, and this holds that difference down thread by
    /// thread rather than papering over it.
    ///
    /// Book C: every thread crosses to the pair opposite (place `p` to `p + 4`),
    /// and the whole arrangement drifts two notches (a quarter of a place)
    /// round the disk each cycle, which is the "slot numbers shift" of the note.
    /// The app's Z table carries `+3` (`RoundTube8SurfacePattern.columnsCarried`).
    ///
    /// **Nothing here changes the app's table** (Task 049's rule): the
    /// disagreement is recorded for the author to rule on.
    @Test func bookCCarriesFourPlacesWhereTheTableCarriesThree() throws {
        let (_, endsAt) = Self.cycle()
        for place in 1...8 {
            #expect(endsAt[place] == (place + 4 - 1) % 8 + 1,
                    "book C moves the thread at place \(place) to \(endsAt[place] ?? 0)")
        }

        let stand = BraidMethodCatalog.stand8
        let recipe = BraidMethodCatalog.yatsuKongoZ8Recipe
        let worked = try #require(recipe.worked(on: stand))
        let derivation = try #require(BraidDerivation.derive(
            stand: stand, method: worked.method, crossSection: worked.section
        ))
        for course in derivation.courses {
            let from = course.slots[0], to = course.slots[1]
            #expect((to - from + 8) % 8 == 3, "the table moves slot \(from) to \(to)")
            // And that is not what book C's figure does.
            #expect((to - from + 8) % 8 != 4)
        }
    }

    /// **What the figure settles about the order inside a printed pair: nothing.**
    /// Book A prints two threads to a step and does not say which goes first
    /// (Task 008, Task 031's test 6). Book C's lines also carry two moves, but
    /// the two belong to *different* pairs of the disk, so their printed order
    /// is not the order inside a pair. The question stays open, and the drawing
    /// still does not depend on it.
    @Test func theOrderInsideAPrintedPairIsStillOpen() throws {
        let lines = stride(from: 0, to: Self.printedMoves.count, by: 2).map {
            [Self.printedMoves[$0], Self.printedMoves[$0 + 1]]
        }
        for line in lines {
            // The two moves of a line start sixteen notches apart: opposite
            // pairs, never the two threads of one pair.
            #expect(abs(line[0].0 - line[1].0) == 16, "\(line)")
        }
    }
}
