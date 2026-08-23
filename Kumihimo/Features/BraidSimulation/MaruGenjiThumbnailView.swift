import SwiftUI

struct MaruGenjiThumbnailView: View {
    let assignments: [ThreadAssignment]

    var body: some View {
        Canvas { context, size in
            let paths = MaruGenjiPathGenerator.generate(
                assignments: assignments,
                cycleCount: 6,
                samplesPerCycle: 10
            )
            guard !paths.isEmpty else { return }
            let segments = projectedSegments(paths: paths, size: size)

            for segment in segments {
                var path = Path()
                path.move(to: segment.start)
                path.addLine(to: segment.end)
                context.stroke(
                    path,
                    with: .color(color(for: segment.colorID).swiftUIColor),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }

    private func color(for id: ThreadColorID) -> ThreadColor {
        ThreadColorCatalog.color(for: id) ?? ThreadColorCatalog.defaultColor
    }

    private func projectedSegments(
        paths: [BraidStrandPath],
        size: CGSize
    ) -> [Segment] {
        let horizontalPadding = size.width * 0.06
        let verticalScale = size.height * 0.72
        let centerY = size.height / 2
        let xRange = max(size.width - horizontalPadding * 2, 1)
        var segments = [Segment]()

        for strand in paths {
            for index in 0..<(strand.points.count - 1) {
                let start = strand.points[index]
                let end = strand.points[index + 1]
                let startXProgress = CGFloat((start.x + 1.7) / 3.4)
                let endXProgress = CGFloat((end.x + 1.7) / 3.4)
                let startPoint = CGPoint(
                    x: horizontalPadding + startXProgress * xRange,
                    y: centerY - CGFloat(start.y) * verticalScale
                )
                let endPoint = CGPoint(
                    x: horizontalPadding + endXProgress * xRange,
                    y: centerY - CGFloat(end.y) * verticalScale
                )
                segments.append(
                    Segment(
                        start: startPoint,
                        end: endPoint,
                        depth: (start.z + end.z) / 2,
                        colorID: strand.colorID
                    )
                )
            }
        }
        return segments.sorted { $0.depth < $1.depth }
    }

    private struct Segment {
        let start: CGPoint
        let end: CGPoint
        let depth: Float
        let colorID: ThreadColorID
    }
}
