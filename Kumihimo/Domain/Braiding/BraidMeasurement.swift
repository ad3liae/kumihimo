import Foundation

/// Where a number came from.
///
/// **A measured value and a derived one must never be told apart by guesswork.**
/// The same distinction `BraidCrossSection.Source` draws for the order round the
/// braid is drawn here for every length, ratio and height: something read off a
/// photograph or a book is `.observed`, something worked out from the moves and the
/// thread's diameter is `.derived`, and the string says which photograph or which
/// working-out.
enum BraidValueSource: Equatable, Sendable {
    /// Read off a reference. Say which one — book, page, task.
    case observed(String)
    /// Worked out. Say from what.
    case derived(String)
    /// **Set by eye against a photograph, and nothing more.** Not measured -- no
    /// procedure produced it — and not derived — nothing implies it. A drawing may
    /// need such a number to look like the thing; carrying it as `.declared` keeps
    /// it from ever being mistaken for either of the others.
    case declared(String)

    var isObserved: Bool {
        if case .observed = self { return true }
        return false
    }

    var isDerived: Bool {
        if case .derived = self { return true }
        return false
    }

    /// Neither measured nor worked out: calibrated by eye.
    var isDeclared: Bool {
        if case .declared = self { return true }
        return false
    }

    /// The book, page, working-out or calibration. Not display text; a view writes
    /// its own.
    var origin: String {
        switch self {
        case let .observed(origin), let .derived(origin), let .declared(origin):
            return origin
        }
    }
}

/// What a number is a fraction of.
///
/// **A length the construction can use has to be in thread diameters**, because a
/// thread's diameter is the only length the construction has. A number given as a
/// fraction of something else is carried as it is and **never converted here** —
/// inventing the conversion is how a measurement stops being a measurement.
enum BraidValueBasis: Equatable, Sendable {
    /// A length, in thread diameters.
    case threadDiameters
    /// A bare ratio: width over thickness, a count per width, and the like.
    case aRatio
    /// A fraction of something else. Say what.
    case fractionOf(String)
}

/// One number about a braid's shape, with where it came from.
///
/// **A value with no source cannot be built.** That is the whole point of the type:
/// a constant fitted to make a picture look right has no honest source to give, so
/// it has nowhere to live.
struct BraidMeasurement: Equatable, Sendable {
    let value: Double
    /// The band the reference gives, when it gives one rather than a single value.
    let spread: ClosedRange<Double>?
    /// What the number is a fraction of.
    let basis: BraidValueBasis
    let source: BraidValueSource
    /// What about this number is not settled, if anything. **A working answer is
    /// still an answer, but it must say it is working** — the round braid's crest
    /// height and aspect ratio are held this way, because the photographs constrain
    /// only their product and neither one on its own.
    let unsettled: String?

    init(
        _ value: Double,
        spread: ClosedRange<Double>? = nil,
        basis: BraidValueBasis = .aRatio,
        source: BraidValueSource,
        unsettled: String? = nil
    ) {
        self.value = value
        self.spread = spread
        self.basis = basis
        self.source = source
        self.unsettled = unsettled
    }

    static func observed(
        _ value: Double,
        spread: ClosedRange<Double>? = nil,
        basis: BraidValueBasis = .aRatio,
        from origin: String,
        unsettled: String? = nil
    ) -> BraidMeasurement {
        BraidMeasurement(value, spread: spread, basis: basis, source: .observed(origin),
                         unsettled: unsettled)
    }

    static func derived(
        _ value: Double,
        basis: BraidValueBasis = .aRatio,
        by working: String,
        unsettled: String? = nil
    ) -> BraidMeasurement {
        BraidMeasurement(value, basis: basis, source: .derived(working),
                         unsettled: unsettled)
    }

    /// A number set by eye against a photograph. **Calibrated, not derived**, and
    /// it says so wherever it is read.
    static func declared(
        _ value: Double,
        basis: BraidValueBasis = .aRatio,
        calibratedBy how: String
    ) -> BraidMeasurement {
        BraidMeasurement(value, basis: basis, source: .declared(how),
                         unsettled: "calibrated against a photograph by eye; "
                             + "no procedure produced it and nothing implies it")
    }

    /// Whether this is a length the construction can use as it stands.
    var isInThreadDiameters: Bool { basis == .threadDiameters }

    var isObserved: Bool { source.isObserved }
    var isDerived: Bool { source.isDerived }
    /// Set by eye against a photograph.
    var isDeclared: Bool { source.isDeclared }
    var isSettled: Bool { unsettled == nil }

    /// Whether the value sits inside the band the reference gives. `true` when
    /// there is no band, because then there is nothing to sit outside of.
    var agreesWithItsSpread: Bool { spread?.contains(value) ?? true }
}
