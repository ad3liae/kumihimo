import Foundation

/// Draws the braid and says which thread is in front at each pixel.
///
/// **The face is what you would see**, so the threads are painted as solid bodies —
/// capsules when they are round, elliptical cylinders when they are pressed — with
/// a depth buffer. **Nothing is inferred about which thread is outermost: whichever
/// one is actually in front is in front.** Parallel projection, one flat colour a
/// thread, no shading.
///
/// This is a reading tool. It replaced asking the construction which thread ought
/// to show, because that question was answered by a rule and the rule was the thing
/// under test (`docs/measurement-procedures.md`, section 5).
struct BraidPicture: Equatable, Sendable {
    /// The thread at each pixel, or `nil` where nothing was painted. Row 0 is the
    /// bottom of the picture.
    let seen: [[Int?]]
    let width: Int
    let height: Int
    /// The picture's own frame, in thread diameters.
    let across: ClosedRange<Double>
    let along: ClosedRange<Double>
    let pixelsPerDiameter: Int
    /// Across the page, up the page, and into it.
    let u: SIMD3<Double>
    let v: SIMD3<Double>
    let n: SIMD3<Double>

    func thread(atPixel column: Int, row: Int) -> Int? {
        guard seen.indices.contains(row), seen[row].indices.contains(column) else { return nil }
        return seen[row][column]
    }

    /// The pixel column a place of the braid falls in, **measured on this picture's
    /// own axis**. Two views of a flat braid have their `u` pointing opposite ways,
    /// so the same place is not at the same column in both.
    func column(ofSpot spot: SIMD3<Double>) -> Int? {
        let at = Int(((spot * u).sum() - across.lowerBound) * Double(pixelsPerDiameter))
        return (0..<width).contains(at) ? at : nil
    }

    func row(atHeight height: Double) -> Int {
        min(max(Int((height - along.lowerBound) * Double(pixelsPerDiameter)), 0), height_ - 1)
    }
    private var height_: Int { height }

    /// A right-handed frame with `direction` looking into the page.
    static func frame(looking direction: SIMD3<Double>) -> (u: SIMD3<Double>, v: SIMD3<Double>, n: SIMD3<Double>) {
        let n = normalise(direction)
        var up = SIMD3<Double>(0, 0, 1)
        if abs((n * up).sum()) > 0.9 { up = SIMD3(1, 0, 0) }
        let u = normalise(cross(up, n))
        return (u, cross(n, u), n)
    }

    /// The picture's own frame: where the braid sits in this view's `u` and `v`.
    static func box(
        of lines: BraidCentrelines, looking direction: SIMD3<Double>
    ) -> (across: ClosedRange<Double>, along: ClosedRange<Double>,
          u: SIMD3<Double>, v: SIMD3<Double>, n: SIMD3<Double>) {
        let frame = frame(looking: direction)
        var lowU = Double.infinity, highU = -Double.infinity
        var lowV = Double.infinity, highV = -Double.infinity
        for thread in lines.threads {
            for point in lines.points[thread]! {
                let a = (point * frame.u).sum(), b = (point * frame.v).sum()
                lowU = min(lowU, a); highU = max(highU, a)
                lowV = min(lowV, b); highV = max(highV, b)
            }
        }
        return ((lowU - 1)...(highU + 1), (lowV - 0.5)...(highV + 0.5),
                frame.u, frame.v, frame.n)
    }

    static func paint(
        _ lines: BraidCentrelines, looking direction: SIMD3<Double>,
        pixelsPerDiameter: Int = 8
    ) -> BraidPicture {
        let box = box(of: lines, looking: direction)
        let u = box.u, v = box.v, n = box.n
        let wide = lines.construction.section.threadWidth
        let thick = lines.construction.section.threadThickness
        let ppd = Double(pixelsPerDiameter)
        let width = max(4, Int((box.across.upperBound - box.across.lowerBound) * ppd))
        let height = max(4, Int((box.along.upperBound - box.along.lowerBound) * ppd))

        var seen = [[Int?]](repeating: [Int?](repeating: nil, count: width), count: height)
        var depth = [[Double]](repeating: [Double](repeating: .infinity, count: width),
                               count: height)

        for thread in lines.threads {
            let way = lines.points[thread]!
            for leg in 0..<max(way.count - 1, 0) {
                let a = way[leg], b = way[leg + 1]
                let pa = SIMD3((a * u).sum(), (a * v).sum(), (a * n).sum())
                let pb = SIMD3((b * u).sum(), (b * v).sum(), (b * n).sum())
                // How wide the thread looks: across the braid it is `wide`, through
                // the thickness `thick`, and the view decides which is which.
                let seenWidth = abs(u.x) * wide + abs(u.y) * thick + abs(u.z) * wide
                let radius = max(seenWidth, 0.2) / 2

                var lowColumn = Int((min(pa.x, pb.x) - radius - box.across.lowerBound) * ppd)
                var highColumn = Int((max(pa.x, pb.x) + radius - box.across.lowerBound) * ppd) + 1
                var lowRow = Int((min(pa.y, pb.y) - radius - box.along.lowerBound) * ppd)
                var highRow = Int((max(pa.y, pb.y) + radius - box.along.lowerBound) * ppd) + 1
                lowColumn = max(lowColumn, 0); highColumn = min(highColumn, width)
                lowRow = max(lowRow, 0); highRow = min(highRow, height)
                guard highColumn > lowColumn, highRow > lowRow else { continue }

                let step = SIMD2(pb.x - pa.x, pb.y - pa.y)
                let span = (step * step).sum()
                for row in lowRow..<highRow {
                    let y = box.along.lowerBound + (Double(row) + 0.5) / ppd
                    for column in lowColumn..<highColumn {
                        let x = box.across.lowerBound + (Double(column) + 0.5) / ppd
                        let part = span < 1e-12 ? 0 : min(max(
                            ((x - pa.x) * step.x + (y - pa.y) * step.y) / span, 0), 1)
                        let cx = pa.x + part * step.x, cy = pa.y + part * step.y
                        let far = ((x - cx) * (x - cx) + (y - cy) * (y - cy)).squareRoot()
                        guard far <= radius else { continue }
                        let here = pa.z + part * (pb.z - pa.z)
                            - (max(radius * radius - far * far, 0)).squareRoot()
                        guard here < depth[row][column] else { continue }
                        depth[row][column] = here
                        seen[row][column] = thread
                    }
                }
            }
        }
        return BraidPicture(
            seen: seen, width: width, height: height, across: box.across, along: box.along,
            pixelsPerDiameter: pixelsPerDiameter, u: u, v: v, n: n
        )
    }

    private static func normalise(_ a: SIMD3<Double>) -> SIMD3<Double> {
        let length = (a * a).sum().squareRoot()
        return length > 0 ? a / length : a
    }

    private static func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }
}

/// How wide and how thick the finished braid came out.
///
/// **Measured on the braid, not declared.** Slabs half a diameter thick are taken
/// along it, the widest way through each slab is found, and the way across from it
/// is the thickness. A thread's own diameter is added to each, because the points
/// are centrelines.
struct BraidSectionMeasure: Equatable, Sendable {
    let width: Double
    let thickness: Double
    let thickest: Double
    let lengthwise: ClosedRange<Double>
    /// Only a tube has one.
    let outerDiameter: Double?

    var widthOverThickness: Double { thickness > 0 ? width / thickness : 0 }

    static func measure(_ lines: BraidCentrelines, tube: Bool) -> BraidSectionMeasure? {
        var all = [SIMD3<Double>]()
        for thread in lines.threads { all.append(contentsOf: lines.points[thread]!) }
        guard let low = all.map(\.z).min(), let high = all.map(\.z).max() else { return nil }

        var widths = [Double](), thicknesses = [Double]()
        var at = low + 1
        while at < high - 0.5 {
            let slab = all.filter { abs($0.z - at) <= 0.5 }
            at += 0.5
            guard slab.count >= 8 else { continue }
            let middleX = slab.map(\.x).reduce(0, +) / Double(slab.count)
            let middleY = slab.map(\.y).reduce(0, +) / Double(slab.count)
            // The principal axes of a two by two spread, worked out rather than
            // searched for.
            var xx = 0.0, xy = 0.0, yy = 0.0
            for point in slab {
                let dx = point.x - middleX, dy = point.y - middleY
                xx += dx * dx; xy += dx * dy; yy += dy * dy
            }
            let mean = (xx + yy) / 2
            let spread = (((xx - yy) / 2) * ((xx - yy) / 2) + xy * xy).squareRoot()
            let major = mean + spread
            let axis: SIMD2<Double>
            if abs(xy) > 1e-12 {
                axis = normalise2(SIMD2(major - yy, xy))
            } else {
                axis = xx >= yy ? SIMD2(1, 0) : SIMD2(0, 1)
            }
            let other = SIMD2(-axis.y, axis.x)
            func extent(_ along: SIMD2<Double>) -> Double {
                let cast = slab.map { ($0.x - middleX) * along.x + ($0.y - middleY) * along.y }
                return (cast.max() ?? 0) - (cast.min() ?? 0) + 1
            }
            widths.append(extent(axis))
            thicknesses.append(extent(other))
        }
        guard !widths.isEmpty else { return nil }
        let width = widths.reduce(0, +) / Double(widths.count)
        let thickness = thicknesses.reduce(0, +) / Double(thicknesses.count)
        let outer = tube
            ? 2 * (all.map { ($0.x * $0.x + $0.y * $0.y).squareRoot() }.max() ?? 0) + 1
            : nil
        return BraidSectionMeasure(
            width: width, thickness: thickness, thickest: thicknesses.max() ?? 0,
            lengthwise: low...high, outerDiameter: outer
        )
    }

    private static func normalise2(_ a: SIMD2<Double>) -> SIMD2<Double> {
        let length = (a * a).sum().squareRoot()
        return length > 0 ? a / length : a
    }
}
