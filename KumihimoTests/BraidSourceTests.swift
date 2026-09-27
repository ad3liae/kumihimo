import Foundation
import Testing
@testable import Kumihimo

/// Task 070: **the step animation and the notes name the book by its published
/// title** — 『かわいい組ひもの教科書』 and its pages, for every braid that can be
/// worked out from it, which is every braid so far.
struct BraidSourceTests {
    /// The textbook's pages for each braid's steps (Tasks 066–069).
    private static let textbookPages: [String: ClosedRange<Int>] = [
        "yatsu-kongo-s-8": 37...37,
        "yatsu-kongo-z-8": 36...36,
        "yatsu-kongo-gaeshi-8": 38...38,
        "edo-yatsu-8": 64...65,
        "maru-yotsu-4": 52...52,
        "maru-genji-16": 94...95,
        "hira-genji-16": 96...97,
    ]

    /// The names this repository has called the books by, never shown.
    private static let internalNames = ["bookA", "bookC", "book A", "book C", "組ひもディスクの本", "レシピ本"]

    @Test func everyRecipeCitesTheTextbookAtItsPages() {
        #expect(Set(BraidMethodCatalog.recipes.map(\.id)) == Set(Self.textbookPages.keys))
        for recipe in BraidMethodCatalog.recipes {
            #expect(recipe.source?.book == .textbook, "\(recipe.id)")
            #expect(recipe.source?.pages == Self.textbookPages[recipe.id], "\(recipe.id)")
        }
    }

    /// The published titles (`docs/sources.md`).
    @Test func theBooksAreCalledByTheirTitles() {
        #expect(BraidBook.textbook.title == "かわいい組ひもの教科書")
        #expect(BraidBook.recipeBook.title == "うつくしい組ひもと小物のレシピ")
        #expect(BraidBook.kumihimoOnTheDisk.title == "ディスクで組紐、はじめませんか")
    }

    /// 「出典：『かわいい組ひもの教科書』p.94–95」 for a spread, 「p.52」 for a page;
    /// in a narrow column, broken only between its parts.
    @Test func theLineUnderTheStepsNamesTheBookAndItsPages() {
        #expect(BraidStepsStrings.source(BraidSource(book: .textbook, pages: 94...95))
                == "出典：『かわいい組ひもの教科書』p.94–95")
        #expect(BraidStepsStrings.source(BraidSource(book: .textbook, page: 52))
                == "出典：『かわいい組ひもの教科書』p.52")
        #expect(BraidStepsStrings.sourceInLines(BraidSource(book: .textbook, page: 37))
                == "出典：\n『かわいい組ひもの教科書』\np.37")
        #expect(BraidStepsStrings.sourceAccessibilityLabel(BraidSource(book: .textbook, pages: 94...95))
                == "出典、かわいい組ひもの教科書、94から95ページ")
    }

    /// **No notice uses a name of this repository's for a book**, and 「教科書」
    /// appears only inside the book's full title.
    @Test(arguments: BraidPresetCatalog.presets)
    func noNoticeUsesAnInternalName(preset: BraidPreset) {
        let notice = preset.prototypeNotice
        for name in Self.internalNames {
            #expect(!notice.contains(name), "\(preset.id.rawValue): \(name)")
        }
        let withoutTheTitle = notice.replacingOccurrences(of: "『\(BraidBook.textbook.title)』", with: "")
        #expect(!withoutTheTitle.contains("教科書"), "\(preset.id.rawValue)")
    }

    /// **A notice that names a book cites what the step animation does**: the
    /// same book and pages. 丸源氏 and 平源氏's notices name none.
    @Test(arguments: BraidPresetCatalog.presets)
    func aNoticeCitesTheRecipesSource(preset: BraidPreset) throws {
        let recipe = try #require(BraidMethodCatalog.recipe(for: preset.id))
        let source = try #require(recipe.source)
        let namesABook = preset.prototypeNotice.contains("『")
        #expect(namesABook == ![BraidPresetID.maruGenji16, .hiraGenji16].contains(preset.id))
        if namesABook {
            #expect(preset.prototypeNotice.contains(BraidStepsStrings.citation(source)),
                    "\(preset.id.rawValue)")
        }
    }
}
