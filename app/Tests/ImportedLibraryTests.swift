import XCTest
@testable import Molago

final class ImportedLibraryTests: XCTestCase {
    func testSavedImportsRoundTripAndReplaceTheSameVideo() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try ImportedLibrary.save(item(slot: "youtube-one", title: "First"), in: directory)
        try ImportedLibrary.save(item(slot: "youtube-two", title: "Second"), in: directory)
        try ImportedLibrary.save(item(slot: "youtube-one", title: "First, updated"), in: directory)

        let loaded = await ImportedLibrary.read(from: directory)

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.first { $0.text.slot == "youtube-one" }?.text.title, "First, updated")
        XCTAssertEqual(Set(loaded.map(\.text.slot)), ["youtube-one", "youtube-two"])
    }

    func testMalformedImportDoesNotHideValidImports() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try ImportedLibrary.save(item(slot: "youtube-good", title: "Good"), in: directory)
        try Data("not json".utf8).write(to: directory.appending(path: "youtube-bad.json"))

        let loaded = await ImportedLibrary.read(from: directory)

        XCTAssertEqual(loaded.map(\.text.slot), ["youtube-good"])
    }

    private func temporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func item(slot: String, title: String) -> Molago.LibraryItem {
        LibraryItem(
            date: "2026-08-17",
            text: Day.Text(
                slot: slot, universe: "YouTube", title: title, minutes: 1,
                icon: nil, kind: "youtube", importedAt: "2026-08-17T00:00:00Z",
                videoID: slot.replacingOccurrences(of: "youtube-", with: ""),
                sourceURL: nil, sourceName: "YouTube", thumbnail: nil,
                durationSeconds: 60, sentences: []
            )
        )
    }
}
