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
/// **Since Task 053 the app braids the disk book's tables**, which agree with
/// this figure (`bookCIsTheAppsZ`).
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

    /// **Book C's braid is the app's Z since Task 053.** Counted with the pairs
    /// drifting round the disk, as `cycle()` counts, book C carries a thread to
    /// the opposite pair, four places a cycle. Counted on the stand's places,
    /// which do not drift — the order of the threads round the braid — it is two,
    /// and so is the disk book's p.36, which the app now braids
    /// (`BraidMethodCatalog.yatsuKongoZDisk`). **The two books agree move for
    /// move** once each is read into the stand the same way: Fig.129's first two
    /// lines are one dan, its third line is the next dan's start one notch back,
    /// and the method they make is the app's Z with the places named from a
    /// different starting pair.
    ///
    /// **Book A p.54's table, which the app braided until Task 053, carried
    /// three**, and that is still not what book C does.
    @Test func bookCIsTheAppsZ() throws {
        let (_, endsAt) = Self.cycle()
        for place in 1...8 {
            #expect(endsAt[place] == (place + 4 - 1) % 8 + 1,
                    "book C moves the thread at place \(place) to \(endsAt[place] ?? 0)")
        }

        // Fig.129 read into the stand: 1・2 at places 1 and 2 (Task 055).
        let bookC = try #require(BookDiskKongo.cycle(
            source: "book C Fig.129",
            placeOneOnward: [1, 2, 9, 10, 17, 18, 25, 26],
            printedDan: Array(Self.printedMoves.prefix(4)),
            driftPerDan: -1
        ))
        let stand = BraidMethodCatalog.stand8
        let fig129 = try #require(bookC.method(
            id: "yatsu-kongo-z-8-book-c", standID: stand.id,
            stepNames: BraidMethodCatalog.yatsuKongoDiskStepNames
        ))
        // The third printed line is the next dan, one notch back.
        let nextDan = Self.printedMoves.prefix(2).map { ((($0.0 - 2) % 32 + 32) % 32 + 1, (($0.1 - 2) % 32 + 32) % 32 + 1) }
        #expect(Set(nextDan.map { "\($0.0)-\($0.1)" }) == Set(Self.printedMoves.suffix(2).map { "\($0.0)-\($0.1)" }))

        let app = BraidMethodCatalog.yatsuKongoZ8
        #expect(fig129.steps.count == app.steps.count)
        // The same method, with the places named from another pair: one turn of
        // the names carries every dan of the one onto the other. Inside a dan the
        // two books work opposite pairs in different orders, which does not
        // reach the drawing (`RoundTube8SurfaceTests
        // .swappingTheOrderInsideADanDoesNotMoveTheMesh`).
        func dan(_ steps: [BraidStep], _ index: Int, shift: Int) -> Set<BraidMove> {
            Set(steps[(4 * index)..<(4 * index + 4)].flatMap(\.moves).map {
                BraidMove(from: ($0.from - 1 + shift) % 8 + 1, to: ($0.to - 1 + shift) % 8 + 1)
            })
        }
        let turn = (0..<8).first { shift in
            (0..<2).allSatisfy { dan(fig129.steps, $0, shift: shift) == dan(app.steps, $0, shift: 0) }
        }
        #expect(turn != nil, "book C Fig.129 is not the app's Z under any naming of the places")
        for step in app.steps { for move in step.moves { #expect((move.to - move.from + 8) % 8 == 2) } }

        let bookA = try #require(BraidMethodCatalog.yatsuKongoBookAP54Disk.reflected(
            about: 30, source: "book A p.55, reflected"
        )?.method(id: "yatsu-kongo-z-8-book-a", standID: stand.id,
                  stepNames: BraidMethodCatalog.yatsuKongoStepNames))
        for step in bookA.steps { for move in step.moves { #expect((move.to - move.from + 8) % 8 == 3) } }
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
