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
    static let stand4 = BraidStands.round4

    /// The stands this app ships.
    static let stands: [BraidStand] = [stand16, stand8, stand4]

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

    /// Four threads on the same thirty-two notch disk rest eight notches apart:
    /// position *p* at notch *8p - 7* (Task 054).
    ///
    /// **Not read off a printed figure**, for the reason
    /// `diskRestingNotchesForEight` is not: book A is a book of the round stand
    /// (丸台) and draws no disk, and book C has no figure for this braid. So this
    /// numbering is this repository's own, chosen so that a position's number and
    /// its notch run the same way round.
    static let diskRestingNotchesForFour: [Int: Int] = [
        1: 1, 9: 2, 17: 3, 25: 4,
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
            // places 1-8, **a pair of the book to a pair of places, 1・2, 3・4,
            // 5・6, 7・8** (Task 055): 12・13 is places 1 and 2.
            placeOneOnward: BookDiskKongo.pairsAtPlaces([12, 13, 20, 21, 28, 29, 4, 5]),
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
            placeOneOnward: BookDiskKongo.pairsAtPlaces([12, 13, 20, 21, 28, 29, 4, 5]),
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
    /// in the east and west. Two colours, four threads each. **Laid pair by pair
    /// at the stand's places 1・2 and 5・6 yellow, 3・4 and 7・8 orange** since
    /// Task 055, where the disk book's pairs now stand (`BookDiskKongo
    /// .pairsAtPlaces`).
    ///
    /// The reference simulator's checkerboard and diagonal, which stood here while
    /// the page was unread, are **kept in the tests** — they are what holds the
    /// move table up, and a colouring is a question about where the recipe comes
    /// from, not about whether the table is right.
    static let yatsuKongoS8Colouring = byPlace(stand8, [
        "yellow", "yellow", "orange", "orange", "yellow", "yellow", "orange", "orange",
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
    /// 8→10, 16→18, 24→26. **Each lifts the four threads the dan before it has
    /// just laid**, and read in the order round the braid carries them two
    /// places further the same way.
    ///
    /// **A hand-over is part of the dan before it, not a dan of its own**: the
    /// braid's stitches do not change at the turn, only its pattern (the author,
    /// 2026-09-22). So those four threads are laid four places on in that dan
    /// instead of two, and the braid keeps its lattice (`BookDiskKongo.rounds`).
    /// An earlier reading (Task 053) counted the hand-over as a dan and drew
    /// cells half a cycle and a cycle and a half long at every turn — stitches
    /// that cannot be there.
    ///
    /// **Six tables worked in turn**: three cycles of S, the last with [4] in its
    /// second dan, and three of Z, the last with [8].
    static let yatsuKongoGaeshiRounds: [BraidDiskNotation] = {
        let s = [(17, 3), (1, 19), (25, 11), (9, 27)]          // p.38 [1], [2]
        let z = [(7, 21), (23, 5), (31, 13), (15, 29)]         // p.38 [5], [6]
        let over = [(8, 6), (16, 14), (24, 22), (32, 30)]      // p.38 [4]
        let back = [(32, 2), (8, 10), (16, 18), (24, 26)]      // p.38 [8]
        func sDan(_ k: Int) -> [(Int, Int)] { BookDiskKongo.dan(s, driftPerDan: 1, times: k) }
        func zDan(_ k: Int) -> [(Int, Int)] { BookDiskKongo.dan(z, driftPerDan: -1, times: k) }
        guard let rounds = BookDiskKongo.rounds(
            source: "the disk book p.38 (八つ金剛返し組)",
            // The book's pair 1・2 at the stand's places 1 and 2 (Task 055).
            placeOneOnward: BookDiskKongo.pairsAtPlaces([1, 2, 9, 10, 17, 18, 25, 26]),
            rounds: [
                [sDan(0), sDan(1)], [sDan(2), sDan(3)], [sDan(4), sDan(5), over],
                [zDan(0), zDan(1)], [zDan(2), zDan(3)], [zDan(4), zDan(5), back],
            ],
            // The book's own words, short: [8S-スパイラル] and [8Z-スパイラル]
            // worked, and [4]・[8] 「隣り合う糸の…側を動かします」 (Task 062).
            names: ["Sの組み", "Sの組み", "Sの組み", "Zの組み", "Zの組み", "Zの組み"],
            handOverName: "持ち替え"
        ) else {
            preconditionFailure("the disk book's 返し組 does not run on the eight-place stand")
        }
        return rounds
    }()

    /// **The book's own colouring for 返し組** (p.38 組みはじめ): slits 1・2
    /// and 17・18 orange, 9・10 and 25・26 pink — pair by pair, at the stand's
    /// places 1・2 … 7・8 (Task 055; it had the two colours the other way
    /// round). The same arrangement as book A p.54's two colours.
    static let yatsuKongoGaeshi8Colouring = byPlace(stand8, [
        "orange", "orange", "pink", "pink", "orange", "orange", "pink", "pink",
    ])

    /// A colouring written place by place, 1 to 8.
    private static func byPlace(_ stand: BraidStand, _ names: [String]) -> [ThreadAssignment] {
        zip(stand.positionIDs.sorted(), names).map {
            ThreadAssignment(position: $0.0, colorID: ThreadColorID(rawValue: $0.1))
        }
    }

    static let yatsuKongoGaeshi8Recipe = BraidRecipe(
        id: "yatsu-kongo-gaeshi-8",
        name: "八つ金剛返し組",
        rounds: yatsuKongoGaeshiRounds,
        colouring: yatsuKongoGaeshi8Colouring,
        shape: BraidShapeValues(),
        orderRoundTheBraid: yatsuKongo8CrossSection
    )

    // MARK: - Maru-yotsu (Task 054)

    /// **Maru-yotsu (丸四つ組), book A p.56, set down in the disk notation.**
    ///
    /// The book prints two steps and 「1〜2をくり返す」: in 1 the right hand takes
    /// the upper thread and the left hand the lower, and the two go to each
    /// other's places, one passing left of the middle and one right; in 2 the
    /// right hand takes the left thread and the left hand the right, and the
    /// flat pair is swapped the same way. So one cycle swaps the upright pair
    /// (north and south) and then the flat pair (west and east).
    ///
    /// **Written the way the book A tables always wrote a landing and its tidy**:
    /// each thread is carried to the notch just past the other's resting notch,
    /// and after the step both are tidied one notch on into place. The carries
    /// are fifteen notches and the tidies one, so `isRepositioning` tells them
    /// apart by distance as it does for every other table. Worked through, the
    /// threads are carried 1, 3, 2, 4, end at 1→3, 3→1, 2→4, 4→2, and the closing
    /// is empty (`MaruYotsuTests`).
    ///
    /// **A printed step is one instant** (`diskOfEight`'s reading): the book
    /// prints the right hand and the left for each step and does not say which
    /// goes first, and book C has no figure of this braid.
    static let maruYotsuDisk = BraidDiskNotation(
        source: "book A p.56, its two printed steps set down in this repository's disk notation",
        notchCount: 32,
        standPositionByRestingNotch: diskRestingNotchesForFour,
        moves: [
            (1, 18), (17, 2), (18, 17), (2, 1),      // printed step 1: the upright pair
            (9, 26), (25, 10), (26, 25), (10, 9),    // printed step 2: the flat pair
        ].map(BraidMove.init(from:to:)),
        threadsPerStep: 2,
        stepReading: .oneStepAnInstant
    )

    /// Book A prints two steps and does not name them; these say which pair each
    /// one swaps. **The derivation never reads them.**
    static let maruYotsuStepNames = ["uprightPair", "flatPair"]

    static let maruYotsu4: BraidMethod = {
        guard let method = maruYotsuDisk.method(
            id: "maru-yotsu-4", standID: stand4.id, stepNames: maruYotsuStepNames
        ) else {
            preconditionFailure("book A p.56's table does not run as a cycle of the four-place stand")
        }
        return method
    }()

    /// **Book A p.56's colouring b, upright 163 and flat 148, set on the
    /// catalogue's nearest colour names** — a reading, not a measurement: the page prints
    /// 163 pale and 148 a greyish lilac, and p.10's photograph b is white and
    /// mauve, so 163 is `white` and 148 is `purple`, the catalogue's only
    /// violet, which is more saturated than the thread.
    ///
    /// **b because it can be judged**: p.10's photograph b is the one whose two
    /// pairs part most plainly. The page prints three: a (147 upright, 169 flat,
    /// both pale — white and pink in the photograph), b, and c (124 alone, one
    /// colour, which shows no pattern to judge).
    static let maruYotsu4Colouring = colouring(on: stand4, [
        "north": ["white"],     // 163
        "east": ["purple"],     // 148
        "south": ["white"],     // 163
        "west": ["purple"],     // 148
    ])

    /// **The measured values are empty: nothing has been measured for the
    /// recipe.** What the drawing rests on belongs to the family's drawer
    /// (`RoundTube4SurfaceMesh.shape`), as the eight-thread braids' does.
    static let maruYotsu4Recipe = BraidRecipe(
        id: "maru-yotsu-4",
        name: "丸四つ組",
        notation: maruYotsuDisk,
        colouring: maruYotsu4Colouring,
        shape: BraidShapeValues()
    )

    // MARK: - Edo-yatsu (Task 009, Task 057)

    /// **Edo-yatsu (江戸八つ組), transcribed from the textbook's p.64–65**
    /// (Task 057; the author took the textbook as the source of record,
    /// 2026-09-23).
    ///
    /// The textbook prints it on the disk, one move a figure, ten figures, from
    /// yatsu-kongo's starting slits 4・5, 12・13, 20・21, 28・29:
    ///
    /// | figure | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
    /// | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
    /// | slit | 4→11 | 28→4 | 20→28 | 12→20 | 11→12 | 5→30 | 13→5 | 21→13 | 29→21 | 30→29 |
    ///
    /// and then 「1段目終了。スリット番号は【組みはじめ】と同じです」: **the slits
    /// do not drift**, where yatsu-kongo's do. **This page's 段 is all ten figures,
    /// every thread braided once — this repository's cycle**; on yatsu-kongo's
    /// page a 段 moves four threads, half a cycle. The same word, two lengths.
    ///
    /// Figures 1–4 lift the anticlockwise thread of each pair and 6–9 the
    /// clockwise one. **Figure 5 lifts the thread figure 1 laid, and figure 10
    /// the one figure 6 laid**, each into the slit the figure before it has just
    /// emptied. So a cycle is two dan of four threads, figures 1–5 and 6–10, as
    /// the drawer counts them, and each is written as one step of
    /// `BookDiskKongo.rounds`: a thread lifted twice inside a step is braided
    /// once, from where it stood to where the step leaves it.
    ///
    /// Worked through, **places 1, 3, 5, 7 go two places on each cycle and
    /// places 2, 4, 6, 8 two back** (`EdoYatsuTests`), which is the book's
    /// 「【1】→【4】は糸を右回りに4回組み、【6】→【9】は糸を左回りに4回組みます」:
    /// two spirals turning opposite ways, 「隣り合う糸の左側にある計4本、右側に
    /// ある計4本で、それぞれ1本のらせんを作ります」.
    ///
    /// **The same braid as the recipe book's p.48** (`edoYatsuRecipeBookP48Disk`,
    /// which the app braided until Task 057, read off a round-stand picture two
    /// threads at a time): name that table's places one on and the two carry
    /// every thread alike. What differs is the order inside a dan.
    static let edoYatsuDisk: BraidDiskNotation = {
        guard let disk = BookDiskKongo.rounds(
            source: "the textbook p.64-65 (江戸八つ組), its ten printed moves",
            placeOneOnward: edoYatsuStartingSlits,
            rounds: [[
                [(4, 11), (28, 4), (20, 28), (12, 20), (11, 12)],   // 【1】〜【5】: clockwise
                [(5, 30), (13, 5), (21, 13), (29, 21), (30, 29)],   // 【6】〜【10】: anticlockwise
            ]]
        )?.first else {
            preconditionFailure("the textbook's 江戸八つ組 does not run as a cycle of the eight-place stand")
        }
        return disk
    }()

    /// The textbook's starting slits for 江戸八つ組 in the order of the stand's
    /// places 1–8, a pair of the book to a pair of places (`BookDiskKongo
    /// .pairsAtPlaces`): 12・13 is places 1 and 2. Yatsu-kongo's own.
    static let edoYatsuStartingSlits = BookDiskKongo.pairsAtPlaces([12, 13, 20, 21, 28, 29, 4, 5])

    /// One name to a thread the cycle braids, in the order it braids them: the
    /// textbook's figures that carry it. **The derivation never reads them.**
    static let edoYatsuStepNames = [
        "figures1And5", "figure2", "figure3", "figure4",
        "figures6And10", "figure7", "figure8", "figure9",
    ]

    static let edoYatsu8: BraidMethod = {
        guard let method = edoYatsuDisk.method(
            id: "edo-yatsu-8", standID: stand8.id, stepNames: edoYatsuStepNames
        ) else {
            preconditionFailure("the textbook's 江戸八つ組 does not run as a cycle of the eight-place stand")
        }
        return method
    }()

    /// **The recipe book's p.48, set down in the disk notation — the table the
    /// app braided until Task 057**, kept so the two books can be held against
    /// each other (`EdoYatsuTests`).
    ///
    /// The book prints four steps and 「1〜4をくり返す」, two threads a step, one to
    /// a hand. Its figures lay the eight threads in four pairs; the text says
    /// that once used to it one sets them in eight even places 「きれいに丸く
    /// なります」. Read as yatsu-kongo was read before Task 055: two places running
    /// are one of the book's pairs, **the top pair places 8 and 1**.
    ///
    /// | step | right hand | left hand |
    /// | --- | --- | --- |
    /// | 1 | top pair's left (8) east | bottom pair's right (4) west |
    /// | 2 | an east thread south | a west thread north |
    /// | 3 | bottom pair's left (5) east | top pair's right (1) west |
    /// | 4 | an east thread north | a west thread south |
    ///
    /// **Steps 2 and 4 take the thread that was already at the side, not the one
    /// just come** — otherwise a cycle would not move all eight. Figure 2 draws
    /// the line from the inner of the west pair, beside the pink, and the one
    /// just come lies outside it.
    ///
    /// **Written as the book A tables write a landing and its tidy** (Task 008's
    /// reading): a thread carried lands just outside the group it joins, and is
    /// tidied one notch into the place emptied by the next step. Worked through,
    /// odd places go two back and even places two on. **A printed step is one
    /// instant** (`diskOfEight`'s reading): the book prints the right hand and
    /// the left and not which goes first.
    ///
    /// **Two things were read into it that the textbook now prints**: which
    /// thread of a step goes first (one move a figure there), and where a
    /// carried thread lands. The textbook's table carries every thread as this
    /// one does, the place names one on.
    static let edoYatsuRecipeBookP48Disk = diskOfEight(
        "the recipe book p.48, its four printed steps set down in this repository's disk notation",
        [
            (29, 4), (13, 22),          // printed step 1: 8 east, 4 west
            (21, 30), (5, 14),          // printed step 2: west north, east south
            (30, 29), (14, 13),         // ...tidied into 8 and 4
            (4, 5), (22, 21),           // step 1's two, tidied into 2 and 6
            (1, 26), (17, 10),          // printed step 3: 1 west, 5 east
            (25, 18), (9, 2),           // printed step 4: west south, east north
            (18, 17), (2, 1),           // ...tidied into 5 and 1
            (26, 25), (10, 9),          // step 3's two, tidied into 7 and 3
        ]
    )

    /// The recipe book prints four steps and does not name them; these say
    /// what each one does. **The derivation never reads them.**
    static let edoYatsuRecipeBookP48StepNames = [
        "acrossTopLeft", "downAndUp", "acrossBottomLeft", "upAndDown",
    ]

    /// **The textbook's own colouring (p.64 組みはじめ), written slit by slit**
    /// and laid on the places through the starting slits, so the colours go
    /// wherever the slits are laid.
    ///
    /// The figure draws two opposite threads as one line through the middle:
    /// 4・20 magenta, 5・21 grey, 12・28 cyan, 13・29 yellow-green. The
    /// photograph at the head of the page is those four, the grey a cream. On
    /// the places: 1 cyan, 2 yellow-green, 3 magenta, 4 cream, and round again.
    /// **The colours come back every two cycles, not every one**
    /// (`EdoYatsuTests`) — 「糸の色は2段ごとに戻ります」, this page's 段 being a
    /// cycle.
    ///
    /// **The names are a reading, not a measurement**: magenta is `pink`, cyan
    /// `light-blue`, the cream `natural`. **The catalogue has no yellow-green**;
    /// it lies between `yellow` and `green`, and `yellow` is the nearer. Read
    /// off the 300 dpi scan, the figure's line is about (0.75, 0.77, 0.45) and
    /// the photograph's thread (0.62, 0.69, 0.49): nearer `yellow` (0.95, 0.75,
    /// 0.12) than `green` (0.12, 0.52, 0.27) in both RGB and hue — `green` is a
    /// dark green. `natural` is nearer than either, and is the cream. Adding a
    /// colour is outside Task 057.
    ///
    /// **Until Task 057 the colouring was the recipe book's**, two colours
    /// alternating round the stand, which keeps every place its colour; the
    /// tests keep it for that (`EdoYatsuTests`). The textbook's photograph is
    /// of this one (Task 025-5: take the colouring the book photographs).
    static let edoYatsu8Colouring = bySlit(stand8, startingSlits: edoYatsuStartingSlits, [
        4: "pink", 20: "pink",
        5: "natural", 21: "natural",
        12: "light-blue", 28: "light-blue",
        13: "yellow", 29: "yellow",
    ])

    /// A colouring written slit by slit on a disk book's starting diagram, laid
    /// on the stand's places in the order `startingSlits` gives them.
    private static func bySlit(
        _ stand: BraidStand, startingSlits: [Int], _ names: [Int: String]
    ) -> [ThreadAssignment] {
        let ordered = startingSlits.compactMap { names[$0] }
        guard ordered.count == startingSlits.count, ordered.count == stand.positionCount else {
            preconditionFailure("a starting slit has no colour")
        }
        return byPlace(stand, ordered)
    }

    /// **The stand's own rim order**, as for yatsu-kongo: a tube declares
    /// nothing. It is declared here only to carry the note.
    ///
    /// **What is left unsettled since Task 057** is where the table comes from:
    /// the textbook prints one move a figure, so the order and the landings are
    /// printed, not read in as they were from the recipe book.
    static let edoYatsu8CrossSection = BraidCrossSection(
        order: stand8.positionIDs,
        source: .standRim,
        unsettled: "the table is the textbook's p.64-65, which the author took as the source of "
            + "record (2026-09-23); book C has no figure of this braid"
    )

    /// **The measured values are empty: nothing has been measured for the
    /// recipe.** It is drawn by the eight-thread tube's drawer with the values of
    /// its family — a tube whose table carries threads both ways round, drawn as
    /// the both-ways family since Task 059 (which replaced 2026-09-22's 「まずは
    /// 既存の出力を参考に」): a place shows the thread that passed over it. Its
    /// pitch was measured on the textbook p.64's photograph and belongs to the
    /// family (`RoundTube8SurfacePatternGenerator.pitchOverDiameterTurningBothWays`).
    static let edoYatsu8Recipe = BraidRecipe(
        id: "edo-yatsu-8",
        name: "江戸八つ組",
        notation: edoYatsuDisk,
        colouring: edoYatsu8Colouring,
        shape: BraidShapeValues(),
        orderRoundTheBraid: edoYatsu8CrossSection
    )

    static let recipes: [BraidRecipe] = [
        maruGenji16Recipe, hiraGenji16Recipe, yatsuKongoS8Recipe, yatsuKongoZ8Recipe,
        yatsuKongoGaeshi8Recipe, maruYotsu4Recipe, edoYatsu8Recipe,
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
/// notation** (Task 053). The disk book is the textbook (`docs/sources.md`);
/// its 江戸八つ組 is read here too (Task 057).
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
/// just short of the resting notch of the place it takes in the new order,
/// **on the side it comes from**, and after the dan, one notch on into that
/// place — the way the book A table always wrote a landing and its tidy.
///
/// **The side is the way the thread went on the book's disk** (Task 061): the
/// sum of its moves there, each the short way. The step animation reads which
/// way a thread goes round from the short way of its move here, and a thread
/// carried half the stand — 返し組's hand-overs, four places — has no short way
/// by places; only its landing says. Until Task 061 every landing was written
/// on the anticlockwise side, which sent the S hand-overs clockwise, against the
/// book's p.38 [4]. **The places the moves go between are the same either way**,
/// so nothing worked out from the table changes.
///
/// `nil` — and so a failed table, not a guess — when the threads that stay put
/// in a dan would not keep their places in the new order, when a dan lands on a
/// taken notch, or when the cycle does not braid every thread exactly once.
enum BookDiskKongo {
    static let notchCount = 32

    /// **The book's pairs are the stand's pairs 1・2, 3・4, 5・6, 7・8** (Task
    /// 055). A pair of the disk — two threads in neighbouring slits, one of
    /// which a dan lifts — keeps its two threads together through the whole
    /// braid, and **a colour laid on a pair is what turns back as one line in
    /// 返し組** (the author, 2026-09-23: 「全ての色が折り返す」). The author
    /// colours by those pairs (1・2 blue, 3・4 red …), so they have to be the
    /// book's. Until Task 055 the book's pairs stood at 8・1, 2・3, 4・5, 6・7 —
    /// the stand's four groups — and a colour on 1・2 split two pairs, and came
    /// apart at the turn.
    ///
    /// Takes the slits pair by pair, the first pair's anticlockwise slit first,
    /// and returns them in the order of the stand's places.
    static func pairsAtPlaces(_ slits: [Int]) -> [Int] { slits }

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
    /// (Task 053): each round is the steps that make one cycle of the stand. The
    /// book's disk is worked through the whole list, notch by notch; each round
    /// comes out as a table of its own.
    ///
    /// **A step that lifts only threads the step before it has just laid lays
    /// them on further, as part of the same dan** — 返し組's hand-overs (p.38
    /// [4] and [8]). The braid's stitches do not change at the turn, only its
    /// pattern (the author, 2026-09-22: 「模様だけが変わるもの」); so such a step
    /// adds no layer, and its threads are carried once, from where they stood
    /// before the dan to where the hand-over leaves them. Any other thread
    /// braided twice in a round is refused.
    ///
    /// **Inside one step a thread may be lifted twice** (江戸八つ組, Task 057:
    /// the textbook's figure 5 carries on the thread figure 1 laid). The step is
    /// worked move by move on the disk, and the thread counts once, from where
    /// it stood before the step to where the step leaves it.
    ///
    /// **A hand-over is written down as well as folded in** (Task 062): each
    /// table keeps, as `handOvers`, where the dan left each thread the hand-over
    /// then carried on, and which way each part went, so the step animation can
    /// show the hand-over as the move of its own a person makes. `names` names
    /// the tables, one each, and `handOverName` the hand-overs, as the screens
    /// say them. The table's moves are the same with or without them.
    static func rounds(
        source: String,
        placeOneOnward: [Int],
        rounds: [[[(Int, Int)]]],
        names: [String]? = nil,
        handOverName: String? = nil
    ) -> [BraidDiskNotation]? {
        let places = placeOneOnward.count
        guard places == 8, Set(placeOneOnward).count == places else { return nil }
        guard names.map({ $0.count == rounds.count }) ?? true else { return nil }
        func resting(_ place: Int) -> Int { 4 * place - 3 }

        // The book's disk: notch -> thread, the thread named by the stand place
        // it starts at.
        var onDisk = [Int: Int]()
        for (index, notch) in placeOneOnward.enumerated() { onDisk[notch] = index + 1 }
        var placeOf = [Int: Int]()                  // thread -> stand place now
        for thread in 1...places { placeOf[thread] = thread }

        var tables = [BraidDiskNotation]()
        for (roundIndex, steps) in rounds.enumerated() {
            let startPlace = placeOf
            var braided = [Int]()                   // in the order first braided
            var travelled = [Int: Int]()            // thread -> notches this round, + clockwise
            var handedOver = [(thread: Int, via: Int, first: Int, second: Int)]()
            var lastStep = Set<Int>()
            for step in steps {
                var movers = [Int]()
                var thisStep = [Int: Int]()         // thread -> notches in this step
                for (from, to) in step {
                    guard let thread = onDisk[from], onDisk[to] == nil else { return nil }
                    onDisk[from] = nil
                    onDisk[to] = thread
                    movers.append(thread)
                    thisStep[thread, default: 0] += shortWay(from: from, to: to)
                }
                // A thread braided again this round must have been laid by the
                // step just before: the hand-over carrying on that dan.
                for thread in movers where braided.contains(thread) {
                    guard lastStep.contains(thread), let via = placeOf[thread] else { return nil }
                    handedOver.append((
                        thread, via, travelled[thread] ?? 0, thisStep[thread] ?? 0
                    ))
                }
                for (thread, notches) in thisStep { travelled[thread, default: 0] += notches }
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
                placeOf = newPlace
                for thread in movers where !braided.contains(thread) { braided.append(thread) }
                lastStep = Set(movers)
            }
            // Written on the stand: each thread braided this round goes, in the
            // order it was first braided, from where it stood to just short of
            // where the round leaves it, on the side it comes from; then each is
            // tidied on into its place.
            func landing(_ thread: Int, at place: Int) -> Int {
                wrapped(resting(place) - ((travelled[thread] ?? 0) < 0 ? -1 : 1))
            }
            var moves = [BraidMove]()
            for thread in braided {
                guard let from = startPlace[thread], let to = placeOf[thread] else { return nil }
                moves.append(BraidMove(from: resting(from), to: landing(thread, at: to)))
            }
            for thread in braided {
                guard let to = placeOf[thread] else { return nil }
                moves.append(BraidMove(from: landing(thread, at: to), to: resting(to)))
            }
            var handOvers = [BraidDiskNotation.HandOver]()
            for handed in handedOver {
                guard let from = startPlace[handed.thread], let to = placeOf[handed.thread] else {
                    return nil
                }
                handOvers.append(BraidDiskNotation.HandOver(
                    carry: BraidMove(from: from, to: to), via: handed.via,
                    firstNotches: handed.first, handOverNotches: handed.second
                ))
            }
            tables.append(BraidDiskNotation(
                source: rounds.count == 1 ? source : "\(source), round \(roundIndex + 1)",
                notchCount: notchCount,
                standPositionByRestingNotch: BraidMethodCatalog.diskRestingNotchesForEight,
                moves: moves,
                threadsPerStep: 1,
                stepReading: .oneThreadAnInstant,
                name: names?[roundIndex],
                handOvers: handOvers,
                handOverName: handOvers.isEmpty ? nil : handOverName
            ))
        }
        return tables
    }

    private static func wrapped(_ notch: Int) -> Int {
        ((notch - 1) % notchCount + notchCount) % notchCount + 1
    }

    /// How far a move goes round the book's disk the short way, + clockwise.
    private static func shortWay(from: Int, to: Int) -> Int {
        let forward = ((to - from) % notchCount + notchCount) % notchCount
        return forward * 2 <= notchCount ? forward : forward - notchCount
    }
}
