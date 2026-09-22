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
}

extension BraidPresetID {
    static let maruGenji16 = BraidPresetID(rawValue: "maru-genji-16")
    static let hiraGenji16 = BraidPresetID(rawValue: "hira-genji-16")
    static let yatsuKongoS8 = BraidPresetID(rawValue: "yatsu-kongo-s-8")
    static let yatsuKongoZ8 = BraidPresetID(rawValue: "yatsu-kongo-z-8")
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
    /// **The notice is longer than the others because more is open.** Since Task
    /// 053 the tables are a disk book's p.36-37, photographed — not the source of
    /// record, though book C Fig.129 prints the same Z — and the solid is drawn
    /// from rules rather than from a transcribed cell figure (Task 031). What is
    /// settled is the colouring, book A p.54 and p.55's a.
    static let yatsuKongoS = BraidPreset(
        id: .yatsuKongoS8,
        displayName: "八つ金剛S",
        supportedThreadCounts: [8],
        crossSectionProfile: .round,
        verificationLevel: .movementRules,
        prototypeNotice: "手順表は組ひもディスクの本（8S-スパイラル）から写した試作です。bookC Fig.129のZと同じ進み方になります。立体は写真に合わせた描画上の近似です。"
    )

    static let yatsuKongoZ = BraidPreset(
        id: .yatsuKongoZ8,
        displayName: "八つ金剛Z",
        supportedThreadCounts: [8],
        crossSectionProfile: .round,
        verificationLevel: .movementRules,
        prototypeNotice: "手順表は組ひもディスクの本（8Z-スパイラル）から写した試作で、bookC Fig.129と同じ進み方です。立体は写真に合わせた描画上の近似です。"
    )

    static let presets = [maruGenji, hiraGenji, yatsuKongoS, yatsuKongoZ]

    static func availablePresets(threadCount: Int) -> [BraidPreset] {
        presets.filter { $0.supports(threadCount: threadCount) }
    }

    static func preset(for id: BraidPresetID) -> BraidPreset? {
        presets.first { $0.id == id }
    }
}
