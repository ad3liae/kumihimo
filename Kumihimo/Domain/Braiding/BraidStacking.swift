import Foundation

/// How far the braid grows in one cycle, in thread diameters.
///
/// **A thread passing a slot takes up the thread's own thickness there**, whether
/// it lands on that slot or only crosses it. So the layers standing at a slot in
/// one cycle are the arrivals *and* the passings, and the tallest such pile is how
/// far the braid has moved on. **k is counted, never written down** — counting only
/// the landings gives k = 1 and a pitch a third of what the books measure
/// (`docs/tasks/020-general-braid-simulator.md`, 導出の前提).
struct BraidStacking: Equatable, Sendable {
    /// One thread standing at a slot: which braiding move of the cycle carried it,
    /// and which thread it is. The move's ordinal is the order the source of record
    /// works them in, so a larger one was laid on a smaller.
    struct Layer: Equatable, Sendable, Comparable {
        let ordinal: Int
        let thread: Int

        static func < (a: Layer, b: Layer) -> Bool {
            (a.ordinal, a.thread) < (b.ordinal, b.thread)
        }
    }

    /// slot -> cycle -> the layers standing there, in the order they arrived.
    let layersBySlot: [Int: [Int: [Layer]]]

    /// **k**: the most layers any one slot carries in one cycle.
    let layersPerCycle: Int

    /// The width the braid is measured across, in thread diameters.
    ///
    /// **Both readings come from the slot count and the thread's diameter.** A flat
    /// braid folds its ring in half and lays the halves side by side, so it is half
    /// the slots wide. A tube's slots stand on a regular polygon of side d, whose
    /// circumdiameter is `d / sin(pi/n)`; the thread's own thickness adds one more.
    let braidWidth: Double

    /// One cycle's growth, in thread diameters: **k x d**.
    var pitchPerCycle: BraidMeasurement {
        .derived(Double(layersPerCycle),
                 by: "the stacking model: k layers of a thread's diameter, k counted")
    }

    /// One cycle's growth as a fraction of the braid's width, which is the form the
    /// books give it in.
    var pitchPerBraidWidth: BraidMeasurement {
        .derived(Double(layersPerCycle) / braidWidth,
                 by: "the stacking model: k x d over the braid's width, both derived")
    }

    /// Which slots a carry occupies: where it lands, and what it passes on the way.
    ///
    /// The slot it leaves is not one of them. Measured on the cross-section the
    /// braid actually has — across the width when it is folded, round the ring when
    /// it is a tube.
    static func slotsOccupied(
        from: Int, to: Int, slotCount: Int, fold: BraidFold?
    ) -> [Int]? {
        guard let fold else {
            let forward = ((to - from) % slotCount + slotCount) % slotCount
            let backward = ((from - to) % slotCount + slotCount) % slotCount
            let step = forward <= backward ? 1 : -1
            let reach = min(forward, backward)
            guard reach > 0 else { return [] }
            return (1...reach).map { ((from + step * $0) % slotCount + slotCount) % slotCount }
        }
        guard let here = fold.width(ofSlot: from), let there = fold.width(ofSlot: to)
        else { return nil }
        if here == there { return [to] }
        // A carry crossing the braid runs under one face, so it passes the slots of
        // that face and the turning slots, and not the other face's.
        let half = fold.face(ofSlot: to) ?? fold.face(ofSlot: from)
        let step = there > here ? 1 : -1
        var result = [Int]()
        var width = here + step
        while width != there + step {
            for slot in 0..<slotCount where fold.width(ofSlot: slot) == width {
                let face = fold.face(ofSlot: slot)
                if face == nil || face == half { result.append(slot) }
            }
            width += step
        }
        return result
    }

    /// Works the piles out of the moves. `nil` when the cross-section and the moves
    /// do not fit together, which is worth stopping over.
    static func stacking(
        of method: BraidMethod,
        on stand: BraidStand,
        crossSection: BraidCrossSection,
        fold: BraidFold?,
        cycles count: Int
    ) -> BraidStacking? {
        guard count > 1, let worked = BraidWorking.cycles(of: method, on: stand, count: count),
              let occupancy = BraidOccupancy.history(of: method, on: stand,
                                                     crossSection: crossSection,
                                                     cycles: count)
        else { return nil }

        var slotOfPosition = [Int: Int]()
        for (slot, position) in crossSection.order.enumerated() {
            slotOfPosition[position] = slot
        }
        let slotCount = crossSection.slotCount
        let closingOrdinal = method.instantCount

        var piles = [Int: [Int: [Layer]]]()
        for cycle in 0..<(count - 1) {
            // The braiding moves of this cycle, in the order the source works them.
            var ordinalOfThread = [Int: Int]()
            var next = 0
            for carried in worked[cycle].allCarried where carried.instant != closingOrdinal {
                next += 1
                ordinalOfThread[carried.thread] = next
            }
            guard
                let here = occupancy.slotByThread(atBoundary: cycle),
                let there = occupancy.slotByThread(atBoundary: cycle + 1)
            else { return nil }
            for (thread, ordinal) in ordinalOfThread {
                guard let from = here[thread], let to = there[thread],
                      let slots = slotsOccupied(from: from, to: to,
                                                slotCount: slotCount, fold: fold)
                else { return nil }
                for slot in slots {
                    piles[slot, default: [:]][cycle, default: []]
                        .append(Layer(ordinal: ordinal, thread: thread))
                }
            }
        }
        for slot in piles.keys {
            for cycle in piles[slot]!.keys { piles[slot]![cycle]!.sort() }
        }

        let tallest = piles.values.flatMap(\.values).map(\.count).max()
        guard let layersPerCycle = tallest, layersPerCycle > 0 else { return nil }

        let width: Double
        if fold == nil {
            width = 1.0 / sin(Double.pi / Double(slotCount)) + 1.0
        } else {
            width = Double(slotCount) / 2.0
        }

        return BraidStacking(layersBySlot: piles, layersPerCycle: layersPerCycle,
                             braidWidth: width)
    }
}

extension BraidOccupancy {
    /// Which slot each thread rests at, at one cycle boundary.
    func slotByThread(atBoundary boundary: Int) -> [Int: Int]? {
        guard boundaries.indices.contains(boundary) else { return nil }
        var result = [Int: Int]()
        for (slot, thread) in boundaries[boundary] { result[thread] = slot }
        return result
    }
}
