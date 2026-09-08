import Foundation

/// The answers the Python scripts produced, held as data rather than as opinions.
///
/// `Scripts/task025/fixtures.py` writes these out of the very scripts Task 024 read
/// against book A p97 and Task 004. **Nothing in `KumihimoTests/Fixtures` may be
/// edited to make a test pass.** When Swift and a fixture disagree, which one is
/// right is a question for the author, not for whoever is holding the keyboard.
enum BraidFixtures {
    private final class Marker {}

    enum Source: String {
        /// Copied into the test bundle by the project's synchronized group.
        case testBundle
        /// Read straight out of the source tree. The fallback, and the reason the
        /// tests do not depend on how the project happens to be configured.
        case sourceTree
    }

    /// Where a fixture was found, and where it was read from.
    static func locate(_ name: String) throws -> (url: URL, source: Source) {
        let bundle = Bundle(for: Marker.self)
        if let url = bundle.url(forResource: name, withExtension: "json") {
            return (url, .testBundle)
        }
        if let url = bundle.url(forResource: name, withExtension: "json",
                                subdirectory: "Fixtures") {
            return (url, .testBundle)
        }
        let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let url = here.appendingPathComponent("Fixtures/\(name).json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw Trouble.notFound(name)
        }
        return (url, .sourceTree)
    }

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: locate(name).url)
    }

    static func decode<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        try JSONDecoder().decode(type, from: data(name))
    }

    enum Trouble: Error, CustomStringConvertible {
        case notFound(String)

        var description: String {
            switch self {
            case let .notFound(name):
                return "fixture \(name).json is neither in the test bundle nor in "
                    + "KumihimoTests/Fixtures. Run Scripts/task025/fixtures.py."
            }
        }
    }
}
