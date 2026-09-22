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

    /// **A printed step is one instant here** (the author, 2026-09-11): the
    /// eight-bobbin braids have no book C figure, so nothing says which of a
    /// printed pair goes first, and splitting the pair would be a choice rather
    /// than a reading.
    private static func diskOfEight(_ source: String, _ moves: [(Int, Int)]) -> BraidDiskNotation {
        BraidDiskNotation(
            source: source,
            notchCount: 32,
            standPositionByRestingNotch: diskRestingNotchesForEight,
            moves: moves.map(BraidMove.init(from:to:)),
            threadsPerStep: 2,
            stepReading: .oneStepAnInstant
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

    /// **Yatsu-kongo S, transcribed from the disk book's p.37 (8S-スパイラル)**
    /// (Task 053; the author chose it over book A p.54's reading, 2026-09-22).
    ///
    /// The book prints one dan (段) — four figures of one move each — from slits
    /// 4・5, 12・13, 20・21, 28・29, and says the slit numbers then stand one notch
    /// further anticlockwise: 「スリット番号は【組みはじめ】から反時計回りに一つずれ
    /// ます」. **A dan moves four threads**, the anticlockwise one of each pair; the
    /// next dan moves the other four. So one cycle of this repository — every
    /// thread braided once — is two dan.
    ///
    /// **The book's drifting slit numbers are the disk's, not the braid's.** What
    /// the braid keeps is the order of the eight threads round it: a thread leaves
    /// its pair and joins the pair opposite, beside the one that stays, in the place
    /// that pair's other thread has just left. Read in that order on the stand's
    /// eight evenly spaced places, **every thread goes two places back each cycle**
    /// (`YatsuKongoTests`), and the threads that stay do not move. Task 035's "+4"
    /// for book C is the same braid counted with the pairs drifting.
    ///
    /// **Not book A p.54's table**, which the app shipped until Task 053: that was
    /// read off book A's pictures and carried every thread three places. Book C
    /// Fig.129 and this book agree with each other and not with it
    /// (`YatsuKongoAgainstBookCTests`).
    static let yatsuKongoSDisk: BraidDiskNotation = {
        guard let disk = BookDiskKongo.cycle(
            source: "the disk book p.37 (8S-スパイラル), one printed dan and its drift",
            // The slits of the starting diagram in the order of the stand's
            // places 1-8: 12・13 is the top pair (the upright pair, pink in the
            // book), and `round8` puts its places 8 and 1 at the top.
            placeOneOnward: [13, 20, 21, 28, 29, 4, 5, 12],
            printedDan: [(20, 6), (4, 22), (12, 30), (28, 14)],
            driftPerDan: 1
        ) else {
            preconditionFailure("the disk book's 8S table does not run as a cycle of the eight-place stand")
        }
        return disk
    }()

    /// **Yatsu-kongo Z, transcribed from the disk book's p.36 (8Z-スパイラル)**,
    /// not reflected from S (Task 053). The same starting slits; one dan moves the
    /// clockwise thread of each pair, and the slits then stand one notch further
    /// clockwise. **That Z is S's mirror is now a check** (`YatsuKongoTests`),
    /// where until Task 053 it was how Z was made — there is a figure for each.
    static let yatsuKongoZDisk: BraidDiskNotation = {
        guard let disk = BookDiskKongo.cycle(
            source: "the disk book p.36 (8Z-スパイラル), one printed dan and its drift",
            placeOneOnward: [13, 20, 21, 28, 29, 4, 5, 12],
            printedDan: [(5, 19), (21, 3), (29, 11), (13, 27)],
            driftPerDan: -1
        ) else {
            preconditionFailure("the disk book's 8Z table does not run as a cycle of the eight-place stand")
        }
        return disk
    }()

    /// Book A p.54's picture read into the disk notation — **the table the app
    /// shipped until Task 053**, kept so the difference stays visible
    /// (`YatsuKongoAgainstBookCTests`). Four printed steps of two threads each,
    /// every thread ending three places anticlockwise, the landing places settled
    /// by the author's ruling of 2026-09-10 (a carried thread comes in on the
    /// outside of the group it joins; the cycle ends with tidying moves).
    static let yatsuKongoBookAP54Disk = diskOfEight(
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

    /// Book A prints four steps and does not name them; these say which pair each
    /// one works. **The derivation never reads them.** Kept for book A p.54's
    /// table (`yatsuKongoBookAP54Disk`).
    static let yatsuKongoStepNames = [
        "uprightPairOuter", "flatPairOuter", "uprightPairInner", "flatPairInner",
    ]

    /// The disk book prints a dan as four numbered figures of one move each; a
    /// cycle is two dan. **The derivation never reads them.**
    static let yatsuKongoDiskStepNames = (1...2).flatMap { dan in
        (1...4).map { figure in "dan\(dan)Figure\(figure)" }
    }

    static let yatsuKongoS8: BraidMethod = {
        guard let method = yatsuKongoSDisk.method(
            id: "yatsu-kongo-s-8", standID: stand8.id, stepNames: yatsuKongoDiskStepNames
        ) else {
            preconditionFailure("the yatsu-kongo S table does not run as a cycle of the eight-place stand")
        }
        return method
    }()

    static let yatsuKongoZ8: BraidMethod = {
        guard let method = yatsuKongoZDisk.method(
            id: "yatsu-kongo-z-8", standID: stand8.id, stepNames: yatsuKongoDiskStepNames
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
        // **Not carried into the construction.** Task 005J's 0.12 is a
        // fraction of the tube's nominal radius, not of a thread's diameter, so
        // it cannot be compared with a crest measured in diameters. The round
        // braid keeps the derived d/2, and that is unverified against a
        // photograph. The surface drawing no longer uses it: since Task 052 it
        // draws a crest chosen by eye (`RoundTube16SurfaceMesh.crestHeightRatio`).
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
    /// **What the note says since Task 053**: the tables come from a disk book
    /// that is not the source of record (book C). It prints one move a figure, so
    /// the order of the moves is its own; book C Fig.129 agrees with it for Z
    /// (`YatsuKongoAgainstBookCTests`), and nothing drawn depends on the order
    /// inside a dan.
    static let yatsuKongo8CrossSection = BraidCrossSection(
        order: stand8.positionIDs,
        source: .standRim,
        unsettled: "the tables are the disk book's p.36-37, photographed by the author; "
            + "that book is not the source of record, which is book C. Book C "
            + "Fig.129 prints the same Z. Book A p.54's picture, read before, carries "
            + "three places a cycle where both books carry two"
    )

    /// Book A p.54's own colouring for yatsu-kongo S: **the upright pair in
    /// yellow and the flat pair in orange.**
    ///
    /// Read off the page's "糸の配色と配置" enlarged (the author, 2026-09-10):
    /// thread 105 yellow stands in the north and south groups, thread 108 orange
    /// in the east and west. Two colours, four threads each.
    ///
    /// The reference simulator's checkerboard and diagonal, which stood here while
    /// the page was unread, are **kept in the tests** — they are what holds the
    /// move table up, and a colouring is a question about where the recipe comes
    /// from, not about whether the table is right.
    static let yatsuKongoS8Colouring = colouring(on: stand8, [
        "north": ["yellow", "yellow"],   // 8, 1
        "east": ["orange", "orange"],    // 2, 3
        "south": ["yellow", "yellow"],   // 5, 4
        "west": ["orange", "orange"],    // 7, 6
    ])

    /// Book A p.55's colouring **a** for yatsu-kongo Z, which is printed the same
    /// way round as p.54's: yellow upright, orange flat.
    ///
    /// **The two braids being coloured alike is the point** (the author,
    /// 2026-09-10). Given the same threads in the same places, the only thing left
    /// between S and Z is which way the spiral leans, and that is what putting the
    /// two side by side is for.
    ///
    /// Page 55 prints five, a to e; a is the one taken. The others are b — white
    /// north, orange south, yellow east and west — c in 114 and 112, d in green,
    /// white and rose, and e mixing four.
    static let yatsuKongoZ8Colouring = yatsuKongoS8Colouring

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

    /// **Yatsu-kongo gaeshi (八つ金剛返し組, 8S&Z-スパイラル), from the disk
    /// book's p.38** (Task 053): six dan of S, a hand-over, six dan of Z and a
    /// hand-over back — 「[8S-スパイラル]を6段組み、次に[8Z-スパイラル]を6段組んで
    /// 1工程となります」 (p.39). After the hand-over back every thread is on the
    /// slit it began at (p.39: 1工程終了 = 組みはじめ).
    ///
    /// **Its dan are p.37's and p.36's**, the disk turned (S three notches on,
    /// Z two). The two hand-overs are printed as they are: [4] 「隣り合う糸の右側を
    /// 動かします」 8→6, 16→14, 24→22, 32→30, and [8] 「左側を動かします」 32→2,
    /// 8→10, 16→18, 24→26. **Read in the order of the threads round the braid**
    /// (`BookDiskKongo`), each hand-over moves the four threads the dan before
    /// it moved, two places the same way again — a dan's worth, which is how it
    /// is drawn (Task 053).
    ///
    /// **Eight tables worked in turn**: three cycles of S (two dan each), the
    /// hand-over, three cycles of Z, the hand-over back.
    static let yatsuKongoGaeshiRounds: [BraidDiskNotation] = {
        let s = [(17, 3), (1, 19), (25, 11), (9, 27)]          // p.38 [1], [2]
        let z = [(7, 21), (23, 5), (31, 13), (15, 29)]         // p.38 [5], [6]
        let over = [(8, 6), (16, 14), (24, 22), (32, 30)]      // p.38 [4]
        let back = [(32, 2), (8, 10), (16, 18), (24, 26)]      // p.38 [8]
        func sDan(_ k: Int) -> [(Int, Int)] { BookDiskKongo.dan(s, driftPerDan: 1, times: k) }
        func zDan(_ k: Int) -> [(Int, Int)] { BookDiskKongo.dan(z, driftPerDan: -1, times: k) }
        guard let rounds = BookDiskKongo.rounds(
            source: "the disk book p.38 (八つ金剛返し組)",
            // 1・2 is the top pair (pink, upright), `round8`'s places 8 and 1.
            placeOneOnward: [2, 9, 10, 17, 18, 25, 26, 1],
            rounds: [
                [sDan(0), sDan(1)], [sDan(2), sDan(3)], [sDan(4), sDan(5)],
                [over],
                [zDan(0), zDan(1)], [zDan(2), zDan(3)], [zDan(4), zDan(5)],
                [back],
            ]
        ) else {
            preconditionFailure("the disk book's 返し組 does not run on the eight-place stand")
        }
        return rounds
    }()

    /// **The book's own colouring for 返し組** (p.38 組みはじめ): the upright
    /// pairs pink, the flat pairs orange — the same arrangement as book A p.54's
    /// yellow and orange.
    static let yatsuKongoGaeshi8Colouring = colouring(on: stand8, [
        "north": ["pink", "pink"],       // 8, 1
        "east": ["orange", "orange"],    // 2, 3
        "south": ["pink", "pink"],       // 5, 4
        "west": ["orange", "orange"],    // 7, 6
    ])

    static let yatsuKongoGaeshi8Recipe = BraidRecipe(
        id: "yatsu-kongo-gaeshi-8",
        name: "八つ金剛返し組",
        rounds: yatsuKongoGaeshiRounds,
        colouring: yatsuKongoGaeshi8Colouring,
        shape: BraidShapeValues(),
        orderRoundTheBraid: yatsuKongo8CrossSection
    )

    static let recipes: [BraidRecipe] = [
        maruGenji16Recipe, hiraGenji16Recipe, yatsuKongoS8Recipe, yatsuKongoZ8Recipe,
        yatsuKongoGaeshi8Recipe,
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

/// **The disk book's eight-thread tables, read into this repository's disk
/// notation** (Task 053).
///
/// The book prints one dan (段) and says the slit numbers then stand one notch
/// further round; its later dan are the printed one moved round by that drift.
/// This works the book's own disk notch by notch, dan by dan, until every
/// thread has been braided once — one cycle — and writes the same moves on the
/// stand's eight evenly spaced resting notches (`diskRestingNotchesForEight`),
/// **keeping the order of the threads round the braid**, which is what the
/// braid is; the book's notch numbers drift and the braid does not turn with
/// them.
///
/// **How a move is written**: from the thread's resting notch to the notch
/// just before the resting notch of the place it takes in the new order, and
/// after the dan, one notch on into that place — the way the book A table
/// always wrote a landing and its tidy.
///
/// `nil` — and so a failed table, not a guess — when the threads that stay put
/// in a dan would not keep their places in the new order, when a dan lands on a
/// taken notch, or when the cycle does not braid every thread exactly once.
enum BookDiskKongo {
    static let notchCount = 32

    /// One cycle of a spiral: the printed dan, and as many more as it takes to
    /// braid every thread once, each moved round by the drift.
    static func cycle(
        source: String,
        placeOneOnward: [Int],
        printedDan: [(Int, Int)],
        driftPerDan: Int
    ) -> BraidDiskNotation? {
        // Two dan braid every thread once: each moves one thread of every pair.
        let dans = (0..<2).map { dan(printedDan, driftPerDan: driftPerDan, times: $0) }
        return rounds(source: source, placeOneOnward: placeOneOnward, rounds: [dans])?.first
    }

    /// A printed dan moved round `times` dan's worth of drift.
    static func dan(_ printed: [(Int, Int)], driftPerDan: Int, times: Int) -> [(Int, Int)] {
        printed.map { (wrapped($0.0 + driftPerDan * times), wrapped($0.1 + driftPerDan * times)) }
    }

    /// **Several cycles of the stand from the book's steps worked in order**
    /// (Task 053): each round is the steps — a dan, or a step the book prints
    /// on its own, like 返し組's hand-over — that make one cycle of the stand,
    /// every thread braided at most once. The book's disk is worked through the
    /// whole list, notch by notch; each round comes out as a table of its own.
    static func rounds(
        source: String,
        placeOneOnward: [Int],
        rounds: [[[(Int, Int)]]]
    ) -> [BraidDiskNotation]? {
        let places = placeOneOnward.count
        guard places == 8, Set(placeOneOnward).count == places else { return nil }
        func resting(_ place: Int) -> Int { 4 * place - 3 }

        // The book's disk: notch -> thread, the thread named by the stand place
        // it starts at.
        var onDisk = [Int: Int]()
        for (index, notch) in placeOneOnward.enumerated() { onDisk[notch] = index + 1 }
        var placeOf = [Int: Int]()                  // thread -> stand place now
        for thread in 1...places { placeOf[thread] = thread }

        var tables = [BraidDiskNotation]()
        for (roundIndex, steps) in rounds.enumerated() {
            var moves = [BraidMove]()
            var braided = [Int]()
            for step in steps {
                var movers = [Int]()
                for (from, to) in step {
                    guard let thread = onDisk[from], onDisk[to] == nil else { return nil }
                    onDisk[from] = nil
                    onDisk[to] = thread
                    movers.append(thread)
                }
                // The new order round the braid, clockwise from notch 1.
                let order = onDisk.keys.sorted().compactMap { onDisk[$0] }
                // The threads that stayed keep their places: that fixes where the
                // order starts. One offset has to fit all of them.
                let stayed = order.indices.filter { !movers.contains(order[$0]) }
                guard let first = stayed.first, let anchor = placeOf[order[first]] else { return nil }
                let offset = anchor - 1 - first
                var newPlace = [Int: Int]()
                for (index, thread) in order.enumerated() {
                    newPlace[thread] = ((index + offset) % places + places) % places + 1
                }
                guard stayed.allSatisfy({ newPlace[order[$0]] == placeOf[order[$0]] }) else { return nil }
                // Written on the stand: each mover lands just short of its new
                // place, then is tidied on into it once the step is done.
                for thread in movers {
                    guard let from = placeOf[thread], let to = newPlace[thread] else { return nil }
                    moves.append(BraidMove(from: resting(from), to: wrapped(resting(to) - 1)))
                }
                for thread in movers {
                    guard let to = newPlace[thread] else { return nil }
                    moves.append(BraidMove(from: wrapped(resting(to) - 1), to: resting(to)))
                }
                placeOf = newPlace
                braided.append(contentsOf: movers)
            }
            guard Set(braided).count == braided.count else { return nil }
            tables.append(BraidDiskNotation(
                source: rounds.count == 1 ? source : "\(source), round \(roundIndex + 1)",
                notchCount: notchCount,
                standPositionByRestingNotch: BraidMethodCatalog.diskRestingNotchesForEight,
                moves: moves,
                threadsPerStep: 1,
                stepReading: .oneThreadAnInstant
            ))
        }
        return tables
    }

    private static func wrapped(_ notch: Int) -> Int {
        ((notch - 1) % notchCount + notchCount) % notchCount + 1
    }
}
