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

    var isObserved: Bool {
        if case .observed = self { return true }
        return false
    }

    var isDerived: Bool { !isObserved }

    /// The book, page or working-out. Not display text; a view writes its own.
    var origin: String {
        switch self {
        case let .observed(origin), let .derived(origin): return origin
        }
    }
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
    let source: BraidValueSource
    /// What about this number is not settled, if anything. **A working answer is
    /// still an answer, but it must say it is working** — the round braid's crest
    /// height and aspect ratio are held this way, because the photographs constrain
    /// only their product and neither one on its own.
    let unsettled: String?

    init(
        _ value: Double,
        spread: ClosedRange<Double>? = nil,
        source: BraidValueSource,
        unsettled: String? = nil
    ) {
        self.value = value
        self.spread = spread
        self.source = source
        self.unsettled = unsettled
    }

    static func observed(
        _ value: Double,
        spread: ClosedRange<Double>? = nil,
        from origin: String,
        unsettled: String? = nil
    ) -> BraidMeasurement {
        BraidMeasurement(value, spread: spread, source: .observed(origin),
                         unsettled: unsettled)
    }

    static func derived(
        _ value: Double,
        by working: String,
        unsettled: String? = nil
    ) -> BraidMeasurement {
        BraidMeasurement(value, source: .derived(working), unsettled: unsettled)
    }

    var isObserved: Bool { source.isObserved }
    var isDerived: Bool { source.isDerived }
    var isSettled: Bool { unsettled == nil }

    /// Whether the value sits inside the band the reference gives. `true` when
    /// there is no band, because then there is nothing to sit outside of.
    var agreesWithItsSpread: Bool { spread?.contains(value) ?? true }
}
