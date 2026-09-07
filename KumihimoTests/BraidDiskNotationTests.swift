import Foundation
import Testing
@testable import Kumihimo

/// The move tables are generated from book C's numbered disk rather than typed out
/// again. This holds the generated tables against the ones transcribed from book A,
/// move for move.
struct BraidDiskNotationTests {
    /// **Repositioning is told apart by the distance alone, with nothing marked by
    /// hand.** A braiding move carries a thread eleven to fourteen notches of
    /// thirty-two; tidying only ever shifts one. There is no overlap.
    @Test func aMoveOfOneNotchIsTidyingAndEveryOtherMoveIsBraiding() {
        for disk in [BraidMethodCatalog.hiraGenjiDisk, BraidMethodCatalog.maruGenjiDisk] {
            let braiding = Set(disk.braidingMoves.map(disk.notches))
            let tidying = Set(disk.repositioningMoves.map(disk.notches))
            #expect(tidying == [1], "\(disk.source)")
            #expect(braiding.min() ?? 0 > 1, "\(disk.source)")
            #expect(braiding.isSubset(of: Set(11...14)), "\(disk.source)")
            #expect(disk.moves.count == 24, "\(disk.source)")
        }
        #expect(BraidMethodCatalog.hiraGenjiDisk.braidingMoves.count == 12)
        #expect(BraidMethodCatalog.hiraGenjiDisk.repositioningMoves.count == 12)
        #expect(BraidMethodCatalog.maruGenjiDisk.braidingMoves.count == 8)
        #expect(BraidMethodCatalog.maruGenjiDisk.repositioningMoves.count == 16)
    }

    /// **The difference.** What book C generates is what book A was transcribed as,
    /// move for move.
    ///
    /// **Book A's printed step is the unit compared here, and it is compared as a
    /// set.** Book A works two threads at once and names them as a pair; book C
    /// moves one at a time and gives them an order. The generated method keeps book
    /// C's order — one move to a step — so the two generated steps that make up one
    /// printed step are taken together and compared without their order.
    /// `bookCsOrderInsideEachPrintedStepIsKept` checks the order itself.
    @Test func bookCGeneratesTheTablesTranscribedFromBookA() throws {
        let expected: [(String, BraidMethod, [[BraidMove]], [BraidMove])] = [
            ("hira-genji", BraidMethodCatalog.hiraGenji16, [
                [BraidMove(from: 3, to: 13), BraidMove(from: 6, to: 12)],
                [BraidMove(from: 14, to: 4), BraidMove(from: 11, to: 5)],
                [BraidMove(from: 9, to: 16), BraidMove(from: 8, to: 1)],
                [BraidMove(from: 16, to: 9), BraidMove(from: 1, to: 8)],
                [BraidMove(from: 10, to: 15), BraidMove(from: 7, to: 2)],
                [BraidMove(from: 15, to: 10), BraidMove(from: 2, to: 7)],
            ], [
                BraidMove(from: 4, to: 3), BraidMove(from: 5, to: 6),
                BraidMove(from: 13, to: 14), BraidMove(from: 12, to: 11),
            ]),
            ("maru-genji", BraidMethodCatalog.maruGenji16, [
                [BraidMove(from: 10, to: 16), BraidMove(from: 7, to: 1)],
                [BraidMove(from: 15, to: 9), BraidMove(from: 2, to: 8)],
                [BraidMove(from: 3, to: 13), BraidMove(from: 6, to: 12)],
                [BraidMove(from: 14, to: 4), BraidMove(from: 11, to: 5)],
            ], [
                BraidMove(from: 16, to: 15), BraidMove(from: 1, to: 2),
                BraidMove(from: 4, to: 3), BraidMove(from: 5, to: 6),
                BraidMove(from: 9, to: 10), BraidMove(from: 8, to: 7),
                BraidMove(from: 13, to: 14), BraidMove(from: 12, to: 11),
            ]),
        ]
        var comparedMoves = 0
        for (name, generated, steps, closing) in expected {
            #expect(generated.steps.count == steps.count * 2, "\(name)")
            for (index, step) in steps.enumerated() {
                let pair = generated.steps[index * 2].moves + generated.steps[index * 2 + 1].moves
                #expect(Set(pair) == Set(step), "\(name) printed step \(index + 1)")
                comparedMoves += step.count
            }
            #expect(Set(generated.closing.moves) == Set(closing), "\(name) closing")
            comparedMoves += closing.count
        }
        #expect(comparedMoves == 32)   // 12 + 4 for hira, 8 + 8 for maru
    }

    /// And the whole derivation still lands where it did: the same repeat, the same
    /// courses, the same fold.
    @Test func theDerivationIsUnchangedByGeneratingTheTables() throws {
        let hira = try #require(BraidDerivation.derive(
            stand: BraidMethodCatalog.stand16,
            method: BraidMethodCatalog.hiraGenji16,
            crossSection: BraidMethodCatalog.hiraGenji16CrossSection
        ))
        #expect(hira.repeatCycleCount == 4)
        #expect(hira.instantsPerCycle == 13)   // twelve moves and the closing
        #expect(hira.threadsRunningAlongTheBraid == [1, 2, 7, 8, 9, 10, 15, 16])
        #expect(hira.fold?.columnCount == 6)

        let maru = try #require(BraidDerivation.derive(
            stand: BraidMethodCatalog.stand16,
            method: BraidMethodCatalog.maruGenji16,
            crossSection: BraidMethodCatalog.maruGenji16CrossSection
        ))
        #expect(maru.repeatCycleCount == 4)
        #expect(maru.instantsPerCycle == 9)    // eight moves and the closing
        #expect(maru.fold == nil)
        #expect(maru.faceColumnCount == 8)
    }

    /// **The order inside each printed step is book C's, not book A's.**
    ///
    /// Book C's table is one move to a line, read down the first column and then
    /// down the next; that order is the order of the hands, so every two threads
    /// have a first and a second. The generated steps are that sequence.
    @Test func bookCsOrderInsideEachPrintedStepIsKept() {
        #expect(BraidMethodCatalog.maruGenji16.steps.flatMap(\.moves) == [
            BraidMove(from: 7, to: 1), BraidMove(from: 10, to: 16),
            BraidMove(from: 2, to: 8), BraidMove(from: 15, to: 9),
            BraidMove(from: 3, to: 13), BraidMove(from: 6, to: 12),
            BraidMove(from: 14, to: 4), BraidMove(from: 11, to: 5),
        ])
        #expect(BraidMethodCatalog.hiraGenji16.steps.flatMap(\.moves) == [
            BraidMove(from: 3, to: 13), BraidMove(from: 6, to: 12),
            BraidMove(from: 14, to: 4), BraidMove(from: 11, to: 5),
            BraidMove(from: 8, to: 1), BraidMove(from: 9, to: 16),
            BraidMove(from: 1, to: 8), BraidMove(from: 16, to: 9),
            BraidMove(from: 7, to: 2), BraidMove(from: 10, to: 15),
            BraidMove(from: 2, to: 7), BraidMove(from: 15, to: 10),
        ])
    }

    /// Which printed steps book C works in the other order from book A. **Recorded,
    /// not judged**: book C is the source of record, so where they differ book C
    /// decides. Book A's transcription is kept as the set comparison above.
    @Test func theStepsBookCWorksInTheOtherOrderFromBookAAreListed() {
        let bookA: [String: [[BraidMove]]] = [
            "maru-genji": [
                [BraidMove(from: 10, to: 16), BraidMove(from: 7, to: 1)],
                [BraidMove(from: 15, to: 9), BraidMove(from: 2, to: 8)],
                [BraidMove(from: 3, to: 13), BraidMove(from: 6, to: 12)],
                [BraidMove(from: 14, to: 4), BraidMove(from: 11, to: 5)],
            ],
            "hira-genji": [
                [BraidMove(from: 3, to: 13), BraidMove(from: 6, to: 12)],
                [BraidMove(from: 14, to: 4), BraidMove(from: 11, to: 5)],
                [BraidMove(from: 9, to: 16), BraidMove(from: 8, to: 1)],
                [BraidMove(from: 16, to: 9), BraidMove(from: 1, to: 8)],
                [BraidMove(from: 10, to: 15), BraidMove(from: 7, to: 2)],
                [BraidMove(from: 15, to: 10), BraidMove(from: 2, to: 7)],
            ],
        ]
        var reversed = [String: [Int]]()
        for (name, method) in [("maru-genji", BraidMethodCatalog.maruGenji16),
                               ("hira-genji", BraidMethodCatalog.hiraGenji16)] {
            let moves = method.steps.flatMap(\.moves)
            for (index, printed) in (bookA[name] ?? []).enumerated()
            where Array(moves[(index * 2)...(index * 2 + 1)]) != printed {
                reversed[name, default: []].append(index + 1)
            }
        }
        #expect(reversed == ["maru-genji": [1, 2], "hira-genji": [3, 4, 5, 6]])
    }

    /// A disk whose cycle does not close on its resting notches is refused rather
    /// than half-read.
    @Test func aTableThatDoesNotCloseIsRefused() {
        let broken = BraidDiskNotation(
            source: "not a cycle",
            notchCount: 32,
            standPositionByRestingNotch: BraidMethodCatalog.diskRestingNotches,
            moves: [BraidMove(from: 9, to: 28)],
            threadsPerStep: 2
        )
        #expect(broken.method(id: "x", standID: "round-16", stepNames: ["one"]) == nil)
    }
}
