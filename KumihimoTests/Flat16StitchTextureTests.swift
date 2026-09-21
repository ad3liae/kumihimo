import Foundation
import Testing
@testable import Kumihimo

/// Stage 4a: the shading a run carries.
///
/// **Since Task 050 it follows the run's own height, not the edges of a
/// rectangle.** The figures are still the round braid's, used for what they mean
/// there; what changed is where they are applied.
struct Flat16StitchTextureTests {
    @Test func theMiddleOfARunIsUnshaded() {
        #expect(abs(Flat16StitchTexture.shading(across: 0.5, along: middleOfTheRun) - 1) < 0.001)
    }

    /// Where along the map one cell's own middle falls. The map spans the whole
    /// run, buried tips included, so the crest is not at 0.5 of it.
    private var middleOfTheRun: Float {
        let shape = Flat16SurfaceMesh.bundleShape
        return (0.5 - shape.runStart) / (shape.runEnd - shape.runStart)
    }

    /// Every figure is the round braid's, used for what it means there. Nothing
    /// in this map is a number of its own.
    @Test func theValleysAreTheRoundBraidsOwnFigures() {
        let valley = RoundTube16StrandTextureFactory.valleyOcclusion

        // At the rim, where the run has no height left, it is the trough between
        // two yarns and takes the whole of the round braid's figure.
        #expect(abs(Flat16StitchTexture.shading(across: 0, along: middleOfTheRun) - valley) < 0.002)
        #expect(abs(Flat16StitchTexture.shading(across: 1, along: middleOfTheRun) - valley) < 0.002)
        // And a place standing a given fraction of the crest is shaded by that
        // fraction of the way back to no shading at all.
        let shape = Flat16SurfaceMesh.bundleShape
        let half = Flat16StitchTexture.shading(across: 0.75, along: middleOfTheRun)
        #expect(abs(shape.crestProfile(across: 0.5) - 0.5) < 0.001)
        #expect(abs(half - (valley + (1 - valley) * 0.5)) < 0.002)
    }

    /// **The shading is in the groove, not on the hidden rim.** A bundle is wider
    /// than its lane, so the point where two of them part — and that is where the
    /// shadow belongs — is inside the map, not at its edge.
    @Test func theGrooveBetweenTwoLanesIsShaded() {
        let shape = Flat16SurfaceMesh.bundleShape
        // Where the neighbouring lane's crest is one lane away.
        let groove = 1 / shape.widthOverLane
        let atTheGroove = Flat16StitchTexture.shading(
            across: (1 + groove) / 2, along: middleOfTheRun
        )
        let onTheCrest = Flat16StitchTexture.shading(across: 0.5, along: middleOfTheRun)
        #expect(atTheGroove < onTheCrest * 0.75)
        #expect(groove < 1)
    }

    /// Darkening all the way out from the crest, with no step in it.
    @Test func theShadingFallsAwaySmoothlyInBothDirections() {
        let across = stride(from: Float(0.5), through: 1, by: 0.02).map {
            Flat16StitchTexture.shading(across: $0, along: middleOfTheRun)
        }
        #expect(zip(across, across.dropFirst()).allSatisfy { $0 >= $1 - 0.000_1 })
        let along = stride(from: middleOfTheRun, through: 1, by: 0.02).map {
            Flat16StitchTexture.shading(across: 0.5, along: $0)
        }
        #expect(zip(along, along.dropFirst()).allSatisfy { $0 >= $1 - 0.000_1 })
        // No jump anywhere.
        let range = 1 - Flat16StitchTexture.shading(across: 0, along: 0)
        let steps = zip(across, across.dropFirst()).map { $0 - $1 }
            + zip(along, along.dropFirst()).map { $0 - $1 }
        #expect(steps.allSatisfy { $0 < range / 5 })
    }

    /// Mirror-symmetric across the run, so a bundle shades the same on either
    /// flank. **Not along it**: the two ends of a run are not alike — one laps
    /// over the run before it and one goes under the run after.
    @Test func theShadingIsSymmetricAcrossTheRun() {
        for value in stride(from: Float(0), through: 1, by: 0.05) {
            #expect(abs(Flat16StitchTexture.shading(across: value, along: middleOfTheRun)
                - Flat16StitchTexture.shading(across: 1 - value, along: middleOfTheRun)) < 0.000_1)
        }
        let shape = Flat16SurfaceMesh.bundleShape
        let span = shape.runEnd - shape.runStart
        let head = Flat16StitchTexture.shading(across: 0.5, along: -shape.runStart / span)
        let tail = Flat16StitchTexture.shading(across: 0.5, along: (1 - shape.runStart) / span)
        #expect(head > tail)
    }

    /// The end that goes under the next run carries a contact shadow on top of
    /// the valley, which is what `crossingOcclusion` means on the round braid.
    @Test func theEndThatGoesUnderCarriesAContactShadow() {
        let shape = Flat16SurfaceMesh.bundleShape
        let span = shape.runEnd - shape.runStart
        let tucked = Flat16StitchTexture.shading(across: 0.5, along: 1)
        let bare = RoundTube16StrandTextureFactory.valleyOcclusion
        #expect(tucked < bare)
        #expect(abs(tucked - bare * RoundTube16StrandTextureFactory.crossingOcclusion) < 0.02)
        // It reaches no further back than the cell's own end.
        let atTheCellsEnd = (1 - shape.runStart) / span
        #expect(Flat16StitchTexture.shading(across: 0.5, along: atTheCellsEnd - 0.05)
            > tucked)
    }

    /// The map is drawn taller than it is wide because a run is, so its detail
    /// stays about square where it lands.
    @Test func theMapIsShapedLikeARun() {
        let run = Flat16StitchTwistGrouping.runLengthInYarns
            / Flat16SurfaceMesh.bundleShape.widthOverLane
        let map = Float(Flat16StitchTexture.height) / Float(Flat16StitchTexture.width)
        #expect(abs(map / run - 1) < 0.2)
    }
}
