import Foundation

/// The words of the step animation (Task 061). **「段」 is not one of them**: the
/// textbook uses it for a cycle on one page and half a cycle on another
/// (`docs/sources.md`), so the unit is 「手」.
enum BraidStepsStrings {
    static let play = "再生"
    static let pause = "一時停止"
    static let stepBack = "1手戻る"
    static let stepForward = "1手進む"
    static let standAccessibilityLabel = "丸台を上から見た、玉を動かす手順"
    /// A braid whose steps cannot be worked out. **Short**, because it stands
    /// where the stand would be.
    static let nothingToShow = "この組み方の手順はまだ描けません"

    /// **Setting every thread back in the starting form once a dan is done**
    /// (Task 068): not a hand, and 「段」 is not said.
    static let setting = "位置をそろえる"

    /// 「3 / 16 手目」: the hand shown, counted from 1, of one time round.
    static func count(_ hand: Int, of total: Int) -> String { "\(hand) / \(total) 手目" }

    static func way(_ way: BraidStepWay) -> String {
        switch way {
        case .clockwise: "右回り"
        case .anticlockwise: "左回り"
        case .across: "中央を横切って"
        }
    }

    /// **Where a thread stands, in the hand's words** (Task 066): 「場所5」 on a
    /// place where a thread began, 「場所2の隣」 beside one.
    struct Spot: Equatable {
        let place: Int
        let isBeside: Bool

        var words: String { isBeside ? "場所\(place)の隣" : "場所\(place)" }
    }

    /// **A hand on the disk as one sentence, as the picture shows it** (Task
    /// 066, Task 067): 「場所5の糸を、左回りに場所2の隣へ」; a hand of two
    /// 「場所1の糸を左回りに場所3の隣へ、場所3の糸を左回りに場所1の隣へ」; a
    /// hand-over 「場所2の糸を、隣の糸を越えて場所1の隣へ」.
    ///
    /// **A braid of several tables says which, in the book's words** (Task
    /// 062): 「Sの組み：…」, and 「持ち替え：…」 for a hand-over — the names the
    /// tables carry; `name` is `nil` where none is said.
    static func diskSentence(
        carries: [(from: Spot, to: Spot, way: BraidStepWay)], isHandOver: Bool, name: String?
    ) -> String {
        let said: String
        if isHandOver, carries.count == 1, let carry = carries.first {
            said = "\(carry.from.words)の糸を、隣の糸を越えて\(carry.to.words)へ"
        } else if carries.count == 1, let carry = carries.first {
            said = "\(carry.from.words)の糸を、\(way(carry.way))\(particle(carry.way))\(carry.to.words)へ"
        } else {
            said = carries
                .map { "\($0.from.words)の糸を\(way($0.way))\(particle($0.way))\($0.to.words)へ" }
                .joined(separator: "、")
        }
        guard let name else { return said }
        return "\(name)：\(said)"
    }

    /// **A hand on a round stand's faces, in the book's own words** (Task 067):
    /// 「3面の左端と右端の糸を、1面の中央へ（左手・右手）」; 「3面の左端の糸を1面の
    /// 左端の糸の右側へ、3面の右端の糸を1面の右端の糸の左側へ（左手・右手）」.
    /// Carried round the rim, the way and 「同時に」 instead of the hands (Task
    /// 068, 丸四つ組 p.52): 「1面の糸を3面へ、3面の糸を1面へ（時計回り、同時に）」.
    static func standSentence(_ hand: BraidStandHands.StandHand) -> String {
        let carries = hand.carries
        guard let first = carries.first else { return "" }
        let aside = hand.way == .across
            ? carries.map { $0.hand == .left ? "左手" : "右手" }.joined(separator: "・")
            : "\(roundWay(hand.way))、同時に"
        let fromOneFace = carries.allSatisfy { $0.face == first.face }
        let toOneFace = carries.allSatisfy { $0.toFace == first.toFace }
        let picks = carries.map { pick($0.end, $0.fromTheEnd) }.joined(separator: "と")
        if fromOneFace, toOneFace, carries.allSatisfy({ if case .centre = $0.spot { true } else { false } }) {
            return "\(first.face)面の\(picks)の糸を、\(first.toFace)面の中央へ（\(aside)）"
        }
        let ends = carries.compactMap { carry -> String? in
            if case .end(let end) = carry.spot { return pick(end, 0) }
            return nil
        }
        if fromOneFace, toOneFace, ends.count == carries.count {
            return "\(first.face)面の\(picks)の糸を、\(first.toFace)面の\(ends.joined(separator: "と"))へ（\(aside)）"
        }
        return carries
            .map { "\(taken($0))を\(laid($0))へ" }
            .joined(separator: "、") + "（\(aside)）"
    }

    /// 「3面の左端の糸」, or 「1面の糸」 for a face's one thread.
    private static func taken(_ carry: BraidStandHands.Carry) -> String {
        guard let end = carry.end else { return "\(carry.face)面の糸" }
        return "\(carry.face)面の\(pick(end, carry.fromTheEnd))の糸"
    }

    /// 「1面の中央」, or 「3面」 for a face its thread has just left.
    private static func laid(_ carry: BraidStandHands.Carry) -> String {
        if carry.spot == .face { return "\(carry.toFace)面" }
        return "\(carry.toFace)面の\(spot(carry.spot))"
    }

    /// 「時計回り」「反時計回り」, the textbook's words for a round stand.
    private static func roundWay(_ way: BraidStepWay) -> String {
        switch way {
        case .clockwise: "時計回り"
        case .anticlockwise: "反時計回り"
        case .across: "中央を横切って"
        }
    }

    /// 「左端」「左から2番目」「奥」「奥から2番目」.
    private static func pick(_ end: BraidStandHands.End?, _ fromTheEnd: Int) -> String {
        guard let end else { return "" }
        let name = endName(end)
        guard fromTheEnd > 0 else { return end == .left || end == .right ? "\(name)端" : name }
        return "\(name)から\(fromTheEnd + 1)番目"
    }

    private static func endName(_ end: BraidStandHands.End) -> String {
        switch end {
        case .left: "左"
        case .right: "右"
        case .far: "奥"
        case .near: "手前"
        }
    }

    /// 「中央」「左端の糸の右側」「左端」.
    private static func spot(_ spot: BraidStandHands.Spot) -> String {
        switch spot {
        case .face: ""
        case .centre: "中央"
        case .insideEnd(let end): "\(pick(end, 0))の糸の\(endName(end.opposite))側"
        case .end(let end): pick(end, 0)
        }
    }

    /// 「右回りに」, but 「中央を横切って」 with nothing after it.
    private static func particle(_ way: BraidStepWay) -> String {
        way == .across ? "" : "に"
    }

    /// What VoiceOver reads for the stand: the count, then the hand.
    static func accessibilityValue(count: String, sentence: String) -> String {
        "\(count)。\(sentence)"
    }
}
