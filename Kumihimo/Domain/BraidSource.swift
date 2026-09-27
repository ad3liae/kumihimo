import Foundation

/// **A book a braid's steps come from, by its published title** (Task 070). The
/// screen names a book only this way — never by the names this repository has
/// used for it (`docs/sources.md`).
enum BraidBook: Equatable, Sendable, CaseIterable {
    /// The source of record: the textbook, 「組ひもディスクの本」 in Task 053, and
    /// the 源氏's 「bookA p94 / p96」.
    case textbook
    /// The same author's recipe book, 「bookA」 in Tasks 008, 031, 054 and 009.
    case recipeBook
    /// The handwritten one, 「book C」 in the code; its pages carry 「KUMIHIMO on
    /// the DISK」.
    case kumihimoOnTheDisk

    var title: String {
        switch self {
        case .textbook: "かわいい組ひもの教科書"
        case .recipeBook: "うつくしい組ひもと小物のレシピ"
        case .kumihimoOnTheDisk: "ディスクで組紐、はじめませんか"
        }
    }
}

/// **Where a braid's steps are printed: the book and its pages** (Task 070).
/// Every braid so far is the textbook's alone, which is what the author asked
/// for — 「かわいい組ひもの教科書から導出できるものならそれだけ」.
struct BraidSource: Equatable, Sendable {
    let book: BraidBook
    /// One page, or a spread.
    let pages: ClosedRange<Int>

    init(book: BraidBook, page: Int) {
        self.init(book: book, pages: page...page)
    }

    init(book: BraidBook, pages: ClosedRange<Int>) {
        self.book = book
        self.pages = pages
    }
}
