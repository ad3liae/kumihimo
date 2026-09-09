/// **Research, for the version that invents its own braids** (Task 025-4, 2026-09-09).
///
/// This is not on the product's drawing path and no screen reaches it. The author's
/// judgement of 2026-09-09, after putting the two paths side by side: **what this
/// construction puts on the face is a row of upright bars, and a photograph shows
/// slanted thread runs.** The construction rests a thread lengthwise at a place and
/// carries it inside, so no crest and no flattening closes that gap — **it needs a
/// construction where a thread runs across the face at a slant.**
///
/// It is kept because it earned its keep: read by the procedure in
/// `docs/measurement-procedures.md` section 5, it reproduced book A p97's three
/// experiments on both faces and Task 004's eight by four cell for cell. Those are
/// agreements about **which thread is at which cell**, not about how a cell looks.
import Foundation

/// The finished centrelines: every thread as a polyline, with the crest on.
///
/// **The crest comes out of the thread's own radius**
/// (`docs/architecture.md`, 山は糸の半径から出る). Where a thread passes under a
/// resting one, the resting one rides over it — **outwards along its face's normal
/// and never inwards**, which is why an over and an under can never swap. The shape
/// is the arc round the thread underneath brought back to the line it was on, so
/// **its width is geometry**: a thread of half-clearance `w` across and `t` through,
/// lying `s` off the line, leaves a crest `t*sqrt(1 - (u/w)^2) - s` high, hence
/// `2w*sqrt(1 - (s/t)^2)` wide. Where several meet, **the highest wins; they do not
/// add.**
struct BraidCentrelines: Equatable, Sendable {
    /// What a point of a thread is doing there.
    enum Kind: Int, Equatable, Sendable {
        case restingOnTheSurface = 0
        case carriedInside = 1
    }

    let points: [Int: [SIMD3<Double>]]
    let kinds: [Int: [Kind]]
    /// How many crests were raised.
    let crests: Int
    let construction: BraidConstruction
    /// What the crest was drawn at, and where that came from.
    let crestHeight: BraidMeasurement

    /// How finely a piece is drawn, so a crest is a shape rather than a corner.
    static let fine = 1.0 / 8

    /// What the construction says a crest is, before any measurement: **a thread
    /// lying on a surface stands half its own diameter proud of it**. This is not a
    /// number chosen to look right — it falls out of the thread's radius and the
    /// half a diameter a weft in the belly lies below the face.
    static let derivedCrestHeight = BraidMeasurement.derived(
        0.5, basis: .threadDiameters,
        by: "half the thread's diameter: the arc round a thread lying d/2 below"
    )

    /// A measured crest height, in diameters, replacing the derived one.
    ///
    /// **The measurement has to be in diameters**, and a measurement in any other
    /// unit is not converted here — converting it would be inventing the
    /// conversion. A braid whose measured crest is a fraction of something else
    /// keeps the derived height, and its own value says so; which braids those are
    /// is written beside the values, in the catalogue.
    static func rise(for measured: BraidMeasurement?) -> (scale: Double, height: BraidMeasurement) {
        guard let measured, measured.isObserved, measured.isInThreadDiameters,
              derivedCrestHeight.value > 0
        else {
            return (1, derivedCrestHeight)
        }
        return (measured.value / derivedCrestHeight.value, measured)
    }

    var threads: [Int] { points.keys.sorted() }

    // MARK: - The pieces

    /// A rest as the line up the surface, and the carry that leaves it.
    struct Piece: Equatable, Sendable {
        let rest: (from: SIMD3<Double>, to: SIMD3<Double>)
        let outward: SIMD3<Double>
        /// The corners of the carry to the next place, or empty at the last rest.
        let carry: [SIMD3<Double>]

        static func == (a: Piece, b: Piece) -> Bool {
            a.rest == b.rest && a.outward == b.outward && a.carry == b.carry
        }
    }

    static func pieces(
        thread: Int, of construction: BraidConstruction
    ) -> [Piece]? {
        guard let way = construction.steps[thread] else { return nil }
        let section = construction.section
        var result = [Piece]()
        for (index, step) in way.enumerated() {
            guard let here = section.places[step.slot] else { return nil }
            let rest = (SIMD3(here.spot.x, here.spot.y, step.arrivedAt),
                        SIMD3(here.spot.x, here.spot.y, step.leftAt))
            var carry = [SIMD3<Double>]()
            if index + 1 < way.count {
                let next = way[index + 1]
                guard let there = section.places[next.slot] else { return nil }
                carry.append(rest.1)
                if section.isFlat, here.kind != there.kind,
                   here.kind != .edge, there.kind != .edge {
                    // Through the neutral plane, and half a thread to one side.
                    let middle = BraidSection.belly(here.spot, there.spot)
                    let across = construction.sideSteps[
                        BraidConstruction.SideStep(thread: thread, step: index)
                    ] ?? 0
                    carry.append(SIMD3(middle.x + across * section.threadWidth / 2,
                                       middle.y,
                                       (step.leftAt + next.arrivedAt) / 2))
                }
                carry.append(SIMD3(there.spot.x, there.spot.y, next.arrivedAt))
            }
            result.append(Piece(rest: rest, outward: here.outward, carry: carry))
        }
        return result
    }

    // MARK: - The crest

    /// The closest points of two segments, and the gap between them.
    static func closest(
        _ p0: SIMD3<Double>, _ p1: SIMD3<Double>,
        _ q0: SIMD3<Double>, _ q1: SIMD3<Double>
    ) -> (along: Double, other: Double, gap: SIMD3<Double>) {
        let d1 = p1 - p0, d2 = q1 - q0, rr = p0 - q0
        let a = (d1 * d1).sum(), e = (d2 * d2).sum()
        let f = (d2 * rr).sum(), c = (d1 * rr).sum(), b = (d1 * d2).sum()
        let denom = a * e - b * b
        var s = denom > 1e-12 ? min(max((b * f - c * e) / denom, 0), 1) : 0
        var t = (b * s + f) / max(e, 1e-12)
        if t < 0 { s = min(max(-c / max(a, 1e-12), 0), 1) }
        if t > 1 { s = min(max((b - c) / max(a, 1e-12), 0), 1) }
        t = min(max(t, 0), 1)
        return (s, t, (p0 + s * d1) - (q0 + t * d2))
    }

    /// One resting piece, drawn with whatever rides over it.
    ///
    /// `laterThan` says whether this rest was laid after the piece it is meeting:
    /// **two that meet on the same face at the same height are parted by book C's
    /// order**, and the one laid later comes out over the other.
    static func crest(
        rest: (from: SIMD3<Double>, to: SIMD3<Double>),
        outward: SIMD3<Double>,
        others: [(rank: Double, line: [SIMD3<Double>])],
        width w: Double,
        thickness t: Double,
        scale: Double = 1,
        laterThan: (Double) -> Bool
    ) -> (points: [SIMD3<Double>], crests: Int) {
        let span = rest.to - rest.from
        let total = (span * span).sum().squareRoot()
        guard total > 1e-9 else { return ([rest.from, rest.to], 0) }
        let count = max(2, Int((total / fine).rounded(.up)) + 1)
        // Stepped the way the Python steps it, so the two agree bit for bit and a
        // point on a slab's edge falls the same side in both.
        var along = [Double](repeating: 0, count: count)
        let step = total / Double(count - 1)
        for index in 0..<count { along[index] = Double(index) * step }
        along[count - 1] = total
        var rise = [Double](repeating: 0, count: count)
        var raised = 0

        for other in others {
            let later = laterThan(other.rank)
            for leg in 0..<max(other.line.count - 1, 0) {
                let a = other.line[leg], b = other.line[leg + 1]
                let met = closest(rest.from, rest.to, a, b)
                let far = (met.gap * met.gap).sum().squareRoot()
                if far >= max(w, t) { continue }
                let here = rest.from + met.along * span
                let there = a + met.other * (b - a)
                let outside = ((there - here) * outward).sum()
                // It is outside this one, and it was there first.
                if outside > 1e-9 && !later { continue }
                let s = abs(outside)
                if s >= t { continue }
                let at = met.along * total
                let half = w * (max(1 - (s / t) * (s / t), 0)).squareRoot()
                for index in 0..<count {
                    let x = min(abs(along[index] - at) / max(half, 1e-9), 1)
                    let shape = max(t * (max(1 - x * x, 0)).squareRoot() - s, 0)
                    rise[index] = max(rise[index], shape)
                }
                raised += 1
            }
        }
        var points = [SIMD3<Double>]()
        for index in 0..<count {
            points.append(rest.from + span * (along[index] / total)
                          + outward * (rise[index] * scale))
        }
        return (points, raised)
    }

    // MARK: - Building

    static func centrelines(
        of construction: BraidConstruction, crestHeight measured: BraidMeasurement? = nil
    ) -> BraidCentrelines? {
        let (scale, height) = rise(for: measured)
        let section = construction.section
        let w = section.threadWidth, t = section.threadThickness

        var byThread = [Int: [Piece]]()
        var everything = [(thread: Int, rank: Double, line: [SIMD3<Double>])]()
        for thread in construction.steps.keys.sorted() {
            guard let mine = pieces(thread: thread, of: construction) else { return nil }
            byThread[thread] = mine
            guard let way = construction.steps[thread] else { return nil }
            for (index, piece) in mine.enumerated() {
                everything.append((thread, way[index].arrivedAt, [piece.rest.0, piece.rest.1]))
                if !piece.carry.isEmpty {
                    everything.append((thread, way[index].leftAt, piece.carry))
                }
            }
        }

        var points = [Int: [SIMD3<Double>]]()
        var kinds = [Int: [Kind]]()
        var crests = 0
        for thread in construction.steps.keys.sorted() {
            let others = everything.filter { $0.thread != thread }
                .map { (rank: $0.rank, line: $0.line) }
            guard let mine = byThread[thread], let way = construction.steps[thread]
            else { return nil }
            var drawn = [SIMD3<Double>]()
            var mark = [Kind]()
            for (index, piece) in mine.enumerated() {
                let arrived = way[index].arrivedAt
                var (line, raised) = crest(
                    rest: piece.rest, outward: piece.outward, others: others,
                    width: w, thickness: t, scale: scale,
                    laterThan: { arrived > $0 + 1e-9 }
                )
                crests += raised
                if let last = drawn.last, let first = line.first,
                   ((last - first) * (last - first)).sum().squareRoot() < 1e-9 {
                    line.removeFirst()
                }
                drawn.append(contentsOf: line)
                mark.append(contentsOf: [Kind](repeating: .restingOnTheSurface,
                                               count: line.count))
                guard !piece.carry.isEmpty else { continue }
                let resampled = evenly(piece.carry).dropFirst()
                drawn.append(contentsOf: resampled)
                mark.append(contentsOf: [Kind](repeating: .carriedInside,
                                               count: resampled.count))
            }
            points[thread] = drawn
            kinds[thread] = mark
        }
        return BraidCentrelines(points: points, kinds: kinds, crests: crests,
                                construction: construction, crestHeight: height)
    }

    /// A polyline drawn again with its points a `fine` step apart along it.
    static func evenly(_ line: [SIMD3<Double>]) -> [SIMD3<Double>] {
        guard line.count > 1 else { return line }
        var along = [0.0]
        for leg in 1..<line.count {
            let step = line[leg] - line[leg - 1]
            along.append(along[leg - 1] + (step * step).sum().squareRoot())
        }
        let total = along[along.count - 1]
        guard total > 1e-12 else { return line }
        let count = max(2, Int((total / fine).rounded(.up)) + 1)
        var out = [SIMD3<Double>]()
        let step = total / Double(count - 1)
        for index in 0..<count {
            let want = index == count - 1 ? total : Double(index) * step
            var leg = 1
            while leg < along.count - 1 && along[leg] < want { leg += 1 }
            let span = along[leg] - along[leg - 1]
            let part = span > 1e-12 ? (want - along[leg - 1]) / span : 0
            out.append(line[leg - 1] + (line[leg] - line[leg - 1]) * part)
        }
        return out
    }
}
