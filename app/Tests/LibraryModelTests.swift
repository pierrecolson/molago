import XCTest
@testable import Molago

final class LibraryModelTests: XCTestCase {
    func testVideoImportDecodesTimedTranscript() throws {
        let item = try decodeItem(slot: "youtube-42M_DVvzye8", importedAt: "2026-08-17T01:00:00Z", extra: """
        ,"kind":"youtube","videoID":"42M_DVvzye8","sourceName":"Didi","thumbnail":"https://i.ytimg.com/test.jpg","durationSeconds":120
        """)

        XCTAssertTrue(item.text.isYouTube)
        XCTAssertEqual(item.text.videoID, "42M_DVvzye8")
        XCTAssertEqual(item.text.sentences[0].start, 6.214)
        XCTAssertEqual(item.text.sentences[0].en, "Hello")
    }

    func testThreeLatestImportsAreRecentRegardlessOfDate() throws {
        let items = try [
            decodeItem(slot: "capture-4", importedAt: "2026-08-17T04:00:00Z"),
            decodeItem(slot: "youtube-3", importedAt: "2026-08-02T03:00:00Z"),
            decodeItem(slot: "capture-2", importedAt: "2026-07-15T02:00:00Z"),
            decodeItem(slot: "youtube-1", importedAt: "2026-06-01T01:00:00Z"),
        ]

        let sections = LibrarySections.split(items)

        XCTAssertEqual(sections.recent.map(\.text.slot), ["capture-4", "youtube-3", "capture-2"])
        XCTAssertEqual(sections.older.map(\.text.slot), ["youtube-1"])
    }

    func testKeptWordRetainsVideoTimestamp() {
        let word = KeptWord(
            lemma: "관계", meaning: "relationship", pos: "noun", icon: nil,
            context: "좋은 관계를 만들어요.", contextAudio: nil, hanja: nil,
            root: nil, family: nil, slot: "youtube-42M_DVvzye8",
            sourceTitle: "A Korean video", sourceDate: "2026-08-17", sourceTime: 6.214
        )

        XCTAssertEqual(word.sourceTime, 6.214)
    }

    func testKeptWordStoresEnrichmentAndUsesTheExactSharedHanjaRoot() {
        let enrichment = Day.Word(
            w: "관리비", lemma: "관리비", pos: "noun", en: "maintenance fee",
            hanja: "管理費", literal: "management expense",
            morphemes: [
                .init(k: "관", h: "管", e: "to oversee"),
                .init(k: "리", h: "理", e: "to organize"),
                .init(k: "비", h: "費", e: "fee, expense"),
            ],
            root: "fee, expense",
            family: [
                .init(k: "학비", h: "學費", e: "tuition fees"),
                .init(k: "교통비", h: "交通費", e: "transport costs"),
            ]
        )
        let kept = KeptWord(
            lemma: "관리비", meaning: "maintenance fee", pos: "noun", icon: nil,
            context: "관리비가 올랐어요.", contextAudio: nil, hanja: nil,
            root: nil, family: nil, slot: "capture-test"
        )

        kept.applyEnrichment(enrichment)

        XCTAssertEqual(kept.literal, "management expense")
        XCTAssertEqual(kept.morphemes?.map(\.h), ["管", "理", "費"])
        XCTAssertEqual(WordRoots.shared(in: enrichment)?.korean, "비")
        XCTAssertEqual(WordRoots.shared(in: enrichment)?.hanja, "費")
    }

    func testTranscriptWordRemainsSelectableBeforeItsDefinitionIsLoaded() {
        XCTAssertTrue(Day.Word(w: "오신").isTappable)
    }

    @MainActor
    func testVideoSkipMovesRelativeToPlaybackAndStopsAtTheBeginning() {
        let player = YouTubePlayerModel()
        player.receive(["type": "time", "value": 6.0])

        player.skip(by: 10)
        XCTAssertEqual(player.currentTime, 16)

        player.skip(by: -20)
        XCTAssertEqual(player.currentTime, 0)
    }

    func testWordLookupRequestIncludesTheSelectedWordAndItsSentence() throws {
        let request = try WordLookup.request(for: "오신", context: "오신 여러분 환영합니다.")
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(request.url?.lastPathComponent, "gloss")
        XCTAssertEqual(json["tokens"] as? [String], ["오신"])
        XCTAssertEqual(json["context"] as? String, "오신 여러분 환영합니다.")
        XCTAssertEqual(json["enrich"] as? Bool, true)
    }

    func testWordLookupDecodesRootsAndFamilyForTheSelectedWord() throws {
        let data = Data(#"{"words":[{"index":0,"surface":"관리비","lemma":"관리비","pos":"noun","en":"maintenance fee","hanja":"管理費","literal":"management expense","morphemes":[{"k":"관","h":"管","e":"to oversee"},{"k":"리","h":"理","e":"to organize"},{"k":"비","h":"費","e":"fee, expense"}],"root":"fee, expense","family":[{"k":"학비","h":"學費","e":"tuition fees"}]}]}"#.utf8)

        let word = try WordLookup.decode(data, surface: "관리비")

        XCTAssertEqual(word.hanja, "管理費")
        XCTAssertEqual(word.literal, "management expense")
        XCTAssertEqual(word.morphemes?.map(\.k), ["관", "리", "비"])
        XCTAssertEqual(word.root, "fee, expense")
        XCTAssertEqual(word.family?.first?.k, "학비")
    }

    private func decodeItem(slot: String, importedAt: String, extra: String = "") throws -> Molago.LibraryItem {
        let json = """
        {"date":"2026-08-17","text":{"slot":"\(slot)","universe":"Capture","title":"Test","minutes":2,"icon":null,"importedAt":"\(importedAt)"\(extra),"sentences":[{"ko":"안녕하세요","en":"Hello","audio":"cue-1","start":6.214,"end":10.301,"words":null}]}}
        """
        return try JSONDecoder().decode(Molago.LibraryItem.self, from: Data(json.utf8))
    }
}
