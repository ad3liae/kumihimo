import CoreGraphics
import SwiftUI

/// The eight-thread tube, unrolled flat for a card.
///
/// **The braid seen from outside, opened out**: along it runs to the right
/// towards the braiding point, as on the solid, and round it runs *up* the
/// card, as it does up the front of the solid — **with the front of the solid
/// across the middle of the card** (Task 045 review). The sixteen-thread card
/// lays round-the-braid down the card from its top edge; that layout
/// (`UnrolledPatternThumbnailLayout`) is kept for how long a repeat is and where
/// the repeats go, and only this card turns round-the-braid the other way, so
/// the sixteen-thread card does not move.
///
/// **What shows at each place is what the solid shows there**: the run standing
/// highest (`RoundTube8SurfacePattern.runsStanding`), and the cell beneath where
/// no run reaches, darkened as the solid's valley floor is. It used to paint
/// whole runs in the order the threads arrived, which is not what the solid
/// shows on the flanks of a run just past the next arrival (Task 045 review).
/// The card is a picture of that rule, one repeat of it, drawn into a bitmap
/// once per braid and laid end to end. A thin line marks where one run meets
/// another — by run, never by colour, so two threads of one colour still part.
///
/// **Drawn off the main thread**, once per braid and kept: working out what
/// shows at every pixel of a repeat takes a moment (about a quarter of a second
/// in a debug build), and the list should not wait for it. Until it is ready the
/// card shows its plain background.
struct RoundTube8ThumbnailView: View {
    let pattern: RoundTube8SurfacePattern
    var bundle: RoundTube8Bundle = .standard

    @State private var loader = RoundTube8CardLoader()
    @Environment(\.displayScale) private var displayScale

    private var key: RoundTube8CardImage.Key {
        RoundTube8CardImage.Key(pattern: pattern, bundle: bundle)
    }

    var body: some View {
        // **Only this braid's picture, never the one before it**: until the
        // picture for the colouring now shown is ready, the card shows its plain
        // background (Task 045 addendum 2).
        let image = loader.image(for: key)
        Canvas { context, size in
            guard let image, let layout = UnrolledPatternThumbnailLayout(
                size: size,
                aspectRatio: pattern.aspectRatio
            ) else { return }
            // Each repeat's edges on whole device pixels, shared with the next
            // one's, so no seam of half-covered pixels shows between them.
            let scale = max(displayScale, 1)
            func snapped(_ value: CGFloat) -> CGFloat { (value * scale).rounded() / scale }
            for repeatIndex in layout.repeatIndices {
                let start = snapped(layout.point(surfaceCoordinate: SIMD2(0, 0), repeatIndex: repeatIndex).x)
                let end = snapped(layout.point(surfaceCoordinate: SIMD2(0, 0), repeatIndex: repeatIndex + 1).x)
                context.draw(
                    Image(decorative: image, scale: 1),
                    in: CGRect(x: start, y: 0, width: end - start, height: layout.circumference)
                )
            }
        }
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
        .task(id: key) {
            await loader.load(pattern: pattern, bundle: bundle)
        }
    }
}

/// One repeat of the card, as a bitmap: which run shows at each pixel, and its
/// colour.
enum RoundTube8CardImage {
    /// Pixels round the braid for one column. The card is 112 points round and
    /// eight columns, so 32 a column is over twice a point.
    static let pixelsPerColumn = 32

    /// How much a cell beneath is darkened: the valley shading the solid gives
    /// it (`RoundTube16StrandTextureFactory.valleyOcclusion`).
    static var beneathShade: Float { RoundTube16StrandTextureFactory.valleyOcclusion }
    /// How much the line where two runs meet is darkened. A look, not a shape:
    /// the stroke the card drew round every cell before, 0.26 of the ink.
    static let edgeShade: Float = 0.74

    /// **Round the braid, up the card, with the solid's front across the
    /// middle.** Row `0` is the top. The solid lays `turns` 0 facing the camera
    /// and more turns further up its front; so does this.
    static func turns(atRow row: Float, rows: Int) -> Float {
        0.5 - (row + 0.5) / Float(rows)
    }

    /// What shows at a place: a run, or the cell beneath.
    enum Shown: Equatable, Hashable {
        case run(repeatOffset: Int, segment: Int)
        case beneath(repeatOffset: Int, segment: Int)

        /// The same thing, counted from `repeats` repeats further back.
        func movedOn(by repeats: Int) -> Shown {
            switch self {
            case .run(let offset, let segment): .run(repeatOffset: offset + repeats, segment: segment)
            case .beneath(let offset, let segment): .beneath(repeatOffset: offset + repeats, segment: segment)
            }
        }
    }

    /// Which run or cell each pixel of one repeat shows, row by row from the
    /// top, and the size. **The card's picture is this and nothing else**, so a
    /// test can hold it against the solid.
    static func shownMap(
        for pattern: RoundTube8SurfacePattern,
        bundle: RoundTube8Bundle = .standard
    ) -> (shown: [Shown?], width: Int, height: Int) {
        let columns = RoundTube8SurfacePatternGenerator.requiredThreadCount
        let height = columns * pixelsPerColumn
        let width = max(1, Int((Float(height) * pattern.aspectRatio).rounded()))
        var shown = [Shown?](repeating: nil, count: width * height)
        let segments = pattern.surface.segments
        for column in 0..<width {
            let along = (Float(column) + 0.5) / Float(width)
            // The runs reaching this far along, before looking round the braid.
            var reaching = [(Int, Int)]()
            for (index, segment) in segments.enumerated() {
                let cycle = segment.centerlineEnd.y - segment.centerlineStart.y
                for offset in -1...1 {
                    let start = segment.centerlineStart.y + Float(offset)
                    if along >= start, along <= start + cycle * bundle.lengthInCycles {
                        reaching.append((offset, index))
                    }
                }
            }
            for row in 0..<height {
                let turns = self.turns(atRow: Float(row), rows: height)
                var best: (Int, Int, Float)?
                for (offset, index) in reaching {
                    guard let standing = pattern.standing(
                        segments[index], repeatOffset: offset,
                        atTurns: turns, along: along, bundle: bundle
                    ) else { continue }
                    if best == nil || standing > best!.2 { best = (offset, index, standing) }
                }
                if let best {
                    shown[row * width + column] = .run(repeatOffset: best.0, segment: best.1)
                } else if let cell = pattern.cellBeneath(atTurns: turns, along: along) {
                    shown[row * width + column] = .beneath(repeatOffset: cell.repeatOffset, segment: cell.segment)
                }
            }
        }
        return (shown, width, height)
    }

    // MARK: - The bitmap

    /// What a card's picture depends on.
    struct Key: Hashable, Sendable {
        let colours: [String]
        /// Where each cell stands, so two tables with the same colours never
        /// share a picture.
        let cells: [Float]
        let columnsCarried: Int
        let rowCount: Int
        let aspectRatio: Float
        let bundle: [Float]

        init(pattern: RoundTube8SurfacePattern, bundle: RoundTube8Bundle) {
            colours = pattern.surface.segments.map(\.colorID.rawValue)
            cells = pattern.surface.segments.flatMap {
                [$0.centerlineStart.x, $0.centerlineStart.y, $0.centerlineEnd.y]
            }
            columnsCarried = pattern.columnsCarried
            rowCount = pattern.rowCount
            aspectRatio = pattern.aspectRatio
            self.bundle = [
                bundle.leanColumnsPerCycle, bundle.tuckedCycles, bundle.headRoundingCycles,
                bundle.arcSpanCycles, bundle.tailBendColumns, bundle.tailBendFromCycles,
                bundle.tailNarrowsFromCycles, bundle.widestHalfWidthInColumns,
            ]
        }
    }

    /// Pictures already drawn: a card is redrawn as the list scrolls, and the
    /// braid does not change under it. **Keeping a picture here is not showing
    /// it**: a picture finished for a colouring the card has since left is
    /// still kept, for when the card comes back to it.
    actor Cache {
        private var images = [Key: CGImage]()
        init() {}
        func image(for key: Key) -> CGImage? { images[key] }
        func keep(_ image: CGImage, for key: Key) {
            if images.count > 32 { images.removeAll() }
            images[key] = image
        }
    }
    static let sharedCache = Cache()

    /// Draws the picture off the main thread.
    @Sendable static func drawOffTheMainThread(
        _ pattern: RoundTube8SurfacePattern, _ bundle: RoundTube8Bundle
    ) async -> CGImage? {
        await Task.detached(priority: .userInitiated) {
            draw(pattern, bundle: bundle)
        }.value
    }

    static func draw(_ pattern: RoundTube8SurfacePattern, bundle: RoundTube8Bundle) -> CGImage? {
        let (shown, width, height) = shownMap(for: pattern, bundle: bundle)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        func colour(_ segment: Int) -> SIMD3<Float> {
            let id = pattern.surface.segments[segment].colorID
            let value = (ThreadColorCatalog.color(for: id) ?? ThreadColorCatalog.defaultColor).value
            return SIMD3(Float(value.red), Float(value.green), Float(value.blue))
        }
        for row in 0..<height {
            for column in 0..<width {
                let here = shown[row * width + column]
                var rgb = SIMD3<Float>(repeating: 0)
                switch here {
                case .run(_, let segment):
                    rgb = colour(segment)
                case .beneath(_, let segment):
                    rgb = colour(segment) * beneathShade
                case nil:
                    break
                }
                // Where this run meets another: the pixel below or to the right
                // shows something else (the bitmap wraps both ways).
                // Across the join into the next repeat the same run is counted
                // one repeat further back.
                var right = shown[row * width + (column + 1) % width]
                if column + 1 == width { right = right.map { $0.movedOn(by: 1) } }
                let below = shown[((row + 1) % height) * width + column]
                if here != right || here != below { rgb *= edgeShade }
                let offset = (row * width + column) * 4
                pixels[offset] = UInt8(min(max(rgb.x, 0), 1) * 255 + 0.5)
                pixels[offset + 1] = UInt8(min(max(rgb.y, 0), 1) * 255 + 0.5)
                pixels[offset + 2] = UInt8(min(max(rgb.z, 0), 1) * 255 + 0.5)
                pixels[offset + 3] = 255
            }
        }
        guard
            let provider = CGDataProvider(data: Data(pixels) as CFData),
            let space = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        return CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )
    }
}

/// **Which picture a card shows, and only the picture for what it shows now**
/// (Task 045 addendum 2).
///
/// A card's colouring can change while its picture is still being drawn — pick
/// a colour, then another, or go back to one already drawn — and the pictures
/// can finish in any order. A picture that finishes for a colouring the card has
/// left is **kept** (the cache) but **not shown**: every picture is shown with
/// the key it was drawn for, and a card asks only for its current key's. Until
/// that one is ready it has none, and the card shows its plain background rather
/// than the colouring before.
///
/// The view calls `load` from `.task(id:)`, which cancels the load for a key the
/// card has left; a cancelled load still keeps what it drew but shows nothing.
@MainActor
@Observable
final class RoundTube8CardLoader {
    typealias Draw = @Sendable (RoundTube8SurfacePattern, RoundTube8Bundle) async -> CGImage?

    /// The key the card last asked for.
    private(set) var requested: RoundTube8CardImage.Key?
    /// The picture on hand, with the key it was drawn for.
    private var shown: (key: RoundTube8CardImage.Key, image: CGImage)?

    @ObservationIgnored private let cache: RoundTube8CardImage.Cache
    @ObservationIgnored private let draw: Draw

    init(
        cache: RoundTube8CardImage.Cache = RoundTube8CardImage.sharedCache,
        draw: @escaping Draw = RoundTube8CardImage.drawOffTheMainThread
    ) {
        self.cache = cache
        self.draw = draw
    }

    /// The picture for `key`, if it is the one on hand; otherwise none.
    func image(for key: RoundTube8CardImage.Key) -> CGImage? {
        guard let shown, shown.key == key else { return nil }
        return shown.image
    }

    /// Asks for the picture of `pattern`: from the cache if it is there,
    /// otherwise drawn. **Whatever comes back is shown only if the card still
    /// wants it** — the load not cancelled, and this key still the last asked for.
    func load(pattern: RoundTube8SurfacePattern, bundle: RoundTube8Bundle) async {
        let key = RoundTube8CardImage.Key(pattern: pattern, bundle: bundle)
        requested = key
        if let cached = await cache.image(for: key) {
            show(cached, for: key)
            return
        }
        let drawn = await draw(pattern, bundle)
        guard let drawn else { return }
        await cache.keep(drawn, for: key)
        show(drawn, for: key)
    }

    private func show(_ image: CGImage, for key: RoundTube8CardImage.Key) {
        guard !Task.isCancelled, requested == key else { return }
        shown = (key, image)
    }
}
