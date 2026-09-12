import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import Kumihimo

/// Builds the sheet the author judges by: the same braid, the same colouring, the
/// same length, the same scale and the same camera, drawn both ways, with the
/// reference photograph under it.
///
/// **Made in Swift, by the same painter for both paths.** The frozen generators'
/// meshes are turned into points in thread diameters in the new path's axes first,
/// so nothing downstream knows which path it is drawing. Both are painted with
/// `BraidPicture`'s rule — parallel projection, one flat colour a thread, a depth
/// buffer — at four times the wanted scale and then boxed down.
enum BraidComparisonSheet {
    // MARK: - The frozen meshes, put in the new path's axes and units

    /// **The two paths do not lay their braids out on the same axes.** Measured on
    /// the meshes themselves: a frozen braid runs along `x`, is wide along `y` and
    /// thick along `z`; the new path is wide along `x`, thick along `y` and runs
    /// along `z`. This says so once, in one place.
    ///
    /// It is why the first comparison drew the frozen flat braid edge-on and it
    /// came out nearly one colour — the picture was of its side.
    static func inNewAxes(_ point: SIMD3<Float>, perDiameter: Double) -> SIMD3<Double> {
        SIMD3(Double(point.y) / perDiameter,      // across the braid
              Double(point.z) / perDiameter,      // through it
              Double(point.x) / perDiameter)      // along it
    }

    /// One mesh, ready to be painted like anything else.
    struct Solid {
        /// Triangle corners, three to a triangle, in thread diameters.
        let triangles: [(SIMD3<Double>, SIMD3<Double>, SIMD3<Double>, ThreadColorID)]
        let along: ClosedRange<Double>
    }

    static func solid(
        positions: [SIMD3<Float>], byColour: [ThreadColorID: [UInt32]], perDiameter: Double
    ) -> Solid {
        let points = positions.map { inNewAxes($0, perDiameter: perDiameter) }
        var triangles = [(SIMD3<Double>, SIMD3<Double>, SIMD3<Double>, ThreadColorID)]()
        for (colour, indices) in byColour {
            var at = 0
            while at + 2 < indices.count {
                triangles.append((points[Int(indices[at])], points[Int(indices[at + 1])],
                                  points[Int(indices[at + 2])], colour))
                at += 3
            }
        }
        let zs = points.map(\.z)
        return Solid(triangles: triangles, along: (zs.min() ?? 0)...(zs.max() ?? 0))
    }

    // MARK: - Painting, the same way for both

    /// Where the eye stands. **Straight on is the face's own normal; turned is
    /// thirty degrees round the braid's axis and twenty degrees above it.**
    static func camera(turned: Bool) -> SIMD3<Double> {
        guard turned else { return SIMD3(0, -1, 0) }
        let round = 30.0 * .pi / 180, up = 20.0 * .pi / 180
        return SIMD3(sin(round) * cos(up), -cos(round) * cos(up), -sin(up))
    }

    struct Panel {
        let pixels: [[ThreadColorValue?]]
        let width: Int
        let height: Int

        /// Laid out with the braid running across the page, which is how a braid is
        /// photographed and how the references below it are printed.
        var lyingDown: Panel {
            var turned = [[ThreadColorValue?]](
                repeating: [ThreadColorValue?](repeating: nil, count: height), count: width
            )
            for row in 0..<height {
                for column in 0..<width { turned[column][row] = pixels[row][column] }
            }
            return Panel(pixels: turned, width: height, height: width)
        }
    }

    /// `window` is the span along the braid to draw, in thread diameters.
    /// `pixelsPerDiameter` is the finished scale; the painting is done at four
    /// times it and boxed down.
    static func paint(
        triangles: [(SIMD3<Double>, SIMD3<Double>, SIMD3<Double>, ThreadColorID)],
        looking direction: SIMD3<Double>,
        window: ClosedRange<Double>,
        acrossWanted: Double,
        pixelsPerDiameter: Int,
        supersample: Int = 4
    ) -> Panel? {
        let frame = BraidPicture.frame(looking: direction)
        let kept = triangles.filter { triangle in
            let zs = [triangle.0.z, triangle.1.z, triangle.2.z]
            return zs.contains { window.contains($0) }
        }
        guard !kept.isEmpty else { return nil }

        let fine = Double(pixelsPerDiameter * supersample)
        let across = (-acrossWanted / 2 - 0.5)...(acrossWanted / 2 + 0.5)
        let middleAcross = kept.flatMap { [$0.0, $0.1, $0.2] }
            .map { ($0 * frame.u).sum() }
        let centre = ((middleAcross.min() ?? 0) + (middleAcross.max() ?? 0)) / 2
        let along = window
        let width = max(4, Int((across.upperBound - across.lowerBound) * fine))
        let height = max(4, Int((along.upperBound - along.lowerBound) * fine))

        var seen = [ThreadColorID?](repeating: nil, count: width * height)
        var depth = [Double](repeating: .infinity, count: width * height)
        for triangle in kept {
            let corners = [triangle.0, triangle.1, triangle.2].map { point -> SIMD3<Double> in
                SIMD3(((point * frame.u).sum() - centre - across.lowerBound) * fine,
                      ((point * frame.v).sum() - along.lowerBound) * fine,
                      (point * frame.n).sum())
            }
            let xs = corners.map(\.x), ys = corners.map(\.y)
            let lowColumn = max(Int(xs.min()!.rounded(.down)), 0)
            let highColumn = min(Int(xs.max()!.rounded(.up)) + 1, width)
            let lowRow = max(Int(ys.min()!.rounded(.down)), 0)
            let highRow = min(Int(ys.max()!.rounded(.up)) + 1, height)
            guard highColumn > lowColumn, highRow > lowRow else { continue }
            let area = (xs[1] - xs[0]) * (ys[2] - ys[0]) - (xs[2] - xs[0]) * (ys[1] - ys[0])
            guard abs(area) > 1e-12 else { continue }
            for row in lowRow..<highRow {
                let y = Double(row) + 0.5
                for column in lowColumn..<highColumn {
                    let x = Double(column) + 0.5
                    let a = ((xs[1] - x) * (ys[2] - y) - (xs[2] - x) * (ys[1] - y)) / area
                    let b = ((xs[2] - x) * (ys[0] - y) - (xs[0] - x) * (ys[2] - y)) / area
                    let c = 1 - a - b
                    guard a >= -1e-9, b >= -1e-9, c >= -1e-9 else { continue }
                    let here = a * corners[0].z + b * corners[1].z + c * corners[2].z
                    let at = row * width + column
                    guard here < depth[at] else { continue }
                    depth[at] = here
                    seen[at] = triangle.3
                }
            }
        }

        // Box down by the supersample, averaging colour so an edge is not a stair.
        let outWidth = width / supersample, outHeight = height / supersample
        var pixels = [[ThreadColorValue?]](
            repeating: [ThreadColorValue?](repeating: nil, count: outWidth), count: outHeight
        )
        for row in 0..<outHeight {
            for column in 0..<outWidth {
                var red = 0.0, green = 0.0, blue = 0.0, taken = 0
                for dy in 0..<supersample {
                    for dx in 0..<supersample {
                        let at = (row * supersample + dy) * width + column * supersample + dx
                        guard let id = seen[at],
                              let colour = ThreadColorCatalog.colors.first(where: { $0.id == id })
                        else { continue }
                        red += colour.value.red
                        green += colour.value.green
                        blue += colour.value.blue
                        taken += 1
                    }
                }
                guard taken > 0 else { continue }
                let share = Double(taken) / Double(supersample * supersample)
                let ground = ThreadColorValue(red: 0.99, green: 0.99, blue: 0.98)
                pixels[row][column] = ThreadColorValue(
                    red: red / Double(taken) * share + ground.red * (1 - share),
                    green: green / Double(taken) * share + ground.green * (1 - share),
                    blue: blue / Double(taken) * share + ground.blue * (1 - share)
                )
            }
        }
        return Panel(pixels: pixels, width: outWidth, height: outHeight)
    }

    /// The new path's threads as triangles, so one painter draws both. A thread is
    /// drawn as a strip of quads facing the eye — the same body the depth buffer
    /// sees, at the width the section gives it.
    static func solid(
        of lines: BraidCentrelines, colouring: [Int: ThreadColorID]
    ) -> [(SIMD3<Double>, SIMD3<Double>, SIMD3<Double>, ThreadColorID)] {
        var triangles = [(SIMD3<Double>, SIMD3<Double>, SIMD3<Double>, ThreadColorID)]()
        let wide = lines.construction.section.threadWidth
        let thick = lines.construction.section.threadThickness
        let around = 8
        for thread in lines.threads {
            guard let colour = colouring[thread] else { continue }
            let way = lines.points[thread]!
            guard way.count > 1 else { continue }
            var rings = [[SIMD3<Double>]]()
            for (at, point) in way.enumerated() {
                let next = way[min(at + 1, way.count - 1)]
                let last = way[max(at - 1, 0)]
                var run = next - last
                let length = (run * run).sum().squareRoot()
                run = length > 1e-12 ? run / length : SIMD3(0, 0, 1)
                var side = SIMD3(-run.y, run.x, 0)
                var sideLength = (side * side).sum().squareRoot()
                if sideLength < 1e-9 { side = SIMD3(1, 0, 0); sideLength = 1 }
                side /= sideLength
                let up = SIMD3(run.y * side.z - run.z * side.y,
                               run.z * side.x - run.x * side.z,
                               run.x * side.y - run.y * side.x)
                rings.append((0..<around).map { step in
                    let angle = 2 * Double.pi * Double(step) / Double(around)
                    return point + side * (cos(angle) * wide / 2) + up * (sin(angle) * thick / 2)
                })
            }
            for leg in 0..<(rings.count - 1) {
                for step in 0..<around {
                    let next = (step + 1) % around
                    triangles.append((rings[leg][step], rings[leg][next],
                                      rings[leg + 1][step], colour))
                    triangles.append((rings[leg][next], rings[leg + 1][next],
                                      rings[leg + 1][step], colour))
                }
            }
        }
        return triangles
    }

    // MARK: - The sheet

    /// `photographWidth` draws the reference at a width of its own instead of
    /// stretching it to the sheet's. **That is what lets a braid be laid beside a
    /// braid rather than beside a bigger one** (`docs/measurement-procedures.md`
    /// 3): hand in a reference already cropped and scaled to the panels, and say
    /// how wide it is. `nil` keeps the old behaviour, which every earlier sheet
    /// was drawn with.
    static func sheet(
        panels: [(label: String, panel: Panel)],
        photograph: CGImage?,
        photographLabel: String,
        legend: [(thread: Int, colour: ThreadColorValue, name: String)],
        title: String,
        photographWidth: Double? = nil
    ) -> CGImage? {
        let margin = 28.0, gap = 18.0, labelRoom = 22.0, legendRoom = 96.0
        // Wide enough for the longest label as well as the widest panel.
        let labelWidth = (panels.map(\.label) + [title, photographLabel])
            .map { Double($0.count) * 8.2 }.max() ?? 0
        let widest = max(panels.map { Double($0.panel.width) }.max() ?? 100, labelWidth)
        let photographDrawnWidth = photographWidth ?? widest
        let photographHeight = photograph.map {
            Double($0.height) * (photographDrawnWidth / Double($0.width))
        } ?? 0
        let bodyHeight = panels.reduce(0.0) { $0 + Double($1.panel.height) + labelRoom + gap }
            + (photograph == nil ? 0 : photographHeight + labelRoom + gap)
        let width = widest + margin * 2
        let height = bodyHeight + margin * 2 + legendRoom + 30

        guard let context = CGContext(
            data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(red: 0.99, green: 0.99, blue: 0.98, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        func write(_ text: String, at point: CGPoint, size: Double = 13, grey: Double = 0.25) {
            let font = CTFontCreateWithName("Menlo" as CFString, size, nil)
            let attributed = NSAttributedString(string: text, attributes: [
                .font: font,
                .foregroundColor: CGColor(red: grey, green: grey, blue: grey, alpha: 1),
            ])
            let line = CTLineCreateWithAttributedString(attributed)
            context.textPosition = point
            CTLineDraw(line, context)
        }

        var y = height - margin
        write(title, at: CGPoint(x: margin, y: y - 14), size: 15, grey: 0.1)
        y -= 30

        for (label, panel) in panels {
            y -= labelRoom
            write(label, at: CGPoint(x: margin, y: y + 5))
            y -= Double(panel.height)
            for row in 0..<panel.height {
                for column in 0..<panel.width {
                    guard let colour = panel.pixels[row][column] else { continue }
                    context.setFillColor(CGColor(red: colour.red, green: colour.green,
                                                 blue: colour.blue, alpha: 1))
                    context.fill(CGRect(x: margin + Double(column),
                                        y: y + Double(row), width: 1, height: 1))
                }
            }
            y -= gap
        }

        if let photograph {
            y -= labelRoom
            write(photographLabel, at: CGPoint(x: margin, y: y + 5))
            y -= photographHeight
            context.draw(photograph, in: CGRect(x: margin, y: y, width: photographDrawnWidth,
                                                height: photographHeight))
            y -= gap
        }

        // The thread-to-colour table, so both paths can be checked against it.
        y -= 4
        write("thread → colour (the same for both)", at: CGPoint(x: margin, y: y), size: 12)
        var x = margin
        var line = y - 20
        for entry in legend {
            if x > width - margin - 90 { x = margin; line -= 18 }
            context.setFillColor(CGColor(red: entry.colour.red, green: entry.colour.green,
                                         blue: entry.colour.blue, alpha: 1))
            context.fill(CGRect(x: x, y: line, width: 12, height: 12))
            write("\(entry.thread) \(entry.name)", at: CGPoint(x: x + 16, y: line + 2), size: 11)
            x += 92
        }
        return context.makeImage()
    }

    /// One braid cut out of a photograph of several, turned to lie across the page
    /// and scaled so that **its width is the width the panels draw a braid at**.
    ///
    /// `columns` is the band of the source the braid occupies, `rows` the run of it
    /// worth showing, both in the source's own pixels; `braidPixels` is how many of
    /// those pixels the braid itself is across. The result is `acrossWanted` wide
    /// in panel pixels, of which `braidWidth * pixelsPerDiameter` is braid — the
    /// same share the panels give it.
    static func reference(
        _ image: CGImage,
        columns: Range<Int>,
        rows: Range<Int>,
        braidPixels: Double,
        braidWidth: Double,
        pixelsPerDiameter: Int
    ) -> CGImage? {
        guard let cut = image.cropping(to: CGRect(
            x: columns.lowerBound, y: rows.lowerBound,
            width: columns.count, height: rows.count
        )) else { return nil }

        // How many panel pixels one source pixel becomes.
        let scale = braidWidth * Double(pixelsPerDiameter) / braidPixels
        // Turned a quarter, so the braid runs across the page as the panels do.
        let wide = Int((Double(cut.height) * scale).rounded())
        let high = Int((Double(cut.width) * scale).rounded())
        guard wide > 0, high > 0 else { return nil }

        guard let context = CGContext(
            data: nil, width: wide, height: high, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.translateBy(x: Double(wide) / 2, y: Double(high) / 2)
        context.rotate(by: .pi / 2)
        context.draw(cut, in: CGRect(
            x: -Double(high) / 2, y: -Double(wide) / 2,
            width: Double(high), height: Double(wide)
        ))
        return context.makeImage()
    }

    static func photograph(at path: String) -> CGImage? {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
