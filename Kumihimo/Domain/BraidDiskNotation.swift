import Foundation

/// A braid written the way book C writes it: a ring of numbered notches, and the
/// moves of one cycle in the order the book prints them.
///
/// **This is the source of record for the move tables.** Book C, *KUMIHIMO on the
/// DISK*, works every braid on a thirty-two notch disk and prints the cycle as
/// numbered moves, which is the only one of the three sources that is already a
/// table rather than a paragraph and a photograph. The methods are generated from
/// it rather than typed out again, and the generated tables are held against the
/// ones transcribed from book A, move for move.
///
/// A disk holds one thread to a notch, so a thread on its way from one resting
/// place to another is parked in a notch between. Reading the cycle back gives
/// each thread's resting place at the start and at the end; those are the moves
/// the stand makes.
struct BraidDiskNotation: Equatable, Sendable {
    /// Which figure of which book this is.
    let source: String
    let notchCount: Int

    /// The notches that hold a thread at rest, and the stand position each of them
    /// stands for. Read off the figure's starting diagram.
    let standPositionByRestingNotch: [Int: Int]

    /// One cycle, in the order the book prints it.
    let moves: [BraidMove]

    /// How many threads one *printed* step of book A carries. Book A and book B
    /// both work two at a time, one in each hand.
    ///
    /// **This is book A's unit, not the source of record's.** Book C's table is one
    /// move to a line, read down the first column and then down the next, and that
    /// order is the order of the hands. So every two threads have a first and a
    /// second, and this number is kept only to name the generated steps after the
    /// printed step they belong to.
    let threadsPerStep: Int

    /// How far round the disk a move carries a thread, the short way.
    func notches(_ move: BraidMove) -> Int {
        let raw = abs(move.to - move.from) % notchCount
        return min(raw, notchCount - raw)
    }

    /// **Repositioning is told apart by the distance alone.**
    ///
    /// A braiding move carries a thread across the braid — eleven to fourteen
    /// notches of thirty-two in both Genji braids. Tidying a group back onto its
    /// standard places only ever shifts a thread to the notch next door. There is
    /// no overlap between the two, so nothing has to be marked by hand.
    ///
    /// **The one is a constant, and it has only been checked against Fig.20 and
    /// Fig.32.** Those two leave a gap of ten notches between the shortest braiding
    /// move and the longest tidy, which is why one is safe here. A square stand
    /// (stage 5) or a method somebody invents (stage 4) has not been looked at, and
    /// a braid whose braiding moves are short would need this read another way.
    func isRepositioning(_ move: BraidMove) -> Bool { notches(move) == 1 }

    var braidingMoves: [BraidMove] { moves.filter { !isRepositioning($0) } }
    var repositioningMoves: [BraidMove] { moves.filter(isRepositioning) }

    /// The stand's own method: where each thread rests at the start of the cycle
    /// and where it rests at the end.
    ///
    /// **One braiding move to a step, in book C's order.** The source of record
    /// moves one thread at a time, so every two threads have a first and a second
    /// and there is no such thing as two threads laid at the same instant. Book A's
    /// "take the outer two of the east group" is shorthand for two moves, and its
    /// printed step only names the generated steps.
    ///
    /// The closing stays one step. It is one instant that carries several threads
    /// because it advances the braid neither round nor along — that is the settled
    /// stacking model, not a new rule.
    ///
    /// `nil` when the cycle does not run cleanly — a move with nothing to lift, a
    /// notch taken twice, a cycle that does not finish on the resting notches, or
    /// a count of braiding moves that the printed step does not divide.
    func method(
        id: String,
        standID: String,
        stepNames: [String],
        closingName: String = "closing"
    ) -> BraidMethod? {
        var occupant = standPositionByRestingNotch          // notch -> thread
        var carried = [Int]()                               // threads, in the order they were braided
        var shuffledOnly = Set<Int>()

        for move in moves {
            guard let thread = occupant[move.from], occupant[move.to] == nil else { return nil }
            occupant[move.from] = nil
            occupant[move.to] = thread
            if isRepositioning(move) { shuffledOnly.insert(thread) } else { carried.append(thread) }
        }
        guard
            Set(occupant.keys) == Set(standPositionByRestingNotch.keys),
            Set(carried).count == carried.count,
            threadsPerStep > 0,
            carried.count % threadsPerStep == 0,
            stepNames.count == carried.count / threadsPerStep
        else {
            return nil
        }
        var end = [Int: Int]()                              // thread -> resting place at the end
        for (notch, thread) in occupant {
            guard let place = standPositionByRestingNotch[notch] else { return nil }
            end[thread] = place
        }

        // A thread is named by the place it rests at when the cycle begins, so its
        // move is from that place to wherever it rests when the cycle ends.
        func move(_ thread: Int) -> BraidMove? {
            end[thread].map { BraidMove(from: thread, to: $0) }
        }

        var steps = [BraidStep]()
        for (index, thread) in carried.enumerated() {
            guard let move = move(thread) else { return nil }
            let printed = stepNames[index / threadsPerStep]
            let name = threadsPerStep == 1 ? printed : "\(printed)-\(index % threadsPerStep + 1)"
            steps.append(BraidStep(name: name, moves: [move]))
        }
        // A thread only ever shifted one notch was not braided this cycle; it is
        // being put back where the next cycle expects it.
        let tidied = shuffledOnly.subtracting(carried).sorted()
        let closing = BraidStep(name: closingName, moves: tidied.compactMap(move))
        guard closing.moves.count == tidied.count else { return nil }
        return BraidMethod(id: id, standID: standID, steps: steps, closing: closing)
    }
}
