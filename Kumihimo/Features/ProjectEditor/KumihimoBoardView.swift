import SwiftUI

struct KumihimoBoardView: View {
    let assignments: [ThreadAssignment]
    let selectPosition: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let boardRadius = size * 0.39
            let threadRadius = size * 0.37

            ZStack {
                Circle()
                    .fill(Color.brown.opacity(0.24))
                    .overlay {
                        Circle().stroke(Color.brown.opacity(0.55), lineWidth: 2)
                    }
                    .frame(width: boardRadius * 2, height: boardRadius * 2)

                Canvas { context, _ in
                    for assignment in assignments {
                        let endpoint = point(
                            position: assignment.position,
                            count: assignments.count,
                            radius: threadRadius,
                            center: center
                        )
                        var path = Path()
                        path.move(to: endpoint)
                        path.addLine(to: center)
                        context.stroke(path, with: .color(.primary.opacity(0.42)), lineWidth: 6)
                        context.stroke(
                            path,
                            with: .color(color(for: assignment.colorID).swiftUIColor),
                            lineWidth: 4
                        )
                    }
                }
                .accessibilityHidden(true)

                Circle()
                    .fill(.background)
                    .frame(width: size * 0.13, height: size * 0.13)
                    .overlay {
                        Circle().stroke(.primary.opacity(0.5), lineWidth: 2)
                    }
                    .accessibilityHidden(true)

                ForEach(assignments) { assignment in
                    let endpoint = point(
                        position: assignment.position,
                        count: assignments.count,
                        radius: threadRadius,
                        center: center
                    )
                    Button {
                        selectPosition(assignment.position)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(color(for: assignment.colorID).swiftUIColor)
                                .frame(width: 24, height: 24)
                                .overlay {
                                    Circle().stroke(.primary.opacity(0.7), lineWidth: 1.5)
                                }
                            Text("\(assignment.position)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(labelColor(for: assignment.colorID))
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .position(endpoint)
                    .accessibilityLabel(
                        ProjectEditorStrings.threadAccessibilityLabel(
                            position: assignment.position,
                            colorName: color(for: assignment.colorID).name
                        )
                    )
                    .accessibilityHint(ProjectEditorStrings.threadAccessibilityHint)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(ProjectEditorStrings.boardAccessibilityLabel)
    }

    private func point(
        position: Int,
        count: Int,
        radius: CGFloat,
        center: CGPoint
    ) -> CGPoint {
        guard count > 0 else { return center }
        let angle = -CGFloat.pi / 2
            + (2 * CGFloat.pi * CGFloat(position - 1) / CGFloat(count))
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }

    private func color(for id: ThreadColorID) -> ThreadColor {
        ThreadColorCatalog.color(for: id) ?? ThreadColorCatalog.defaultColor
    }

    private func labelColor(for id: ThreadColorID) -> Color {
        let value = color(for: id).value
        let luminance = 0.299 * value.red + 0.587 * value.green + 0.114 * value.blue
        return luminance > 0.58 ? .black : .white
    }
}
