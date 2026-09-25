import Foundation
import SwiftData
import Testing
@testable import Kumihimo

/// Task 063: **the thread colours are the 38 of a Nishijin thread shop**, and the
/// twelve provisional colours they replaced are read as their nearest.
///
/// `docs/colours.md` is the source of record; these tests read its two tables
/// rather than copy them, so the catalogue and the document cannot drift apart.
@MainActor
struct ThreadColorCatalogTests {
    // MARK: the 38

    @Test func theCatalogueIsTheShopsThirtyEightInItsOrder() {
        let colours = ThreadColorCatalog.colors
        #expect(colours.count == 38)
        #expect(Set(colours.map(\.id)).count == 38)
        #expect(colours.map(\.code)
                == (1...36).map { String(format: "No.%02d", $0) } + ["限定", "限定"])
        #expect(ThreadColorCatalog.defaultColor.id.rawValue == "zoge")
        #expect(ThreadColorCatalog.defaultColor.code == "No.15")
        #expect(colours.contains(ThreadColorCatalog.defaultColor))
    }

    /// Every row of the table, in order: number, name, reading, ID, and the value
    /// to three places.
    @Test func everyColourIsItsRowInTheSourceOfRecord() throws {
        let rows = try Self.thirtyEight()
        #expect(rows.count == 38)
        for (colour, row) in zip(ThreadColorCatalog.colors, rows) {
            #expect(colour.code == row.code, "\(row.id)")
            #expect(colour.name == row.name, "\(row.id)")
            #expect(colour.reading == row.reading, "\(row.id)")
            #expect(colour.id.rawValue == row.id)
            for (mine, theirs) in zip([colour.value.red, colour.value.green, colour.value.blue], row.value) {
                #expect(abs(mine - theirs) < 0.000_5, "\(row.id)")
            }
        }
    }

    // MARK: the twelve former IDs

    /// Each of the twelve reads as the colour the table gives it, and **no two
    /// become the same colour**.
    @Test func eachFormerIDReadsAsTheColourTheTableGivesIt() throws {
        let rows = try Self.formerTable()
        #expect(rows.count == 12)
        #expect(ThreadColorCatalog.formerIDs.count == 12)
        for (former, current) in rows {
            let formerID = ThreadColorID(rawValue: former)
            #expect(ThreadColorCatalog.formerIDs[formerID]?.rawValue == current)
            #expect(ThreadColorCatalog.color(for: formerID)?.id.rawValue == current, "\(former)")
            #expect(ThreadColorCatalog.contains(formerID))
            #expect(ThreadColorCatalog.currentID(for: formerID).rawValue == current)
        }
        #expect(Set(rows.map(\.current)).count == 12)
        // A former ID is never also a current one, so reading one never shadows a colour.
        let current = Set(ThreadColorCatalog.colors.map(\.id))
        #expect(ThreadColorCatalog.formerIDs.keys.allSatisfy { !current.contains($0) })
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

    /// **A project saved with the twelve former IDs opens in their colours, and
    /// is written with the new IDs the next time it is saved.** The store is
    /// written to disk the way an older build wrote it — by the schema as it
    /// stood before Task 058, with the IDs as they were — and opened the way the
    /// app opens it.
    @Test func aProjectSavedWithTheFormerIDsOpensInTheirColoursAndSavesWithTheNewOnes() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "task063-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "former-colours.store")
        let id = UUID()
        let former = try Self.formerTable()
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
                id: id, name: "仮の12色の作品",
                braidTypeName: KumihimoProject.undecidedBraidName,
                selectedBraidRecipeID: nil,
                threadCount: 12,
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
        store.selectedThreadPosition = 12
        store.selectColor(ThreadColorID(rawValue: "ruri"))
        #expect(store.hasUnsavedChanges)
        store.overwrite()
        current.mainContext.rollback()
        let reloaded = try #require(try service.load(id: id))
        let written = try reloaded.validatedThreadAssignments()
        #expect(written.map(\.colorID.rawValue) == former.dropLast().map(\.current) + ["ruri"])
        #expect(written.allSatisfy { ThreadColorCatalog.formerIDs[$0.colorID] == nil })
        #expect(store.draft.threadAssignments == written)
        #expect(!store.hasUnsavedChanges)
    }

    // MARK: the sheet

    @Test func theSheetReadsTheNameItsReadingAndTheShopsNumber() throws {
        let first = try #require(ThreadColorCatalog.colors.first)
        let last = try #require(ThreadColorCatalog.colors.last)
        #expect(ProjectEditorStrings.threadColorAccessibilityLabel(first) == "菫色（すみれいろ）、No.01")
        #expect(ProjectEditorStrings.threadColorAccessibilityLabel(last) == "瑠璃（るり）、限定")
    }

    // MARK: reading docs/colours.md

    private struct Row {
        let code: String
        let name: String
        let reading: String
        let id: String
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

    /// The table「38色」: 番号 | 色名 | 読み | 内部ID | 色値 | 0〜1 | 見本の画像.
    private static func thirtyEight() throws -> [Row] {
        try document().split(separator: "\n")
            .filter { $0.hasPrefix("| No.") || $0.hasPrefix("| 限定 |") }
            .map { line in
                let cells = cells(line)
                return Row(
                    code: cells[0], name: cells[1], reading: cells[2], id: unquoted(cells[3]),
                    value: cells[5].components(separatedBy: ",").compactMap {
                        Double($0.trimmingCharacters(in: .whitespaces))
                    }
                )
            }
    }

    /// The table「仮の12色から38色への移し替え」: 古いID | 古い名前 | 古い値 | 新しい色 | ΔE00,
    /// the new colour's ID being the last quoted word of its cell.
    private static func formerTable() throws -> [(former: String, current: String)] {
        try document().split(separator: "\n")
            .filter { $0.hasPrefix("| `") }
            .map { line in
                let cells = cells(line)
                let current = cells[3].components(separatedBy: "`").dropLast().last ?? ""
                return (unquoted(cells[0]), current)
            }
    }
}
