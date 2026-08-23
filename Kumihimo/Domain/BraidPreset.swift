import Foundation

struct BraidPreset: Identifiable, Equatable, Sendable {
    let id: BraidPresetID
    let displayName: String
    let supportedThreadCounts: Set<Int>

    func supports(threadCount: Int) -> Bool {
        supportedThreadCounts.contains(threadCount)
    }
}

extension BraidPresetID {
    static let maruGenji16 = BraidPresetID(rawValue: "maru-genji-16")
}

enum BraidPresetCatalog {
    static let maruGenji = BraidPreset(
        id: .maruGenji16,
        displayName: "丸源氏",
        supportedThreadCounts: [16]
    )

    static let presets = [maruGenji]

    static func availablePresets(threadCount: Int) -> [BraidPreset] {
        presets.filter { $0.supports(threadCount: threadCount) }
    }

    static func preset(for id: BraidPresetID) -> BraidPreset? {
        presets.first { $0.id == id }
    }
}
