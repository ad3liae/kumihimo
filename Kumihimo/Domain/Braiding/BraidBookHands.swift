import Foundation

/// Which way a thread goes round the stand, seen from above (Task 061).
enum BraidStepWay: Equatable, Sendable {
    /// 右回り: clockwise from above, the way the position numbers run.
    case clockwise
    /// 左回り.
    case anticlockwise
    /// Straight over the middle: a round stand's carry across the mirror to the
    /// face opposite (Task 067), or a disk move of exactly half the disk.
    case across

    /// The way that goes a given distance round a rim of `count`, the short way.
    /// `nil` for no distance.
    static func shortWay(forward: Int, around count: Int) -> BraidStepWay? {
        guard count > 0 else { return nil }
        let forward = (forward % count + count) % count
        guard forward != 0 else { return nil }
        if forward * 2 == count { return .across }
        return forward * 2 < count ? .clockwise : .anticlockwise
    }
}

/// **One printed step of a book's disk** (Task 067): the moves it makes at once,
/// in the book's own slit numbers. A hand-over — a thread stepped over its
/// partner — is marked, for its words.
///
/// **For the step animation only**; the derivation never reads it.
struct BraidBookStep: Equatable, Sendable {
    let moves: [BraidMove]
    let isHandOver: Bool

    init(moves: [BraidMove], isHandOver: Bool = false) {
        self.moves = moves
        self.isHandOver = isHandOver
    }
}

/// **A braid's hands on a round stand's faces, as a book of the round stand
/// writes them** (Task 067): four faces of threads, and each hand two threads
/// taken at once, one in each hand, from the ends of a face and laid in another
/// — straight over the mirror, or round the rim the way the book's arrows go
/// (Task 068). The words are the book's: a face's ends are 左・右 or 奥・手前 as
/// the braider sits, and a thread goes to a face's 中央, or beside or past an
/// end, or to a face its thread has just left.
///
/// **For the step animation only**; the derivation never reads it.
struct BraidStandHands: Equatable, Sendable {
    /// An end of a face as the braider sees it: 左, 右, 奥, 手前.
    enum End: Equatable, Sendable {
        case left, right, far, near

        var opposite: End {
            switch self {
            case .left: .right
            case .right: .left
            case .far: .near
            case .near: .far
            }
        }
    }

    /// 左手 or 右手.
    enum Hand: Equatable, Sendable {
        case left, right
    }

    /// Where on a face a thread is laid.
    enum Spot: Equatable, Sendable {
        /// The face itself, its one thread having just left: 「3面へ」.
        case face
        /// 中央, on the given end's side of the middle.
        case centre(End)
        /// Just inside the given end: 「左端の糸の右側」.
        case insideEnd(End)
        /// Past the given end, the face's new end: 「左端」.
        case end(End)
    }

    struct Face: Equatable, Sendable {
        /// The book's number for it: 1面 …
        let number: Int
        /// Its middle, in turns clockwise from the top.
        let turn: Double
        /// The stand's places on it at the start, clockwise.
        let places: [Int]
        /// The end that comes first going clockwise.
        let clockwiseFirst: End
    }

    /// One thread of a hand: taken from `face`, the `fromTheEnd`th from its
    /// `end` (0 for the end itself) — or, with no end, the face's one thread —
    /// and laid on `toFace` at `spot`.
    struct Carry: Equatable, Sendable {
        let hand: Hand
        let face: Int
        let end: End?
        let fromTheEnd: Int
        let toFace: Int
        let spot: Spot

        init(hand: Hand, face: Int, end: End?, fromTheEnd: Int = 0, toFace: Int, spot: Spot) {
            self.hand = hand
            self.face = face
            self.end = end
            self.fromTheEnd = fromTheEnd
            self.toFace = toFace
            self.spot = spot
        }
    }

    /// The threads carried at once, and the way they go: straight over the
    /// mirror (`.across`), or round the rim, 時計回り or 反時計回り.
    struct StandHand: Equatable, Sendable {
        let carries: [Carry]
        let way: BraidStepWay

        init(_ carries: [Carry], way: BraidStepWay = .across) {
            self.carries = carries
            self.way = way
        }
    }

    let faces: [Face]
    /// **One dan**: the hands in turn.
    let hands: [StandHand]
}
