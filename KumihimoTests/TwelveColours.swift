@testable import Kumihimo

/// Twelve colours told apart, for the tests that want threads told apart.
///
/// **Written out here rather than read off `ThreadColorCatalog.colors`** (Task
/// 063). Those tests used to go round the catalogue, `colors[$0 % colors.count]`;
/// when the catalogue changed from twelve colours to thirty-eight, going round it
/// would have changed which threads share a colour, and with that more than the
/// colour. These are the twelve the catalogue listed until then, in its order.
enum TwelveColours {
    static let ids: [ThreadColorID] = [
        "red", "orange", "yellow", "green", "light-blue", "blue",
        "purple", "pink", "brown", "black", "white", "natural",
    ].map(ThreadColorID.init(rawValue:))
}
