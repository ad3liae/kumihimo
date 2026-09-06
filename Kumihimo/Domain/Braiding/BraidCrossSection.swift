import Foundation

/// The order the threads come in round the braid, one slot to a thread.
///
/// **This is a ring and nothing else.** It has no front, no back and no edges; a
/// braid that is a tube is fully described by it, and a braid that is flat is this
/// same ring folded — which is a consequence of how the thread pulls and tucks at
/// the braiding point, not something the move table says. So the fold is worked
/// out from the ring and the courses (`BraidFold`), never declared.
struct BraidCrossSection: Equatable, Sendable {
    /// Stand positions in the order they come round the braid.
    let order: [Int]
    let source: Source

    /// What about this order is not yet settled, if anything.
    ///
    /// **A working answer is still an answer, but it must say it is working.**
    /// This is a note for the people reading the code and for whatever shows the
    /// braid; it is not display text, so a view writes its own wording rather
    /// than printing this.
    let unsettled: String?

    init(order: [Int], source: Source, unsettled: String? = nil) {
        self.order = order
        self.source = source
        self.unsettled = unsettled
    }

    enum Source: Equatable, Sendable {
        /// The default: the stand's own rim order, taken straight across. A braid
        /// worked without anything else said about it comes out as a tube.
        case standRim
        /// An order read off a reference. Say which one; a derived figure and a
        /// figure read off a photograph must never be told apart by guesswork.
        case reference(String)
    }

    var slotCount: Int { order.count }

    func slotIndex(ofPositionID id: Int) -> Int? {
        order.firstIndex(of: id)
    }

    func positionID(atSlot slot: Int) -> Int? {
        order.indices.contains(slot) ? order[slot] : nil
    }

    /// The stand's rim order taken straight across.
    static func tube(of stand: BraidStand) -> BraidCrossSection {
        BraidCrossSection(order: stand.positionIDs, source: .standRim)
    }

    var isWellFormed: Bool { Set(order).count == order.count && !order.isEmpty }

    /// Whether a figure taken from this cross-section rests on a measurement or on
    /// a reference. Shown rather than hidden.
    var isDeclared: Bool {
        if case .reference = source { return true }
        return false
    }

    var isSettled: Bool { unsettled == nil }

    /// Whether two runs round the ring have to pass each other.
    ///
    /// They do when their ends alternate round the ring: one thread cannot get
    /// from its start to its finish without crossing the other. Two runs that
    /// lie side by side, or one wholly inside the other's span, never meet.
    func runsMustPassEachOther(
        _ first: (from: Int, to: Int),
        _ second: (from: Int, to: Int)
    ) -> Bool {
        func isInsideTheArc(_ slot: Int, from start: Int, to end: Int) -> Bool {
            let span = (end - start + slotCount) % slotCount
            let offset = (slot - start + slotCount) % slotCount
            return offset > 0 && offset < span
        }
        // The run cuts the ring in two. The other run crosses it exactly when one
        // of its ends is on each side.
        let onOneSide = [second.from, second.to].filter {
            isInsideTheArc($0, from: first.from, to: first.to)
        }
        return onOneSide.count == 1
    }
}

/// Which side of a flat braid a slot is on.
enum BraidFace: String, Equatable, Sendable, CaseIterable {
    case front
    case back

    var opposite: BraidFace { self == .front ? .back : .front }
}

/// A flat braid: the ring cut at two places and laid out across a width.
///
/// **Derived, never declared.** A thread that keeps to one pair of slots for the
/// whole repeat runs along the braid, and its two slots lie one behind the other
/// through the thickness. Those pairs, taken together, are a reflection of the
/// ring; where the reflection's axis crosses the ring is where the braid turns
/// back on itself, which is an edge. A braid with no such thread — every thread
/// travelling — determines no reflection, no axis and no edges, and stays a tube.
struct BraidFold: Equatable, Sendable {
    /// Across the width, edges included: the slots at one edge are at `-1` and the
    /// slots at the other at `columnCount`, so a course can be measured without a
    /// special case. A step of one is a turn at an edge; a longer step crosses the
    /// braid.
    let widthBySlot: [Int]
    /// `nil` at a turning slot, which is on neither face.
    let faceBySlot: [BraidFace?]
    /// The four slots at the two edges — two at each, one behind the other.
    let turningSlots: Set<Int>
    let columnCount: Int

    func width(ofSlot slot: Int) -> Int? {
        widthBySlot.indices.contains(slot) ? widthBySlot[slot] : nil
    }

    func face(ofSlot slot: Int) -> BraidFace? {
        faceBySlot.indices.contains(slot) ? faceBySlot[slot] : nil
    }

    /// The column across a face, or `nil` at an edge. Columns are counted on the
    /// same axis as the widths, so both faces number them the same way round.
    func column(ofSlot slot: Int) -> Int? {
        guard let width = width(ofSlot: slot), (0..<columnCount).contains(width) else {
            return nil
        }
        return width
    }

    /// Folds the ring given the pairs of slots that lie through the thickness.
    ///
    /// `nil` when there are no pairs to go on, when they do not agree on one
    /// reflection, or when that reflection's axis runs through a slot rather than
    /// between two — the braid is then not flat in this sense, and saying so is
    /// the right answer rather than forcing a fold on it.
    static func folding(slotCount: Int, throughThicknessPairs pairs: Set<Set<Int>>) -> BraidFold? {
        guard slotCount > 0, slotCount.isMultiple(of: 2), !pairs.isEmpty else { return nil }

        // Every pair of a reflection of the ring has the same index sum, modulo
        // the ring. Disagreement means the pairs are not a reflection at all.
        var sums = Set<Int>()
        for pair in pairs {
            let members = pair.sorted()
            guard members.count == 2 else { return nil }
            sums.insert((members[0] + members[1]) % slotCount)
        }
        guard sums.count == 1, let sum = sums.first else { return nil }

        // An odd sum on an even ring has no fixed slot, so the axis falls between
        // two slots. An even sum would put the axis through a slot, which is a
        // different shape and not one either known braid has.
        guard !sum.isMultiple(of: 2) else { return nil }

        let half = slotCount / 2
        // The axis crosses between `cut` and `cut + 1`, and again half a turn on.
        let cut = ((sum - 1) / 2 + slotCount) % slotCount
        let otherCut = (cut + half) % slotCount
        let columnCount = half - 2
        guard columnCount > 0 else { return nil }

        var widths = [Int](repeating: 0, count: slotCount)
        var faces = [BraidFace?](repeating: nil, count: slotCount)

        // Walk one half of the ring from just past a cut. Its first and last slot
        // are the ones the braid turns at, so they take the width one step outside
        // the columns. The other half is the reflection of this one, which is what
        // "folded" means: paired slots lie at the same place across the width, one
        // behind the other through the thickness.
        let start = (otherCut + 1) % slotCount
        var arc = [Int]()
        for offset in 0..<half {
            let slot = (start + offset) % slotCount
            arc.append(slot)
            widths[slot] = offset - 1
            widths[((sum - slot) % slotCount + slotCount) % slotCount] = offset - 1
        }
        let turning = Set(
            [arc[0], arc[half - 1]].flatMap { slot in
                [slot, ((sum - slot) % slotCount + slotCount) % slotCount]
            }
        )

        // The half holding the first slot of the declared order is the front. That
        // is the one naming choice in the whole derivation, and it is the same one
        // the older per-braid map carried: it says which way round to look, not
        // what shape the braid is.
        let firstHalf = Set(arc)
        let frontIsFirstHalf = firstHalf.contains(0)
        for slot in 0..<slotCount where !turning.contains(slot) {
            let inFirst = firstHalf.contains(slot)
            faces[slot] = (inFirst == frontIsFirstHalf) ? .front : .back
        }

        return BraidFold(
            widthBySlot: widths,
            faceBySlot: faces,
            turningSlots: turning,
            columnCount: columnCount
        )
    }
}
