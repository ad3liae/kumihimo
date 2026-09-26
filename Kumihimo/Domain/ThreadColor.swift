import Foundation
import simd

struct ThreadColorID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

struct ThreadColorValue: Codable, Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
}

struct ThreadColor: Identifiable, Equatable, Sendable {
    let id: ThreadColorID
    let name: String
    /// How the name is read, in hiragana: すみれいろ for 菫色.
    let reading: String
    /// The shop's number: "No.01" to "No.36", or "限定" for its two limited colours.
    let code: String
    let value: ThreadColorValue
}

struct ThreadRenderColor: Equatable, Sendable {
    let sRGB: SIMD3<Float>
    let boundarySRGB: SIMD3<Float>
    let fiberHighlightSRGB: SIMD3<Float>
}

enum ThreadColorRendering {
    static func renderColor(for color: ThreadColor) -> ThreadRenderColor {
        let base = SIMD3<Float>(
            clampedComponent(color.value.red),
            clampedComponent(color.value.green),
            clampedComponent(color.value.blue)
        )
        let linear = transformed(base, using: sRGBToLinear)
        let boundaryLinear = linear * 0.68
        let highlightLinear = simd_mix(
            linear,
            SIMD3<Float>(repeating: 1),
            SIMD3<Float>(repeating: 0.08)
        )

        return ThreadRenderColor(
            sRGB: base,
            boundarySRGB: transformed(boundaryLinear, using: linearToSRGB),
            fiberHighlightSRGB: transformed(highlightLinear, using: linearToSRGB)
        )
    }

    static func relativeLuminance(of sRGB: SIMD3<Float>) -> Float {
        let clamped = SIMD3<Float>(
            clampedComponent(Double(sRGB.x)),
            clampedComponent(Double(sRGB.y)),
            clampedComponent(Double(sRGB.z))
        )
        let linear = transformed(clamped, using: sRGBToLinear)
        return 0.2126 * linear.x + 0.7152 * linear.y + 0.0722 * linear.z
    }

    private static func clampedComponent(_ value: Double) -> Float {
        guard value.isFinite else { return 0 }
        return Float(min(max(value, 0), 1))
    }

    private static func sRGBToLinear(_ component: Float) -> Float {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }

    private static func linearToSRGB(_ component: Float) -> Float {
        let clamped = min(max(component, 0), 1)
        return clamped <= 0.0031308
            ? 12.92 * clamped
            : 1.055 * pow(clamped, 1 / 2.4) - 0.055
    }

    private static func transformed(
        _ value: SIMD3<Float>,
        using transform: (Float) -> Float
    ) -> SIMD3<Float> {
        SIMD3<Float>(transform(value.x), transform(value.y), transform(value.z))
    }
}

/// **The 38 colours of a Nishijin thread shop's 正絹唐打ち紐**, its 36 and two
/// limited (Task 063). `docs/colours.md` is the source of record for every name,
/// number and value; the values are read off the shop's photographs, so they are
/// near, not measured.
enum ThreadColorCatalog {
    /// No.15 象牙, which a new project's threads start in.
    static let defaultColor = color("zoge", "象牙", "ぞうげ", "No.15", 0.898, 0.855, 0.675)

    /// In the shop's order: No.01 to No.36, then the two limited colours.
    static let colors: [ThreadColor] = [
        color("sumire", "菫色", "すみれいろ", "No.01", 0.275, 0.020, 0.600),
        color("kodai-murasaki", "古代紫", "こだいむらさき", "No.02", 0.263, 0.090, 0.204),
        color("shikon", "紫紺", "しこん", "No.03", 0.192, 0.141, 0.282),
        color("edo-murasaki", "江戸紫", "えどむらさき", "No.04", 0.549, 0.196, 0.306),
        color("fuji", "藤色", "ふじいろ", "No.05", 0.902, 0.663, 0.804),
        color("kenpo", "憲房", "けんぽう", "No.06", 0.212, 0.086, 0.008),
        color("rikancha", "璃寛茶", "りかんちゃ", "No.07", 0.314, 0.231, 0.027),
        color("kokiake", "深緋", "こきあけ", "No.08", 0.420, 0.247, 0.031),
        color("kuriume", "栗梅", "くりうめ", "No.09", 0.467, 0.098, 0.012),
        color("karacha", "唐茶", "からちゃ", "No.10", 0.533, 0.267, 0.027),
        color("kincha", "金茶", "きんちゃ", "No.11", 0.620, 0.490, 0.067),
        color("honkin", "本金", "ほんきん", "No.12", 0.784, 0.671, 0.110),
        color("karashi", "芥子", "からし", "No.13", 0.580, 0.545, 0.145),
        color("usukin", "薄金", "うすきん", "No.14", 0.706, 0.682, 0.337),
        defaultColor,
        color("karakurenai", "唐紅", "からくれない", "No.16", 0.498, 0.008, 0.008),
        color("kurenai", "紅色", "くれないいろ", "No.17", 0.643, 0.024, 0.012),
        color("shu", "朱色", "しゅいろ", "No.18", 0.843, 0.165, 0.016),
        color("sango", "珊瑚", "さんご", "No.19", 1.000, 0.667, 0.435),
        color("ikkon", "一斤", "いっこん", "No.20", 0.941, 0.722, 0.698),
        color("oni", "黄丹", "おうに", "No.21", 0.851, 0.361, 0.035),
        color("yamabuki", "山吹", "やまぶき", "No.22", 0.812, 0.600, 0.106),
        color("kiiro", "黄色", "きいろ", "No.23", 0.894, 0.812, 0.106),
        color("yamabato", "山鳩", "やまばと", "No.24", 0.243, 0.192, 0.024),
        color("tokiwa", "常盤", "ときわ", "No.25", 0.365, 0.525, 0.169),
        color("matcha", "抹茶", "まっちゃ", "No.26", 0.576, 0.675, 0.106),
        color("seiji", "青磁", "せいじ", "No.27", 0.741, 0.776, 0.651),
        color("aonibi", "青鈍", "あおにび", "No.28", 0.102, 0.145, 0.212),
        color("asagi", "浅葱", "あさぎ", "No.29", 0.314, 0.451, 0.459),
        color("tsuyukusa", "露草色", "つゆくさいろ", "No.30", 0.471, 0.592, 0.851),
        color("byakugun", "白群", "びゃくぐん", "No.31", 0.808, 0.804, 0.843),
        color("shikkoku", "漆黒", "しっこく", "No.32", 0.110, 0.063, 0.055),
        color("tsurubami", "橡色", "つるばみいろ", "No.33", 0.118, 0.059, 0.137),
        color("nibi", "鈍色", "にびいろ", "No.34", 0.553, 0.502, 0.475),
        color("hakkin", "白金", "はっきん", "No.35", 0.647, 0.663, 0.631),
        color("hakudo", "白土", "はくど", "No.36", 1.000, 0.973, 0.839),
        color("tokusa", "木賊", "とくさ", "限定", 0.196, 0.588, 0.200),
        color("ruri", "瑠璃", "るり", "限定", 0.200, 0.220, 0.686),
    ]

    /// **The twelve provisional colours' IDs, each read as its nearest of the 38**
    /// (CIEDE2000, `docs/colours.md`). Projects saved before Task 063 carry these:
    /// they open in the colour given here and are written with its ID the next
    /// time they are saved. **Every saved project relies on this, so it stays.**
    static let formerIDs: [ThreadColorID: ThreadColorID] = Dictionary(
        uniqueKeysWithValues: [
            ("red", "shu"),
            ("orange", "oni"),
            ("yellow", "kiiro"),
            ("green", "tokusa"),
            ("light-blue", "tsuyukusa"),
            ("blue", "ruri"),
            ("purple", "sumire"),
            ("pink", "fuji"),
            ("brown", "kokiake"),
            ("black", "shikkoku"),
            ("white", "hakudo"),
            ("natural", "zoge"),
        ].map { (ThreadColorID(rawValue: $0.0), ThreadColorID(rawValue: $0.1)) }
    )

    /// The colour an ID names, reading a former ID as the colour it became.
    static func color(for id: ThreadColorID) -> ThreadColor? {
        let current = currentID(for: id)
        return colors.first { $0.id == current }
    }

    static func contains(_ id: ThreadColorID) -> Bool {
        color(for: id) != nil
    }

    /// The ID to write for a colour: a former ID becomes the one it is read as,
    /// and any other comes back as it is.
    static func currentID(for id: ThreadColorID) -> ThreadColorID {
        formerIDs[id] ?? id
    }

    private static func color(
        _ id: String,
        _ name: String,
        _ reading: String,
        _ code: String,
        _ red: Double,
        _ green: Double,
        _ blue: Double
    ) -> ThreadColor {
        ThreadColor(
            id: ThreadColorID(rawValue: id),
            name: name,
            reading: reading,
            code: code,
            value: ThreadColorValue(red: red, green: green, blue: blue)
        )
    }
}
