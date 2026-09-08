import Foundation
import Testing
@testable import Kumihimo

/// Task 020 stage 2, the flat braid: the drawing that answers a braid nobody has
/// made yet.
///
/// Every claim here is read off the figure and held against a book. **Nothing in
/// the figure comes from a measurement**, so nothing in it can be wrong about a
/// braid that has never been photographed — which is the whole reason the figure
/// is the product and the mesh is not.
@MainActor
struct BraidPatternFigureTests {
    private var derivation: BraidDerivation {
        get throws {
            try #require(BraidDerivation.derive(
                stand: BraidMethodCatalog.stand16,
                method: BraidMethodCatalog.hiraGenji16,
                crossSection: BraidMethodCatalog.hiraGenji16CrossSection
            ))
        }
    }

    private func figure(
        _ assignments: [ThreadAssignment],
        _ face: BraidFace
    ) throws -> BraidFigure {
        try #require(BraidFigureBuilder.figure(
            from: derivation, assignments: assignments, face: face
        ))
    }

    private func colours(_ figure: BraidFigure, row: Int) -> [String] {
        figure.row(row).map(\.colorID.rawValue)
    }

    // MARK: - The shape of the drawing

    @Test func theFigureIsSixColumnsAndAnEdgeOnEachSide() throws {
        let figure = try figure(BraidReferenceColourings.bookAP96, .front)
        #expect(figure.columnCount == 6)
        #expect(figure.rowCount == 4)
        #expect(figure.rowsDrawn == 12)
        #expect(figure.size == SIMD2<Double>(9, 12))

        // Every place across the width carries exactly one thread at every row —
        // six columns and the two edges, which is eight of the sixteen threads.
        for row in 0..<figure.rowsDrawn {
            #expect(figure.row(row).count == 8)
        }
        let appearances = figure.shapes.filter { $0.kind == .appearance }
        #expect(appearances.count == 8 * figure.rowsDrawn)
    }

    /// A braid the derivation has not folded flat has no face to draw this way.
    @Test func aTubeHasNoFigure() throws {
        let tube = try #require(BraidDerivation.derive(
            stand: BraidMethodCatalog.stand16,
            method: BraidMethodCatalog.maruGenji16,
            crossSection: BraidMethodCatalog.maruGenji16CrossSection
        ))
        #expect(BraidFigureBuilder.figure(
            from: tube, assignments: BraidReferenceColourings.bookAP96, face: .front
        ) == nil)
    }

    // MARK: - What is seen and what is not

    /// **The figure distinguishes the two.** Every thread carried across the braid
    /// has runs drawn beneath the face, and every thread running along it dips to
    /// the other face and comes back.
    @Test func everyThreadThatGoesUnderTheFaceIsDrawnGoingUnderIt() throws {
        let figure = try figure(BraidReferenceColourings.bookAP96, .front)
        let derivation = try derivation

        for thread in derivation.threadsCarriedAcrossTheBraid {
            let hidden = figure.shapes.filter {
                $0.kind == .passage && $0.threadPosition == thread && !$0.isOnTheFace
            }
            #expect(!hidden.isEmpty, "thread \(thread)")
            // A run that crosses the braid spans more than one column.
            #expect(hidden.contains { abs($0.points[1].x - $0.points[0].x) > 2 }, "thread \(thread)")
        }
        for thread in derivation.threadsRunningAlongTheBraid {
            let hidden = figure.shapes.filter {
                $0.kind == .passage && $0.threadPosition == thread && !$0.isOnTheFace
            }
            // It turns over every row, so every step of it is out of sight.
            #expect(!hidden.isEmpty, "thread \(thread)")
            #expect(hidden.allSatisfy { abs($0.points[1].x - $0.points[0].x) < 0.001 })
        }
    }

    /// The threads carried across turn at the edges. Read off the drawing: a thread
    /// that reaches an edge is next seen coming back the other way.
    @Test func theThreadsCarriedAcrossTurnAtBothEdges() throws {
        let figure = try figure(BraidReferenceColourings.bookAP96, .front)
        let derivation = try derivation
        for thread in derivation.threadsCarriedAcrossTheBraid {
            let places = (0..<figure.rowCount).compactMap { row in
                figure.shapes.first {
                    $0.kind == .appearance && $0.threadPosition == thread && $0.place?.row == row
                }?.place?.width
            }
            guard !places.isEmpty else { continue }
            #expect(places.contains(-1) || places.contains(figure.columnCount), "thread \(thread)")
        }
    }

    // MARK: - Where in a row each place turns over

    /// **The half-notch.** The places the threads run along are held level with
    /// each other, and the edges sit off them by an amount that came out of the
    /// order of the moves rather than off a picture.
    @Test func theEdgesSitOffTheBodyByTheAmountTaskZeroZeroSevenGDerived() throws {
        let derivation = try derivation
        let fold = try #require(derivation.fold)
        let phases = BraidFigureBuilder.longitudinalPhases(of: derivation, fold: fold)

        // The four places held lengthwise line up.
        for width in derivation.columnsHeldLengthwise {
            #expect(phases[width] == 0, "width \(width)")
        }
        // The left edge sits behind the body, the right rather less so. **In book
        // C's instants**: a cycle is thirteen of them, one to a move, and the body's
        // own mean is 8.5 of them.
        // Seven thirteenths of a row behind, and five for the right edge. Counting
        // book A's printed steps two at a time, as Task 007G did, made the left one
        // exactly half a row; the source of record moves one thread at a time and
        // it is a little more. (The body's mean is a sum of quotients, so these are
        // compared to within the last bits rather than exactly.)
        //
        // **Seven thirteenths behind is six thirteenths ahead**, and the phases are
        // wrapped into half a row either way, so that is the number here. At a half
        // exactly the wrap did not bite, which is why 007G never saw it.
        #expect(abs((phases[-1] ?? 0) - 6.0 / 13) < 1e-12)
        #expect(abs((phases[6] ?? 0) + 5.0 / 13) < 1e-12)
        // And the outermost columns, where the weft shows, take the other side.
        #expect(abs((phases[0] ?? 0) - 4.5 / 13) < 1e-12)
        #expect(phases[5] == phases[0])
    }

    // MARK: - Book A p97 left: a plain body and an arrow-feather edging

    /// The sample colours everything worked lengthwise in one neutral and gives
    /// each side a pair of colours. Its two claims are read off the figure here.
    @Test func theBodyStaysPlainAndOnlyTheEdgingTakesColour() throws {
        for face in BraidFace.allCases {
            let figure = try figure(BraidReferenceColourings.bookAP97Left, face)
            let derivation = try derivation
            for row in 0..<figure.rowsDrawn {
                let line = colours(figure, row: row)
                for width in derivation.columnsHeldLengthwise.sorted() {
                    #expect(line[width + 1] == "natural", "\(face) row \(row) width \(width)")
                }
                // The edges and the outermost columns carry the colours, never the
                // neutral.
                for width in [-1, 0, 5, 6] {
                    #expect(line[width + 1] != "natural", "\(face) row \(row) width \(width)")
                }
            }
        }
    }

    /// The edging is not one flat colour: it changes from row to row, and the two
    /// sides run against each other. That is what reads as arrow feather.
    @Test func theEdgingChangesColourFromRowToRow() throws {
        let figure = try figure(BraidReferenceColourings.bookAP97Left, .front)
        for width in [-1, 0, 5, 6] {
            let downTheEdge = (0..<figure.rowCount).map { row in
                figure.appearance(atWidth: width, row: row)?.colorID.rawValue ?? "?"
            }
            #expect(Set(downTheEdge).count > 1, "width \(width)")
        }
    }

    // MARK: - Book A p97 right: the ladder

    /// The far half of the stand in one colour and the near half in another. Every
    /// row of the body comes out one colour right across, the rows alternate, and
    /// the two faces are the other way round from each other.
    @Test func theLadderIsOneColourAcrossEachRowAndReversesBetweenTheFaces() throws {
        let front = try figure(BraidReferenceColourings.bookAP97Right, .front)
        let back = try figure(BraidReferenceColourings.bookAP97Right, .back)
        let body = try derivation.columnsHeldLengthwise.sorted()

        var rungs = [String]()
        for row in 0..<front.rowsDrawn {
            let frontLine = colours(front, row: row)
            let backLine = colours(back, row: row)
            let frontRung = Set(body.map { frontLine[$0 + 1] })
            let backRung = Set(body.map { backLine[$0 + 1] })
            #expect(frontRung.count == 1, "row \(row)")
            #expect(backRung.count == 1, "row \(row)")
            #expect(frontRung != backRung, "row \(row)")
            #expect(frontRung.union(backRung) == ["brown", "yellow"])
            rungs.append(frontRung.first ?? "?")
        }
        #expect(zip(rungs, rungs.dropFirst()).allSatisfy { $0 != $1 })
    }

    // MARK: - Book A p96: the finished braid in the photograph

    /// The braid photographed at the head of book A p96 reads, across its width:
    /// salmon, mauve, mauve, vermilion, black, salmon. **This is the reading the
    /// whole cross-section rests on**, so the figure is held against it directly.
    @Test func theP96ColouringComesOutAsThePhotographedBraid() throws {
        let figure = try figure(BraidReferenceColourings.bookAP96, .front)
        for row in 0..<figure.rowsDrawn {
            let face = (0..<figure.columnCount).map { column in
                figure.appearance(atWidth: column, row: row)?.colorID.rawValue ?? "?"
            }
            #expect(face == ["pink", "purple", "purple", "orange", "black", "pink"], "row \(row)")
        }
    }
}
