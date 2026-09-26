import Foundation
import SwiftData
import Testing
@testable import Kumihimo

/// Task 065: **the thread colours are the 30 of Hamanaka Amerry F 《合太》**, and
/// the former IDs — the twelve provisional colours' and the Nishijin shop's 38
/// (Task 063) — are read as the colours `docs/colours.md` gives them.
///
/// `docs/colours.md` is the source of record; these tests read its tables rather
/// than copy them, so the catalogue and the document cannot drift apart.
@MainActor
struct ThreadColorCatalogTests {
    // MARK: the 30

    @Test func theCatalogueIsTheThirtyInTheSwatchesOrder() throws {
        let colours = ThreadColorCatalog.colors
        #expect(colours.count == 30)
        #expect(Set(colours.map(\.id)).count == 30)
        #expect(Set(colours.map(\.code)) == Set((501...530).map(String.init)))
        #expect(colours.map(\.code) == (try Self.thirty()).map(\.code))
        #expect(ThreadColorCatalog.defaultColor.id.rawValue == "amerry-f-501")
        #expect(ThreadColorCatalog.defaultColor.code == "501")
        #expect(colours.first == ThreadColorCatalog.defaultColor)
        // **The ID is made from the number**, not from the order or the name.
        #expect(colours.allSatisfy { $0.id.rawValue == "amerry-f-" + $0.code })
    }

    /// Every row of the table, in order: number, ID, name, and the value to three
    /// places.
    @Test func everyColourIsItsRowInTheSourceOfRecord() throws {
        let rows = try Self.thirty()
        #expect(rows.count == 30)
        #expect(rows.map(\.order) == Array(1...30))
        for (colour, row) in zip(ThreadColorCatalog.colors, rows) {
            #expect(colour.code == row.code, "\(row.id)")
            #expect(colour.id.rawValue == row.id)
            #expect(colour.name == row.name, "\(row.id)")
            for (mine, theirs) in zip([colour.value.red, colour.value.green, colour.value.blue], row.value) {
                #expect(abs(mine - theirs) < 0.000_5, "\(row.id)")
            }
        }
    }

    // MARK: the former IDs

    /// Each of the twelve and each of the 38 reads as the colour its table gives
    /// it — **`natural` and `zoge`, the default colours they were, as the new
    /// default 501**, not as their nearest.
    @Test func eachFormerIDReadsAsTheColourTheTableGivesIt() throws {
        let twelve = try Self.formerTable("仮の12色"), thirtyEight = try Self.formerTable("西陣の38色")
        #expect(twelve.count == 12)
        #expect(thirtyEight.count == 38)
        #expect(ThreadColorCatalog.formerIDs.count == 50)
        for (former, current) in twelve + thirtyEight {
            let formerID = ThreadColorID(rawValue: former)
            #expect(ThreadColorCatalog.formerIDs[formerID]?.rawValue == current, "\(former)")
            #expect(ThreadColorCatalog.color(for: formerID)?.id.rawValue == current, "\(former)")
            #expect(ThreadColorCatalog.contains(formerID))
            #expect(ThreadColorCatalog.currentID(for: formerID).rawValue == current)
        }
        for former in ["natural", "zoge"] {
            #expect(ThreadColorCatalog.currentID(for: ThreadColorID(rawValue: former))
                    == ThreadColorCatalog.defaultColor.id)
        }
        // A former ID is never also a current one, so reading one never shadows a colour.
        let current = Set(ThreadColorCatalog.colors.map(\.id))
        #expect(ThreadColorCatalog.formerIDs.keys.allSatisfy { !current.contains($0) })
        #expect(ThreadColorCatalog.formerIDs.values.allSatisfy { current.contains($0) })
    }

    @Test func aCurrentIDIsWrittenAsItIsAndAnUnknownOneNamesNothing() {
        for colour in ThreadColorCatalog.colors {
            #expect(ThreadColorCatalog.currentID(for: colour.id) == colour.id)
            #expect(ThreadColorCatalog.color(for: colour.id) == colour)
        }
        let unknown = ThreadColorID(rawValue: "mauve")
        #expect(ThreadColorCatalog.color(for: unknown) == nil)
        #expect(!ThreadColorCatalog.contains(unknown))
        #expect(ThreadColorCatalog.currentID(for: unknown) == unknown)
    }

    /// **A project saved with former IDs opens in the colours they are read as,
    /// and is written with the new IDs the next time it is saved.** The store is
    /// written to disk the way an older build wrote it — by the schema as it
    /// stood before Task 058, with the IDs as they were — and opened the way the
    /// app opens it. Case 0 is the twelve on twelve threads; cases 1 to 3 are the
    /// 38 on sixteen threads each, in the table's order and round again.
    @Test(arguments: 0..<4)
    func aProjectSavedWithFormerIDsOpensInTheirColoursAndSavesWithTheNewOnes(project: Int) throws {
        let former: [(former: String, current: String)]
        if project == 0 {
            former = try Self.formerTable("仮の12色")
        } else {
            let thirtyEight = try Self.formerTable("西陣の38色")
            former = (0..<16).map { thirtyEight[((project - 1) * 16 + $0) % thirtyEight.count] }
        }
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "task065-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "former-colours.store")
        let id = UUID()
        let saved = former.enumerated().map {
            ThreadAssignment(position: $0.offset + 1, colorID: ThreadColorID(rawValue: $0.element.former))
        }

        try autoreleasepool {
            let old = try ModelContainer(
                for: Schema(versionedSchema: KumihimoSchemaBeforeStands.self),
                configurations: ModelConfiguration(url: url)
            )
            let context = ModelContext(old)
            context.insert(KumihimoSchemaBeforeStands.KumihimoProject(
                id: id, name: "古い色の作品",
                braidTypeName: KumihimoProject.undecidedBraidName,
                selectedBraidRecipeID: nil,
                threadCount: former.count,
                threadAssignmentsData: try JSONEncoder().encode(saved)
            ))
            try context.save()
        }

        let current = try ModelContainer(
            for: KumihimoProject.self,
            configurations: ModelConfiguration(url: url)
        )
        let service = ProjectEditorPersistenceService(context: current.mainContext)
        let store = ProjectEditorStore(persistence: service, projectID: id)

        // Opened: the IDs are as they were written, and each is drawn in the
        // colour the table gives it — the colour the board and the braid ask for.
        #expect(!store.hasLoadError)
        #expect(store.draft.threadAssignments == saved)
        #expect(store.draft.hasValidAssignments)
        #expect(!store.hasUnsavedChanges)
        for (assignment, row) in zip(store.draft.threadAssignments, former) {
            #expect(ThreadColorCatalog.color(for: assignment.colorID)?.id.rawValue == row.current)
        }

        // Saved again, with one thread changed: every thread is written with its
        // new ID, the ones not touched too, and reads back in the same colour.
        store.selectedThreadPosition = former.count
        store.selectColor(ThreadColorID(rawValue: "amerry-f-513"))
        #expect(store.hasUnsavedChanges)
        store.overwrite()
        current.mainContext.rollback()
        let reloaded = try #require(try service.load(id: id))
        let written = try reloaded.validatedThreadAssignments()
        #expect(written.map(\.colorID.rawValue) == former.dropLast().map(\.current) + ["amerry-f-513"])
        #expect(written.allSatisfy { ThreadColorCatalog.formerIDs[$0.colorID] == nil })
        #expect(store.draft.threadAssignments == written)
        #expect(!store.hasUnsavedChanges)
    }

    // MARK: the recipes' own colourings

    /// Each recipe's colouring as it stood before Task 063, place by place, in
    /// the twelve former IDs.
    private static let formerColourings: [String: [String]] = {
        func byGroup(_ stand: BraidStand, _ groups: [String: [String]]) -> [String] {
            BraidMethodCatalog.colouring(on: stand, groups)
                .sorted { $0.position < $1.position }.map(\.colorID.rawValue)
        }
        let eightYellowOrange = ["yellow", "yellow", "orange", "orange", "yellow", "yellow", "orange", "orange"]
        return [
            "maru-genji-16": byGroup(BraidMethodCatalog.stand16, [
                "north": ["pink", "orange", "orange", "pink"], "east": Array(repeating: "black", count: 4),
                "south": ["natural", "red", "red", "natural"], "west": Array(repeating: "black", count: 4),
            ]),
            "hira-genji-16": byGroup(BraidMethodCatalog.stand16, [
                "north": ["purple", "purple", "black", "orange"], "east": Array(repeating: "pink", count: 4),
                "south": ["purple", "purple", "black", "orange"], "west": Array(repeating: "pink", count: 4),
            ]),
            "yatsu-kongo-s-8": eightYellowOrange,
            "yatsu-kongo-z-8": eightYellowOrange,
            "yatsu-kongo-gaeshi-8": ["orange", "orange", "pink", "pink", "orange", "orange", "pink", "pink"],
            "maru-yotsu-4": byGroup(BraidMethodCatalog.stand4, [
                "north": ["white"], "east": ["purple"], "south": ["white"], "west": ["purple"],
            ]),
            "edo-yatsu-8": ["light-blue", "yellow", "pink", "natural", "light-blue", "yellow", "pink", "natural"],
        ]
    }()

    /// **Every recipe's colouring is written in the 30**, not read through the
    /// former IDs, and **its threads keep their pattern**: two threads that were
    /// the same colour before Task 063 are the same colour now, and two that
    /// were different are still different — though the 30 read several of the
    /// 38 as one colour. The colours were chosen afresh from the books'
    /// photographs, so which colour each is, is not held here.
    @Test(arguments: BraidMethodCatalog.recipes)
    func aRecipesColouringIsInTheThirtyAndKeepsItsPattern(recipe: BraidRecipe) throws {
        let current = Set(ThreadColorCatalog.colors.map(\.id))
        #expect(recipe.colouring.allSatisfy { current.contains($0.colorID) }, "\(recipe.id)")

        let before = try #require(Self.formerColourings[recipe.id])
        let now = recipe.colouring.sorted { $0.position < $1.position }.map(\.colorID.rawValue)
        #expect(now.count == before.count)
        for first in now.indices {
            for second in now.indices where second > first {
                #expect((now[first] == now[second]) == (before[first] == before[second]),
                        "\(recipe.id) places \(first + 1) and \(second + 1)")
            }
        }
    }

    // MARK: the sheet

    /// The sheet and the board read the maker's number first, then what the
    /// colour is called here.
    @Test func theSheetReadsTheNumberAndThenTheName() throws {
        let first = try #require(ThreadColorCatalog.colors.first)
        let last = try #require(ThreadColorCatalog.colors.last)
        #expect(ProjectEditorStrings.threadColorAccessibilityLabel(first) == "501、オフホワイト")
        #expect(ProjectEditorStrings.threadColorAccessibilityLabel(last) == "524、黒")
        #expect(ProjectEditorStrings.threadAccessibilityLabel(
            position: 3, colorName: ProjectEditorStrings.threadColorAccessibilityLabel(first)
        ) == "糸3、501、オフホワイト")
    }

    // MARK: reading docs/colours.md

    private struct Row {
        let order: Int
        let code: String
        let id: String
        let name: String
        let value: [Double]
    }

    private static func document() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "docs/colours.md")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func cells(_ line: Substring) -> [String] {
        line.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func unquoted(_ cell: String) -> String {
        cell.trimmingCharacters(in: CharacterSet(charactersIn: "`"))
    }

    /// The table「30色」: 並び | 色番号 | 内部ID | 呼び名 | 色値 | 0〜1.
    private static func thirty() throws -> [Row] {
        try document().split(separator: "\n")
            .map { cells($0) }
            .filter { $0.count == 6 && Int($0[0]) != nil && $0[2].hasPrefix("`amerry-f-") }
            .map { cells in
                Row(
                    order: Int(cells[0]) ?? 0, code: cells[1], id: unquoted(cells[2]), name: cells[3],
                    value: cells[5].components(separatedBy: ",").compactMap {
                        Double($0.trimmingCharacters(in: .whitespaces))
                    }
                )
            }
    }

    /// A table of former IDs, found by the start of its heading (「### 仮の12色」,
    /// 「### 西陣の38色」): 古いID | 古い名前 | 読み替え先, the new colour being
    /// the number its cell starts with.
    private static func formerTable(_ heading: String) throws -> [(former: String, current: String)] {
        let lines = try document().split(separator: "\n", omittingEmptySubsequences: false)
        guard let start = lines.firstIndex(where: { $0.hasPrefix("### " + heading) }) else { return [] }
        return lines[(start + 1)...]
            .prefix { !$0.hasPrefix("#") }
            .filter { $0.hasPrefix("| `") }
            .map { line in
                let cells = cells(line)
                return (unquoted(cells[0]), "amerry-f-" + cells[2].prefix(3))
            }
    }
}
