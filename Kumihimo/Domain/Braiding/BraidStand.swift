import Foundation
import simd

/// A braiding stand: a set of positions a thread can stand at, and where those
/// positions are.
///
/// **The derivation reads two things and no more: how many positions there are,
/// and the order they come in round the rim.** Everything else here — the point
/// on the top of the stand, the names the books give the groups — is for drawing
/// and for writing move tables down, and is never consulted when the braid is
/// worked out.
///
/// That is what lets one stand type stand in for another. A round stand divides
/// the turn evenly; a square stand walks its own perimeter; both are a closed rim
/// with positions on it, and both come out of the derivation the same way.
struct BraidStand: Equatable, Sendable {
    let id: String

    /// The positions, in rim order. The order is the braid's own cyclic order of
    /// the stand, so it is held as an array rather than recovered by sorting.
    let positions: [BraidPosition]

    /// The names a source uses when it writes a move table — "north", "east", the
    /// sides of a square stand. **The derivation never reads this.** It exists so
    /// a table can be written the way the book writes it.
    let groups: [BraidGroup]

    var positionCount: Int { positions.count }

    var positionIDs: [Int] { positions.map(\.id) }

    /// Where a position stands in the rim order, which is the only thing about
    /// the stand's shape the derivation uses.
    func rimIndex(ofPositionID id: Int) -> Int? {
        positions.firstIndex { $0.id == id }
    }

    func position(withID id: Int) -> BraidPosition? {
        positions.first { $0.id == id }
    }

    func group(named name: String) -> BraidGroup? {
        groups.first { $0.name == name }
    }

    /// Every position appears once, every group names positions that exist, and
    /// the rim runs the same way round as the ids.
    var isWellFormed: Bool {
        let ids = positionIDs
        guard Set(ids).count == ids.count, !ids.isEmpty else { return false }
        let known = Set(ids)
        guard groups.allSatisfy({ Set($0.positions).isSubset(of: known) }) else { return false }
        return zip(positions, positions.dropFirst()).allSatisfy { $0.rim < $1.rim }
    }
}

struct BraidPosition: Equatable, Sendable {
    let id: Int

    /// Where the position sits along the rim, in turns from a fixed mark, 0..<1.
    /// A round stand divides the turn evenly; a square stand measures arc length
    /// round its perimeter, so its corners crowd and its sides spread.
    let rim: Double

    /// Where the position is on the top of the stand. Carried for drawing, and so
    /// a stand that is not round can still say how far apart two positions are.
    /// **The derivation does not read it.**
    let point: SIMD2<Double>
}

struct BraidGroup: Equatable, Sendable {
    let name: String
    /// The positions of the group, in the order the source lists them.
    let positions: [Int]
}

enum BraidStands {
    /// A round stand with its positions evenly spaced, numbered from the mark and
    /// running clockwise.
    ///
    /// Position 1 is at the mark, so a position's number and its rim order are the
    /// same thing. Both Genji move tables are written against this numbering.
    static func round(id: String, positionCount: Int, groups: [BraidGroup] = []) -> BraidStand {
        let positions = (0..<max(0, positionCount)).map { index -> BraidPosition in
            let rim = Double(index) / Double(max(1, positionCount))
            let angle = 2 * Double.pi * rim
            return BraidPosition(
                id: index + 1,
                rim: rim,
                point: SIMD2<Double>(sin(angle), cos(angle))
            )
        }
        return BraidStand(id: id, positions: positions, groups: groups)
    }

    /// The sixteen-position round stand both known methods are worked on, with the
    /// four groups the books name. The group members are listed the way the books
    /// list them — outermost first, which for the south and west groups runs
    /// against the rim.
    static let round16 = round(
        id: "round-16",
        positionCount: 16,
        groups: [
            BraidGroup(name: "north", positions: [15, 16, 1, 2]),
            BraidGroup(name: "east", positions: [3, 4, 5, 6]),
            BraidGroup(name: "south", positions: [10, 9, 8, 7]),
            BraidGroup(name: "west", positions: [14, 13, 12, 11]),
        ]
    )
}
