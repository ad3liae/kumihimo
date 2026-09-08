import Foundation
import Testing
@testable import Kumihimo

/// The three published descriptions of 十六丸源氏組, and what each of them does and
/// does not say.
///
/// `HiraGenjiMoveRuleSourcesTests` does this for the flat braid. The round one had
/// only ever been read from book A, so book C is checked here for the first time —
/// and with it the question Task 020 stage 1 left open: whether the books settle
/// which of two threads moved together lies over the other.
struct MaruGenjiMoveRuleSourcesTests {
    /// Book C, Fig.32: twenty-four numbered moves round a thirty-two notch disk.
    ///
    /// Transcribed from the handwriting, four to a printed row.
    private static let bookCMethod: [(from: Int, to: Int)] = [
        (17, 4), (22, 3), (6, 19), (1, 20),
        (9, 28), (14, 27), (30, 11), (25, 12),
        (2, 1), (3, 2), (5, 6), (4, 5),
        (21, 22), (20, 21), (18, 17), (19, 18),
        (29, 30), (28, 29), (26, 25), (27, 26),
        (10, 9), (11, 10), (13, 14), (12, 13),
    ]

    /// The sixteen disk notches that carry a thread, and the board position each
    /// stands for. The same reading of the same disk that Task 005H made for
    /// Fig.20, which Fig.32 numbers identically.
    private static let diskToApp: [Int: Int] = [
        1: 15, 2: 16, 5: 1, 6: 2, 9: 3, 10: 4, 13: 5, 14: 6,
        17: 7, 18: 8, 21: 9, 22: 10, 25: 11, 26: 12, 29: 13, 30: 14,
    ]

    private static func bookCCycle() -> (occupied: [Int: Int], faults: [String]) {
        var occupied = Dictionary(uniqueKeysWithValues: diskToApp.keys.map { ($0, $0) })
        var faults = [String]()
        for (index, move) in bookCMethod.enumerated() {
            guard let thread = occupied[move.from] else {
                faults.append("move \(index + 1): nothing on notch \(move.from)")
                continue
            }
            guard occupied[move.to] == nil else {
                faults.append("move \(index + 1): notch \(move.to) already taken")
                continue
            }
            occupied[move.from] = nil
            occupied[move.to] = thread
        }
        return (occupied, faults)
    }

    /// A misreading of the handwriting would almost certainly send a thread to an
    /// occupied notch or finish somewhere else.
    @Test func bookCsTwentyFourMovesRunCleanlyAndCloseOnThemselves() {
        let (occupied, faults) = Self.bookCCycle()
        #expect(faults.isEmpty, "\(faults)")
        #expect(Set(occupied.keys) == Set(Self.diskToApp.keys))
    }

    /// **A third source for the round braid, checked for the first time.** Where
    /// each of the sixteen threads ends up after one repeat, compared thread by
    /// thread against the implementation written from book A.
    @Test func bookCAgreesWithTheImplementationOnEveryThread() throws {
        let (occupied, faults) = Self.bookCCycle()
        #expect(faults.isEmpty)

        var bookC = [Int: Int]()
        for (notch, startedOn) in occupied {
            let from = try #require(Self.diskToApp[startedOn])
            let to = try #require(Self.diskToApp[notch])
            bookC[from] = to
        }

        let cycle = try #require(MaruGenjiSimulation.cycle(from: .initial))
        let before = MaruGenjiBoardState.initial.boardPositionsByThread
        let after = cycle.endState.boardPositionsByThread
        let implementation = before.reduce(into: [Int: Int]()) { result, entry in
            result[entry.value] = after[entry.key]
        }

        #expect(implementation.count == 16)
        #expect(bookC == implementation)
    }

    /// **There is no such thing as two threads laid at the same instant.**
    ///
    /// Book A p94 and book B p73 name the two threads of a step by the hand that
    /// takes them — "the left-hand end with the left hand, the right-hand end with
    /// the right" — and neither says which is laid down first. **Book C does, and
    /// book C is the source of record**: its table is one move to a line, read down
    /// the first column and then down the next, and that is the order of the hands.
    /// So every two threads have a first and a second, and the generated methods
    /// carry one move to a step.
    ///
    /// Which leaves this empty. The closing is the one instant that still carries
    /// several moves, and none of its shifts have to pass each other either — each
    /// goes one place into a slot just vacated.
    ///
    /// **The guard stays** for the methods somebody invents on the stand (stage 4),
    /// where two threads could be declared to move together.
    @Test func noTwoThreadsMovedTogetherEverHaveToPassEachOther() throws {
        for (name, method, section) in [
            (
                "maru-genji",
                BraidMethodCatalog.maruGenji16,
                BraidMethodCatalog.maruGenji16CrossSection
            ),
            (
                "hira-genji",
                BraidMethodCatalog.hiraGenji16,
                BraidMethodCatalog.hiraGenji16CrossSection
            ),
        ] {
            let derivation = try #require(BraidDerivation.derive(
                stand: BraidMethodCatalog.stand16, method: method, crossSection: section
            ))
            for step in method.steps {
                #expect(step.moves.count == 1, "\(name) step \(step.name)")
            }
            let passings = derivation.passingsWithinOneInstant
            #expect(
                passings.isEmpty,
                "\(name): \(passings.map { "row \($0.row) instant \($0.instant) \($0.threads)" })"
            )
        }
    }

    /// The guard above has to be able to fail. A step that does carry two threads
    /// past each other is caught.
    ///
    /// **The generated methods have one move to a step, so such a step has to be
    /// built by hand here.** Book C never writes one; the guard exists for the
    /// methods somebody invents on the stand (stage 4), where two threads could be
    /// declared to move together.
    @Test func aStepThatDoesSendTwoThreadsPastEachOtherIsCaught() throws {
        // Maru-genji with its two east-to-west moves put into one step and their
        // destinations swapped, so the thread from position 3 finishes beyond the
        // one from position 6 instead of beside it. Everything else is untouched.
        var steps = BraidMethodCatalog.maruGenji16.steps.filter {
            !$0.name.hasPrefix("eastToWest")
        }
        steps.append(BraidStep(name: "eastToWest", moves: [
            BraidMove(from: 3, to: 12), BraidMove(from: 6, to: 13),
        ]))
        let crossing = BraidMethod(
            id: "crossing",
            standID: BraidMethodCatalog.maruGenji16.standID,
            steps: steps,
            closing: BraidMethodCatalog.maruGenji16.closing
        )
        let derivation = try #require(BraidDerivation.derive(
            stand: BraidMethodCatalog.stand16, method: crossing
        ))
        #expect(!derivation.passingsWithinOneInstant.isEmpty)
    }
}
