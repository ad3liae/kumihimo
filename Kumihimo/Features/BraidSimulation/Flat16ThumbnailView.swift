import CoreGraphics
import SwiftUI

/// The flat braid, opened out for a card.
///
/// **What shows at each place is what the solid shows there**: the run standing
/// highest (`Flat16SurfacePattern.runsStanding`), and the cell beneath where no
/// run reaches, darkened as the solid's floor is. Until Task 050 this painted
/// each cell as a rectangle of its own colour with a line round it, which is not
/// what the solid shows once a bundle is wider than its lane and longer than its
/// step — and the outlined rectangles were themselves part of what made the card
/// read as a grid. The card is a picture of that one rule, one repeat of it,
/// drawn into a bitmap once per braid and laid end to end. A thin line marks
/// where one run meets another — by run, never by colour, so two threads of one
/// colour still part.
///
/// **Drawn off the main thread**, once per braid and kept: working out what shows
/// at every pixel of a repeat takes a moment, and the list should not wait for
/// it. Until it is ready the card shows its plain background — **and never the
/// colouring before** (Task 045 addendum 2, carried over here with it).
struct Flat16ThumbnailView: View {
    /// How far the whole drawing is turned round the braid before it is laid out.
    ///
    /// **This is where the figure is cut open, not where the braid is.** A tube of
    /// surface has to be cut somewhere to be drawn flat, and the mesh's own cut
    /// falls in the middle of one edge — so that edge arrived as two half-bands, one
    /// at each end of the frame, while the other three regions read whole. Turning
    /// the drawing by the half-edge that sits past the cut moves the cut to the
    /// boundary between two regions instead, and all four read in order: edge,
    /// front, edge, back.
    ///
    /// **The braid is not turned.** `Flat16SurfaceMesh.arcSpan` is untouched and the
    /// solid is drawn exactly as before; what moved is where this drawing starts
    /// reading it.
    /// Arithmetic on the cross-section, so it belongs to no actor.
    nonisolated static var seamRotation: Float {
        1 - Flat16SurfaceMesh.arcSpan(of: .rightEdge).start
    }

    let assignments: [ThreadAssignment]

    @State private var loader = Flat16CardLoader()
    @Environment(\.displayScale) private var displayScale

    private var pattern: Flat16SurfacePattern? {
        Flat16SurfacePatternGenerator.generate(assignments: assignments)
    }

    var body: some View {
        let pattern = pattern
        let key = pattern.map(Flat16CardImage.Key.init(pattern:))
        let image = key.flatMap { loader.image(for: $0) }
        Canvas { context, size in
            // **The frame's height is one turn round the braid**, not one face of
            // it (Task 029). The ratio handed to the layout is therefore over the
            // turn, not over the width — measured on the outline the mesh draws
            // (Task 050; Task 029 counted lanes instead, which drew every cell
            // eleven per cent too short for its width).
            guard
                let image,
                let roundTheBraid = Flat16SurfaceMesh.patternAspectRatioRoundTheBraid,
                let layout = UnrolledPatternThumbnailLayout(
                    size: size,
                    aspectRatio: roundTheBraid
                )
            else {
                return
            }
            // Each repeat's edges on whole device pixels, shared with the next
            // one's, so no seam of half-covered pixels shows between them.
            let scale = max(displayScale, 1)
            func snapped(_ value: CGFloat) -> CGFloat { (value * scale).rounded() / scale }
            for repeatIndex in layout.repeatIndices {
                let start = snapped(
                    layout.point(surfaceCoordinate: .zero, repeatIndex: repeatIndex).x
                )
                let end = snapped(
                    layout.point(surfaceCoordinate: .zero, repeatIndex: repeatIndex + 1).x
                )
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
            guard let pattern else { return }
            await loader.load(pattern: pattern)
        }
    }
}

/// One repeat of the card, as a bitmap: which run shows at each pixel, and its
/// colour.
enum Flat16CardImage {
    /// Pixels round the braid for one lane. The card is 112 points round and
    /// sixteen lanes, so 24 a lane is over three times a point.
    static let pixelsPerLane = 24

    /// How much a cell beneath is darkened: the valley shading the solid gives
    /// it (`RoundTube16StrandTextureFactory.valleyOcclusion`).
    static var beneathShade: Float { RoundTube16StrandTextureFactory.valleyOcclusion }
    /// How much the line where two runs meet is darkened. A look, not a shape:
    /// the stroke the card drew round every cell before, 0.26 of the ink.
    static let edgeShade: Float = 0.74

    /// How many lanes there are round the braid.
    static var lanes: Int { Flat16SurfacePatternGenerator.boardPositionCount }

    /// **Round the braid, down the card, cut at a region boundary.** Row 0 is the
    /// top, and the four regions come down the frame in order — right edge,
    /// front, left edge, back — which is what Task 029-2 settled.
    static func arc(atRow row: Float, rows: Int) -> Float {
        (row + 0.5) / Float(rows) - Flat16ThumbnailView.seamRotation
    }

    /// What shows at a place: a run, or the cell beneath.
    enum Shown: Equatable, Hashable {
        case run(repeatOffset: Int, bundle: Int)
        case beneath(repeatOffset: Int, bundle: Int)

        /// The same thing, counted from `repeats` repeats further back.
        func movedOn(by repeats: Int) -> Shown {
            switch self {
            case .run(let offset, let bundle):
                .run(repeatOffset: offset + repeats, bundle: bundle)
            case .beneath(let offset, let bundle):
                .beneath(repeatOffset: offset + repeats, bundle: bundle)
            }
        }

        var bundle: Int {
            switch self {
            case .run(_, let bundle), .beneath(_, let bundle): bundle
            }
        }
    }

    /// Which run or cell each pixel of one repeat shows, row by row from the top,
    /// and the size. **The card's picture is this and nothing else**, so a test
    /// can hold it against the solid.
    static func shownMap(
        for pattern: Flat16SurfacePattern,
        shape: Flat16BundleShape = Flat16SurfaceMesh.bundleShape
    ) -> (shown: [Shown?], width: Int, height: Int) {
        let lanes = max(1, self.lanes)
        let height = lanes * pixelsPerLane
        let ratio = Flat16SurfaceMesh.patternAspectRatioRoundTheBraid ?? pattern.aspectRatio
        let width = max(1, Int((Float(height) * ratio).rounded()))
        var shown = [Shown?](repeating: nil, count: width * height)

        for column in 0..<width {
            let along = (Float(column) + 0.5) / Float(width)
            // The runs reaching this far along, before looking round the braid.
            var reaching = [(offset: Int, bundle: Int)]()
            for (index, bundle) in pattern.bundles.enumerated() {
                for offset in -1...1 {
                    // Roughly: the centreline alone, widened by the lean a run
                    // may carry, so nothing that could reach this far along is
                    // left out. `standing` settles it exactly.
                    guard let place = bundle.along(atLengthwise: along - Float(offset)),
                          place >= shape.runStart - 0.5, place <= shape.runEnd + 0.5
                    else { continue }
                    reaching.append((offset, index))
                }
            }
            for row in 0..<height {
                let arc = self.arc(atRow: Float(row), rows: height)
                var best: (offset: Int, bundle: Int, height: Float)?
                for candidate in reaching {
                    guard let standing = pattern.standing(
                        pattern.bundles[candidate.bundle],
                        repeatOffset: candidate.offset,
                        atArc: arc, along: along, shape: shape
                    ), standing > 0 else { continue }
                    if best == nil || standing > best!.height {
                        best = (candidate.offset, candidate.bundle, standing)
                    }
                }
                if let best {
                    shown[row * width + column] = .run(
                        repeatOffset: best.offset, bundle: best.bundle
                    )
                } else if let cell = pattern.cellBeneath(atArc: arc, along: along) {
                    shown[row * width + column] = .beneath(
                        repeatOffset: cell.repeatOffset, bundle: cell.bundle
                    )
                }
            }
        }
        return (shown, width, height)
    }

    // MARK: - The bitmap

    /// What a card's picture depends on.
    struct Key: Hashable, Sendable {
        let colours: [String]
        /// Where each run stands, so two patterns with the same colours never
        /// share a picture.
        let runs: [Float]
        let rowCount: Int
        let aspectRatio: Float
        let shape: [Float]

        init(pattern: Flat16SurfacePattern) {
            colours = pattern.bundles.map(\.colorID.rawValue)
            runs = pattern.bundles.flatMap {
                [$0.leadingCentre.x, $0.leadingCentre.y, $0.trailingCentre.y, $0.drawnInPerStep]
            }
            rowCount = pattern.rowCount
            aspectRatio = pattern.aspectRatio
            let bundle = Flat16SurfaceMesh.bundleShape
            shape = [
                bundle.joinHeight, bundle.laneJoinHeight, bundle.endWidth,
                bundle.tipReach, bundle.buriedTipSink, bundle.tipNarrowing,
                bundle.headLift, bundle.tailDip,
            ]
        }
    }

    /// Pictures already drawn: a card is redrawn as the list scrolls, and the
    /// braid does not change under it. **Keeping a picture here is not showing
    /// it**: a picture finished for a colouring the card has since left is still
    /// kept, for when the card comes back to it.
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
    @Sendable static func drawOffTheMainThread(_ pattern: Flat16SurfacePattern) async -> CGImage? {
        await Task.detached(priority: .userInitiated) {
            draw(pattern)
        }.value
    }

    static func draw(_ pattern: Flat16SurfacePattern) -> CGImage? {
        let (shown, width, height) = shownMap(for: pattern)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        func colour(_ bundle: Int) -> SIMD3<Float> {
            let id = pattern.bundles[bundle].colorID
            let value = (ThreadColorCatalog.color(for: id) ?? ThreadColorCatalog.defaultColor).value
            return SIMD3(Float(value.red), Float(value.green), Float(value.blue))
        }
        for row in 0..<height {
            for column in 0..<width {
                let here = shown[row * width + column]
                var rgb = SIMD3<Float>(repeating: 0)
                switch here {
                case .run(_, let bundle):
                    rgb = colour(bundle)
                case .beneath(_, let bundle):
                    rgb = colour(bundle) * beneathShade
                case nil:
                    break
                }
                // Where this run meets another: the pixel below or to the right
                // shows something else. The bitmap wraps both ways — round the
                // braid down the card, and into the next repeat across it, where
                // the same run is counted one repeat further back.
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
/// (Task 045 addendum 2, carried to the flat braid by Task 050).
///
/// A card's colouring can change while its picture is still being drawn — pick a
/// colour, then another, or go back to one already drawn — and the pictures can
/// finish in any order. A picture that finishes for a colouring the card has left
/// is **kept** (the cache) but **not shown**: every picture is shown with the key
/// it was drawn for, and a card asks only for its current key's. Until that one
/// is ready it has none, and the card shows its plain background rather than the
/// colouring before.
///
/// The view calls `load` from `.task(id:)`, which cancels the load for a key the
/// card has left; a cancelled load still keeps what it drew but shows nothing.
@MainActor
@Observable
final class Flat16CardLoader {
    typealias Draw = @Sendable (Flat16SurfacePattern) async -> CGImage?

    /// The key the card last asked for.
    private(set) var requested: Flat16CardImage.Key?
    /// The picture on hand, with the key it was drawn for.
    private var shown: (key: Flat16CardImage.Key, image: CGImage)?

    @ObservationIgnored private let cache: Flat16CardImage.Cache
    @ObservationIgnored private let draw: Draw

    init(
        cache: Flat16CardImage.Cache = Flat16CardImage.sharedCache,
        draw: @escaping Draw = Flat16CardImage.drawOffTheMainThread
    ) {
        self.cache = cache
        self.draw = draw
    }

    /// The picture for `key`, if it is the one on hand; otherwise none.
    func image(for key: Flat16CardImage.Key) -> CGImage? {
        guard let shown, shown.key == key else { return nil }
        return shown.image
    }

    /// Asks for the picture of `pattern`: from the cache if it is there,
    /// otherwise drawn. **Whatever comes back is shown only if the card still
    /// wants it** — the load not cancelled, and this key still the last asked for.
    func load(pattern: Flat16SurfacePattern) async {
        let key = Flat16CardImage.Key(pattern: pattern)
        requested = key
        if let cached = await cache.image(for: key) {
            show(cached, for: key)
            return
        }
        let drawn = await draw(pattern)
        guard let drawn else { return }
        await cache.keep(drawn, for: key)
        show(drawn, for: key)
    }

    private func show(_ image: CGImage, for key: Flat16CardImage.Key) {
        guard !Task.isCancelled, requested == key else { return }
        shown = (key, image)
    }
}
