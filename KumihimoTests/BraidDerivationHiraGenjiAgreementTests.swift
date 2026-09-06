import Foundation
import Testing
@testable import Kumihimo

/// Task 020 stage 1, the difference: the general working-out has to give the same
/// answers as `HiraGenjiWeaveDerivation`, which is the one Tasks 007F and 007G
/// checked against the books.
///
/// The old file is left in place and both are run. Nothing here asserts a new
/// figure; every claim is "these two agree", so a disagreement shows up as a
/// disagreement rather than as a new opinion.
@MainActor
struct BraidDerivationHiraGenjiAgreementTests {
    private var derivation: BraidDerivation {
        get throws {
            try #require(BraidDerivation.derive(
                stand: BraidMethodCatalog.stand16,
                method: BraidMethodCatalog.hiraGenji16,
                crossSection: BraidMethodCatalog.hiraGenji16CrossSection
            ))
        }
    }

    // MARK: - The cross-section

    /// All sixteen places, compared one at a time.
    @Test func everyBoardPositionLandsWhereTheOlderMapPutIt() throws {
        let derivation = try derivation
        let fold = try #require(derivation.fold)
        var compared = 0
        for position in 1...16 {
            let slot = try #require(derivation.crossSection.slotIndex(ofPositionID: position))
            let old = try #require(
                HiraGenjiWeaveDerivation.crossSectionPlace(ofBoardPosition: position)
            )
            let oldWidth = try #require(
                HiraGenjiWeaveDerivation.widthPosition(ofBoardPosition: position)
            )
            #expect(fold.width(ofSlot: slot) == oldWidth)
            switch old {
            case .face(let face, let column):
                #expect(fold.column(ofSlot: slot) == column)
                #expect(fold.face(ofSlot: slot)?.rawValue == face.rawValue)
                #expect(!fold.turningSlots.contains(slot))
            case .edge:
                #expect(fold.face(ofSlot: slot) == nil)
                #expect(fold.turningSlots.contains(slot))
            }
            compared += 1
        }
        #expect(compared == 16)
    }

    /// The two reflections the older file wrote as arithmetic on the board number
    /// come out of the pairs the courses make, with no formula.
    @Test func theMirrorThroughTheThicknessIsTheOneTheOlderFileWroteAsNineMinusP() throws {
        let derivation = try derivation
        let fold = try #require(derivation.fold)
        for position in 1...16 {
            let partner = HiraGenjiWeaveDerivation.positionThroughTheBraid(from: position)
            let slot = try #require(derivation.crossSection.slotIndex(ofPositionID: position))
            let partnerSlot = try #require(
                derivation.crossSection.slotIndex(ofPositionID: partner)
            )
            #expect(fold.width(ofSlot: slot) == fold.width(ofSlot: partnerSlot))
            if let face = fold.face(ofSlot: slot) {
                #expect(fold.face(ofSlot: partnerSlot) == face.opposite)
            } else {
                #expect(fold.face(ofSlot: partnerSlot) == nil)
            }
        }
    }

    // MARK: - The courses

    /// Sixteen threads, five samples each: eighty places compared, plus the
    /// classification each course carries.
    @Test func everyCourseMatchesSampleForSample() throws {
        let derivation = try derivation
        let fold = try #require(derivation.fold)
        let old = try #require(HiraGenjiWeaveDerivation.courses(cycleCount: 4))
        #expect(old.count == 16)

        var comparedSamples = 0
        for oldCourse in old {
            let new = try #require(derivation.course(ofThread: oldCourse.threadPosition))
            #expect(new.slots.count == oldCourse.samples.count)
            for (index, sample) in oldCourse.samples.enumerated() {
                let slot = new.slots[index]
                #expect(derivation.crossSection.positionID(atSlot: slot) == sample.boardPosition)
                #expect(fold.width(ofSlot: slot) == sample.widthPosition)
                comparedSamples += 1
            }
            #expect(new.runsAlongTheBraid == oldCourse.runsAlongTheBraid)
        }
        #expect(comparedSamples == 80)
    }

    @Test func theRepeatAndTheInstantsPerCycleMatch() throws {
        #expect(try derivation.repeatCycleCount == HiraGenjiWeaveDerivation.repeatCycleCount())
        #expect(try derivation.instantsPerCycle == HiraGenjiWeaveDerivation.instantsPerCycle)
    }

    /// Eight places across the width, compared as instants and as phases.
    @Test func everyArrivalPhaseMatches() throws {
        let derivation = try derivation
        var compared = 0
        for width in -1...HiraGenjiWeaveDerivation.columnCount {
            let oldInstants = HiraGenjiWeaveDerivation.arrivalInstants(atWidthPosition: width)
            let newInstants = try #require(derivation.arrivalInstants(atWidth: width))
            #expect(newInstants.map(Float.init).sorted() == oldInstants.sorted())

            let oldPhase = HiraGenjiWeaveDerivation.arrivalPhase(atWidthPosition: width)
            let newPhase = derivation.arrivalPhase(atWidth: width)
            #expect(newPhase.map(Float.init) == oldPhase)
            compared += 1
        }
        #expect(compared == 8)
    }

    // MARK: - The surface, on the reference colourings

    /// The whole surface, rebuilt from the general working-out, against the one the
    /// shipped generator makes — patch for patch, edge for edge, crossing for
    /// crossing, on all four of the colourings the books set up.
    ///
    /// This is what makes the three colour experiments hold on the new route
    /// without restating them: the two surfaces are the same object.
    @Test func theWholeSurfaceMatchesOnEveryReferenceColouring() throws {
        let derivation = try derivation
        for (name, assignments) in HiraGenjiReferenceColourings.all {
            let old = try #require(HiraGenjiWeavePatternGenerator.generate(assignments: assignments))
            let new = try #require(
                BraidPatternBridge.hiraStylePattern(from: derivation, assignments: assignments)
            )
            #expect(new.columnCount == old.columnCount, "\(name)")
            #expect(new.rowCount == old.rowCount, "\(name)")
            #expect(new.patches == old.patches, "\(name) patches")
            #expect(new.edgePlaces == old.edgePlaces, "\(name) edge places")
            #expect(new.weftCrossings == old.weftCrossings, "\(name) crossings")
        }
    }

    /// Book A p97, left: colour everything worked sideways and leave everything
    /// worked lengthwise plain, and the braid comes out plain in the body with the
    /// colour only at the two sides.
    @Test func theWeftOnlyColouringLeavesTheBodyPlain() throws {
        let pattern = try bridged(HiraGenjiReferenceColourings.weftOnly)
        let middle = pattern.lengthwiseColumns
        #expect(middle == [1, 2, 3, 4])
        for patch in pattern.patches where middle.contains(patch.column) {
            #expect(patch.colorID.rawValue == "white")
        }
        for face in HiraGenjiBraidFace.allCases {
            for row in 0..<pattern.rowCount {
                let line = pattern.row(row, face: face)
                #expect(line.first?.colorID.rawValue != "white")
                #expect(line.last?.colorID.rawValue != "white")
            }
        }
    }

    /// Book A p97's caption: colour the middle two of each side one way and the far
    /// and near two another, and the **edging** comes out in arrow feather.
    @Test func theArrowFeatherColouringPatternsOnlyTheEdging() throws {
        let pattern = try bridged(HiraGenjiReferenceColourings.arrowFeather)
        let middle = pattern.lengthwiseColumns
        for patch in pattern.patches where middle.contains(patch.column) {
            #expect(patch.colorID.rawValue == "white")
        }
        // The edging is not one flat colour: the outermost column carries a
        // different one of the sideways threads from row to row.
        for face in HiraGenjiBraidFace.allCases {
            let outer = (0..<pattern.rowCount).compactMap {
                pattern.patch(column: 0, row: $0, face: face)?.colorID.rawValue
            }
            #expect(Set(outer).count > 1)
        }
    }

    /// Book A p97's second sample: the far group and the near group in two colours,
    /// and the braid comes out a ladder whose rungs reverse between the two faces.
    @Test func theLadderColouringReversesBetweenTheFaces() throws {
        let pattern = try bridged(ProjectEditorPreviewData.hiraGenjiSurfaceLadder)
        for row in 0..<pattern.rowCount {
            for column in pattern.lengthwiseColumns.sorted() {
                let front = pattern.patch(column: column, row: row, face: .front)?.colorID.rawValue
                let back = pattern.patch(column: column, row: row, face: .back)?.colorID.rawValue
                #expect(front != back)
                #expect(Set([front, back]) == ["brown", "yellow"])
            }
        }
    }

    private func bridged(_ assignments: [ThreadAssignment]) throws -> HiraGenjiWeavePattern {
        try #require(BraidPatternBridge.hiraStylePattern(from: derivation, assignments: assignments))
    }
}
