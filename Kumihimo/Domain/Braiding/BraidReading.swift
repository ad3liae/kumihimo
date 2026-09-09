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

/// Reading the face off the picture.
///
/// **The procedure is the one in `docs/measurement-procedures.md`, section 5**, and
/// it is not to be reinvented: the body is the occupancy history's, a column is
/// measured on its own picture's axis, a tube is viewed along the slots a hand
/// lands on, each column is read at its own rest, and the reading starts where the
/// braid has settled into its pitch.
///
/// **Only where to look comes from the construction. What is there is whatever the
/// picture has in front.**
enum BraidReading {
    /// How much of a face's body is painted by threads worked lengthwise.
    struct FaceCount: Equatable, Sendable {
        let lengthwise: Int
        let painted: Int
        var percent: Double { painted > 0 ? 100 * Double(lengthwise) / Double(painted) : 0 }
    }

    /// Reads the columns of the body off one face.
    ///
    /// `widths` are the body's columns — **the occupancy history's, not the
    /// picture's**: on a sixteen-thread flat braid they are one to four, and the
    /// outermost column on each side is where a weft stands, which is edging and is
    /// meant to take colour.
    static func face(
        _ picture: BraidPicture,
        section: BraidSection,
        widths: [Int],
        worry: Int = 3,
        workedLengthwise: (Int) -> Bool
    ) -> FaceCount {
        var lengthwise = 0, painted = 0
        for width in widths {
            let spot = SIMD3(Double(width) * section.threadWidth, 0, 0)
            guard let middle = picture.column(ofSpot: spot) else { continue }
            for row in 0..<picture.height {
                for column in max(middle - worry, 0)...min(middle + worry, picture.width - 1) {
                    guard let thread = picture.thread(atPixel: column, row: row) else { continue }
                    painted += 1
                    if workedLengthwise(thread) { lengthwise += 1 }
                }
            }
        }
        return FaceCount(lengthwise: lengthwise, painted: painted)
    }

    /// Where each column's rows stand, and the row to start reading at.
    ///
    /// **The columns do not change over at the same height**: a slot's resting
    /// thread changes when a hand lands there, and the hands of one cycle do not
    /// land together. A line drawn across the braid cuts the columns at different
    /// points of the cycle, so it is not one row at all.
    ///
    /// The first rests at a slot are the seed being taken up, and their spacing is
    /// not yet the cycle's. **The row to start at is the first from which every
    /// column's spacing is k** — read off the heights, not chosen.
    static func rows(
        of construction: BraidConstruction, atColumns columns: [Int]
    ) -> (heights: [[Double]], settled: Int)? {
        var heights = [[Double]]()
        var settled = 0
        for slot in columns {
            var arrivals = [Double]()
            for (_, way) in construction.steps {
                for step in way where step.slot == slot { arrivals.append(step.arrivedAt) }
            }
            arrivals.sort()
            guard arrivals.count > 1 else { return nil }
            var first = 0
            for gap in stride(from: arrivals.count - 2, through: 0, by: -1) {
                if abs(arrivals[gap + 1] - arrivals[gap] - Double(construction.layersPerCycle)) > 1e-9 {
                    first = gap + 1
                    break
                }
            }
            settled = max(settled, first)
            heights.append(arrivals)
        }
        return (heights, settled)
    }

    /// The thread showing at the middle of the silhouette, at one height.
    ///
    /// **The middle of the silhouette is the point of the tube nearest the eye**,
    /// which is the place the view is aimed at.
    static func middleOfSilhouette(
        _ picture: BraidPicture, atHeight height: Double, worry: Int = 4
    ) -> Int? {
        let row = min(max(Int((height - picture.along.lowerBound)
                              * Double(picture.pixelsPerDiameter)), 0), picture.height - 1)
        let painted = (0..<picture.width).filter { picture.thread(atPixel: $0, row: row) != nil }
        let centre = painted.isEmpty
            ? picture.width / 2
            : Int((painted.reduce(0, +) / painted.count))
        var tally = [Int: Int]()
        for column in max(centre - worry, 0)..<min(centre + worry, picture.width) {
            guard let thread = picture.thread(atPixel: column, row: row) else { continue }
            tally[thread, default: 0] += 1
        }
        // The commonest, ties to the smaller thread number, as the Python takes it.
        return tally.sorted { ($0.value, -$0.key) > ($1.value, -$1.key) }.first?.key
    }

    /// **The two faces must be built alike**: every resting place the same distance
    /// from the middle, every crest going out of its own face, and the crests
    /// reaching as far one way as the other.
    static func facesBuiltAlike(_ lines: BraidCentrelines) -> [String] {
        var trouble = [String]()
        for (slot, place) in lines.construction.section.places {
            switch place.kind {
            case .front where place.spot.y < 0:
                trouble.append("place \(slot) is on the wrong side of the middle")
            case .back where place.spot.y > 0:
                trouble.append("place \(slot) is on the wrong side of the middle")
            case .front where place.outward.y <= 0, .back where place.outward.y >= 0:
                trouble.append("place \(slot)'s normal does not follow its face")
            default: break
            }
        }
        let ups = lines.construction.section.places.values
            .filter { $0.kind == .front }.map { abs($0.spot.y) }
        let downs = lines.construction.section.places.values
            .filter { $0.kind == .back }.map { abs($0.spot.y) }
        if let up = ups.max(), let down = downs.max(), abs(up - down) > 1e-9 {
            trouble.append("the two faces are not the same distance from the middle")
        }
        var out = 0.0, back = 0.0
        for thread in lines.threads {
            for (point, kind) in zip(lines.points[thread]!, lines.kinds[thread]!)
            where kind == .restingOnTheSurface {
                out = max(out, point.y); back = min(back, point.y)
            }
        }
        if !ups.isEmpty, abs(out + back) > 1e-6 {
            trouble.append("the crests do not reach as far one way as the other")
        }
        return trouble
    }
}
