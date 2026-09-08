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

    /// Book C's Fig.20 and Fig.32 number the same disk the same way: sixteen of its
    /// thirty-two notches hold a thread at rest. Read off Fig.20's starting diagram
    /// in Task 005H, and Fig.32 numbers identically.
    static let diskRestingNotches: [Int: Int] = [
        1: 15, 2: 16, 5: 1, 6: 2, 9: 3, 10: 4, 13: 5, 14: 6,
        17: 7, 18: 8, 21: 9, 22: 10, 25: 11, 26: 12, 29: 13, 30: 14,
    ]

    private static func disk(_ source: String, _ moves: [(Int, Int)]) -> BraidDiskNotation {
        BraidDiskNotation(
            source: source,
            notchCount: 32,
            standPositionByRestingNotch: diskRestingNotches,
            moves: moves.map(BraidMove.init(from:to:)),
            threadsPerStep: 2
        )
    }

    /// Maru-genji as book C prints it: Fig.32, twenty-four numbered moves.
    static let maruGenjiDisk = disk("book C Fig.32", [
        (17, 4), (22, 3), (6, 19), (1, 20),
        (9, 28), (14, 27), (30, 11), (25, 12),
        (2, 1), (3, 2), (5, 6), (4, 5),
        (21, 22), (20, 21), (18, 17), (19, 18),
        (29, 30), (28, 29), (26, 25), (27, 26),
        (10, 9), (11, 10), (13, 14), (12, 13),
    ])

    /// Hira-genji as book C prints it: Fig.20.
    static let hiraGenjiDisk = disk("book C Fig.20", [
        (9, 28), (14, 27), (30, 11), (25, 12),
        (18, 4), (21, 3), (5, 18), (2, 21),
        (17, 5), (22, 2), (6, 17), (1, 22),
        (29, 30), (28, 29), (26, 25), (27, 26),
        (10, 9), (11, 10), (13, 14), (12, 13),
        (2, 1), (3, 2), (5, 6), (4, 5),
    ])

    /// Maru-genji on the sixteen-position round stand, generated from book C.
    ///
    /// Four steps and a closing. Every thread travels, so nothing runs along the
    /// braid and the cross-section stays the stand's own ring — a tube.
    ///
    /// **The step names are book A's**, which prints the same four steps as "take
    /// the outer threads of one face to the middle of the opposite one". They
    /// document the table; the derivation never reads them. Book A also names the
    /// two threads of a step in the other order from book C for some steps, which
    /// changes nothing: the two are never carried past each other
    /// (`BraidDerivation.passingsWithinOneInstant`).
    static let maruGenji16: BraidMethod = {
        guard let method = maruGenjiDisk.method(
            id: "maru-genji-16",
            standID: stand16.id,
            stepNames: ["southToNorth", "northToSouth", "eastToWest", "westToEast"]
        ) else {
            preconditionFailure("book C Fig.32 does not run as a cycle of the sixteen-place stand")
        }
        return method
    }()

    /// Hira-genji on the same stand, generated from book C.
    ///
    /// Six steps and a closing. The east and west threads are carried from one side
    /// of the braid to the other; the north and south threads stay where they are
    /// across the width and only turn over, which is what makes the braid flat.
    static let hiraGenji16: BraidMethod = {
        guard let method = hiraGenjiDisk.method(
            id: "hira-genji-16",
            standID: stand16.id,
            stepNames: [
                "eastOuterToWestCenter", "westOuterToEastCenter",
                "southInnerToNorthCenter", "northInnerToSouthCenter",
                "southOuterToNorthOuter", "northOuterToSouthOuter",
            ]
        ) else {
            preconditionFailure("book C Fig.20 does not run as a cycle of the sixteen-place stand")
        }
        return method
    }()

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

    // MARK: - Recipes

    /// The measured values for hira-genji. **All four sources are references.**
    ///
    /// The pitch is kept here as the measurement it is; what the stacking model
    /// works out for itself (0.375) is a `.derived` value on `BraidStacking` and
    /// the two are held side by side rather than one replacing the other.
    static let hiraGenji16Shape = BraidShapeValues(
        widthOverThickness: .observed(
            3.3359, from: "a perimeter of sixteen threads and a thickness of two"
        ),
        pitchPerBraidWidth: .observed(0.3665, from: "book A p96 / book B p23"),
        crestHeight: .observed(0.45, from: "book A p96, the silhouette with the physics")
    )

    /// The measured values for maru-genji.
    ///
    /// **The crest height and the pattern's aspect ratio are held only as a
    /// product** — Task 005J could separate neither from the photographs — so each
    /// carries that on its face rather than in a comment.
    static let maruGenji16Shape = BraidShapeValues(
        crestHeight: .observed(
            0.12, from: "Task 005J",
            unsettled: "only the product with the pattern's aspect ratio 0.65 is held "
                + "by the photographs; neither value is checked on its own"
        ),
        chevronsPerBraidWidth: .observed(
            2.0, spread: 1.8...2.15, from: "photographs, Task 005I"
        )
    )

    /// A colouring written the way the books write one: by the stand's four
    /// groups, each listed outermost first, which is how the sources list them.
    /// Positions the source leaves out come out in the catalogue's default.
    static func colouring(
        on stand: BraidStand, _ byGroup: [String: [String]]
    ) -> [ThreadAssignment] {
        var colours = [Int: String]()
        for group in stand.groups {
            guard let names = byGroup[group.name] else { continue }
            for (position, name) in zip(group.positions, names) { colours[position] = name }
        }
        return stand.positionIDs.map { position in
            ThreadAssignment(
                position: position,
                colorID: colours[position].map(ThreadColorID.init(rawValue:))
                    ?? ThreadColorCatalog.defaultColor.id
            )
        }
    }

    /// Book A p94's own colouring for maru-genji, whose finished braid is
    /// photographed at the head of the same page.
    static let maruGenji16Colouring = colouring(on: stand16, [
        "north": ["pink", "orange", "orange", "pink"],
        "east": Array(repeating: "black", count: 4),
        "south": ["natural", "red", "red", "natural"],
        "west": Array(repeating: "black", count: 4),
    ])

    /// Book A p96's starting diagram for hira-genji, photographed at the head of
    /// the same page.
    static let hiraGenji16Colouring = colouring(on: stand16, [
        "north": ["purple", "purple", "black", "orange"],
        "east": Array(repeating: "pink", count: 4),
        "south": ["purple", "purple", "black", "orange"],
        "west": Array(repeating: "pink", count: 4),
    ])

    static let maruGenji16Recipe = BraidRecipe(
        id: "maru-genji-16",
        name: "丸源氏組",
        notation: maruGenjiDisk,
        colouring: maruGenji16Colouring,
        shape: maruGenji16Shape
    )

    static let hiraGenji16Recipe = BraidRecipe(
        id: "hira-genji-16",
        name: "平源氏組",
        notation: hiraGenjiDisk,
        colouring: hiraGenji16Colouring,
        shape: hiraGenji16Shape,
        orderRoundTheBraid: hiraGenji16CrossSection
    )

    static let recipes: [BraidRecipe] = [maruGenji16Recipe, hiraGenji16Recipe]
}
