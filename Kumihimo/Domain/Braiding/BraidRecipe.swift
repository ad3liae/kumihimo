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
    let notation: BraidDiskNotation
    let colouring: [ThreadAssignment]
    let shape: BraidShapeValues
    /// The order the threads come in round the braid, when the source gives one.
    /// `nil` leaves the stand's own rim order, which is a tube.
    let orderRoundTheBraid: BraidCrossSection?

    init(
        id: String,
        name: String,
        notation: BraidDiskNotation,
        colouring: [ThreadAssignment],
        shape: BraidShapeValues,
        orderRoundTheBraid: BraidCrossSection? = nil
    ) {
        self.id = id
        self.name = name
        self.notation = notation
        self.colouring = colouring
        self.shape = shape
        self.orderRoundTheBraid = orderRoundTheBraid
    }

    func crossSection(on stand: BraidStand) -> BraidCrossSection {
        orderRoundTheBraid ?? .tube(of: stand)
    }

    /// The method the table generates. Step names are the source's own when it
    /// gives them and numbered when it does not; **the derivation never reads
    /// them.**
    func method(on stand: BraidStand, stepNames: [String]? = nil) -> BraidMethod? {
        let braidingCount = notation.braidingMoves.count
        guard notation.threadsPerStep > 0,
              braidingCount % notation.threadsPerStep == 0 else { return nil }
        let printed = braidingCount / notation.threadsPerStep
        let names = stepNames ?? (1...max(printed, 1)).map { "step \($0)" }
        return notation.method(id: id, standID: stand.id, stepNames: names)
    }

    /// Everything the working-out needs, in one go. `nil` when the table is not a
    /// cycle of this stand.
    func worked(on stand: BraidStand) -> (method: BraidMethod, section: BraidCrossSection,
                                          derivation: BraidDerivation)? {
        guard let method = method(on: stand) else { return nil }
        let section = crossSection(on: stand)
        guard let derivation = BraidDerivation.derive(
            stand: stand, method: method, crossSection: section
        ) else { return nil }
        return (method, section, derivation)
    }
}
