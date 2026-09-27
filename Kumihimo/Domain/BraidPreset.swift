import Foundation

enum BraidCrossSectionProfile: Equatable, Sendable {
    case round
    case flat(widthToThicknessRatio: Float)
}

enum BraidVerificationLevel: Int, Comparable, Sendable {
    case movementRules = 1
    case referenceSurface = 2
    case physicalSamples = 3

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct BraidPreset: Identifiable, Equatable, Sendable {
    let id: BraidPresetID
    let displayName: String
    let supportedThreadCounts: Set<Int>
    let crossSectionProfile: BraidCrossSectionProfile
    let verificationLevel: BraidVerificationLevel
    /// What has and has not been checked about this braid's picture. **Carried by
    /// the preset** so a view does not have to know which braid it is showing.
    let prototypeNotice: String

    func supports(threadCount: Int) -> Bool {
        supportedThreadCounts.contains(threadCount)
    }

    /// The kind of stand this braid is set up on, **read off its recipe's stand**
    /// rather than written on the preset (Task 058). `nil` for a preset with no
    /// recipe, which no stand offers.
    var standKind: BraidStandKind? {
        BraidMethodCatalog.recipe(for: id)
            .flatMap(BraidMethodCatalog.stand(for:))?
            .kind
    }

    func supports(standKind: BraidStandKind) -> Bool {
        self.standKind == standKind
    }
}

extension BraidPresetID {
    static let maruGenji16 = BraidPresetID(rawValue: "maru-genji-16")
    static let hiraGenji16 = BraidPresetID(rawValue: "hira-genji-16")
    static let yatsuKongoS8 = BraidPresetID(rawValue: "yatsu-kongo-s-8")
    static let yatsuKongoZ8 = BraidPresetID(rawValue: "yatsu-kongo-z-8")
    static let yatsuKongoGaeshi8 = BraidPresetID(rawValue: "yatsu-kongo-gaeshi-8")
    static let maruYotsu4 = BraidPresetID(rawValue: "maru-yotsu-4")
    static let edoYatsu8 = BraidPresetID(rawValue: "edo-yatsu-8")
}

enum BraidPresetCatalog {
    static let maruGenji = BraidPreset(
        id: .maruGenji16,
        displayName: "丸源氏",
        supportedThreadCounts: [16],
        crossSectionProfile: .round,
        verificationLevel: .physicalSamples,
        prototypeNotice: "実物3例で配色傾向を照合した試作です。糸の上下関係と締め具合は未検証です。"
    )

    static let hiraGenji = BraidPreset(
        id: .hiraGenji16,
        displayName: "平源氏",
        supportedThreadCounts: [16],
        crossSectionProfile: .flat(widthToThicknessRatio: 6),
        verificationLevel: .referenceSurface,
        prototypeNotice: "反復色を使った複数例で配色傾向を照合した試作です。16位置をすべて異なる色にした対応と、糸の上下関係・締め具合は未検証です。"
    )

    /// The eight-bobbin braids, S and Z.
    ///
    /// **The notice names the book by its title** (Task 070): the tables are the
    /// textbook's p.37 and p.36 (Task 053), and book C Fig.129 prints the same Z,
    /// which the notice no longer says. The solid is drawn from rules rather than
    /// from a transcribed cell figure (Task 031). What is settled is the
    /// colouring, book A p.54 and p.55's a.
    static let yatsuKongoS = BraidPreset(
        id: .yatsuKongoS8,
        displayName: "八つ金剛S",
        supportedThreadCounts: [8],
        crossSectionProfile: .round,
        verificationLevel: .movementRules,
        prototypeNotice: "手順は『かわいい組ひもの教科書』p.37（8S-スパイラル）から。立体は写真に合わせた描画上の近似です。"
    )

    static let yatsuKongoZ = BraidPreset(
        id: .yatsuKongoZ8,
        displayName: "八つ金剛Z",
        supportedThreadCounts: [8],
        crossSectionProfile: .round,
        verificationLevel: .movementRules,
        prototypeNotice: "手順は『かわいい組ひもの教科書』p.36（8Z-スパイラル）から。立体は写真に合わせた描画上の近似です。"
    )

    /// 八つ金剛返し組 (Task 053): six dan of S, then six of Z, from the disk
    /// book's p.38. **More is open than for S and Z**: the finished braid's
    /// photographs are small, and how the drawing lays the turn is its own
    /// reading.
    static let yatsuKongoGaeshi = BraidPreset(
        id: .yatsuKongoGaeshi8,
        displayName: "八つ金剛返し",
        supportedThreadCounts: [8],
        crossSectionProfile: .round,
        verificationLevel: .movementRules,
        prototypeNotice: "手順は『かわいい組ひもの教科書』p.38–39（8S&Z-スパイラル）から。Sを6段、Zを6段で1工程です。折り返しの見え方は小さな写真にしか照らしていない描画上の近似です。"
    )

    /// 丸四つ組 (Task 054), the first braid of four threads. **Read off book A
    /// p.56's picture**, which prints each step's two threads, one to a hand,
    /// and not which goes first; book C has no figure of it. **The notice cites
    /// the textbook's p.52 alone** (Task 070), which moves the two 「同時に」.
    static let maruYotsu = BraidPreset(
        id: .maruYotsu4,
        displayName: "丸四つ",
        supportedThreadCounts: [4],
        crossSectionProfile: .round,
        verificationLevel: .movementRules,
        prototypeNotice: "手順は『かわいい組ひもの教科書』p.52 から。立体は写真に合わせた描画上の近似です。"
    )

    /// 江戸八つ組 (Task 009). **Transcribed from the textbook's p.64–65** since
    /// Task 057, which prints it on the disk one move a figure; until then it
    /// was read off the recipe book's p.48 pictures. Drawn by the eight-thread
    /// tube's drawer, **as the both-ways family since Task 059**: its table carries
    /// threads both ways round, a place shows the thread that passed over it, and
    /// that family has a shape of its own.
    static let edoYatsu = BraidPreset(
        id: .edoYatsu8,
        displayName: "江戸八つ",
        supportedThreadCounts: [8],
        crossSectionProfile: .round,
        verificationLevel: .movementRules,
        prototypeNotice: "手順は『かわいい組ひもの教科書』p.64–65 から。立体の目の形は同書 p.64 の写真に合わせた描画上の近似です。"
    )

    static let presets = [
        maruGenji, hiraGenji, yatsuKongoS, yatsuKongoZ, yatsuKongoGaeshi, maruYotsu, edoYatsu,
    ]

    /// The braids that take this many threads, **whatever the stand**.
    static func availablePresets(threadCount: Int) -> [BraidPreset] {
        presets.filter { $0.supports(threadCount: threadCount) }
    }

    /// The braids the editor offers: this many threads, **on this kind of stand**
    /// (Task 058).
    static func availablePresets(threadCount: Int, standKind: BraidStandKind) -> [BraidPreset] {
        availablePresets(threadCount: threadCount).filter { $0.supports(standKind: standKind) }
    }

    static func preset(for id: BraidPresetID) -> BraidPreset? {
        presets.first { $0.id == id }
    }
}
