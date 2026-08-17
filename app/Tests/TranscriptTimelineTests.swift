import XCTest
@testable import Molago

final class TranscriptTimelineTests: XCTestCase {
    @MainActor
    func testPlayerKeepsAnExplicitOfflineStateUntilTheNetworkReturns() {
        let model = YouTubePlayerModel()

        model.networkChanged(isConnected: false)
        XCTAssertEqual(model.state, .offline)

        model.networkChanged(isConnected: true)
        XCTAssertEqual(model.state, .loading)
    }

    @MainActor
    func testPlayerDistinguishesMissingVideosFromEmbedRestrictions() {
        let model = YouTubePlayerModel()

        model.receive(["type": "error", "value": 100])
        XCTAssertEqual(model.state, .unavailable)

        model.receive(["type": "error", "value": 153])
        XCTAssertEqual(model.state, .blocked)
    }

    @MainActor
    func testWordCardReturnsToPlaybackOnlyWhenTheVideoWasPlaying() {
        let playing = YouTubePlayerModel()
        playing.receive(["type": "ready", "value": 0])
        playing.receive(["type": "state", "value": 1])

        playing.pauseForWordCard()
        XCTAssertFalse(playing.isPlaying)
        playing.resumeAfterWordCard()
        XCTAssertTrue(playing.isPlaying)

        let paused = YouTubePlayerModel()
        paused.receive(["type": "ready", "value": 0])
        paused.receive(["type": "state", "value": 2])

        paused.pauseForWordCard()
        paused.resumeAfterWordCard()
        XCTAssertFalse(paused.isPlaying)
    }

    @MainActor
    func testPlayerHTMLContainsTheRequestedVideoID() {
        let html = YouTubePlayerView.html(videoID: "abc123")

        XCTAssertTrue(html.contains("videoId:\"abc123\""))
        XCTAssertFalse(html.contains("videoId:(encoded)"))
    }

    func testCueOwnsStartButNotEndAndGapsHaveNoActiveCue() throws {
        let json = """
        {"slot":"youtube-test","universe":"YouTube","title":"Test","minutes":1,"icon":null,"kind":"youtube","videoID":"abc","sentences":[
          {"ko":"하나","en":"One","audio":"cue-1","start":1.0,"end":2.0,"words":null},
          {"ko":"둘","en":"Two","audio":"cue-2","start":3.0,"end":4.0,"words":null}
        ]}
        """
        let text = try JSONDecoder().decode(Day.Text.self, from: Data(json.utf8))

        XCTAssertNil(TranscriptTimeline.index(at: 0.9, in: text.sentences))
        XCTAssertEqual(TranscriptTimeline.index(at: 1.0, in: text.sentences), 0)
        XCTAssertNil(TranscriptTimeline.index(at: 2.5, in: text.sentences))
        XCTAssertEqual(TranscriptTimeline.index(at: 3.9, in: text.sentences), 1)
        XCTAssertNil(TranscriptTimeline.index(at: 4.0, in: text.sentences))
    }
}
