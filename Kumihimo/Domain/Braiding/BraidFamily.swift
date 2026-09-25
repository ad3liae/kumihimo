import Foundation

/// The kind of braid a drawing has to draw.
///
/// **Read off the braid, not declared.** A braid whose courses fold it is flat; one
/// whose threads all travel is a tube. With the thread count that is enough to
/// choose which drawer to hand it to — and it is the only thing a drawer is allowed
/// to know about the braid, because a drawer holds shape values and shape values
/// belong to a family, not to a name.
///
/// **A tube also says which ways round its threads are carried** (Task 059). Eight
/// threads carried all one way lie as one spiral of long, slanting bundles; eight
/// of which four go one way and four the other cross as two spirals, and a line
/// along the braid meets the two sets in turn. That is the braid's structure, read
/// off its table, and it is why the two draw with different shape values.
enum BraidFamily: Equatable, Sendable {
    /// A tube of this many threads, carried round it one way or both ways.
    case roundTube(threads: Int, turning: BraidTurning)
    /// A flat braid of this many threads, folded to the given number of columns a
    /// face.
    case flat(threads: Int, columns: Int)

    var threads: Int {
        switch self {
        case let .roundTube(threads, _): return threads
        case let .flat(threads, _): return threads
        }
    }

    /// Works the family out of a braid.
    static func family(of derivation: BraidDerivation) -> BraidFamily {
        if let fold = derivation.fold {
            return .flat(threads: derivation.threadCount, columns: fold.columnCount)
        }
        return .roundTube(threads: derivation.threadCount, turning: .of(derivation))
    }

    /// Whether a drawer for this family can draw that braid.
    func fits(_ other: BraidFamily) -> Bool { self == other }
}

/// **Which ways round a tube's threads are carried**, cycle by cycle (Task 059).
///
/// Read off the braiding moves of each cycle — the closing, which only tidies the
/// threads into their places, left out — each carry counted the shorter way round
/// the ring. **A half turn has no shorter way and counts for neither**, and nor
/// does a thread left where it was.
///
/// - `oneWay`: no cycle carries threads opposite ways round — a single spiral.
///   A braid worked with several tables in turn can turn its spiral round from
///   one table to the next and still be one way: what is asked is whether one
///   cycle carries both ways. A table whose every carry is a half turn has no
///   way round at all, and is not both ways either.
/// - `bothWays`: some cycle carries threads opposite ways round — two spirals
///   that cross.
///
/// Which braid reads which is recorded in `docs/architecture.md` (筒の族は「運び
/// が一方向か、両方向か」でも分ける) and held by `BraidFamilyDrawingTests
/// .theWaysRoundAreReadOffTheBraid`.
///
/// **Nothing here knows a braid's name**; it counts which way the moves go.
enum BraidTurning: Equatable, Sendable {
    case oneWay
    case bothWays

    static func of(_ derivation: BraidDerivation) -> BraidTurning {
        let section = derivation.crossSection
        let count = section.slotCount
        guard
            count > 0,
            let cycles = BraidWorking.cycles(
                ofRounds: derivation.rounds, on: derivation.stand,
                count: derivation.repeatCycleCount
            )
        else { return .oneWay }
        for (index, cycle) in cycles.enumerated() {
            let braidingInstants = derivation.rounds[index % derivation.rounds.count].steps.count
            var ways = Set<Int>()
            for carried in cycle.allCarried where carried.instant <= braidingInstants {
                guard
                    let from = section.slotIndex(ofPositionID: carried.move.from),
                    let to = section.slotIndex(ofPositionID: carried.move.to)
                else { continue }
                let forward = ((to - from) % count + count) % count
                guard forward != 0, forward * 2 != count else { continue }
                ways.insert(forward * 2 < count ? 1 : -1)
            }
            if ways.count > 1 { return .bothWays }
        }
        return .oneWay
    }
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
