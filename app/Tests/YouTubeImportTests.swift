import XCTest
@testable import Molago

final class YouTubeImportTests: XCTestCase {
    func testOnlyYouTubeVideoLinksAreAccepted() throws {
        XCTAssertEqual(
            try YouTubeImport.videoID(from: "https://youtu.be/zC4aRaHI-yw?si=test"),
            "zC4aRaHI-yw"
        )
        XCTAssertThrowsError(try YouTubeImport.videoID(from: "https://example.com/watch?v=zC4aRaHI-yw"))
        XCTAssertThrowsError(try YouTubeImport.videoID(from: "https://www.youtube.com/@channel"))
    }

    func testTheAPIReplyDecodesIntoAVideo() throws {
        let reply = Data("""
        {"videoID":"zC4aRaHI-yw","title":"항공사 뉴스","channel":"Didi","duration":253,
         "thumbnail":"https://i.ytimg.com/test.jpg",
         "sourceURL":"https://www.youtube.com/watch?v=zC4aRaHI-yw",
         "cues":[{"start":18.8,"end":19.8,"ko":"마일리지 전환은 어떻게?"}]}
        """.utf8)

        let video = try JSONDecoder().decode(YouTubeImport.Video.self, from: reply)

        XCTAssertEqual(video.videoID, "zC4aRaHI-yw")
        XCTAssertEqual(video.duration, 253)
        XCTAssertEqual(video.cues.map(\.text), ["마일리지 전환은 어떻게?"])
        XCTAssertEqual(video.cues[0].start, 18.8)
        XCTAssertEqual(video.cues[0].end, 19.8)
    }

    func testAVideoWithoutCuesStillDecodes() throws {
        let reply = Data("""
        {"videoID":"zC4aRaHI-yw","title":"YouTube video","channel":"YouTube","duration":0,
         "thumbnail":null,"sourceURL":"https://www.youtube.com/watch?v=zC4aRaHI-yw","cues":[]}
        """.utf8)

        let video = try JSONDecoder().decode(YouTubeImport.Video.self, from: reply)

        XCTAssertTrue(video.cues.isEmpty)
        XCTAssertNil(video.thumbnail)
    }

    func testTimedKoreanCuesBecomeTheExistingLibraryFormat() throws {
        let video = YouTubeImport.Video(
            videoID: "zC4aRaHI-yw",
            title: "항공사 뉴스",
            channel: "Didi",
            duration: 120,
            thumbnail: "https://i.ytimg.com/test.jpg",
            sourceURL: "https://www.youtube.com/watch?v=zC4aRaHI-yw",
            cues: [
                .init(text: "안녕하세요 여러분", start: 1.25, end: 3.5),
                .init(text: "오늘의 뉴스입니다", start: 3.5, end: 6.0),
            ]
        )
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-17T01:00:00Z"))

        let item = try YouTubeImport.item(
            from: video,
            translations: ["Hello everyone", "Here is today’s news"],
            now: now
        )

        XCTAssertEqual(item.date, "2026-08-17")
        XCTAssertEqual(item.text.slot, "youtube-zC4aRaHI-yw")
        XCTAssertEqual(item.text.title, "항공사 뉴스")
        XCTAssertEqual(item.text.sourceName, "Didi")
        XCTAssertEqual(item.text.sentences.map(\.en), ["Hello everyone", "Here is today’s news"])
        XCTAssertEqual(item.text.sentences[0].start, 1.25)
        XCTAssertEqual(item.text.sentences[0].end, 3.5)
        XCTAssertEqual(item.text.sentences[0].words?.map(\.w), ["안녕하세요", "여러분"])
    }

    func testVideoWithoutTranscriptStillBecomesAWatchableLibraryItem() throws {
        let video = YouTubeImport.Video(
            videoID: "zC4aRaHI-yw", title: "YouTube video", channel: "YouTube",
            duration: 0, thumbnail: nil,
            sourceURL: "https://www.youtube.com/watch?v=zC4aRaHI-yw", cues: []
        )

        let item = try YouTubeImport.item(from: video, translations: [], now: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(item.text.videoID, "zC4aRaHI-yw")
        XCTAssertTrue(item.text.sentences.isEmpty)
    }
}
