import Foundation

/// The move tables this app ships, written as data.
///
/// **These are inputs to the derivation, not part of it.** Nothing in
/// `Domain/Braiding/` knows any of these names; adding a braid means adding an
/// entry here. The tables themselves are the ones checked against book A, book B
/// and book C — they are transcribed from `MaruGenjiSimulation` and
/// `HiraGenjiSimulation` move for move, with the thread numbers dropped because a
/// move names places and the state says which thread is at them.
enum BraidMethodCatalog {
    static let stand16 = BraidStands.round16

    /// Maru-genji on the sixteen-position round stand.
    ///
    /// Four steps and a closing. Every thread travels, so nothing runs along the
    /// braid and the cross-section stays the stand's own ring — a tube.
    ///
    /// **The order inside a step is the order book A names the two threads in**,
    /// and book A names them by which hand takes them: steps 1 and 2 as "the
    /// left-hand end with the left hand, the right-hand end with the right"
    /// (p94), steps 3 and 4 as "the far one with the right hand, the near one
    /// with the left". Book B's diagrams (p73) put the same 左L and 右R on the
    /// same threads. **Neither book says which of the two is laid down first**,
    /// because both are carried at once, one in each hand. Book C works the braid
    /// on a thirty-two notch disk (Fig.32) and does give a strict sequence, but a
    /// disk holds one thread to a notch, so its order is partly the tool's and not
    /// the braid's.
    ///
    /// **It makes no difference.** The two threads of a step are carried to
    /// opposite sides of the braid, or one inside the other's span, so they never
    /// pass each other; nor do any two of the closing's shifts. See
    /// `BraidDerivation.passingsWithinOneInstant`, which is empty here.
    static let maruGenji16 = BraidMethod(
        id: "maru-genji-16",
        standID: stand16.id,
        steps: [
            step("southToNorth", [10, 7], [16, 1]),
            step("northToSouth", [15, 2], [9, 8]),
            step("eastToWest", [3, 6], [13, 12]),
            step("westToEast", [14, 11], [4, 5]),
        ],
        closing: step(
            "closing",
            [16, 1, 4, 5, 9, 8, 13, 12],
            [15, 2, 3, 6, 10, 7, 14, 11]
        )
    )

    /// Hira-genji on the same stand.
    ///
    /// Six steps and a closing. The east and west threads are carried from one
    /// side of the braid to the other; the north and south threads stay where they
    /// are across the width and only turn over, which is what makes the braid flat.
    static let hiraGenji16 = BraidMethod(
        id: "hira-genji-16",
        standID: stand16.id,
        steps: [
            step("eastOuterToWestCenter", [3, 6], [13, 12]),
            step("westOuterToEastCenter", [14, 11], [4, 5]),
            step("southInnerToNorthCenter", [9, 8], [16, 1]),
            step("northInnerToSouthCenter", [16, 1], [9, 8]),
            step("southOuterToNorthOuter", [10, 7], [15, 2]),
            step("northOuterToSouthOuter", [15, 2], [10, 7]),
        ],
        closing: step("closing", [4, 5, 13, 12], [3, 6, 14, 11])
    )

    /// The order the threads come in round the hira-genji braid.
    ///
    /// **Read off book A p96, not derived.** The braid there is worked with the
    /// north and south groups in four colours and the east and west groups all in
    /// one, and the finished braid photographed at the head of the page reads,
    /// across its width: salmon, mauve, mauve, vermilion, black, salmon — six
    /// bands of one thread. That fixes the order, and in particular puts board
    /// position 1 outboard of position 2, the other way round from the stand's own
    /// ring.
    ///
    /// **Only the order is declared.** Where the braid turns back on itself, which
    /// slots are its edges, which face is which and how wide the faces are all come
    /// out of `BraidFold`, from this order and the courses.
    ///
    /// The first slot names the front, which is the one naming choice: it says the
    /// north side of the stand is the front of the braid.
    static let hiraGenji16CrossSection = BraidCrossSection(
        order: [14, 16, 15, 2, 1, 3, 4, 5, 6, 8, 7, 10, 9, 11, 12, 13],
        source: .reference("book A p96")
    )

    /// The order the threads come in round the maru-genji braid.
    ///
    /// **The stand's own rim order, used as the working answer.** Every thread
    /// travels, so no thread pairs the slots through a thickness and there is no
    /// fold to find; a tube is what the derivation returns and the ring is all
    /// there is to say.
    ///
    /// It is not settled. Task 004's transcribed sixty-four-cell table agrees with
    /// this cell for cell, but puts the eight columns round the braid in an order
    /// no unrolling of a tube can produce — its four face blocks run one way round
    /// and the two columns inside each block run the other. The three colourings
    /// Task 004 checked against real braids are all unchanged by the difference,
    /// so the photographs never tested it. See `docs/architecture.md`.
    static let maruGenji16CrossSection = BraidCrossSection(
        order: stand16.positionIDs,
        source: .standRim,
        unsettled: "the order of the columns round the braid disagrees with Task 004's "
            + "transcribed table; awaiting the author's colouring experiment"
    )

    private static func step(_ name: String, _ from: [Int], _ to: [Int]) -> BraidStep {
        BraidStep(name: name, moves: zip(from, to).map(BraidMove.init(from:to:)))
    }
}
