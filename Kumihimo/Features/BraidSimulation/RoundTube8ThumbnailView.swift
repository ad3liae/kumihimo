import SwiftUI

/// The eight-thread tube, unrolled flat for a card.
///
/// **The same drawing the solid is built from**, laid out by the same
/// `UnrolledPatternThumbnailLayout` the sixteen-thread tube's card uses, so the
/// two cards read at the same scale. Each thread is drawn as its visible run
/// (`RoundTube8Bundle`) — the outline the solid's run has, leaning the carry's
/// way and ending in a point beneath the next thread — **earliest arrival
/// first**, so a later thread is painted over the one it was laid on, as it lies
/// on it on the solid (Task 045).
///
/// **A run hangs past the ends of its repeat** — its thread arrived in the cycle
/// before, and it goes on beneath the next one — and the frame crops what hangs
/// past the card, as it crops every overhanging repeat. Nothing is cut at a
/// repeat's edge, so no line runs across all eight lanes (Task 033).
///
/// **The colour diagonal is still which thread stands where**, one place a
/// cycle; the lean of each run is how that thread shows.
struct RoundTube8ThumbnailView: View {
    let pattern: RoundTube8SurfacePattern
    var bundle: RoundTube8Bundle = .standard

    /// Points down each side of a run's outline.
    private static let outlineSamples = 16

    var body: some View {
        Canvas { context, size in
            guard let layout = UnrolledPatternThumbnailLayout(
                size: size,
                aspectRatio: pattern.aspectRatio
            ) else { return }

            // Beneath: each thread's own cell, in the shade the solid gives the
            // valley floor, so a gap between two runs shows the thread lying there.
            for repeatIndex in layout.repeatIndices {
                for segment in pattern.surface.segments {
                    var path = Path()
                    for (index, corner) in cell(of: segment).enumerated() {
                        let point = layout.point(surfaceCoordinate: corner, repeatIndex: repeatIndex)
                        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    path.closeSubpath()
                    context.fill(path, with: .color(color(for: segment.colorID).swiftUIColor))
                    context.fill(path, with: .color(.black.opacity(Self.beneathShade)))
                }
            }

            // Every run of every repeat, in the order the threads arrived.
            let runs = layout.repeatIndices.flatMap { repeatIndex in
                pattern.surface.segments.map { (repeatIndex, $0) }
            }.sorted {
                Float($0.0) + $0.1.centerlineStart.y < Float($1.0) + $1.1.centerlineStart.y
            }
            for (repeatIndex, segment) in runs {
                // Round the braid is a ring: a run near the seam shows at both
                // edges of the card, so it is drawn a turn either side as well.
                for turn in [-1, 0, 1] {
                    var path = Path()
                    for (index, corner) in outline(of: segment).enumerated() {
                        let point = layout.point(
                            surfaceCoordinate: corner + SIMD2(Float(turn), 0),
                            repeatIndex: repeatIndex
                        )
                        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    path.closeSubpath()
                    context.fill(path, with: .color(color(for: segment.colorID).swiftUIColor))
                    context.stroke(path, with: .color(.primary.opacity(0.26)), lineWidth: 0.7)
                }
            }
        }
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }

    /// How much darker a cell beneath shows than a run: the valley shading the
    /// solid gives it (`RoundTube16StrandTextureFactory.valleyOcclusion`).
    private static var beneathShade: Double {
        Double(1 - RoundTube16StrandTextureFactory.valleyOcclusion)
    }

    /// The thread's cell: one column wide, from its arrival to the next.
    private func cell(of segment: BraidStrandSegment) -> [SIMD2<Float>] {
        [
            segment.surfacePoint(along: 0, across: -1),
            segment.surfacePoint(along: 0, across: 1),
            segment.surfacePoint(along: 1, across: 1),
            segment.surfacePoint(along: 1, across: -1),
        ]
    }

    /// The run's outline in surface coordinates: down one side from the
    /// arrival to the tip, and back up the other.
    private func outline(of segment: BraidStrandSegment) -> [SIMD2<Float>] {
        let columns = Float(RoundTube8SurfacePatternGenerator.requiredThreadCount)
        let cycle = segment.centerlineEnd.y - segment.centerlineStart.y
        func point(_ step: Int, _ side: Float) -> SIMD2<Float> {
            let cycles = bundle.lengthInCycles * Float(step) / Float(Self.outlineSamples)
            let across = bundle.leanInColumns(atCycles: cycles, direction: pattern.leanDirection)
                + side * bundle.halfWidthInColumns(atCycles: cycles)
            return SIMD2(
                segment.centerlineStart.x + across / columns,
                segment.centerlineStart.y + cycles * cycle
            )
        }
        let steps = 0...Self.outlineSamples
        return steps.map { point($0, -1) } + steps.reversed().map { point($0, 1) }
    }

    private func color(for id: ThreadColorID) -> ThreadColor {
        ThreadColorCatalog.color(for: id) ?? ThreadColorCatalog.defaultColor
    }
}
