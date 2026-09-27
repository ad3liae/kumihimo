import Foundation

/// The measured values that say what a braid's shape is like.
///
/// **Every one of these is `.observed`.** They come off photographs and books;
/// nothing here is worked out, and nothing here may be adjusted to make a picture
/// look right. What the derivation works out for itself — the pitch, the flattened
/// section, the crest's width — does not live here.
struct BraidShapeValues: Equatable, Sendable {
    /// How much wider than thick the braid is.
    let widthOverThickness: BraidMeasurement?
    /// One cycle's growth as a fraction of the braid's width.
    let pitchPerBraidWidth: BraidMeasurement?
    /// How high a thread stands over the surface, as a fraction of the half
    /// thickness.
    let crestHeight: BraidMeasurement?
    /// How many chevrons show in one braid width.
    let chevronsPerBraidWidth: BraidMeasurement?

    init(
        widthOverThickness: BraidMeasurement? = nil,
        pitchPerBraidWidth: BraidMeasurement? = nil,
        crestHeight: BraidMeasurement? = nil,
        chevronsPerBraidWidth: BraidMeasurement? = nil
    ) {
        self.widthOverThickness = widthOverThickness
        self.pitchPerBraidWidth = pitchPerBraidWidth
        self.crestHeight = crestHeight
        self.chevronsPerBraidWidth = chevronsPerBraidWidth
    }

    var all: [BraidMeasurement] {
        [widthOverThickness, pitchPerBraidWidth, crestHeight, chevronsPerBraidWidth]
            .compactMap { $0 }
    }

    /// Nothing measured pretends to be worked out.
    var everythingIsObserved: Bool { all.allSatisfy(\.isObserved) }

    /// What is not settled about these values, if anything, ready to be shown
    /// rather than hidden.
    var unsettled: [String] { all.compactMap(\.unsettled) }
}

/// **Where the book's starting diagram puts each place's thread on its disk**
/// (Task 066): the disk's notch count, and the slit of place 1, place 2, … in
/// turn. The eight-bobbin braids rest in pairs, two neighbouring slits to a pair
/// and the pairs a quarter turn apart — 「金剛は2本ずつ東西南北よせる、その方が
/// 組みやすい」 (the author, 2026-09-26).
///
/// **For the step animation's drawing only.** The derivation and the step script
/// work on the stand's evenly spaced places and never read this.
struct BraidStartingSlits: Equatable, Sendable {
    let notchCount: Int
    /// The slit of each place, place 1 onward.
    let placeOneOnward: [Int]
    /// **Where the book's figure has the top of its disk**, in slits — 4.5,
    /// between slits 4 and 5, in the textbook (Task 071) — so the stand is
    /// drawn the way the figure is. `nil` draws place 1's pair at the top,
    /// which is what every braid drawn before Task 071 does: yatsu-kongo S and
    /// Z and 江戸八つ組 have their pair 4・5 there in the book too, and 返し組's
    /// pair 1・2 is drawn at the top where its figure has it up and to the left.
    let slitAtTheTop: Double?

    init(notchCount: Int, placeOneOnward: [Int], slitAtTheTop: Double? = nil) {
        self.notchCount = notchCount
        self.placeOneOnward = placeOneOnward
        self.slitAtTheTop = slitAtTheTop
    }
}

/// A braid this app can show: **the move table, the colouring, and the measured
/// values.**
///
/// **Three things, and adding a braid is adding them.** Nothing in the working-out
/// is touched. The stand's own rim order is the default for the order round the
/// braid, so a braid that is a tube needs nothing else; a braid whose source gives
/// a different order round the braid declares it, which is Task 020's judgement 1
/// — the order is an input with a default, not something the moves decide.
struct BraidRecipe: Equatable, Sendable {
    let id: String
    /// What the braid is called. **The one place a braid's name belongs.**
    let name: String
    /// **The book and pages its steps are printed on** (Task 070), shown under
    /// the step animation. The working-out never reads it.
    let source: BraidSource?
    /// The tables worked in turn, cycle by cycle (Task 053). One, for most
    /// braids; a braid that turns its spiral round partway through works one
    /// table for some cycles and another for the next.
    let rounds: [BraidDiskNotation]
    /// The first table — **the** table, for a braid of one.
    var notation: BraidDiskNotation { rounds[0] }
    let colouring: [ThreadAssignment]
    let shape: BraidShapeValues
    /// The order the threads come in round the braid, when the source gives one.
    /// `nil` leaves the stand's own rim order, which is a tube.
    let orderRoundTheBraid: BraidCrossSection?
    /// Where the book's starting diagram puts each place's thread on its disk,
    /// when the book works the braid on a disk (Task 066). **Only the step
    /// animation reads it**, with the tables' `bookSteps`.
    let startingSlits: BraidStartingSlits?
    /// **The braid's hands on a round stand's faces**, when a book of the round
    /// stand is the one the step animation follows (Task 067). **Only the step
    /// animation reads it**; it takes the place of the disk when both are given.
    let standHands: BraidStandHands?
    /// **How many hands make a dan of the book's disk** — the book's 「1段目終了」
    /// (Task 068). The step animation sets the threads back in the starting form
    /// only at the end of a dan, never between hands. `nil` for a braid on a
    /// round stand's faces, whose dan is `standHands.hands`; a braid worked on
    /// the disk without it is not drawn.
    let handsADan: Int?

    init(
        id: String,
        name: String,
        source: BraidSource? = nil,
        notation: BraidDiskNotation,
        colouring: [ThreadAssignment],
        shape: BraidShapeValues,
        orderRoundTheBraid: BraidCrossSection? = nil,
        startingSlits: BraidStartingSlits? = nil,
        standHands: BraidStandHands? = nil,
        handsADan: Int? = nil
    ) {
        self.init(
            id: id, name: name, source: source, rounds: [notation], colouring: colouring,
            shape: shape, orderRoundTheBraid: orderRoundTheBraid, startingSlits: startingSlits,
            standHands: standHands, handsADan: handsADan
        )
    }

    /// A braid worked with several tables in turn. **At least one**: an empty
    /// list is a programming error, not a braid.
    init(
        id: String,
        name: String,
        source: BraidSource? = nil,
        rounds: [BraidDiskNotation],
        colouring: [ThreadAssignment],
        shape: BraidShapeValues,
        orderRoundTheBraid: BraidCrossSection? = nil,
        startingSlits: BraidStartingSlits? = nil,
        standHands: BraidStandHands? = nil,
        handsADan: Int? = nil
    ) {
        precondition(!rounds.isEmpty, "a recipe needs a table")
        self.id = id
        self.name = name
        self.source = source
        self.rounds = rounds
        self.colouring = colouring
        self.shape = shape
        self.orderRoundTheBraid = orderRoundTheBraid
        self.startingSlits = startingSlits
        self.standHands = standHands
        self.handsADan = handsADan
    }

    func crossSection(on stand: BraidStand) -> BraidCrossSection {
        orderRoundTheBraid ?? .tube(of: stand)
    }

    /// The method the table generates. Step names are the source's own when it
    /// gives them and numbered when it does not; **the derivation never reads
    /// them.**
    func method(on stand: BraidStand, stepNames: [String]? = nil) -> BraidMethod? {
        Self.method(of: notation, id: id, on: stand, stepNames: stepNames)
    }

    /// Every table's method, in turn. `nil` when any of them is not a cycle of
    /// this stand.
    func methods(on stand: BraidStand) -> [BraidMethod]? {
        var methods = [BraidMethod]()
        for (index, round) in rounds.enumerated() {
            let roundID = rounds.count == 1 ? id : "\(id)-round-\(index + 1)"
            guard let method = Self.method(of: round, id: roundID, on: stand, stepNames: nil) else {
                return nil
            }
            methods.append(method)
        }
        return methods
    }

    private static func method(
        of notation: BraidDiskNotation, id: String, on stand: BraidStand, stepNames: [String]?
    ) -> BraidMethod? {
        let braidingCount = notation.braidingMoves.count
        guard notation.threadsPerStep > 0,
              braidingCount % notation.threadsPerStep == 0 else { return nil }
        let printed = braidingCount / notation.threadsPerStep
        let names = stepNames ?? (1...max(printed, 1)).map { "step \($0)" }
        return notation.method(id: id, standID: stand.id, stepNames: names)
    }

    /// Everything the working-out needs, in one go. `nil` when the table is not a
    /// cycle of this stand. `method` is the first table; the derivation carries
    /// them all (`BraidDerivation.rounds`).
    func worked(on stand: BraidStand) -> (method: BraidMethod, section: BraidCrossSection,
                                          derivation: BraidDerivation)? {
        guard let methods = methods(on: stand), let method = methods.first else { return nil }
        let section = crossSection(on: stand)
        guard let derivation = BraidDerivation.derive(
            stand: stand, rounds: methods, crossSection: section
        ) else { return nil }
        return (method, section, derivation)
    }
}
