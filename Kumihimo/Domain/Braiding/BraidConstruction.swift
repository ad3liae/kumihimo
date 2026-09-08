import Foundation

/// The braid written down: where every thread runs, in thread diameters.
///
/// **No solver, no search, no iteration** (`docs/tasks/024-crest-by-half-diameter.md`).
/// A thread rests on the surface at a place from the height it arrives at to the
/// height it leaves, and is carried straight through the section between rests.
/// Both heights are the stacking model's: a carry's height at a place is where it
/// sits in that place's own pile, which is why a carry slopes and why the thread
/// taking a place over does not start where the last one finished.
struct BraidConstruction: Equatable, Sendable {
    /// One stay at one place.
    struct Step: Equatable, Sendable {
        let slot: Int
        /// The height the thread arrives at this place at.
        let arrivedAt: Double
        /// The height it leaves at.
        let leftAt: Double
        /// The height it arrives at the *next* place at. A carry runs between these
        /// two, so it slopes.
        let arrivesNextAt: Double
    }

    /// Which way round a face swap passes, by thread and which of its steps.
    /// **A promise, not geometry**: the one that moved later goes to its own right.
    struct SideStep: Hashable, Sendable {
        let thread: Int
        let step: Int
    }

    let steps: [Int: [Step]]
    /// How many hand-overs had to be raised a layer.
    let handOversRaisedALayer: Int
    let sideSteps: [SideStep: Double]
    let layersPerCycle: Int
    let section: BraidSection

    /// Two wefts crossing one column at one height. **The model says this cannot
    /// happen** — a column takes a landing and two passings in a cycle, so two
    /// wefts stand a diameter apart. Any that do are listed, not mended.
    let weftsSharingAHeight: [(column: Int, height: Double, threads: (Int, Int))]

    static func == (a: BraidConstruction, b: BraidConstruction) -> Bool {
        a.steps == b.steps && a.handOversRaisedALayer == b.handOversRaisedALayer
            && a.sideSteps == b.sideSteps && a.layersPerCycle == b.layersPerCycle
            && a.section == b.section
    }

    // MARK: - Building

    static func construct(
        of method: BraidMethod,
        on stand: BraidStand,
        crossSection: BraidCrossSection,
        fold: BraidFold?,
        cycles: Int,
        flatten: Bool = false
    ) -> BraidConstruction? {
        guard
            cycles > 0,
            let section = BraidSection.section(slotCount: crossSection.slotCount,
                                               fold: fold, flatten: flatten),
            let occupancy = BraidOccupancy.history(of: method, on: stand,
                                                   crossSection: crossSection,
                                                   cycles: cycles + 1),
            let stacking = BraidStacking.stacking(of: method, on: stand,
                                                  crossSection: crossSection,
                                                  fold: fold, cycles: cycles + 2)
        else { return nil }

        let k = stacking.layersPerCycle
        /// Where this thread's layer sits in that place's pile, as a height.
        func layer(slot: Int, cycle: Int, thread: Int) -> Double? {
            guard let pile = stacking.layersBySlot[slot]?[cycle] else { return nil }
            guard let index = pile.firstIndex(where: { $0.thread == thread }) else { return nil }
            return Double(cycle * k + index)
        }

        var boundaries = [[Int: Int]]()
        for boundary in 0...(cycles + 1) {
            guard let at = occupancy.slotByThread(atBoundary: boundary) else { return nil }
            boundaries.append(at)
        }

        var steps = [Int: [Step]]()
        for thread in boundaries[0].keys.sorted() {
            guard var here = boundaries[0][thread] else { return nil }
            var height = 0.0
            var way = [Step]()
            for cycle in 0..<cycles {
                guard let next = boundaries[cycle + 1][thread] else { return nil }
                // Where it lands this cycle, and where it leaves from.
                let landed = layer(slot: next, cycle: cycle, thread: thread)
                let left = layer(slot: here, cycle: cycle, thread: thread)
                // Only the closing moved it: the closing sends the braid on
                // neither round nor along, so it moves at the height it stands at.
                let arrive = landed ?? (left ?? height)
                let leave = left ?? arrive
                way.append(Step(slot: here, arrivedAt: height,
                                leftAt: leave, arrivesNextAt: arrive))
                here = next
                height = arrive
            }
            way.append(Step(slot: here, arrivedAt: height,
                            leftAt: height + Double(k), arrivesNextAt: height + Double(k)))
            steps[thread] = way
        }

        let lifted = handOver(&steps)
        let order = handOrder(of: method, on: stand, cycles: cycles)
        let sides = sideStep(steps: steps, section: section, hands: order)
        let clashes = weftsApart(steps: steps, section: section)

        return BraidConstruction(
            steps: steps, handOversRaisedALayer: lifted, sideSteps: sides,
            layersPerCycle: k, section: section, weftsSharingAHeight: clashes
        )
    }

    /// **Two threads never stand in the same spot at the same height.** Where one
    /// takes a place over from another, it arrives a layer above the one that left.
    private static func handOver(_ steps: inout [Int: [Step]]) -> Int {
        struct Entry { var height: Double; let thread: Int; let index: Int }
        var atSlot = [Int: [Entry]]()
        for (thread, way) in steps {
            for (index, step) in way.enumerated() {
                atSlot[step.slot, default: []]
                    .append(Entry(height: step.arrivedAt, thread: thread, index: index))
            }
        }
        var moved = 0
        for slot in atSlot.keys.sorted() {
            var entries = atSlot[slot]!
            entries.sort { ($0.height, $0.thread, $0.index) < ($1.height, $1.thread, $1.index) }
            for position in 1..<max(entries.count, 1) {
                let entry = entries[position]
                let before = entries[position - 1]
                let floor = steps[before.thread]![before.index].leftAt + 1
                guard entry.height < floor - 1e-9 else { continue }
                let mine = steps[entry.thread]![entry.index]
                steps[entry.thread]![entry.index] = Step(
                    slot: mine.slot, arrivedAt: floor,
                    leftAt: max(mine.leftAt, floor), arrivesNextAt: mine.arrivesNextAt
                )
                if entry.index > 0 {
                    let previous = steps[entry.thread]![entry.index - 1]
                    steps[entry.thread]![entry.index - 1] = Step(
                        slot: previous.slot, arrivedAt: previous.arrivedAt,
                        leftAt: previous.leftAt, arrivesNextAt: floor
                    )
                }
                entries[position].height = floor
                moved += 1
            }
            atSlot[slot] = entries
        }
        return moved
    }

    /// Which hand carried each thread each time it was braided, numbered over the
    /// whole run. **Only the order matters**, and the order is book C's.
    private static func handOrder(
        of method: BraidMethod, on stand: BraidStand, cycles: Int
    ) -> [SideStep: Int] {
        guard let worked = BraidWorking.cycles(of: method, on: stand, count: cycles)
        else { return [:] }
        let closing = method.instantCount
        var result = [SideStep: Int]()
        var turn = [Int: Int]()
        var hand = 0
        for cycle in worked {
            for carried in cycle.allCarried {
                hand += 1
                guard carried.instant != closing else { continue }
                let next = (turn[carried.thread] ?? -1) + 1
                turn[carried.thread] = next
                result[SideStep(thread: carried.thread, step: next)] = hand
            }
        }
        return result
    }

    /// A carry that crosses from one face to the other, and where its belly is.
    private static func swap(
        _ step: Step, _ next: Step, section: BraidSection
    ) -> (column: Double, height: Double)? {
        guard
            let here = section.places[step.slot], let there = section.places[next.slot],
            here.kind != there.kind, here.kind != .edge, there.kind != .edge
        else { return nil }
        return ((here.spot.x + there.spot.x) / 2, (step.leftAt + next.arrivedAt) / 2)
    }

    /// Two threads swapping faces in one column at one height pass each other
    /// **sideways**, half a thread each way. **Which way round is a promise**: the
    /// one that moved later goes to its own right.
    private static func sideStep(
        steps: [Int: [Step]], section: BraidSection, hands: [SideStep: Int]
    ) -> [SideStep: Double] {
        guard section.isFlat else { return [:] }
        struct Key: Hashable { let column: Int; let height: Int }
        var seen = [Key: SideStep]()
        var sides = [SideStep: Double]()
        for thread in steps.keys.sorted() {
            let way = steps[thread]!
            for index in 0..<(way.count - 1) {
                guard let belly = swap(way[index], way[index + 1], section: section)
                else { continue }
                let key = Key(column: Int(belly.column.rounded()),
                              height: Int((belly.height * 1000).rounded()))
                let mine = SideStep(thread: thread, step: index)
                guard let first = seen[key] else { seen[key] = mine; continue }
                let late = (hands[mine] ?? 0) > (hands[first] ?? 0) ? mine : first
                let early = late == mine ? first : mine
                sides[late] = 1
                sides[early] = -1
            }
        }
        return sides
    }

    private static func weftsApart(
        steps: [Int: [Step]], section: BraidSection
    ) -> [(column: Int, height: Double, threads: (Int, Int))] {
        guard section.isFlat else { return [] }
        struct Key: Hashable { let column: Int; let height: Int }
        var seen = [Key: Int]()
        var clashes = [(column: Int, height: Double, threads: (Int, Int))]()
        for thread in steps.keys.sorted() {
            let way = steps[thread]!
            for index in 0..<(way.count - 1) {
                guard let belly = swap(way[index], way[index + 1], section: section)
                else { continue }
                let column = Int(belly.column.rounded())
                let key = Key(column: column, height: Int((belly.height * 1000).rounded()))
                if let first = seen[key] {
                    clashes.append((column, belly.height, (first, thread)))
                } else {
                    seen[key] = thread
                }
            }
        }
        return clashes
    }
}
