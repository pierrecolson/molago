import XCTest
@testable import Molago

/// L'import d'une vidéo, vu du flux.
///
/// Il ne fait plus qu'une chose : chercher les sous-titres, ranger la vidéo, et
/// la rendre à l'app qui l'ouvre. L'anglais est le travail de `Translations`,
/// et il ne doit jamais pouvoir coûter l'import.
@MainActor
final class CaptureFlowTests: XCTestCase {
    private func video(cues: Int) -> YouTubeImport.Video {
        YouTubeImport.Video(
            videoID: "zC4aRaHI-yw",
            title: "항공사 뉴스",
            channel: "Didi",
            duration: 120,
            thumbnail: nil,
            sourceURL: "https://www.youtube.com/watch?v=zC4aRaHI-yw",
            cues: (0..<cues).map { .init(text: "줄 \($0)", start: Double($0), end: Double($0) + 1) }
        )
    }

    /// La récupération n'est pas structurée : on laisse le flux arriver au bout.
    private func settle(_ flow: CaptureFlow, opened: () -> Bool) async {
        for _ in 0..<2000 {
            if opened() { return }
            if case .nothing = flow.step { return }
            await Task.yield()
        }
    }

    func testAVideoIsFiledOnItsCaptionsAloneAndHandedBackToBeOpened() async {
        let flow = CaptureFlow()
        var saved: Molago.LibraryItem?
        var opened: Molago.LibraryItem?
        flow.begin("  https://youtu.be/zC4aRaHI-yw  ",
                   fetch: { _ in self.video(cues: 3) },
                   save: { saved = $0 },
                   opened: { opened = $0 })
        await settle(flow) { opened != nil }

        XCTAssertEqual(saved?.text.sentences.map(\.ko), ["줄 0", "줄 1", "줄 2"])
        XCTAssertEqual(saved?.text.sentences.map(\.en), ["", "", ""], "le coréen seul suffit à ranger")
        XCTAssertEqual(opened?.text.slot, "youtube-zC4aRaHI-yw")
        guard case .choosing = flow.step else { return XCTFail("l'écran se remet à zéro : \(flow.step)") }
    }

    func testAnUnreachableServiceSaysSoRatherThanSpin() async {
        let flow = CaptureFlow()
        flow.begin("https://youtu.be/zC4aRaHI-yw",
                   fetch: { _ in throw YouTubeImport.ImportError.unavailable },
                   save: { _ in XCTFail("rien à ranger") },
                   opened: { _ in XCTFail("rien à ouvrir") })
        await settle(flow) { false }

        guard case .nothing(let message) = flow.step else { return XCTFail("attendu une erreur : \(flow.step)") }
        XCTAssertTrue(message.contains("transcript service"))
    }

    func testALinkThatIsNotAVideoNeverReachesTheServer() async {
        let flow = CaptureFlow()
        flow.begin("https://example.com/watch?v=zC4aRaHI-yw",
                   fetch: { _ in throw YouTubeImport.ImportError.invalidURL },
                   save: { _ in XCTFail("rien à ranger") },
                   opened: { _ in XCTFail("rien à ouvrir") })
        await settle(flow) { false }

        guard case .nothing(let message) = flow.step else { return XCTFail("attendu une erreur : \(flow.step)") }
        XCTAssertEqual(message, "Paste a YouTube video link.")
    }

    func testAVideoWithoutCaptionsIsStillFiledAndOpened() async {
        let flow = CaptureFlow()
        var opened: Molago.LibraryItem?
        flow.begin("https://youtu.be/zC4aRaHI-yw",
                   fetch: { _ in self.video(cues: 0) },
                   save: { _ in },
                   opened: { opened = $0 })
        await settle(flow) { opened != nil }

        XCTAssertEqual(opened?.text.sentences.count, 0, "une vidéo sans transcript reste regardable")
    }
}
