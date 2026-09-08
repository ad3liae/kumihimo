import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import Kumihimo

/// Draws a figure as an SVG so a person can look at it.
///
/// **For the author's eyes, not for a judgement.** Nothing is decided by looking;
/// the judgements are the fixture comparisons next door. Files land in
/// `.build/task025-figures/`, which git does not track.
enum BraidFigureDrawing {
    static var directory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()        // KumihimoTests
            .deletingLastPathComponent()        // the repository
            .appendingPathComponent(".build/task025-figures")
    }

    static func hex(_ id: ThreadColorID) -> String {
        let colour = ThreadColorCatalog.colors.first { $0.id == id }
            ?? ThreadColorCatalog.defaultColor
        func byte(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02x%02x%02x", byte(colour.value.red),
                      byte(colour.value.green), byte(colour.value.blue))
    }

    @discardableResult
    static func write(_ figure: BraidTubeFigure, named name: String) throws -> URL {
        let scale = 44.0
        let margin = 16.0
        let width = Double(figure.columns.count) * scale + margin * 2
        let height = Double(figure.rowsDrawn) * scale + margin * 2 + 54
        var body = ""
        for shape in figure.shapes where shape.isOnTheFace {
            guard let place = shape.place else { continue }
            let x = margin + Double(place.width) * scale + 2
            // Row 0 at the bottom: the braid grows upwards.
            let y = margin + Double(figure.rowsDrawn - 1 - place.row) * scale + 2
            body += "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(scale - 4)\" "
                + "height=\"\(scale - 4)\" rx=\"5\" fill=\"\(hex(shape.colorID))\"/>\n"
            body += "<text x=\"\(x + (scale - 4) / 2)\" y=\"\(y + scale / 2)\" "
                + "font-family=\"ui-monospace, monospace\" font-size=\"13\" "
                + "text-anchor=\"middle\" fill=\"#00000099\">\(shape.threadPosition)</text>\n"
        }
        for (index, column) in figure.columns.enumerated() {
            let x = margin + Double(index) * scale + scale / 2
            body += "<text x=\"\(x)\" y=\"\(height - 34)\" font-family=\"ui-monospace, "
                + "monospace\" font-size=\"11\" text-anchor=\"middle\" fill=\"#555\">"
                + "slot \(column.slot)</text>\n"
            body += "<text x=\"\(x)\" y=\"\(height - 20)\" font-family=\"ui-monospace, "
                + "monospace\" font-size=\"11\" text-anchor=\"middle\" fill=\"#555\">"
                + String(format: "%.1f", column.angleInTurns * 360) + "\u{00b0}</text>\n"
        }
        body += "<text x=\"\(margin)\" y=\"\(height - 4)\" font-family=\"ui-monospace, "
            + "monospace\" font-size=\"10\" fill=\"#777\">"
            + "unsettled: mirror counts as agreement; E/W column order undecided"
            + "</text>\n"

        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(width)\" "
            + "height=\"\(height)\" viewBox=\"0 0 \(width) \(height)\">\n"
            + "<rect width=\"\(width)\" height=\"\(height)\" fill=\"#fdfdfb\"/>\n"
            + body + "</svg>\n"

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).svg")
        try svg.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

extension BraidFigureDrawing {
    /// Writes a drawn braid out as a PNG, for looking at.
    @discardableResult
    static func write(_ image: CGImage, named name: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).png")
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, "public.png" as CFString, 1, nil
        ) else { throw Trouble.couldNotWrite(name) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw Trouble.couldNotWrite(name) }
        return url
    }

    enum Trouble: Error { case couldNotWrite(String) }
}
