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
    static let stand8 = BraidStands.round8

    /// The stands this app ships.
    static let stands: [BraidStand] = [stand16, stand8]

    /// The stand a recipe is worked on.
    ///
    /// **Data, not a branch on the braid.** A table says how many places rest on
    /// the disk, and that is which stand it is; the screens ask this rather than
    /// naming a stand of their own. `nil` for a table no shipped stand fits.
    static func stand(for recipe: BraidRecipe) -> BraidStand? {
        stands.first {
            $0.positionCount == recipe.notation.standPositionByRestingNotch.count
        }
    }

    /// Book C's Fig.20 and Fig.32 number the same disk the same way: sixteen of its
    /// thirty-two notches hold a thread at rest. Read off Fig.20's starting diagram
    /// in Task 005H, and Fig.32 numbers identically.
    static let diskRestingNotches: [Int: Int] = [
        1: 15, 2: 16, 5: 1, 6: 2, 9: 3, 10: 4, 13: 5, 14: 6,
        17: 7, 18: 8, 21: 9, 22: 10, 25: 11, 26: 12, 29: 13, 30: 14,
    ]

    /// Eight threads on the same thirty-two notch disk rest four notches apart:
    /// position *p* at notch *4p - 3*, numbered from the mark the way `round8` is.
    ///
    /// **Not read off a printed figure.** Book C's figure for the eight-bobbin
    /// braids is not to hand, so this numbering is this repository's own, chosen so
    /// that a position's number and its notch run the same way round.
    static let diskRestingNotchesForEight: [Int: Int] = [
        1: 1, 5: 2, 9: 3, 13: 4, 17: 5, 21: 6, 25: 7, 29: 8,
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

    private static func diskOfEight(_ source: String, _ moves: [(Int, Int)]) -> BraidDiskNotation {
        BraidDiskNotation(
            source: source,
            notchCount: 32,
            standPositionByRestingNotch: diskRestingNotchesForEight,
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

    /// Yatsu-kongo S, written for the disk from book A p54.
    ///
    /// **This is not a copy of book C.** Book C's figure for this braid is not to
    /// hand (`docs/tasks/008-yatsu-kongo-8.md`). It is book A p54's picture — four
    /// printed steps of two threads each, the upright pair and the flat pair
    /// alternating, every thread ending three places anticlockwise of where it
    /// began — set down in this repository's disk notation, with the landing places
    /// settled by the author's ruling of 2026-09-10 (`docs/architecture.md`,
    /// 詰め直しの入り方): **a carried thread comes in on the outside of the group it
    /// joins, and the cycle ends with tidying moves that put it on its standard
    /// notch.**
    ///
    /// The first eight moves are the braiding, in book A's printed order: the
    /// upright pair (8 and 4), the flat pair (2 and 6), the upright pair again
    /// (1 and 5), the flat pair again (7 and 3). Each is eleven or thirteen notches;
    /// each of the eight tidies that follow is one notch, which is how
    /// `isRepositioning` tells the two apart.
    ///
    /// **Where a thread waits is free and does not reach the result.** What the
    /// table carries into the method is the order the threads were braided in and
    /// where each ends up; the parking notch between the two is only what makes the
    /// cycle run on a disk that holds one thread to a notch.
    static let yatsuKongoSDisk = diskOfEight(
        "book A p54, its picture set down in this repository's disk notation",
        [
            (29, 18), (13, 2),          // 8 -> 5, 4 -> 1
            (5, 26), (21, 10),          // 2 -> 7, 6 -> 3
            (1, 20), (17, 4),           // 1 -> 6, 5 -> 2
            (25, 12), (9, 28),          // 7 -> 4, 3 -> 8
            (18, 17), (2, 1), (26, 25), (10, 9),
            (20, 21), (4, 5), (12, 13), (28, 29),
        ]
    )

    /// Yatsu-kongo Z: **the S table reflected, never transcribed.**
    ///
    /// Book A p54 and p55 print the two as mirror images of each other, down to the
    /// hands in the speech bubbles — S takes the far thread with the left hand, Z
    /// with the right. So Z is made by reflecting S across the disk rather than
    /// written out again, and "Z is the mirror of S" is then something a test can
    /// check instead of something a transcription might quietly break.
    ///
    /// The axis is the line through the mark: notch *n* goes to notch *30 - n*,
    /// which carries position *p* to position *9 - p*. **Book A p55's picture is for
    /// checking this, not for producing it.**
    static let yatsuKongoZDisk: BraidDiskNotation = {
        guard let reflected = yatsuKongoSDisk.reflected(
            about: 30,
            source: "book A p55, made by reflecting the p54 table across the disk"
        ) else {
            preconditionFailure("the eight-place resting notches are not carried onto themselves")
        }
        return reflected
    }()

    /// Book A prints four steps and does not name them; these say which pair each
    /// one works. **The derivation never reads them.**
    static let yatsuKongoStepNames = [
        "uprightPairOuter", "flatPairOuter", "uprightPairInner", "flatPairInner",
    ]

    static let yatsuKongoS8: BraidMethod = {
        guard let method = yatsuKongoSDisk.method(
            id: "yatsu-kongo-s-8", standID: stand8.id, stepNames: yatsuKongoStepNames
        ) else {
            preconditionFailure("the yatsu-kongo S table does not run as a cycle of the eight-place stand")
        }
        return method
    }()

    static let yatsuKongoZ8: BraidMethod = {
        guard let method = yatsuKongoZDisk.method(
            id: "yatsu-kongo-z-8", standID: stand8.id, stepNames: yatsuKongoStepNames
        ) else {
            preconditionFailure("the yatsu-kongo Z table does not run as a cycle of the eight-place stand")
        }
        return method
    }()

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
        // **In diameters.** That generator's own working says the flat braid's
        // half-thickness is one thread's diameter -- sixteen threads round the
        // section and two through it -- so its 0.45 of a half-thickness is 0.45 d.
        crestHeight: .observed(
            0.45, basis: .threadDiameters,
            from: "book A p96, the silhouette with the physics (a fraction of "
                + "the half-thickness, which is one thread's diameter)"
        )
    )

    /// The measured values for maru-genji.
    ///
    /// **The crest height and the pattern's aspect ratio are held only as a
    /// product** — Task 005J could separate neither from the photographs — so each
    /// carries that on its face rather than in a comment.
    static let maruGenji16Shape = BraidShapeValues(
        // **Not carried into the construction.** The generator's 0.12 is a
        // fraction of the tube's nominal radius, not of a thread's diameter
        // (`RoundTube16SurfaceMesh.crestHeightRatio`), so it cannot be
        // compared with a crest measured in diameters. The round braid keeps the
        // derived d/2, and that is unverified against a photograph.
        crestHeight: .observed(
            0.12, basis: .fractionOf("the tube's nominal radius"),
            from: "Task 005J, as a fraction of the nominal radius",
            unsettled: "not in thread diameters, so it is not carried into the "
                + "construction; and only the product with the pattern's aspect "
                + "ratio 0.65 is held by the photographs"
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
        shape: maruGenji16Shape,
        // **The same order the stand's rim gives** -- a tube declares nothing about
        // its order, and this does not either. What it carries is the note: the
        // transcribed table's columns run in an order no unrolling of a tube can
        // produce, and that is unsettled. Declared here so the note reaches the
        // figure and can be shown where the figure is read.
        orderRoundTheBraid: maruGenji16CrossSection
    )

    static let hiraGenji16Recipe = BraidRecipe(
        id: "hira-genji-16",
        name: "平源氏組",
        notation: hiraGenjiDisk,
        colouring: hiraGenji16Colouring,
        shape: hiraGenji16Shape,
        orderRoundTheBraid: hiraGenji16CrossSection
    )

    /// The order the threads come in round a yatsu-kongo braid.
    ///
    /// **The stand's own rim order** — every thread travels, nothing pairs the
    /// slots through a thickness, and a tube is what the derivation returns. It is
    /// declared here only to carry the note.
    ///
    /// What the note says is the one thing book A p54–55 does not: **which of a
    /// pair goes first.** The pictures give the arrows and the hands, not the order
    /// inside a printed step. It changes nothing that is drawn today — the figure
    /// reads the occupancy history, and the eight-thread family has no drawer — so
    /// it is carried rather than guessed at.
    static let yatsuKongo8CrossSection = BraidCrossSection(
        order: stand8.positionIDs,
        source: .standRim,
        unsettled: "which thread of a pair is carried first is not settled; book A "
            + "p54-55 draw the arrows and the hands but not the order inside a "
            + "printed step, and book C's figure for this braid is not to hand"
    )

    /// The colouring shipped with yatsu-kongo S: the checkerboard.
    ///
    /// **Not book A p54's.** Book A's own "糸の配色と配置" for this braid could not be
    /// read — no transcription of that page is in this repository — so this is the
    /// checkerboard fixture recorded in `docs/tasks/008-yatsu-kongo-8.md`, position
    /// by position, mapped onto the nearest colours the catalogue has:
    /// `#ffffff` white, `#4a649f` blue, `#de6473` pink. **The author's ruling is
    /// wanted here**; the task lists book A p54 as the source it should come from.
    static let yatsuKongoS8Colouring = colouring(on: stand8, [
        "north": ["pink", "white"],      // 8, 1
        "east": ["blue", "white"],       // 2, 3
        "south": ["white", "pink"],      // 5, 4
        "west": ["white", "blue"],       // 7, 6
    ])

    /// The colouring shipped with yatsu-kongo Z: the diagonal.
    ///
    /// **Not book A p55's b.** The same gap as for S — book A's five colourings
    /// a–e could not be read — so this is the diagonal fixture recorded in
    /// `docs/tasks/008-yatsu-kongo-8.md`: `#52884e` green, `#a5cc6f` the nearest
    /// catalogue colour to a yellow-green, which is yellow, `#ffffff` white.
    /// **Shipped on Z rather than on S so that the two braids show the two
    /// reference patterns between them**, which is what the task asks to be able to
    /// look at. The author's ruling is wanted here too.
    static let yatsuKongoZ8Colouring = colouring(on: stand8, [
        "north": ["white", "green"],     // 8, 1
        "east": ["yellow", "white"],     // 2, 3
        "south": ["green", "white"],     // 5, 4
        "west": ["white", "yellow"],     // 7, 6
    ])

    /// Yatsu-kongo S and Z.
    ///
    /// **The measured values are empty, and that is what has been measured:
    /// nothing.** The eight-thread family has no drawer, so no drawing wants a
    /// shape; taking numbers off the photograph on book A p.8 is for a later
    /// version. Nothing here is set by eye and called measured.
    static let yatsuKongoS8Recipe = BraidRecipe(
        id: "yatsu-kongo-s-8",
        name: "八つ金剛組S",
        notation: yatsuKongoSDisk,
        colouring: yatsuKongoS8Colouring,
        shape: BraidShapeValues(),
        orderRoundTheBraid: yatsuKongo8CrossSection
    )

    static let yatsuKongoZ8Recipe = BraidRecipe(
        id: "yatsu-kongo-z-8",
        name: "八つ金剛組Z",
        notation: yatsuKongoZDisk,
        colouring: yatsuKongoZ8Colouring,
        shape: BraidShapeValues(),
        orderRoundTheBraid: yatsuKongo8CrossSection
    )

    static let recipes: [BraidRecipe] = [
        maruGenji16Recipe, hiraGenji16Recipe, yatsuKongoS8Recipe, yatsuKongoZ8Recipe,
    ]

    /// The recipe a preset stands for.
    ///
    /// **A preset's own identifier is the recipe's**, which is how the screens and
    /// the drawing meet without either learning the other's list. `nil` for a
    /// preset with no recipe, which is a preset this app cannot yet braid.
    static func recipe(for presetID: BraidPresetID) -> BraidRecipe? {
        recipes.first { $0.id == presetID.rawValue }
    }
}
