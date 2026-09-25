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

    /// 「3 / 16 手目」: the hand shown, counted from 1, of one time round.
    static func count(_ hand: Int, of total: Int) -> String { "\(hand) / \(total) 手目" }

    static func way(_ way: BraidStepWay) -> String {
        switch way {
        case .clockwise: "右回り"
        case .anticlockwise: "左回り"
        case .across: "中央を横切って"
        }
    }

    /// **The hand as one sentence**: 「場所7の糸を、右回りに場所1へ」, and for a
    /// hand of two 「場所1の糸を左回りに場所3へ、場所3の糸を左回りに場所1へ」. A
    /// hand-over: 「場所8の糸を、隣の糸を越えて場所6へ」.
    ///
    /// **A braid of several tables says which, in the book's words** (Task
    /// 062): 「Sの組み：…」, and 「持ち替え：…」 for a hand-over — the names the
    /// tables carry. A braid of one table says no name.
    static func sentence(for hand: BraidStepScript.Hand, tableCount: Int) -> String {
        let carries: String
        if hand.isHandOver, hand.carries.count == 1, let carry = hand.carries.first {
            carries = "場所\(carry.from)の糸を、隣の糸を越えて場所\(carry.to)へ"
        } else if hand.carries.count == 1, let carry = hand.carries.first {
            carries = "場所\(carry.from)の糸を、\(way(carry.way))\(particle(carry.way))場所\(carry.to)へ"
        } else {
            carries = hand.carries
                .map { "場所\($0.from)の糸を\(way($0.way))\(particle($0.way))場所\($0.to)へ" }
                .joined(separator: "、")
        }
        guard hand.isHandOver || tableCount > 1, let name = hand.name else { return carries }
        return "\(name)：\(carries)"
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
