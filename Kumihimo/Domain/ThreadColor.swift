import Foundation

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
