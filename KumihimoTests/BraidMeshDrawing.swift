import CoreGraphics
import Foundation
@testable import Kumihimo

/// Draws a triangle mesh the way `BraidPicture` draws thread bodies: parallel
/// projection, a depth buffer, one flat colour a thread.
///
/// **A judging tool, not product code.** It exists so the frozen generators and the
/// new path can be put in the same picture at the same braid width, which is what
/// `docs/measurement-procedures.md` asks for before anything is compared.
enum BraidMeshDrawing {
    struct Mesh {
        let positions: [SIMD3<Float>]
        /// Triangle indices, grouped by the colour they are drawn in.
        let byColour: [ThreadColorID: [UInt32]]
    }

    /// What was painted, and where: the colour index at each pixel, row 0 at the
    /// bottom, and the frame it was drawn in.
    struct Picture {
        let seen: [[ThreadColorID?]]
        let width: Int
        let height: Int
        let across: ClosedRange<Double>
        let along: ClosedRange<Double>
        let pixelsPerUnit: Double
    }

    /// `widthWanted` is how many pixels the braid's width should come out as, so
    /// two braids of different nominal sizes can be laid side by side.
    static func paint(
        _ mesh: Mesh, looking direction: SIMD3<Double>, widthWanted: Int = 320
    ) -> Picture? {
        let frame = BraidPicture.frame(looking: direction)
        let points = mesh.positions.map { SIMD3(Double($0.x), Double($0.y), Double($0.z)) }
        guard !points.isEmpty else { return nil }
        let us = points.map { ($0 * frame.u).sum() }
        let vs = points.map { ($0 * frame.v).sum() }
        guard let lowU = us.min(), let highU = us.max(),
              let lowV = vs.min(), let highV = vs.max(), highU > lowU
        else { return nil }
        let margin = (highU - lowU) * 0.04
        let across = (lowU - margin)...(highU + margin)
        let along = (lowV - margin)...(highV + margin)
        let scale = Double(widthWanted) / (across.upperBound - across.lowerBound)
        let width = widthWanted
        let height = max(4, Int((along.upperBound - along.lowerBound) * scale))

        var seen = [[ThreadColorID?]](repeating: [ThreadColorID?](repeating: nil, count: width),
                                      count: height)
        var depth = [[Double]](repeating: [Double](repeating: .infinity, count: width),
                               count: height)

        for (colour, indices) in mesh.byColour {
            var at = 0
            while at + 2 < indices.count {
                let corners = (0..<3).map { leg -> SIMD3<Double> in
                    let point = points[Int(indices[at + leg])]
                    return SIMD3((point * frame.u).sum(), (point * frame.v).sum(),
                                 (point * frame.n).sum())
                }
                at += 3
                paint(corners, colour: colour, into: &seen, depth: &depth,
                      across: across, along: along, scale: scale)
            }
        }
        return Picture(seen: seen, width: width, height: height, across: across,
                       along: along, pixelsPerUnit: scale)
    }

    private static func paint(
        _ corners: [SIMD3<Double>], colour: ThreadColorID,
        into seen: inout [[ThreadColorID?]], depth: inout [[Double]],
        across: ClosedRange<Double>, along: ClosedRange<Double>, scale: Double
    ) {
        let width = seen[0].count, height = seen.count
        let xs = corners.map { ($0.x - across.lowerBound) * scale }
        let ys = corners.map { ($0.y - along.lowerBound) * scale }
        let lowColumn = max(Int(xs.min()!.rounded(.down)), 0)
        let highColumn = min(Int(xs.max()!.rounded(.up)) + 1, width)
        let lowRow = max(Int(ys.min()!.rounded(.down)), 0)
        let highRow = min(Int(ys.max()!.rounded(.up)) + 1, height)
        guard highColumn > lowColumn, highRow > lowRow else { return }
        let area = (xs[1] - xs[0]) * (ys[2] - ys[0]) - (xs[2] - xs[0]) * (ys[1] - ys[0])
        guard abs(area) > 1e-12 else { return }

        for row in lowRow..<highRow {
            let y = Double(row) + 0.5
            for column in lowColumn..<highColumn {
                let x = Double(column) + 0.5
                let a = ((xs[1] - x) * (ys[2] - y) - (xs[2] - x) * (ys[1] - y)) / area
                let b = ((xs[2] - x) * (ys[0] - y) - (xs[0] - x) * (ys[2] - y)) / area
                let c = 1 - a - b
                guard a >= -1e-9, b >= -1e-9, c >= -1e-9 else { continue }
                let here = a * corners[0].z + b * corners[1].z + c * corners[2].z
                guard here < depth[row][column] else { continue }
                depth[row][column] = here
                seen[row][column] = colour
            }
        }
    }

    static func image(
        of picture: Picture,
        ground: ThreadColorValue = ThreadColorValue(red: 0.99, green: 0.99, blue: 0.98)
    ) -> CGImage? {
        var bytes = [UInt8](repeating: 0, count: picture.width * picture.height * 4)
        func byte(_ value: Double) -> UInt8 { UInt8(min(max(value, 0), 1) * 255) }
        for row in 0..<picture.height {
            let line = picture.height - 1 - row
            for column in 0..<picture.width {
                let colour = picture.seen[row][column].flatMap { id in
                    ThreadColorCatalog.colors.first { $0.id == id }?.value
                } ?? ground
                let at = (line * picture.width + column) * 4
                bytes[at] = byte(colour.red)
                bytes[at + 1] = byte(colour.green)
                bytes[at + 2] = byte(colour.blue)
                bytes[at + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: picture.width, height: picture.height, bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: picture.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }
}
