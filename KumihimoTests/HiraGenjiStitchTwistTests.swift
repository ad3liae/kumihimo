import Foundation
import Testing
@testable import Kumihimo

/// Stage 4b: Task 005G's arrangement applied to the flat braid.
struct HiraGenjiStitchTwistTests {
    /// The point of solving per strand: every one of them shows the same yarn,
    /// twisted the same way and by the same amount.
    @Test func everyStitchShowsTheStripesAtTheNominalAngle() throws {
        let nominal = MaruGenjiSurfaceMeshGenerator.twistAngleDegrees

        for region in HiraGenjiSurfaceRegion.allCases {
            let twist = try #require(HiraGenjiStitchTwistGrouping.twist(in: region))
            let angle = try #require(
                HiraGenjiStitchTwistGrouping.stripeAngleDegrees(of: twist, in: region)
            )
            #expect(abs(angle - nominal) < 3)
        }
    }

    /// One yarn, one hand. What this replaced leaned one way for the threads
    /// worked lengthwise and the other for those worked across.
    @Test func everyStitchLeansTheSameWay() throws {
        let hands = try HiraGenjiSurfaceRegion.allCases.map { region in
            HiraGenjiStitchTwistGrouping.hand(
                of: try #require(HiraGenjiStitchTwistGrouping.twist(in: region))
            )
        }
        #expect(Set(hands).count == 1)
    }

    /// The round braid needs several groups because its chevrons shear the frame
    /// two ways. Every stitch of the flat braid is the same unsheared rectangle —
    /// one yarn wide since stage 2.5c divided the outline by arc, one step long —
    /// so one group serves it. Measured, not assumed.
    @Test func theFlatBraidNeedsOneGroup() {
        #expect(HiraGenjiStitchTwistGrouping.groups().count == 1)
    }

    /// Every lane really is one yarn wide, in every region, which is what makes
    /// the single group correct.
    @Test func everyLaneIsOneYarnWideInEveryRegion() {
        let halfWidth = HiraGenjiSurfaceMeshGenerator.defaultHalfWidth
        let halfThickness = HiraGenjiSurfaceMeshGenerator.defaultHalfThickness

        for region in HiraGenjiSurfaceRegion.allCases {
            let lane = HiraGenjiStitchTwistGrouping.laneWidth(
                in: region, halfWidth: halfWidth, halfThickness: halfThickness
            )
            #expect(abs(lane / halfThickness - 1) < 0.03)
        }
    }

    /// The stripes stand about as far apart as the round braid's do, measured
    /// against the yarn rather than against the patch they are drawn on — and
    /// there are a whole number of them, so they meet at every join.
    @Test func theStripesStandAboutAsFarApartAsTheRoundBraids() {
        let roundSegmentInYarns = Float(MaruGenjiStrandTextureFactory.width)
            / Float(MaruGenjiStrandTextureFactory.height)
        let roundPerYarn = Float(MaruGenjiSurfaceMeshGenerator.fiberCount) / roundSegmentInYarns
        let flatPerYarn = HiraGenjiStitchTwistGrouping.stripesPerStitch
            / HiraGenjiStitchTwistGrouping.stitchLengthInYarns

        #expect(abs(roundPerYarn - 2) < 0.000_1)
        #expect(abs(flatPerYarn / roundPerYarn - 1) < 0.12)
        // A whole number, so the phase closes over a stitch.
        let count = HiraGenjiStitchTwistGrouping.stripesPerStitch
        #expect(count == count.rounded())
        #expect(abs(count - HiraGenjiStitchTwistGrouping.stripesPerStitchBeforeRounding) <= 0.5)
    }

    /// The phase runs the whole turn over one stitch, so a stitch shows the same
    /// stripes wherever it is drawn.
    @Test func thePhaseTurnsOnceAStitchAlongTheBraid() throws {
        let twist = try #require(HiraGenjiStitchTwistGrouping.groups().first)
        let turned = twist.phase(along: 1, across: 0.5) - twist.phase(along: 0, across: 0.5)

        #expect(abs(turned / (2 * .pi) + HiraGenjiStitchTwistGrouping.stripesPerStitch) < 0.001)
        // A whole turn, so the stripes of one stitch meet the next one's.
        #expect(abs(cos(twist.phase(along: 0, across: 0.5))
            - cos(twist.phase(along: 1, across: 0.5))) < 0.001)
        // And across the stitch the phase moves too, which is the lean.
        #expect(twist.phasePerAcross != 0)
    }

    /// The stripe shading and roughness both follow the same phase, so the two
    /// maps light the same stripes.
    @Test func theShadingAndRoughnessFollowTheSameStripes() throws {
        let twist = try #require(HiraGenjiStitchTwistGrouping.groups().first)
        var brightest = (value: -Float.greatestFiniteMagnitude, along: Float(0))
        var roughest = (value: -Float.greatestFiniteMagnitude, along: Float(0))
        for step in 0...200 {
            let along = Float(step) / 200
            let tint = HiraGenjiStitchDetailTexture.twistTint(twist, 0.5, along)
            let rough = HiraGenjiStitchDetailTexture.roughness(twist, 0.5, along)
            if tint > brightest.value { brightest = (tint, along) }
            if rough > roughest.value { roughest = (rough, along) }
        }
        // The tint is brightest and the roughness highest at the same phase.
        #expect(abs(brightest.along - roughest.along) < 0.02)
        // The twist barely tints; it is carried by the normal and roughness maps.
        #expect(1 - brightest.value < 0.001)
        let floor = HiraGenjiStitchDetailTexture.twistTint(twist, 0.5, roughest.along + 0.5
            / HiraGenjiStitchTwistGrouping.stripesPerStitch)
        #expect(1 - floor <= MaruGenjiStrandTextureFactory.twistTint + 0.001)
    }
}
