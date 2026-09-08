import Foundation

/// Two slots the closing carries a thread between.
///
/// They are neighbours round the ring: `trail` is the slot one step on from `lead`.
struct BraidClosingPair: Hashable, Sendable {
    let lead: Int
    let trail: Int
}

/// Which thread rests at which slot, cycle by cycle.
///
/// **This is the face pattern, and it comes out of the move table alone.** The
/// author's premise (`docs/architecture.md`, 組み台の力学) is that a thread standing
/// at a slot is held against the braid's surface there by its own weight, from the
/// height it arrived at to the height it leaves. So what shows on the face is not
/// the last thread laid, nor the topmost layer: **it is whatever is resting there**,
/// and the history of that is this.
///
/// **No geometry and no physics.** Nothing here knows a thread's diameter.
struct BraidOccupancy: Equatable, Sendable {
    /// One entry a cycle boundary, `count + 1` of them for `count` cycles: which
    /// thread rests at each slot of the cross-section.
    let boundaries: [[Int: Int]]

    /// The closing's neighbouring pairs. The occupancy history folds the ring into
    /// these: each pair is one column of the face, holding the same run of threads
    /// one cycle apart.
    let closingPairs: [BraidClosingPair]

    /// The slots a braiding move lands on. **Exactly one slot of each closing pair
    /// is one of these**; the other is reached only by the closing.
    let landingSlots: Set<Int>

    /// Which slot of a pair a column is read at.
    ///
    /// **Not a choice about the braid, a choice about the question being asked.**
    /// The two slots of a pair hold the same run of threads one cycle apart, so
    /// both read the same pattern shifted by a row. The landing slot is the one a
    /// hand actually sets a thread down on.
    enum Reading: Sendable {
        case landing
        case closing
    }

    /// One slot for each closing pair, in the pairs' own order.
    ///
    /// `nil` when a pair does not hold exactly one slot of the kind asked for,
    /// which would mean the closing is not what this assumes and is worth stopping
    /// over rather than guessing past.
    func columns(_ reading: Reading) -> [Int]? {
        var result = [Int]()
        for pair in closingPairs {
            let both = [pair.lead, pair.trail]
            let wanted = both.filter {
                reading == .landing ? landingSlots.contains($0) : !landingSlots.contains($0)
            }
            guard wanted.count == 1 else { return nil }
            result.append(wanted[0])
        }
        return result
    }

    /// One row a cycle, one cell a column: the thread resting there.
    func grid(atColumns columns: [Int], rows: Int) -> [[Int]]? {
        guard rows <= boundaries.count else { return nil }
        var result = [[Int]]()
        for row in 0..<rows {
            var line = [Int]()
            for slot in columns {
                guard let thread = boundaries[row][slot] else { return nil }
                line.append(thread)
            }
            result.append(line)
        }
        return result
    }

    /// Every slot's own run of threads, cycle by cycle. The flat braid is read this
    /// way: its columns are the widths, not the closing's pairs.
    func lanes(rows: Int) -> [Int: [Int]]? {
        guard rows <= boundaries.count else { return nil }
        var result = [Int: [Int]]()
        for slot in boundaries[0].keys {
            var run = [Int]()
            for row in 0..<rows {
                guard let thread = boundaries[row][slot] else { return nil }
                run.append(thread)
            }
            result[slot] = run
        }
        return result
    }

    /// Works the history out of the moves.
    ///
    /// `nil` when the method is not a cycle of this stand, when a slot of the
    /// cross-section holds a position the stand does not have, or when a closing
    /// move carries a thread between slots that are not neighbours — none of which
    /// this should paper over.
    static func history(
        of method: BraidMethod,
        on stand: BraidStand,
        crossSection: BraidCrossSection,
        cycles count: Int
    ) -> BraidOccupancy? {
        guard count > 0, let worked = BraidWorking.cycles(of: method, on: stand, count: count)
        else { return nil }

        var slotOfPosition = [Int: Int]()
        for (slot, position) in crossSection.order.enumerated() {
            slotOfPosition[position] = slot
        }
        func slots(of state: BraidStandState) -> [Int: Int]? {
            guard let byPosition = state.threadByPosition else { return nil }
            var result = [Int: Int]()
            for (position, thread) in byPosition {
                guard let slot = slotOfPosition[position] else { return nil }
                result[slot] = thread
            }
            return result
        }

        var boundaries = [[Int: Int]]()
        for cycle in worked {
            guard let at = slots(of: cycle.startState) else { return nil }
            boundaries.append(at)
        }
        guard let last = slots(of: worked[worked.count - 1].endState) else { return nil }
        boundaries.append(last)

        // One cycle decides the folding, and every cycle repeats it.
        let first = worked[0]
        let closingOrdinal = method.instantCount
        var braided = Set<Int>()
        var shuffled = Set<Int>()
        for instant in first.instants {
            if instant.ordinal == closingOrdinal {
                shuffled.formUnion(instant.carried)
            } else {
                braided.formUnion(instant.carried)
            }
        }
        guard
            let startByThread = first.startState.positionByThread,
            let endByThread = first.endState.positionByThread
        else { return nil }
        func slot(ofThread thread: Int, in byThread: [Int: Int]) -> Int? {
            byThread[thread].flatMap { slotOfPosition[$0] }
        }

        let ringSize = crossSection.slotCount
        var pairs = Set<BraidClosingPair>()
        for thread in shuffled.subtracting(braided).sorted() {
            guard
                let from = slot(ofThread: thread, in: startByThread),
                let to = slot(ofThread: thread, in: endByThread)
            else { return nil }
            if (to + 1) % ringSize == from {
                pairs.insert(BraidClosingPair(lead: to, trail: from))
            } else if (from + 1) % ringSize == to {
                pairs.insert(BraidClosingPair(lead: from, trail: to))
            } else {
                return nil          // the closing did not move between neighbours
            }
        }

        var landings = Set<Int>()
        for thread in braided {
            guard let to = slot(ofThread: thread, in: endByThread) else { return nil }
            landings.insert(to)
        }

        return BraidOccupancy(
            boundaries: boundaries,
            closingPairs: pairs.sorted { ($0.lead, $0.trail) < ($1.lead, $1.trail) },
            landingSlots: landings
        )
    }
}

/// Laying a worked grid on a transcribed one.
///
/// **A tube has no origin and no printed direction**, so which column the
/// transcription started at, which way round it ran, which way up it was held and
/// which cycle it began on are all free. **Nothing else is.** Renumbering threads
/// or shifting one column against another is not allowed and is not tried.
enum BraidGridAgreement {
    struct Laying: Equatable, Sendable {
        let same: Int
        let of: Int
        let mirrored: Bool
        let rotation: Int
        let upwards: Bool
        let shift: Int
        let laidOn: [[Int]]
    }

    /// The best laying, ties going to the first tried: not mirrored before
    /// mirrored, smaller rotation first, upwards before downwards, smaller shift
    /// first.
    static func best(of grid: [[Int]], against target: [[Int]]) -> Laying? {
        guard
            let width = grid.first?.count, width > 0,
            grid.allSatisfy({ $0.count == width }),
            target.count == grid.count,
            target.allSatisfy({ $0.count == width })
        else { return nil }

        let rows = grid.count
        var best: Laying?
        for mirrored in [false, true] {
            for rotation in 0..<width {
                let columns = (0..<width).map {
                    ((rotation + (mirrored ? -1 : 1) * $0) % width + width) % width
                }
                for upwards in [true, false] {
                    for shift in 0..<rows {
                        var laid = [[Int]]()
                        for row in 0..<rows {
                            let source = ((shift + (upwards ? 1 : -1) * row) % rows + rows) % rows
                            laid.append(columns.map { grid[source][$0] })
                        }
                        var same = 0
                        for row in 0..<rows where laid[row].count == width {
                            for column in 0..<width where laid[row][column] == target[row][column] {
                                same += 1
                            }
                        }
                        if same > (best?.same ?? -1) {
                            best = Laying(same: same, of: rows * width, mirrored: mirrored,
                                          rotation: rotation, upwards: upwards, shift: shift,
                                          laidOn: laid)
                        }
                    }
                }
            }
        }
        return best
    }
}
