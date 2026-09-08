import CoreGraphics
import Foundation

/// Turns a drawn braid into an image, one flat colour a thread.
///
/// **The picture decides what shows.** This only gives the threads their colours;
/// which one is in front was settled by the depth buffer
/// (`BraidPicture`), and nothing here may second-guess it.
enum BraidDrawing {
    /// The colour of each pixel, row 0 at the *top* so it can go straight into an
    /// image. Anything unpainted is the ground.
    static func image(
        of picture: BraidPicture,
        colours: [Int: ThreadColorValue],
        ground: ThreadColorValue = ThreadColorValue(red: 0.99, green: 0.99, blue: 0.98)
    ) -> CGImage? {
        let width = picture.width, height = picture.height
        guard width > 0, height > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        func byte(_ value: Double) -> UInt8 { UInt8(min(max(value, 0), 1) * 255) }
        for row in 0..<height {
            // The picture grows upwards; an image starts at the top.
            let line = height - 1 - row
            for column in 0..<width {
                let colour = picture.thread(atPixel: column, row: row)
                    .flatMap { colours[$0] } ?? ground
                let at = (line * width + column) * 4
                bytes[at] = byte(colour.red)
                bytes[at + 1] = byte(colour.green)
                bytes[at + 2] = byte(colour.blue)
                bytes[at + 3] = 255
            }
        }
        let space = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    /// The views worth showing of a braid: the two faces of a flat one, or the
    /// slots a hand lands on for a tube.
    ///
    /// **Derived, not listed.** A flat braid has faces because its courses fold it;
    /// a tube's views are the occupancy history's own columns, which do not stand
    /// at even angles.
    static func views(
        of lines: BraidCentrelines, occupancy: BraidOccupancy, slotCount: Int
    ) -> [(name: String, direction: SIMD3<Double>)] {
        if lines.construction.section.isFlat {
            return [("front", SIMD3(0, -1, 0)), ("back", SIMD3(0, 1, 0))]
        }
        guard let columns = occupancy.columns(.landing) else { return [] }
        return columns.map { slot in
            let angle = 2 * Double.pi * Double(slot) / Double(slotCount)
            // The eye stands over the column, looking in.
            return ("slot \(slot)", SIMD3(-cos(angle), -sin(angle), 0))
        }
    }
}
