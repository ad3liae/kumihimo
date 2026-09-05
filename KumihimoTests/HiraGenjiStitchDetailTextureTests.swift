import Foundation
import Testing
@testable import Kumihimo

/// Stage 4a: the shading a stitch carries, which replaced the two-material
/// painting the flat braid used to have.
struct HiraGenjiStitchDetailTextureTests {
    @Test func theMiddleOfAStitchIsUnshaded() {
        #expect(abs(HiraGenjiStitchDetailTexture.shading(across: 0.5, along: 0.5) - 1) < 0.001)
    }

    /// Every figure is the round braid's, used for what it means there. Nothing
    /// in this map is a number of its own.
    @Test func theValleysAreTheRoundBraidsOwnFigures() {
        let valley = MaruGenjiStrandTextureFactory.valleyOcclusion
        let crossing = MaruGenjiStrandTextureFactory.crossingOcclusion

        // Against the lane next to it, in the middle of a run.
        let side = HiraGenjiStitchDetailTexture.shading(across: 0, along: 0.5)
        #expect(abs(side - valley) < 0.001)
        // At a join: the trough between two stitches, and the pick tucked under
        // them along the same line.
        let join = HiraGenjiStitchDetailTexture.shading(across: 0.5, along: 0)
        #expect(abs(join - valley * crossing) < 0.001)
        // A corner takes all three.
        let corner = HiraGenjiStitchDetailTexture.shading(across: 0, along: 0)
        #expect(abs(corner - valley * valley * crossing) < 0.001)
    }

    /// Darkening all the way out from the middle, with no step in it. The band it
    /// replaced stepped once, from one flat colour to another.
    @Test func theShadingFallsAwaySmoothlyInBothDirections() {
        let across = stride(from: Float(0.5), through: 1, by: 0.02).map {
            HiraGenjiStitchDetailTexture.shading(across: $0, along: 0.5)
        }
        #expect(zip(across, across.dropFirst()).allSatisfy { $0 >= $1 - 0.000_1 })
        let along = stride(from: Float(0.5), through: 1, by: 0.02).map {
            HiraGenjiStitchDetailTexture.shading(across: 0.5, along: $0)
        }
        #expect(zip(along, along.dropFirst()).allSatisfy { $0 >= $1 - 0.000_1 })
        // No jump anywhere. The painting this replaced stepped the whole way at
        // one edge; here no step between neighbouring samples is more than a
        // sixth of the whole range.
        let range = 1 - HiraGenjiStitchDetailTexture.shading(across: 0, along: 0)
        let steps = zip(across, across.dropFirst()).map { $0 - $1 }
            + zip(along, along.dropFirst()).map { $0 - $1 }
        #expect(steps.allSatisfy { $0 < range / 6 })
    }

    /// Mirror-symmetric, so a stitch shades the same however it is laid.
    @Test func theShadingIsSymmetricAboutBothMiddles() {
        for value in stride(from: Float(0), through: 1, by: 0.05) {
            #expect(abs(HiraGenjiStitchDetailTexture.shading(across: value, along: 0.37)
                - HiraGenjiStitchDetailTexture.shading(across: 1 - value, along: 0.37)) < 0.000_1)
            #expect(abs(HiraGenjiStitchDetailTexture.shading(across: 0.37, along: value)
                - HiraGenjiStitchDetailTexture.shading(across: 0.37, along: 1 - value)) < 0.000_1)
        }
    }

    /// The map is drawn taller than it is wide because a stitch is, so its detail
    /// stays about square where it lands.
    @Test func theMapIsShapedLikeAStitch() {
        let stitch = HiraGenjiSurfacePatternGenerator.stitchPitchPerBraidWidth
            * Float(HiraGenjiSurfacePatternGenerator.broadFaceColumnCount)
        let map = Float(HiraGenjiStitchDetailTexture.height)
            / Float(HiraGenjiStitchDetailTexture.width)
        #expect(abs(map / stitch - 1) < 0.15)
    }
}
