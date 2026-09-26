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
    /// The maker's colour number, "501" to "530": what the sheet shows first.
    let code: String
    /// **What the colour is called here, not by the maker**, which gives numbers
    /// only: オフホワイト for 501. The reviewer's names, shown beside the number
    /// and read aloud with it.
    let name: String
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

/// **The 30 colours of Hamanaka Amerry F 《合太》**, numbers 501 to 530 (Task
/// 065). `docs/colours.md` is the source of record for every number, name and
/// value; the values are read off the maker's swatch picture, so they are near,
/// not measured, and the names are ours — the maker gives numbers only.
enum ThreadColorCatalog {
    /// 501 オフホワイト, which a new project's threads start in.
    static let defaultColor = color("501", "オフホワイト", 0.976, 0.961, 0.890)

    /// In the swatch's order, row by row: the order the sheet shows them in.
    static let colors: [ThreadColor] = [
        defaultColor,
        color("529", "ベージュ", 0.886, 0.796, 0.682),
        color("530", "薄黄緑", 0.882, 0.902, 0.706),
        color("502", "レモン", 0.996, 0.957, 0.592),
        color("503", "マスタード", 0.871, 0.690, 0.039),
        color("504", "ピーチ", 0.929, 0.757, 0.651),
        color("505", "ローズ", 0.827, 0.443, 0.467),
        color("506", "オレンジ", 0.867, 0.451, 0.145),
        color("507", "朱赤", 0.706, 0.173, 0.133),
        color("508", "赤", 0.722, 0.078, 0.149),
        color("509", "ワイン", 0.569, 0.090, 0.180),
        color("510", "ぶどう", 0.329, 0.220, 0.380),
        color("525", "赤紫", 0.498, 0.173, 0.349),
        color("511", "紫", 0.427, 0.325, 0.529),
        color("512", "水色", 0.627, 0.808, 0.902),
        color("513", "青", 0.192, 0.361, 0.576),
        color("514", "紺", 0.000, 0.169, 0.392),
        color("527", "マリンブルー", 0.000, 0.412, 0.604),
        color("515", "青緑", 0.016, 0.416, 0.467),
        color("528", "ターコイズ", 0.251, 0.612, 0.608),
        color("516", "黄緑", 0.463, 0.678, 0.196),
        color("517", "薄緑", 0.545, 0.729, 0.510),
        color("518", "緑", 0.106, 0.424, 0.227),
        color("519", "焦げ茶", 0.243, 0.125, 0.027),
        color("520", "キャメル", 0.737, 0.549, 0.286),
        color("521", "グレージュ", 0.643, 0.588, 0.529),
        color("522", "ライトグレー", 0.749, 0.741, 0.710),
        color("523", "グレー", 0.510, 0.529, 0.533),
        color("526", "チャコール", 0.282, 0.267, 0.294),
        color("524", "黒", 0.031, 0.043, 0.047),
    ]

    /// **Every former ID, read as one of the 30** (`docs/colours.md`, its two
    /// tables). Projects saved before Task 065 carry these: they open in the
    /// colour given here and are written with its ID the next time they are
    /// saved. **Every saved project relies on this, so it stays.**
    ///
    /// Each is its nearest of the 30 by CIEDE2000, but for the two that were the
    /// default colour, `natural` and `zoge`, which become the default, 501. The
    /// 38 are more than the 30, so some of them become the same colour.
    static let formerIDs: [ThreadColorID: ThreadColorID] = Dictionary(
        uniqueKeysWithValues: (twelveFormerIDs + thirtyEightFormerIDs).map {
            (ThreadColorID(rawValue: $0.0), ThreadColorID(rawValue: "amerry-f-" + $0.1))
        }
    )

    /// The twelve provisional colours, before Task 063.
    private static let twelveFormerIDs = [
        ("red", "508"),
        ("orange", "506"),
        ("yellow", "503"),
        ("green", "518"),
        ("light-blue", "512"),
        ("blue", "513"),
        ("purple", "511"),
        ("pink", "505"),
        ("brown", "519"),
        ("black", "524"),
        ("white", "501"),
        ("natural", "501"),
    ]

    /// The 38 of a Nishijin thread shop, Task 063 to Task 065.
    private static let thirtyEightFormerIDs = [
        ("sumire", "514"),
        ("kodai-murasaki", "510"),
        ("shikon", "510"),
        ("edo-murasaki", "525"),
        ("fuji", "505"),
        ("kenpo", "519"),
        ("rikancha", "519"),
        ("kokiake", "519"),
        ("kuriume", "509"),
        ("karacha", "507"),
        ("kincha", "520"),
        ("honkin", "503"),
        ("karashi", "520"),
        ("usukin", "503"),
        ("zoge", "501"),
        ("karakurenai", "509"),
        ("kurenai", "507"),
        ("shu", "507"),
        ("sango", "504"),
        ("ikkon", "504"),
        ("oni", "506"),
        ("yamabuki", "503"),
        ("kiiro", "503"),
        ("yamabato", "519"),
        ("tokiwa", "516"),
        ("matcha", "516"),
        ("seiji", "530"),
        ("aonibi", "514"),
        ("asagi", "515"),
        ("tsuyukusa", "512"),
        ("byakugun", "522"),
        ("shikkoku", "524"),
        ("tsurubami", "524"),
        ("nibi", "521"),
        ("hakkin", "522"),
        ("hakudo", "501"),
        ("tokusa", "516"),
        ("ruri", "514"),
    ]

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

    /// A colour whose ID is made from its number: `amerry-f-501` for 501.
    private static func color(
        _ code: String,
        _ name: String,
        _ red: Double,
        _ green: Double,
        _ blue: Double
    ) -> ThreadColor {
        ThreadColor(
            id: ThreadColorID(rawValue: "amerry-f-" + code),
            code: code,
            name: name,
            value: ThreadColorValue(red: red, green: green, blue: blue)
        )
    }
}
