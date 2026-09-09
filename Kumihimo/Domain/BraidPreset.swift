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

    static let presets = [maruGenji, hiraGenji]

    static func availablePresets(threadCount: Int) -> [BraidPreset] {
        presets.filter { $0.supports(threadCount: threadCount) }
    }

    static func preset(for id: BraidPresetID) -> BraidPreset? {
        presets.first { $0.id == id }
    }
}
