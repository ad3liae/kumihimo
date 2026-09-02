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
    let temporaryCode: String
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

enum ThreadColorCatalog {
    static let defaultColor = color("natural", "生成り", "K-12", 0.86, 0.81, 0.68)

    static let colors: [ThreadColor] = [
        color("red", "赤", "K-01", 0.78, 0.12, 0.16),
        color("orange", "橙", "K-02", 0.94, 0.39, 0.10),
        color("yellow", "黄", "K-03", 0.95, 0.75, 0.12),
        color("green", "緑", "K-04", 0.12, 0.52, 0.27),
        color("light-blue", "水色", "K-05", 0.35, 0.70, 0.82),
        color("blue", "青", "K-06", 0.12, 0.32, 0.68),
        color("purple", "紫", "K-07", 0.43, 0.20, 0.58),
        color("pink", "桃", "K-08", 0.90, 0.43, 0.57),
        color("brown", "茶", "K-09", 0.42, 0.25, 0.14),
        color("black", "黒", "K-10", 0.08, 0.08, 0.09),
        color("white", "白", "K-11", 0.96, 0.96, 0.94),
        defaultColor,
    ]

    static func color(for id: ThreadColorID) -> ThreadColor? {
        colors.first { $0.id == id }
    }

    static func contains(_ id: ThreadColorID) -> Bool {
        color(for: id) != nil
    }

    private static func color(
        _ id: String,
        _ name: String,
        _ code: String,
        _ red: Double,
        _ green: Double,
        _ blue: Double
    ) -> ThreadColor {
        ThreadColor(
            id: ThreadColorID(rawValue: id),
            name: name,
            temporaryCode: code,
            value: ThreadColorValue(red: red, green: green, blue: blue)
        )
    }
}
