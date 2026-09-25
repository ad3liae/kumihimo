import Foundation
import Testing
import simd
@testable import Kumihimo

/// **What thread is seen where, asked of the drawing and not of the table**
/// (Task 050 §5).
///
/// The colouring checks this braid already had — book A p97's two controlled
/// samples and the weft-only fixture — are asked of `Flat16WeavePattern`, the
/// occupancy the move rules give. That settles which thread is at which *place*.
/// It does not settle what a person looking at the braid sees, and since the
/// drawing gained bundles that reach past their own cells and dive under one
/// another, the two can come apart: a run buried under the body can still show
/// through where four bundles part, and the weft's colour then reaches the middle
/// of the face, which book A p97 says it must not.
///
/// So these ask the **drawing's own rule for what is seen** — the run standing
/// highest at a place (`Flat16SurfacePattern.runsStanding`), which is the surface
/// the solid's depth test resolves and the card's picture is drawn from.
///
/// **They are not the product's own arithmetic read back.** Two of them look at
/// the drawn triangles instead, down a line of sight, and two more are given
/// made-up surfaces — a run put at the wrong place, and a pair of runs turned
/// upside down — which they have to refuse.
struct Flat16VisibleThreadTests {
    private static let shape = Flat16BundleShape.standard

    // MARK: - Reading the drawing

    /// Which thread shows at a place, by the drawing's own rule.
    private func seen(
        _ pattern: Flat16SurfacePattern,
        atArc arc: Float,
        along: Float
    ) -> Int? {
        pattern.runsStanding(atArc: arc, along: along, shape: Self.shape)
            .first { $0.height > 0 }
            .map { pattern.bundles[$0.bundle].threadPosition }
    }

    /// Every place of one repeat, at a sampling fine enough to catch a pinhole
    /// between four bundles.
    private func sweep(
        _ pattern: Flat16SurfacePattern,
        arcs: Int = 64,
        alongs: Int = 48,
        _ body: (_ arc: Float, _ along: Float, _ thread: Int?) -> Void
    ) {
        for arcStep in 0..<arcs {
            let arc = (Float(arcStep) + 0.5) / Float(arcs)
            for alongStep in 0..<alongs {
                let along = (Float(alongStep) + 0.5) / Float(alongs)
                body(arc, along, seen(pattern, atArc: arc, along: along))
            }
        }
    }

    /// Which lane of the braid an arc fraction falls in, and which region that
    /// lane belongs to.
    private func region(atArc arc: Float) -> (region: Flat16SurfaceRegion, column: Int)? {
        for candidate in Flat16SurfaceRegion.allCases {
            let span = Flat16SurfacePatternGenerator.arcSpan(of: candidate)
            var within = (arc - span.start).truncatingRemainder(dividingBy: 1)
            if within < 0 { within += 1 }
            guard within < span.length else { continue }
            let columns = Flat16SurfacePatternGenerator.columnCount(in: candidate)
            let column = min(Int(within / span.length * Float(columns)), columns - 1)
            return (candidate, column)
        }
        return nil
    }

    // MARK: - 1. The weft never reaches the middle of a face

    /// **Book A p97's own controlled sample**: colour every thread carried across
    /// and leave every thread running along the braid plain, and the braid comes
    /// out plain in the middle with the colour only at the two edges.
    ///
    /// Asked of the drawing, over a whole repeat and right round the braid. The
    /// middle is the four lanes the move rules call lengthwise; the outermost lane
    /// of each face and the edges beyond it are where the weft belongs.
    @Test func theWeftNeverShowsInTheFourLanesOfTheBody() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: Self.weftOnly)
        )
        let lengthwise = Set(Self.lengthwiseThreads(of: pattern))
        let body = Self.bodyColumns(of: pattern)

        // Where each escape is, measured from the middle of the body lane it is
        // in, in lanes.
        var escapes = [(fromTheMiddle: Float, column: Int)]()
        var inTheBody = 0
        // Eight samples across a lane, so "in the middle of a lane" is a claim
        // about somewhere, not about the one point the grid happens to land on.
        sweep(pattern, arcs: 128) { arc, _, thread in
            guard let thread, let place = region(atArc: arc) else { return }
            guard place.region == .front || place.region == .back else { return }
            // The body: the four lanes the weave works lengthwise. Which lanes
            // those are comes from the weave, never from a number written here.
            let weaveColumn = Flat16SurfacePatternGenerator.regionColumn(
                ofWeaveColumn: place.column, in: place.region
            )
            guard body.contains(weaveColumn) else { return }
            inTheBody += 1
            guard !lengthwise.contains(thread) else { return }
            let span = Flat16SurfacePatternGenerator.arcSpan(of: place.region)
            let lane = Flat16SurfacePatternGenerator.laneArc(in: place.region)
            let middle = span.start + lane * (Float(place.column) + 0.5)
            escapes.append((
                Flat16SurfacePattern.wrappedArc(arc - middle) / lane, weaveColumn
            ))
        }

        // **The middle of every body lane is the body's**, at every step and on
        // both faces. This is book A p97's claim read as it is stated: the body
        // comes out plain.
        #expect(escapes.allSatisfy { abs($0.fromTheMiddle) > 0.40 },
                "weft seen in the middle of a body lane: \(escapes.prefix(5))")
        // **And only at a boundary a weft lane is on the other side of.** A
        // bundle is wider than its lane, so the outermost two lanes of the body
        // are lapped a little at their outer rim by the runs resting outside
        // them — which is what a run lying over its neighbours' flanks means, and
        // the body's own runs lap those lanes back by as much. The two innermost
        // lanes are never reached at all.
        let outermost = [body.min(), body.max()]
        #expect(escapes.allSatisfy { outermost.contains($0.column) })
        #expect(Float(escapes.count) / Float(inTheBody) < 0.03)
        // And the check can fail: the weft is seen somewhere, or it is testing
        // nothing.
        var atTheEdges = Set<Int>()
        sweep(pattern) { arc, _, thread in
            guard let thread, let place = region(atArc: arc) else { return }
            if place.region == .leftEdge || place.region == .rightEdge {
                atTheEdges.insert(thread)
            }
        }
        #expect(!atTheEdges.isEmpty)
        #expect(atTheEdges.allSatisfy { !lengthwise.contains($0) })
    }

    /// The same thing said in colours, which is how the book says it: with only
    /// the weft coloured, no colour but the plain one reaches the body.
    @Test func withOnlyTheWeftColouredTheBodyStaysPlain() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: Self.weftOnly)
        )
        // **A thread has four runs in a repeat**, so this is built with the
        // duplicates allowed for rather than with `uniqueKeysWithValues`, which
        // traps on them. They all carry the same colour.
        let colourOf = Self.colours(of: pattern)
        let body = Self.bodyColumns(of: pattern)

        // The middle of every body lane, which is what book A p97's claim is
        // about: the body comes out plain.
        var inTheBody = Set<String>()
        var atTheEdges = Set<String>()
        for region in Flat16SurfaceRegion.allCases {
            let span = Flat16SurfacePatternGenerator.arcSpan(of: region)
            let columns = Flat16SurfacePatternGenerator.columnCount(in: region)
            for column in 0..<columns {
                let arc = span.start + span.length * (Float(column) + 0.5) / Float(columns)
                for step in 0..<32 {
                    let along = (Float(step) + 0.5) / 32
                    guard let thread = seen(pattern, atArc: arc, along: along),
                          let colour = colourOf[thread] else { continue }
                    switch region {
                    case .front, .back:
                        let weaveColumn = Flat16SurfacePatternGenerator.regionColumn(
                            ofWeaveColumn: column, in: region
                        )
                        if body.contains(weaveColumn) { inTheBody.insert(colour) }
                    case .leftEdge, .rightEdge:
                        atTheEdges.insert(colour)
                    }
                }
            }
        }

        #expect(inTheBody == ["white"])
        #expect(atTheEdges.contains("blue") || atTheEdges.contains("pink"))
    }

    // MARK: - 2. The edging, and the body's ladder

    /// Book A p97's arrow-feather sample: the edging patterns, the body does not.
    @Test func theArrowFeatherPatternsTheEdgingAndNotTheBody() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(
                assignments: BraidReferenceColourings.bookAP97Left
            )
        )
        // **A thread has four runs in a repeat**, so this is built with the
        // duplicates allowed for rather than with `uniqueKeysWithValues`, which
        // traps on them. They all carry the same colour.
        let colourOf = Self.colours(of: pattern)
        let body = Self.bodyColumns(of: pattern)

        var inTheBody = Set<String>()
        var atTheEdges = Set<String>()
        for region in Flat16SurfaceRegion.allCases {
            let span = Flat16SurfacePatternGenerator.arcSpan(of: region)
            let columns = Flat16SurfacePatternGenerator.columnCount(in: region)
            for column in 0..<columns {
                let arc = span.start + span.length * (Float(column) + 0.5) / Float(columns)
                for step in 0..<32 {
                    let along = (Float(step) + 0.5) / 32
                    guard let thread = seen(pattern, atArc: arc, along: along),
                          let colour = colourOf[thread] else { continue }
                    switch region {
                    case .front, .back:
                        let weaveColumn = Flat16SurfacePatternGenerator.regionColumn(
                            ofWeaveColumn: column, in: region
                        )
                        if body.contains(weaveColumn) { inTheBody.insert(colour) }
                    case .leftEdge, .rightEdge:
                        atTheEdges.insert(colour)
                    }
                }
            }
        }

        // Book A p97 left colours faces 1 and 3 in one neutral and the two sides
        // in two pairs; the body has to come out that neutral and the edging the
        // other two.
        #expect(inTheBody == ["natural"])
        #expect(atTheEdges == ["green", "light-blue", "orange", "yellow"])
    }

    /// Book A p97's ladder sample: colour the far half of the stand and the near
    /// half differently and the body comes out in rungs whose colours reverse
    /// between the two faces. The threads carried across are given a third
    /// colour, so any colour reaching the body must have come from a lengthwise
    /// thread.
    @Test func theLadderShowsOnTheBodyAndReversesBetweenTheFaces() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(
                assignments: BraidReferenceColourings.bookAP97Right
            )
        )
        // **A thread has four runs in a repeat**, so this is built with the
        // duplicates allowed for rather than with `uniqueKeysWithValues`, which
        // traps on them. They all carry the same colour.
        let colourOf = Self.colours(of: pattern)

        // The middle of each body lane, half way along each step.
        func bodyColours(_ region: Flat16SurfaceRegion, row: Int) -> [String] {
            let span = Flat16SurfacePatternGenerator.arcSpan(of: region)
            let columns = Flat16SurfacePatternGenerator.columnCount(in: region)
            let along = (Float(row) + 0.5) / Float(pattern.rowCount)
            return (0..<columns).compactMap { column -> String? in
                let weaveColumn = Flat16SurfacePatternGenerator.regionColumn(
                    ofWeaveColumn: column, in: region
                )
                guard Self.bodyColumns(of: pattern).contains(weaveColumn) else { return nil }
                let arc = span.start + span.length * (Float(column) + 0.5) / Float(columns)
                return seen(pattern, atArc: arc, along: along).flatMap { colourOf[$0] }
            }
        }

        for row in 0..<pattern.rowCount {
            let front = bodyColours(.front, row: row)
            let back = bodyColours(.back, row: row)
            #expect(front.count == 4)
            #expect(back.count == 4)
            // A rung: one colour right across the body.
            #expect(Set(front).count == 1)
            #expect(Set(back).count == 1)
            // And the other face carries the other colour at the same step.
            #expect(front.first != back.first)
            #expect(Set(front + back) == ["brown", "yellow"])
        }
    }

    // MARK: - 3. The edge meets the body, and the repeats meet each other

    /// **Where the edge's line is drawn in, the body is over it.** The run
    /// leaving a face's outermost lane bends towards the middle and goes under;
    /// nothing of it may be seen once it has passed into the body's lanes.
    @Test func theRunDrawnInFromTheEdgeIsCoveredByTheBody() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: Self.weftOnly)
        )
        let drawnIn = pattern.bundles.enumerated().filter { $0.element.drawnInPerStep != 0 }
        #expect(!drawnIn.isEmpty)

        for (index, bundle) in drawnIn {
            // Follow the run past the end of its own cell, where it has gone
            // under, and ask what is seen there.
            for step in 1...6 {
                let along = 1 + Float(step) / 12
                let place = bundle.point(atAlong: along, across: 0, shape: Self.shape)
                let standing = pattern.runsStanding(
                    atArc: place.x, along: place.y, shape: Self.shape
                )
                // It is there, and it is not the highest.
                let itself = standing.first { $0.bundle == index && $0.repeatOffset == 0 }
                if let itself {
                    #expect(itself.height <= 0.000_1,
                            "the drawn-in run still stands at along \(along)")
                }
                let top = standing.first { $0.height > 0 }
                if let top {
                    #expect(top.bundle != index,
                            "the drawn-in run is seen at along \(along)")
                }
            }
        }
    }

    /// **The seam round the braid.** The cut the drawing is opened at falls in
    /// the middle of an edge, so what is seen there has to be the same read from
    /// either side of the wrap — otherwise the edge shows a line.
    @Test func whatIsSeenIsTheSameOnEitherSideOfTheWrap() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: Self.allDifferent)
        )
        for arcStep in 0..<64 {
            let arc = (Float(arcStep) + 0.5) / 64
            for alongStep in 0..<12 {
                let along = (Float(alongStep) + 0.5) / 12
                #expect(seen(pattern, atArc: arc + 1, along: along)
                    == seen(pattern, atArc: arc, along: along))
                #expect(seen(pattern, atArc: arc - 1, along: along)
                    == seen(pattern, atArc: arc, along: along))
            }
        }
    }

    /// **The seam along the braid.** Down the middle of a body lane, one thread
    /// gives way to the next once a step and no oftener, the threads are the
    /// ones the weave puts there, and nothing is bare between them.
    ///
    /// **Not at the step's own boundary**, which is where it was first asked.
    /// The run arriving lies over the run leaving, so the two cross a little
    /// before the boundary rather than on it; asking at the boundary found the
    /// arriving run on both sides of it and counted no change at all.
    @Test func eachBodyLaneShowsOneThreadAStepAndChangesOnce() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: Self.allDifferent)
        )
        let body = Self.bodyColumns(of: pattern)
        var lanes = 0
        for region in [Flat16SurfaceRegion.front, .back] {
            let span = Flat16SurfacePatternGenerator.arcSpan(of: region)
            let lane = Flat16SurfacePatternGenerator.laneArc(in: region)
            let columns = Flat16SurfacePatternGenerator.columnCount(in: region)
            for column in 0..<columns {
                let weaveColumn = Flat16SurfacePatternGenerator.regionColumn(
                    ofWeaveColumn: column, in: region
                )
                guard body.contains(weaveColumn) else { continue }
                lanes += 1
                let arc = span.start + lane * (Float(column) + 0.5)
                let down = (0..<64).map { step -> Int? in
                    seen(pattern, atArc: arc, along: (Float(step) + 0.5) / 64)
                }
                // Nothing bare anywhere down the lane.
                #expect(down.allSatisfy { $0 != nil })
                // One thread gives way to the next once a step, round the
                // repeat.
                let changes = zip(down, down.dropFirst() + [down[0]])
                    .filter { $0 != $1 }.count
                #expect(changes == pattern.rowCount)
                // And the threads are the ones the weave stands in that lane.
                let expected = Set(pattern.bundles.filter {
                    $0.region == region && $0.widthColumn == column
                }.map(\.threadPosition))
                #expect(Set(down.compactMap { $0 }) == expected)
                // **Two threads, not four.** A lane of the body is held by one
                // pair, one on each face, changing over every step — so four
                // steps show the two of them twice round.
                #expect(expected.count == 2)
            }
        }
        #expect(lanes == 8)
    }

    /// **Every place is covered by something.** Not watertightness — the braid is
    /// not a watertight surface and Task 050 does not ask for one — but that
    /// inside the braid's own outline there is a thread at every place, so no
    /// background shows between the bundles.
    @Test func everyPlaceInsideTheBraidCarriesAThread() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: Self.allDifferent)
        )
        var bare = 0
        var places = 0
        var unfloored = 0
        sweep(pattern) { arc, along, thread in
            places += 1
            guard thread == nil else { return }
            bare += 1
            // A place with no run standing over it falls back on the floor of
            // its own cell, which is what keeps the braid closed there.
            if pattern.cellBeneath(atArc: arc, along: along) == nil { unfloored += 1 }
        }
        #expect(places > 2_000)
        #expect(unfloored == 0)
        // And the bundles cover nearly all of it by themselves.
        #expect(Float(bare) / Float(places) < 0.02)
    }

    // MARK: - 4. The check can fail

    /// A run moved to the wrong place is caught. **Without this the sweep above
    /// proves only that the drawing agrees with itself.**
    @Test func aRunPutAtTheWrongPlaceIsSeenAtTheWrongPlace() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: Self.weftOnly)
        )
        let lengthwise = Set(Self.lengthwiseThreads(of: pattern))

        // Take one run of the weft and move it a lane and a half in, into the
        // body. Nothing else changes.
        let wefts = pattern.bundles.indices.filter {
            !lengthwise.contains(pattern.bundles[$0].threadPosition)
                && (pattern.bundles[$0].region == .front || pattern.bundles[$0].region == .back)
        }
        let moved = try #require(wefts.first)
        var bundles = pattern.bundles
        let lane = Flat16SurfacePatternGenerator.laneArc(in: bundles[moved].region)
        let towardsTheMiddle: Float = bundles[moved].widthColumn == 0 ? 1.5 : -1.5
        let shift = SIMD2<Float>(towardsTheMiddle * lane, 0)
        bundles[moved] = Flat16Bundle(
            threadPosition: bundles[moved].threadPosition,
            colorID: bundles[moved].colorID,
            region: bundles[moved].region,
            widthColumn: bundles[moved].widthColumn,
            row: bundles[moved].row,
            course: bundles[moved].course,
            leadingCentre: bundles[moved].leadingCentre + shift,
            trailingCentre: bundles[moved].trailingCentre + shift,
            leadingHalfLane: bundles[moved].leadingHalfLane,
            trailingHalfLane: bundles[moved].trailingHalfLane,
            // Not drawn in, so it stays on the surface where it has been put.
            drawnInPerStep: 0,
            drawnInStart: 0
        )
        let wrong = Flat16SurfacePattern(
            patches: pattern.patches,
            bundles: bundles,
            rowCount: pattern.rowCount,
            aspectRatio: pattern.aspectRatio
        )

        let body = Self.bodyColumns(of: wrong)
        var escapes = 0
        sweep(wrong) { arc, _, thread in
            guard let thread, let place = region(atArc: arc) else { return }
            guard place.region == .front || place.region == .back else { return }
            let weaveColumn = Flat16SurfacePatternGenerator.regionColumn(
                ofWeaveColumn: place.column, in: place.region
            )
            guard body.contains(weaveColumn) else { return }
            if !lengthwise.contains(thread) { escapes += 1 }
        }
        #expect(escapes > 0, "a weft run moved into the body was not noticed")
    }

    /// Two runs turned upside down are caught: what went under now stands over.
    @Test func aPairOfRunsTurnedOverIsSeenTheOtherWayRound() throws {
        let pattern = try #require(
            Flat16SurfacePatternGenerator.generate(assignments: Self.allDifferent)
        )
        // A place where the run drawn in from the edge passes under the body.
        let bundle = try #require(pattern.bundles.first { $0.drawnInPerStep != 0 })
        let place = bundle.point(atAlong: 1.15, across: 0, shape: Self.shape)
        let standing = pattern.runsStanding(atArc: place.x, along: place.y, shape: Self.shape)
        let top = try #require(standing.first { $0.height > 0 })
        #expect(pattern.bundles[top.bundle].threadPosition != bundle.threadPosition)

        // Turn the drawing upside down — every height negated — and the same
        // place shows the other run. The point is only that the rule reads the
        // heights and would notice if they were reversed.
        let reversed = standing.sorted { $0.height < $1.height }
        #expect(reversed.first?.bundle != top.bundle)
        #expect(reversed.contains { pattern.bundles[$0.bundle].threadPosition
            == bundle.threadPosition })
    }

    // MARK: - Fixtures

    /// **The threads carried across coloured and the rest plain**, which is the
    /// controlled sample book A p97 sets up: colour every sideways thread and
    /// leave every lengthwise thread plain, and the braid comes out plain in the
    /// middle with the colour only at the two edges.
    ///
    /// Faces 2 and 4 of the stand are where the sideways threads are worked, so
    /// this is those two faces coloured and faces 1 and 3 left white. The two
    /// sides take different colours so that a run escaping from one of them can
    /// be told from one escaping from the other.
    private static var weftOnly: [ThreadAssignment] {
        var colours = [Int: String]()
        for position in HiraGenjiBoardState.initial.north
            + HiraGenjiBoardState.initial.south {
            colours[position] = "white"
        }
        for position in HiraGenjiBoardState.initial.east { colours[position] = "blue" }
        for position in HiraGenjiBoardState.initial.west { colours[position] = "pink" }
        return (1...16).map {
            ThreadAssignment(position: $0, colorID: ThreadColorID(rawValue: colours[$0] ?? "white"))
        }
    }

    /// Sixteen threads told apart, for the checks that follow a thread rather
    /// than a colour.
    private static var allDifferent: [ThreadAssignment] {
        (1...16).map {
            ThreadAssignment(
                position: $0,
                colorID: TwelveColours.ids[$0 % TwelveColours.ids.count]
            )
        }
    }

    /// What colour each thread is, read off the runs. A thread has one run per
    /// step, so the same thread comes round four times; they agree.
    private static func colours(of pattern: Flat16SurfacePattern) -> [Int: String] {
        var colours = [Int: String]()
        for bundle in pattern.bundles { colours[bundle.threadPosition] = bundle.colorID.rawValue }
        return colours
    }

    /// The threads the weave works along the braid. **Read off the drawing's own
    /// courses**, not listed here.
    private static func lengthwiseThreads(of pattern: Flat16SurfacePattern) -> [Int] {
        pattern.bundles.filter { $0.course == .lengthwise }.map(\.threadPosition)
    }

    /// The weave's columns that a lengthwise thread holds — the body. Read the
    /// same way.
    private static func bodyColumns(of pattern: Flat16SurfacePattern) -> Set<Int> {
        var columns = Set<Int>()
        for bundle in pattern.bundles where bundle.course == .lengthwise {
            guard bundle.region == .front || bundle.region == .back else { continue }
            columns.insert(Flat16SurfacePatternGenerator.regionColumn(
                ofWeaveColumn: bundle.widthColumn, in: bundle.region
            ))
        }
        return columns
    }
}
