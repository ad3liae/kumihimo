import SwiftUI

/// **A braid's working, hand by hand, on a round stand seen from above** (Task
/// 061): the stand's top, the hole in its middle, a bobbin for every thread in
/// the thread's colour and its thread running in to the middle. Each hand lights
/// the thread it carries, points where it goes, and slides it round the rim
/// there; a thread that arrives at a place still taken waits beside it until
/// that place's thread leaves. Beside it, or under it where there is no room,
/// the hand in words and how far through the time round it is; under both,
/// back a hand, play, on a hand.
///
/// **Place 1 at the top and the places clockwise**, as the colouring screen draws
/// them, so the colours stand where the person put them. The drawing reads the
/// script only (`BraidStepScript`), never the braid's name.
struct BraidStepsView: View {
    private let script: BraidStepScript?
    private let colours: [Int: ThreadColorID]
    /// The room offered: the width to keep inside, and the height to fill.
    private let room: CGSize

    @State private var playback: BraidStepPlayback
    @State private var wordsHeight: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    static let minimumStandHeight: CGFloat = 150
    /// The least width the words take beside the stand.
    private static let minimumColumnWidth: CGFloat = 140
    private static let spacing: CGFloat = 8

    init(recipe: BraidRecipe?, assignments: [ThreadAssignment], room: CGSize) {
        let colours = Dictionary(
            assignments.map { ($0.position, $0.colorID) }, uniquingKeysWith: { first, _ in first }
        )
        let script = recipe.flatMap { recipe in
            BraidMethodCatalog.stand(for: recipe).flatMap {
                BraidStepScript(recipe: recipe, stand: $0, colours: colours)
            }
        }
        self.script = script.flatMap { $0.hands.isEmpty ? nil : $0 }
        self.colours = colours
        self.room = room
        _playback = State(initialValue: BraidStepPlayback(handCount: script?.hands.count ?? 1))
    }

    var body: some View {
        Group {
            if let script {
                TimelineView(.animation(minimumInterval: nil, paused: !playback.isRunning)) { context in
                    let position = playback.position(at: context.date)
                    let hand = script.hands[min(position.hand, script.hands.count - 1)]
                    let sentence = BraidStepsStrings.sentence(for: hand, tableCount: script.tableCount)
                    let count = BraidStepsStrings.count(position.hand + 1, of: script.hands.count)
                    arranged(
                        stand: BraidStandDrawing(
                            frame: BraidStepFrame.at(
                                position.time, of: hand, on: script.stand, reduceMotion: reduceMotion
                            ),
                            stand: script.stand,
                            colours: colours
                        )
                        .accessibilityElement()
                        .accessibilityLabel(BraidStepsStrings.standAccessibilityLabel)
                        .accessibilityValue(
                            BraidStepsStrings.accessibilityValue(count: count, sentence: sentence)
                        ),
                        words: words(sentence: sentence, count: count)
                    )
                    .onChange(of: position.hand) {
                        announce(sentence)
                    }
                    .onChange(of: playback.hasFinishedStepping(at: context.date)) { _, finished in
                        if finished { playback.settle(at: .now) }
                    }
                }
            } else {
                Text(BraidStepsStrings.nothingToShow)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: Self.minimumStandHeight)
            }
        }
    }

    /// **The stand with the words beside it, and the buttons under both, when
    /// that gives the stand more room** than putting everything under it — an
    /// iPhone held upright and anything wider, where the lower part is short and
    /// wide. Never at the accessibility text sizes, where the words need the
    /// width.
    private var sideBySide: Bool {
        guard !dynamicTypeSize.isAccessibilitySize else { return false }
        return besideSide >= min(room.width, room.height - Self.wordsAllowance)
    }

    /// The stand's side when the words stand beside it.
    private var besideSide: CGFloat {
        min(room.height - Self.controlsAllowance - Self.spacing,
            room.width - Self.minimumColumnWidth - 2 * Self.spacing)
    }

    /// Roughly what the words and buttons take under the stand: two lines, the
    /// count, the buttons; and the buttons alone.
    private static let wordsAllowance: CGFloat = 120
    private static let controlsAllowance: CGFloat = 50

    /// **Everything kept inside `room.width`**: the words wrap in a column of
    /// fixed width, and the buttons share the full width, so a large text size
    /// makes the part taller, never wider.
    @ViewBuilder
    private func arranged(stand: some View, words: some View) -> some View {
        if sideBySide {
            let side = max(Self.minimumStandHeight, besideSide.rounded(.down))
            VStack(spacing: Self.spacing) {
                HStack(spacing: 2 * Self.spacing) {
                    stand.frame(width: side, height: side)
                    words.frame(width: max(0, room.width - side - 2 * Self.spacing))
                }
                controls
            }
            .frame(width: room.width)
        } else {
            VStack(spacing: Self.spacing) {
                stand.frame(
                    height: max(Self.minimumStandHeight, (room.height - wordsHeight - Self.spacing).rounded(.down))
                )
                VStack(spacing: Self.spacing) {
                    words
                    controls
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { wordsHeight = $0 }
            }
            .frame(width: room.width)
        }
    }

    /// The hand in words, over two lines' room so nothing jumps as the
    /// sentences change length, and the count. VoiceOver reads both off the
    /// stand instead.
    private func words(sentence: String, count: String) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Text(verbatim: "\n").hidden()
                Text(sentence)
            }
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            Text(count)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }

    private var controls: some View {
        HStack(spacing: Self.spacing) {
            control(BraidStepsStrings.stepBack, systemImage: "backward.frame.fill") {
                playback.stepBack(at: .now)
            }
            if playback.isPlaying {
                control(BraidStepsStrings.pause, systemImage: "pause.fill") {
                    playback.pause(at: .now)
                }
            } else {
                control(BraidStepsStrings.play, systemImage: "play.fill") {
                    playback.play(at: .now)
                }
            }
            control(BraidStepsStrings.stepForward, systemImage: "forward.frame.fill") {
                playback.stepForward(at: .now)
            }
        }
    }

    private func control(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(title)
    }

    private func announce(_ sentence: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        AccessibilityNotification.Announcement(sentence).post()
    }
}

/// The stand itself, drawn from one frame.
private struct BraidStandDrawing: View {
    let frame: BraidStepFrame
    let stand: BraidStand
    let colours: [Int: ThreadColorID]

    /// The drawing's reach in units of the rim's radius: the numbers stand
    /// outside the arrows, which stand outside the rim.
    private static let reach: Double = 1.44
    private static let boardRadius: Double = 1.07
    private static let arrowRadius: Double = 1.17
    private static let numberRadius: Double = 1.34
    private static let holeRadius: Double = 0.11

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 2 / Self.reach
            let middle = CGPoint(x: size.width / 2, y: size.height / 2)
            func onCanvas(_ point: CGPoint) -> CGPoint {
                CGPoint(x: middle.x + point.x * scale, y: middle.y + point.y * scale)
            }
            let ballRadius = min(0.15, 0.4 * sin(.pi / Double(max(stand.positionCount, 1)))) * scale

            let board = circle(at: middle, radius: Self.boardRadius * scale)
            context.fill(board, with: .color(Color.brown.opacity(0.24)))
            context.stroke(board, with: .color(Color.brown.opacity(0.55)), lineWidth: 2)

            // The numbers are part of the drawing, so they go with its size
            // rather than the text size; VoiceOver reads the hand instead.
            let numberSize = min(max(scale * 0.16, 9), 15)
            for position in stand.positions {
                let point = BraidStepFrame.Polar(turn: position.rim, radius: Self.numberRadius).cartesian
                context.draw(
                    Text("\(position.id)").font(.system(size: numberSize)).foregroundStyle(.secondary),
                    at: onCanvas(point)
                )
            }

            for arrow in frame.arrows {
                drawArrow(arrow, in: &context, onCanvas: onCanvas, scale: scale)
            }

            let lineWidth = max(2, ballRadius * 0.34)
            for ball in frame.balls {
                var line = Path()
                line.move(to: onCanvas(ball.point))
                line.addLine(to: middle)
                context.stroke(line, with: .color(.primary.opacity(0.42)), lineWidth: lineWidth + 2)
                context.stroke(line, with: .color(colour(of: ball.thread)), lineWidth: lineWidth)
            }

            let hole = circle(at: middle, radius: Self.holeRadius * scale)
            context.fill(hole, with: .color(Color(uiColor: .systemBackground)))
            context.stroke(hole, with: .color(.primary.opacity(0.5)), lineWidth: 2)

            for ball in frame.balls {
                let centre = onCanvas(ball.point)
                if ball.isCarried {
                    context.stroke(
                        circle(at: centre, radius: ballRadius + 4), with: .color(.accentColor), lineWidth: 3
                    )
                }
                let bobbin = circle(at: centre, radius: ballRadius)
                context.fill(bobbin, with: .color(colour(of: ball.thread)))
                context.stroke(bobbin, with: .color(.primary.opacity(0.7)), lineWidth: 1.5)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func colour(of thread: Int) -> Color {
        colours[thread].flatMap(ThreadColorCatalog.color(for:))?.swiftUIColor ?? .gray
    }

    private func circle(at centre: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: 2 * radius, height: 2 * radius))
    }

    /// An arc just outside the rim from the place left to the place reached,
    /// the way the thread goes, with its head at the end; straight over the
    /// middle for a thread carried across.
    private func drawArrow(
        _ arrow: BraidStepFrame.Arrow, in context: inout GraphicsContext,
        onCanvas: (CGPoint) -> CGPoint, scale: CGFloat
    ) {
        guard
            let from = stand.position(withID: arrow.from)?.rim,
            let to = stand.position(withID: arrow.to)?.rim
        else { return }
        var points = [CGPoint]()
        if arrow.way == .across {
            let start = BraidStepFrame.Polar(turn: from, radius: 0.8).cartesian
            let end = BraidStepFrame.Polar(turn: to, radius: 0.8).cartesian
            points = [onCanvas(start), onCanvas(end)]
        } else {
            // A little short of both places, so two arrows that meet — a hand of
            // two carried half way round each — still read as two.
            let gap = 0.12 / Double(max(stand.positionCount, 1)) * (arrow.way == .clockwise ? 1 : -1)
            let startPolar = BraidStepFrame.Polar(turn: from + gap, radius: Self.arrowRadius)
            let endPolar = BraidStepFrame.Polar(turn: to - gap, radius: Self.arrowRadius)
            let samples = 48
            for index in 0...samples {
                let share = Double(index) / Double(samples)
                let polar = BraidStepFrame.slide(
                    from: startPolar, to: endPolar, way: arrow.way, share: share, lift: 0
                )
                points.append(onCanvas(polar.cartesian))
            }
        }
        guard points.count >= 2, let tip = points.last else { return }
        var path = Path()
        path.addLines(points)
        context.stroke(path, with: .color(.accentColor), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        let back = points[points.count - 2]
        let angle = atan2(tip.y - back.y, tip.x - back.x)
        let length: CGFloat = 10, spread: CGFloat = .pi / 7
        var head = Path()
        head.move(to: tip)
        head.addLine(to: CGPoint(x: tip.x - length * cos(angle - spread), y: tip.y - length * sin(angle - spread)))
        head.addLine(to: CGPoint(x: tip.x - length * cos(angle + spread), y: tip.y - length * sin(angle + spread)))
        head.closeSubpath()
        context.fill(head, with: .color(.accentColor))
    }
}
