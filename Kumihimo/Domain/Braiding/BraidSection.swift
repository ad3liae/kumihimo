import Foundation

/// Where each slot of the cross-section stands, and which way is out of the braid
/// there. Lengths are in thread diameters.
///
/// **The tube and the flat braid are the same statement read two ways.** Sixteen
/// threads standing side by side round a tube have their centres on a regular
/// sixteen-sided figure of side d; the same ring folded flat lays six across each
/// face with one thread at each edge on each side, and the two faces touch.
///
/// **Nothing here is chosen.** The radius is the polygon's, the fold is
/// `BraidFold`'s, and the flattening is the section keeping its area.
struct BraidSection: Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        /// A tube: one surface, and its normal is radial.
        case round
        case front
        case back
        /// Where the braid turns back on itself. **Two threads, not one** — they
        /// sit on the two sides like every other column.
        case edge
    }

    struct Place: Equatable, Sendable {
        /// Across the braid and through it, in thread diameters.
        let spot: SIMD2<Double>
        /// Out of the braid at that place. **A crest goes this way and never the
        /// other** (`docs/architecture.md`, 山は糸の半径から出る).
        let outward: SIMD3<Double>
        let kind: Kind
    }

    let places: [Int: Place]

    /// How much room a thread takes across the braid, centre to centre when two of
    /// them touch. `d` unless the threads are pressed together.
    let threadWidth: Double
    /// The same through the braid's thickness.
    let threadThickness: Double

    var isFlat: Bool { places.values.contains { $0.kind == .front || $0.kind == .back } }

    /// How wide and how thick a thread is once it is pressed against its
    /// neighbours.
    ///
    /// **Silk is a bundle, not a rod.** Where threads are pressed side by side they
    /// spread: a face `width` diameters across carrying `faceThreads` of them gives
    /// each `width / faceThreads`, and **the section keeps its area**, so the
    /// thickness is `d^2 / w`. **The edges and the tube are not pressed**, so they
    /// keep the diameter they would have if they were round again.
    static func flattened(width: Double, faceThreads: Int) -> (width: Double, thickness: Double) {
        guard faceThreads > 0, width > 0 else { return (1, 1) }
        let w = width / Double(faceThreads)
        return (w, 1 / w)
    }

    /// Works the section out of the fold, or out of the ring when there is none.
    ///
    /// `flatten` presses the faces together; a tube is never pressed.
    static func section(
        slotCount: Int, fold: BraidFold?, flatten: Bool = false
    ) -> BraidSection? {
        guard slotCount > 0 else { return nil }
        guard let fold else {
            let radius = 1 / (2 * sin(.pi / Double(slotCount)))
            var places = [Int: Place]()
            for slot in 0..<slotCount {
                let angle = 2 * Double.pi * Double(slot) / Double(slotCount)
                places[slot] = Place(
                    spot: SIMD2(radius * cos(angle), radius * sin(angle)),
                    outward: SIMD3(cos(angle), sin(angle), 0),
                    kind: .round
                )
            }
            return BraidSection(places: places, threadWidth: 1, threadThickness: 1)
        }

        // A face is as wide as it has threads standing across it, and the flat
        // braid is the ring folded in half.
        let faceThreads = fold.columnCount
        let width = Double(slotCount) / 2
        let pressed = flatten
            ? flattened(width: width, faceThreads: faceThreads)
            : (width: 1.0, thickness: 1.0)
        let middle = (Double(fold.columnCount) - 1) / 2

        var places = [Int: Place]()
        var sideTaken = [Int: Int]()
        for slot in 0..<slotCount {
            guard let across = fold.width(ofSlot: slot) else { return nil }
            if let face = fold.face(ofSlot: slot) {
                let sign = face == .front ? 1.0 : -1.0
                places[slot] = Place(
                    spot: SIMD2(Double(across) * pressed.width, sign * pressed.thickness / 2),
                    outward: SIMD3(0, sign, 0),
                    kind: face == .front ? .front : .back
                )
            } else {
                // An edge is two threads over two diameters, so it is not pressed.
                let side = sideTaken[across, default: 0]
                sideTaken[across] = side + 1
                places[slot] = Place(
                    spot: SIMD2(Double(across), side == 0 ? 0.5 : -0.5),
                    outward: SIMD3(Double(across) < middle ? -1 : 1, 0, 0),
                    kind: .edge
                )
            }
        }
        return BraidSection(places: places, threadWidth: pressed.width,
                            threadThickness: pressed.thickness)
    }

    /// Where a carry goes when it crosses from one face to the other: through the
    /// middle, which is the neutral plane. **The belly is an empty layer except
    /// where a weft is crossing it.**
    static func belly(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> SIMD2<Double> {
        SIMD2((a.x + b.x) / 2, 0)
    }
}
