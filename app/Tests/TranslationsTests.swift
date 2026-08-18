import XCTest
@testable import Molago

/// La traduction qui continue toute seule.
///
/// Elle a quitté l'écran de capture parce qu'elle y était annulée dès qu'on
/// partait. Ce qui compte ici : elle avance par tranches, elle écrit ce qu'elle
/// reçoit, et une tranche perdue n'emporte ni les autres ni l'import.
@MainActor
final class TranslationsTests: XCTestCase {
    private func item(lines: Int, english: [String]? = nil) -> Molago.LibraryItem {
        LibraryItem(
            date: "2026-08-18",
            text: Day.Text(
                slot: "youtube-zC4aRaHI-yw", universe: "YouTube", title: "항공사 뉴스",
                minutes: 2, icon: nil, kind: "youtube", importedAt: "2026-08-18T01:00:00Z",
                videoID: "zC4aRaHI-yw", sourceURL: "https://www.youtube.com/watch?v=zC4aRaHI-yw",
                sourceName: "Didi", thumbnail: nil, durationSeconds: 120,
                sentences: (0..<lines).map { i in
                    Day.Sentence(ko: "줄 \(i)", en: english?[i] ?? "", audio: "a\(i)",
                                 start: Double(i), end: Double(i) + 1, words: nil)
                }
            )
        )
    }

    private func settle(_ translations: Translations, until done: () -> Bool) async {
        for _ in 0..<2000 where !done() { await Task.yield() }
    }

    func testItTranslatesInSlicesAndWritesEachOneAsItLands() async {
        let translations = Translations()
        var asked: [(Int, Int)] = []
        var saved: [Molago.LibraryItem] = []

        translations.start(item(lines: 450),
                           translate: { _, from, to in
                               asked.append((from, to))
                               return (from..<to).map { "en \($0)" }
                           },
                           save: { saved.append($0) })
        await settle(translations) { translations.job(for: "zC4aRaHI-yw")?.isRunning == false }

        XCTAssertEqual(asked.map(\.0), [0, 200, 400], "par tranches, pas d'un bloc")
        XCTAssertEqual(saved.count, 3, "chaque tranche revenue est écrite")
        XCTAssertEqual(saved.last?.text.sentences.map(\.en).last, "en 449")
        XCTAssertEqual(translations.job(for: "zC4aRaHI-yw"), .init(done: 450, total: 450, failed: false))
    }

    func testItResumesWhereAPreviousRunStopped() async {
        let translations = Translations()
        var asked: [(Int, Int)] = []
        var already = Array(repeating: "", count: 300)
        for i in 0..<200 { already[i] = "en \(i)" }

        translations.start(item(lines: 300, english: already),
                           translate: { _, from, to in
                               asked.append((from, to))
                               return (from..<to).map { "en \($0)" }
                           },
                           save: { _ in })
        await settle(translations) { translations.job(for: "zC4aRaHI-yw")?.isRunning == false }

        XCTAssertEqual(asked.map(\.0), [200], "les deux cents premières ne se repayent pas")
    }

    func testAFailedSliceStopsThereAndKeepsWhatCameBefore() async {
        enum Failure: Error { case down }
        let translations = Translations()
        var saved: [Molago.LibraryItem] = []

        translations.start(item(lines: 450),
                           translate: { _, from, to in
                               if from >= 200 { throw Failure.down }
                               return (from..<to).map { "en \($0)" }
                           },
                           save: { saved.append($0) })
        await settle(translations) { translations.job(for: "zC4aRaHI-yw")?.isRunning == false }

        let job = translations.job(for: "zC4aRaHI-yw")
        XCTAssertEqual(job?.done, 200)
        XCTAssertEqual(job?.failed, true, "le bouton du lecteur doit pouvoir le dire")
        XCTAssertEqual(saved.last?.text.sentences.first?.en, "en 0", "la première tranche est gardée")
    }

    func testAnImportAlreadyTranslatedAsksNothing() async {
        let translations = Translations()
        translations.start(item(lines: 3, english: ["a", "b", "c"]),
                           translate: { _, _, _ in XCTFail("rien à traduire"); return [] },
                           save: { _ in XCTFail("rien à réécrire") })

        XCTAssertEqual(translations.job(for: "zC4aRaHI-yw"), .init(done: 3, total: 3, failed: false))
    }
}
