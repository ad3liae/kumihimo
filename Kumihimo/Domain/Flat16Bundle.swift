import Foundation
import simd

/// **What a thread's visible run looks like on the flat braid: a bundle with a
/// round belly that meets its neighbours in a groove, and — where the thread
/// leaves the face — bends in across the width and sinks beneath the body**
/// (Task 050).
///
/// **A drawing approximation, not a derivation.** The cell a thread holds — one
/// lane round the cross-section, one step along the braid — is still what the
/// occupancy history gives, and it is still `Flat16SurfacePatch`: which thread is
/// at which place, and what colour it is, does not move. What this adds is how
/// that thread *shows*, and it is the same separation the eight-thread tube makes
/// between its cells and `RoundTube8Bundle`.
///
/// **The bundle is not the cell.** It is wider than its lane, so it lies over its
/// neighbours' flanks instead of sharing a valley floor with them, and longer than
/// its step, so the runs of one lane overlap instead of meeting end to end at a
/// height of nothing. What the braid had before was each cell filled by a ridge
/// that died to the valley at all four of its own edges, which drew a deep grid
/// over the whole face — the reading Task 050 was opened to be rid of.
///
/// **The two directions are not alike, because the braid is not.** Along a lane
/// the two threads of that place change over at every step — one goes to the
/// other face and one comes from it — so the parting there is a crossing, and it
/// runs deep (`joinHeight`). Across the width two threads only lie side by side
/// and press together, so that parting is shallower (`widthOverLane`). What keeps
/// the face from reading as lanes is not that the two are equal but that a bundle
/// is a **lens**: it is pinched at the ends of its own cell (`endWidth`), so the
/// parting between two lanes is scalloped by the steps rather than ruled straight
/// down the braid.
struct Flat16BundleShape: Equatable, Sendable {
    /// How high two runs of one lane meet, as a fraction of the crest. The groove
    /// between one bundle and the next along the braid is this far above the
    /// valley floor.
    let joinHeight: Float
    /// How high two lanes' bundles meet, as a fraction of the crest. A bundle is
    /// made as wide as it has to be for its flank to be this high where it
    /// crosses its neighbour's — see `widthOverLane`.
    let laneJoinHeight: Float
    /// How wide a bundle is at the two ends of its own cell, as a fraction of its
    /// widest. Under 1 it is a lens, pinched where the runs of the lanes beside
    /// it are pinched too, so the four of them part at a point.
    let endWidth: Float
    /// How much higher a bundle stands at the end where it laps over the run
    /// before it, as a fraction of its own height there.
    let headLift: Float
    /// How much lower it stands at the end where it passes under the run after
    /// it.
    let tailDip: Float
    /// How far past the ends of its own swell a bundle goes on, sinking, so its
    /// tip is buried rather than cut. In steps along the braid.
    let tipReach: Float
    /// How far below the valley floor a buried tip ends, in crests.
    let buriedTipSink: Float
    /// How much narrower a bundle is at its buried tips, so a tip does not stand
    /// out sideways from under the run covering it.
    let tipNarrowing: Float

    /// **Set by eye against the photographs — and there are eight of them, not
    /// two.** `joinHeight`, `laneJoinHeight`, `endWidth`, `headLift`, `tailDip`,
    /// `tipReach`, `buriedTipSink` and `tipNarrowing` are every one calibrated.
    /// What is *not* chosen is the form — **one raised cosine, along the run and
    /// across it alike** — and the two figures solved from the join heights,
    /// `bellyHalfSpan` and `widthOverLane`.
    ///
    /// **Every one of them is in `Flat16SurfaceMesh.shape` with its own
    /// standing**, and `BraidFamilyDrawingTests` counts the calibrated against
    /// the worked-out so that a figure cannot move quietly from one to the
    /// other.
    ///
    /// `joinHeight` 0.16 leaves the groove between two runs of a lane about five
    /// sixths of the way down to the valley. **It was tried at 0.45 first and
    /// that is too shallow**: the body read as four smooth lengthwise tubes with
    /// a hint of a cross line, which is the opposite of the fault Task 050 was
    /// opened on and no nearer book A p.72, where the navy beads part plainly.
    /// What the drawing before it had was 0 — every groove all the way down to
    /// the valley, in both directions at once — and that is the grid.
    ///
    /// `laneJoinHeight` 0.36 leaves the parting between two lanes much shallower
    /// than the one along the braid, which is what the braid itself has: along a
    /// lane the two threads cross over, and across it they only lie side by side
    /// and press together.
    ///
    /// `endWidth` 0.62 makes the lens, and **the lens is what makes the face read
    /// as beads rather than as lanes.** Across its belly a bundle lies well over
    /// the flanks of the lanes beside it (`widthOverLane` comes out at 1.70) and
    /// the parting there is shallow; at the ends of its own cell it is pinched to
    /// a little over one lane and the parting drops to the valley. So the line
    /// between two lanes is not ruled down the braid but pinches in and out once
    /// a step, and four bundles part at a point. A bundle of constant width was
    /// tried first and drew the face as a quilt of rectangles — the
    /// 「升ごとの平板」 Task 050 names — and a gentler lens (0.78 on a belly of
    /// 1.45) left the partings ruled.
    ///
    /// **The pinch may not open a slot.** Every lane's cells end at the same step
    /// (the body's joins are square, `Flat16SurfacePatternGenerator
    /// .longitudinalPhases`), so if the pinched width fell below one lane the
    /// four bundles would part along a line running right across the braid, and
    /// the floor would show through it as a ruled crosswise groove — worse than
    /// the rectangles. `widthOverLane * endWidth` is 1.694 × 0.62 = 1.050, so
    /// they still overlap where they are narrowest, and what parts them is a
    /// point rather than a line. This was found by drawing it where the product
    /// is 0.83, and the line is plain to see.
    ///
    /// `headLift` and `tailDip` say which of two runs meeting in a lane shows at
    /// the join. **They are not free either**: the two threads of a body lane
    /// change places at every step, one going to the other face and one coming
    /// from it, so the one arriving lies on the one leaving
    /// (`docs/architecture.md`, 組み台の力学). They only say how plainly that
    /// reads.
    static let standard = Flat16BundleShape(
        joinHeight: 0.16,
        laneJoinHeight: 0.36,
        endWidth: 0.62,
        headLift: 0.16,
        tailDip: 0.3,
        tipReach: 0.25,
        buriedTipSink: 0.1,
        tipNarrowing: 0.45
    )

    /// How far a bundle's swell reaches either side of the middle of its cell,
    /// in steps along the braid. **Solved from `joinHeight`**, by inverting the
    /// swell's own profile at the cell's end.
    var bellyHalfSpan: Float { 0.5 / Self.swellPlace(ofHeight: joinHeight) }

    /// How wide a bundle is compared with its lane. **Solved from
    /// `laneJoinHeight`**, by inverting the same profile across the run: the
    /// bundle is wide enough that the point half a lane from its crest — where
    /// its neighbour's crest is a lane away — stands at that height.
    var widthOverLane: Float { 1 / Self.swellPlace(ofHeight: laneJoinHeight) }

    /// Where on the swell, 0 at the crest and 1 at the rim, the profile has a
    /// given height.
    static func swellPlace(ofHeight height: Float) -> Float {
        acos(min(max(2 * height - 1, -1), 1)) / .pi
    }

    /// **The swell's own profile, and the one shape both directions use**: a
    /// raised cosine, 1 at the crest and 0 at the rim.
    ///
    /// **Not a circle's section, and that took two tries to see.** A circle —
    /// `sqrt(1 - x²)`, which is what a round yarn's own section is — is nearly
    /// flat over the middle of its span and does four fifths of its falling in
    /// the last tenth. A bundle drawn with it has a broad flat top and parts from
    /// the next one along a hairline; lit from the front, as the preview lights
    /// this braid, that is a quilt of tiles with slots cut between them, which is
    /// the fault Task 050 was opened on wearing different clothes. A parabola
    /// (the round braid's own choice for its bundles, Task 047) is better and
    /// still not enough. The raised cosine spreads the fall over the whole span —
    /// half its height at half its reach — so a bundle shades as a bean from its
    /// crest outwards, which is what book A p.72's navy body does.
    ///
    /// **It is a drawing choice about how a bundle reads, not a claim about the
    /// section of a yarn.**
    static func swell(atPlace place: Float) -> Float {
        let clamped = min(max(abs(place), 0), 1)
        return (1 + cos(.pi * clamped)) / 2
    }

    /// Where a run begins and ends, in steps past the start of its own cell.
    var runStart: Float { 0.5 - bellyHalfSpan - tipReach }
    var runEnd: Float { 0.5 + bellyHalfSpan + tipReach }

    /// The swell along the run: 1 at the middle of the cell and nothing at
    /// `0.5 ± bellyHalfSpan`. **Even about the middle** — the author's ruling on
    /// the eight-thread tube's bundles (Task 049: 「偏りのある膨らみではない。
    /// 円弧というか半円状で良い」), and a flat braid's yarn is the same yarn.
    func belly(atAlong along: Float) -> Float {
        Self.swell(atPlace: (along - 0.5) / bellyHalfSpan)
    }

    /// 1 at the two ends of a cell and 0 at its middle. The round braid's own
    /// weight, used for what it means there.
    func crossingWeight(atAlong along: Float) -> Float {
        (1 + cos(2 * .pi * min(max(along, 0), 1))) / 2
    }

    /// Higher towards the end that laps over, lower towards the end that passes
    /// under, and 1 at mid-span, so the swell itself is untouched.
    func endFactor(atAlong along: Float) -> Float {
        let weight = crossingWeight(atAlong: along)
        return along < 0.5 ? 1 + headLift * weight : 1 - tailDip * weight
    }

    /// How far past the swell's own ends a point is, and nothing inside them.
    func pastTheSwell(atAlong along: Float) -> Float {
        max(0.5 - bellyHalfSpan - along, along - 0.5 - bellyHalfSpan, 0)
    }

    /// How far a buried tip has sunk, 0 to 1.
    func sinking(atAlong along: Float) -> Float {
        guard tipReach > 0 else { return pastTheSwell(atAlong: along) > 0 ? 1 : 0 }
        let progress = min(max(pastTheSwell(atAlong: along) / tipReach, 0), 1)
        return progress * progress * (3 - 2 * progress)
    }

    /// The section across the run: 1 on the crest and nothing at either rim. The
    /// same profile as the swell along it, so a bundle domes alike both ways.
    func crestProfile(across: Float) -> Float {
        Self.swell(atPlace: across)
    }

    /// How far the surface stands at one place on a run, **in crests**. Negative
    /// past the swell, where the tip is buried below the valley floor.
    func standing(atAlong along: Float, across: Float) -> Float {
        let sunk = sinking(atAlong: along)
        return belly(atAlong: along) * endFactor(atAlong: along)
            * crestProfile(across: across) * (1 - sunk)
            - buriedTipSink * sunk
    }

    /// How wide the run is at one point along it, as a fraction of its widest:
    /// the lens, pinched to `endWidth` at the ends of its own cell and beyond,
    /// and narrowed further where the tip is buried.
    func widthFactor(atAlong along: Float) -> Float {
        let lens = endWidth + (1 - endWidth) * sin(.pi * min(max(along, 0), 1))
        return lens * (1 - tipNarrowing * sinking(atAlong: along))
    }
}

/// One visible run of one thread, in the coordinates the flat braid's surface is
/// drawn in: `x` is the fraction of the way round the cross-section, measured the
/// way `Flat16SurfaceMesh.arcSpan` measures it, and `y` is the distance along the
/// braid in repeats.
///
/// **It carries the thread it belongs to, and the cell it came from**, so
/// whatever the drawing does with the shape, what is seen can always be taken
/// back to a thread, a step, a face and a place.
struct Flat16Bundle: Equatable, Sendable {
    let threadPosition: Int
    let colorID: ThreadColorID
    let region: Flat16SurfaceRegion
    /// The lane of that region, the same numbering `Flat16SurfacePatch` uses.
    let widthColumn: Int
    let row: Int
    let course: Flat16ThreadCourseKind

    /// The middle of the cell's leading and trailing edges.
    let leadingCentre: SIMD2<Float>
    let trailingCentre: SIMD2<Float>
    /// Half of the cell's own width, as an offset from the centre to the
    /// `across == 1` side, at each end. A bundle is this times
    /// `Flat16BundleShape.widthOverLane` wide.
    let leadingHalfLane: SIMD2<Float>
    let trailingHalfLane: SIMD2<Float>

    /// **How far across the width the run is drawn in as it leaves its place**,
    /// in the arc coordinate, per step along the braid — and where along the cell
    /// that begins.
    ///
    /// Zero for a thread that holds its lane. For one carried across the braid,
    /// this is the bend Task 007J settled from the move rules: it starts where
    /// that thread's own crossing starts, goes the way the crossing's first
    /// passed column lies, and moves one lane in the time the crossing takes to
    /// pass one column. **None of the three is chosen here** — see
    /// `Flat16SurfacePatternGenerator.bundles`.
    let drawnInPerStep: Float
    let drawnInStart: Float

    /// Where the run's centreline is at `along`, which is 0 at the start of its
    /// own cell and 1 at the end.
    func centre(atAlong along: Float) -> SIMD2<Float> {
        let base = simd_mix(leadingCentre, trailingCentre, SIMD2<Float>(repeating: along))
        return base + SIMD2<Float>(drawnIn(atAlong: along), 0)
    }

    /// How far in across the width the run has been drawn at `along`.
    func drawnIn(atAlong along: Float) -> Float {
        guard drawnInPerStep != 0 else { return 0 }
        return drawnInPerStep * max(0, along - drawnInStart)
    }

    /// **How far the run has gone under, 0 to 1, because it is diving into the
    /// braid** — nothing for a thread that holds its lane.
    ///
    /// A thread carried across does not merely bend in: it goes *under* the
    /// threads running along the braid, and the bend is where it starts doing so
    /// (Task 007J's correction 3 — 「引き込みの区間だけ層は `.under`」). It is
    /// fully under by the time it has moved one lane, which is the end of its own
    /// cell, so what is seen is one lane's worth of the line turning in and
    /// sinking. **Any slower and the buried run shows through where four bundles
    /// of the body part**, and the weft-only colouring then reaches the middle
    /// four lanes, which book A p97's own sample says it must not.
    func diving(atAlong along: Float) -> Float {
        guard drawnInPerStep != 0, drawnInStart < 1 else { return 0 }
        let progress = min(max((along - drawnInStart) / (1 - drawnInStart), 0), 1)
        return progress * progress * (3 - 2 * progress)
    }

    /// How far the surface stands at one place on this run, in crests: the
    /// bundle's own shape, taken under where the run dives.
    func standing(atAlong along: Float, across: Float, shape: Flat16BundleShape) -> Float {
        let dived = diving(atAlong: along)
        return shape.standing(atAlong: along, across: across) * (1 - dived)
            - shape.buriedTipSink * dived
    }

    /// Half the bundle's width at `along`, as an offset in surface coordinates.
    func halfWidth(atAlong along: Float, shape: Flat16BundleShape) -> SIMD2<Float> {
        let lane = simd_mix(leadingHalfLane, trailingHalfLane, SIMD2<Float>(repeating: along))
        return lane * (shape.widthOverLane * shape.widthFactor(atAlong: along))
    }

    /// A point of the bundle's surface, in surface coordinates.
    func point(atAlong along: Float, across: Float, shape: Flat16BundleShape) -> SIMD2<Float> {
        centre(atAlong: along) + halfWidth(atAlong: along, shape: shape) * across
    }

    /// How far along its own centreline a point of the braid lies, from where it
    /// is along the braid.
    ///
    /// **The centreline alone.** Where a cell's two ends are not level — the
    /// outermost face lanes and the edges, which carry the phase the move order
    /// gives them (Task 007G) — the bundle leans, and a point off the centreline
    /// is then further along than this says. `place(atArc:along:)` solves that;
    /// this is the first step of the solve and what the rest of the run's own
    /// reckoning is measured in.
    func along(atLengthwise y: Float) -> Float? {
        let span = trailingCentre.y - leadingCentre.y
        guard abs(span) > 1e-9 else { return nil }
        return (y - leadingCentre.y) / span
    }

    /// **Where on this run a point of the braid falls**, as `(along, across)` —
    /// **and there can be two of them.**
    ///
    /// **Solved, not guessed at.** A bundle's frame leans two ways at once: the
    /// two ends of a cell need not be level (the outermost face lanes and the
    /// edges carry the phase the move order gives them, Task 007G), so a point
    /// off the centreline is further along the braid than the centreline says;
    /// and where a run bends in across the width as it leaves the face, its
    /// centre moves six lanes for every step, so which point of the run an arc
    /// names depends on how far along it is. Reading one off the centreline and
    /// the other off the arc is out by as much as a whole half-width there, and
    /// iterating the two against each other runs away.
    ///
    /// It does not have to be either. **Both the centre and the half-width are
    /// piecewise linear in `along`** — the bend is one straight ramp that starts
    /// at `drawnInStart`, and the half-width's own direction does not turn along
    /// the run, only lengthen and shorten — so eliminating `across` between the
    /// two leaves one linear equation a branch, and the lens cancels out of it.
    /// Two branches, two solutions, and **both may be real**: a run that bends
    /// in across the width as it leaves the face passes back over the lanes it
    /// has already crossed, so one place of the braid can be two places of one
    /// run — the part lying on the face, and the part gone under it. Which of
    /// them shows is not this question but the next one, and it is settled the
    /// way everything else is: whichever stands higher (`Flat16SurfacePattern
    /// .standing`).
    func places(atArc arc: Float, along y: Float, shape: Flat16BundleShape) -> [SIMD2<Float>] {
        // The half-width's direction. It is the same at both ends of a cell —
        // what changes along a run is only how long it is, which is the lens,
        // and the lens divides out of the solve below.
        let lane = leadingHalfLane
        let alongCentre = trailingCentre.y - leadingCentre.y
        let arcCentre = trailingCentre.x - leadingCentre.x
        let towardsTheArc = Flat16SurfacePattern.wrappedArc(arc - leadingCentre.x)
        let towardsTheLength = y - leadingCentre.y

        /// One branch of the centre's path: `arc = leadingCentre.x + slope *
        /// along + offset`.
        func solved(slope: Float, offset: Float) -> Float? {
            let denominator = lane.y * slope - lane.x * alongCentre
            guard abs(denominator) > 1e-12 else { return nil }
            return (lane.y * (towardsTheArc - offset) - lane.x * towardsTheLength) / denominator
        }

        /// The pair a branch's root makes, once `across` is read back off it.
        func pair(_ down: Float) -> SIMD2<Float>? {
            let width = halfWidth(atAlong: down, shape: shape)
            // Read `across` off whichever of the two equations the half-width
            // leans further along, which is the better conditioned of them.
            if abs(lane.x) >= abs(lane.y) {
                guard abs(width.x) > 1e-12 else { return nil }
                return SIMD2<Float>(
                    down,
                    (towardsTheArc - arcCentre * down - drawnIn(atAlong: down)) / width.x
                )
            }
            guard abs(width.y) > 1e-12 else { return nil }
            return SIMD2<Float>(down, (towardsTheLength - alongCentre * down) / width.y)
        }

        // **Both branches, and then the one that answers.** Each branch's line
        // is exact on its own stretch of the run and says nothing anywhere else,
        // so a root of one that falls outside it is not a solution — and taking
        // it because it happened to be found first put a whole run's colour half
        // a braid away from where it belongs.
        //
        // The two cannot be told apart by putting them back through the
        // equations, because each satisfies the pair it was solved from. What
        // tells them apart is **how far across the run they land**: a place the
        // run really covers is within a half-width of its centreline, and a root
        // of the wrong branch is not.
        var candidates = [Float]()
        if drawnInPerStep != 0, drawnInStart < 1 {
            if let past = solved(
                slope: arcCentre + drawnInPerStep, offset: -drawnInPerStep * drawnInStart
            ), past >= drawnInStart {
                candidates.append(past)
            }
            if let before = solved(slope: arcCentre, offset: 0), before <= drawnInStart {
                candidates.append(before)
            }
        } else if let straight = solved(slope: arcCentre, offset: 0) {
            candidates.append(straight)
        }
        return candidates.compactMap(pair)
    }

}

/// One thread's run where it reaches a place on the braid's surface.
struct Flat16StandingRun: Equatable, Sendable {
    /// Which repeat the run belongs to, counted from the one the place is
    /// counted in: a run can reach into the next repeat and the one before.
    let repeatOffset: Int
    /// The run, as an index into the pattern's `bundles` — and so into its
    /// `patches`, which are in the same order.
    let bundle: Int
    /// How far it stands there, in crests. Negative where its tip is buried.
    let height: Float
}

extension Flat16SurfacePattern {
    /// **Every run that reaches a place on the braid, highest first**: `arc` the
    /// fraction of the way round the cross-section and `along` the distance in
    /// repeats.
    ///
    /// **This is the rule for what is seen**, and the solid, the card and the
    /// checks all read it. The solid does not ask it — its own depth test
    /// answers the same question on the same surfaces — so the card and the
    /// checks are held against the solid rather than against this
    /// (`Flat16CardAgreesWithSolidTests`). Found by run and thread; colour never
    /// enters.
    func runsStanding(
        atArc arc: Float,
        along: Float,
        shape: Flat16BundleShape = .standard
    ) -> [Flat16StandingRun] {
        var found = [Flat16StandingRun]()
        for (index, bundle) in bundles.enumerated() {
            for repeatOffset in -1...1 {
                guard let height = standing(
                    bundle, repeatOffset: repeatOffset,
                    atArc: arc, along: along, shape: shape
                ) else { continue }
                found.append(Flat16StandingRun(
                    repeatOffset: repeatOffset, bundle: index, height: height
                ))
            }
        }
        return found.sorted { $0.height > $1.height }
    }

    /// How far one run stands at a place, or `nil` where it does not reach.
    /// A buried tip does reach, and stands below the valley floor.
    func standing(
        _ bundle: Flat16Bundle,
        repeatOffset: Int,
        atArc arc: Float,
        along: Float,
        shape: Flat16BundleShape = .standard
    ) -> Float? {
        // **The highest of them**, where a run covers a place more than once.
        return bundle.places(atArc: arc, along: along - Float(repeatOffset), shape: shape)
            .filter { $0.x >= shape.runStart && $0.x <= shape.runEnd && abs($0.y) <= 1 }
            .map { bundle.standing(atAlong: $0.x, across: $0.y, shape: shape) }
            .max()
    }

    /// The cell lying beneath a place: the thread the occupancy history has
    /// standing there, whatever the runs above it do.
    func cellBeneath(atArc arc: Float, along: Float) -> (repeatOffset: Int, bundle: Int)? {
        for (index, bundle) in bundles.enumerated() {
            let halfLane = bundle.leadingHalfLane.x
            guard abs(halfLane) > 1e-9 else { continue }
            let acrossLane = Self.wrappedArc(arc - bundle.leadingCentre.x) / halfLane
            guard abs(acrossLane) <= 1 else { continue }
            for repeatOffset in -1...1 {
                let start = bundle.leadingCentre.y + Float(repeatOffset)
                let end = bundle.trailingCentre.y + Float(repeatOffset)
                if along >= start, along < end { return (repeatOffset, index) }
            }
        }
        return nil
    }

    /// The shortest way round the cross-section between two arc fractions.
    static func wrappedArc(_ difference: Float) -> Float {
        var value = difference.truncatingRemainder(dividingBy: 1)
        if value > 0.5 { value -= 1 }
        if value < -0.5 { value += 1 }
        return value
    }
}
