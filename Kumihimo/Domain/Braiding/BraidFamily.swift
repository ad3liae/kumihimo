import Foundation

/// The kind of braid a drawing has to draw.
///
/// **Read off the braid, not declared.** A braid whose courses fold it is flat; one
/// whose threads all travel is a tube. With the thread count that is enough to
/// choose which drawer to hand it to — and it is the only thing a drawer is allowed
/// to know about the braid, because a drawer holds shape values and shape values
/// belong to a family, not to a name.
enum BraidFamily: Equatable, Sendable {
    /// A tube of this many threads.
    case roundTube(threads: Int)
    /// A flat braid of this many threads, folded to the given number of columns a
    /// face.
    case flat(threads: Int, columns: Int)

    var threads: Int {
        switch self {
        case let .roundTube(threads): return threads
        case let .flat(threads, _): return threads
        }
    }

    /// Works the family out of a braid.
    static func family(of derivation: BraidDerivation) -> BraidFamily {
        if let fold = derivation.fold {
            return .flat(threads: derivation.threadCount, columns: fold.columnCount)
        }
        return .roundTube(threads: derivation.threadCount)
    }

    /// Whether a drawer for this family can draw that braid.
    func fits(_ other: BraidFamily) -> Bool { self == other }
}

/// What a drawer says about the shape it draws, and where each number came from.
///
/// **A drawer keeps its own shape values** — the section's proportions, the pitch,
/// the height a thread stands proud, the numbers calibrated by eye — and every one
/// of them says whether it was measured, worked out, or set against a photograph.
/// Nothing here changes a value; it says what a value is.
struct BraidFamilyShape: Equatable, Sendable {
    let family: BraidFamily
    /// The values the family's drawing rests on, by the name the drawer calls them.
    let values: [String: BraidMeasurement]

    var measured: [String: BraidMeasurement] { values.filter { $0.value.isObserved } }
    var workedOut: [String: BraidMeasurement] { values.filter { $0.value.isDerived } }
    /// The ones set by eye. **Kept, and kept visible.**
    var calibratedByEye: [String: BraidMeasurement] { values.filter { $0.value.isDeclared } }
}
