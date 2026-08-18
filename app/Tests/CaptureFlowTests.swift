import XCTest
@testable import Molago

/// L'import d'une vidéo, vu du flux.
///
/// Ce qui compte ici : la vidéo est rangée **dès les sous-titres**, avant tout
/// anglais. Une traduction ratée, coupée ou arrêtée ne doit donc jamais laisser
/// la bibliothèque vide — c'est la leçon des deux essais précédents, où huit
/// minutes de traduction sur l'appareil pouvaient partir en fumée d'un coup.
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
    private func settle(_ flow: CaptureFlow) async {
        for _ in 0..<2000 {
            switch flow.step {
            case .filed, .nothing, .choosing: return
            default: await Task.yield()
            }
        }
    }

    func testTheVideoIsFiledOnItsCaptionsThenAgainWithItsEnglish() async {
        let flow = CaptureFlow()
        var saved: [Molago.LibraryItem] = []
        flow.begin("https://youtu.be/zC4aRaHI-yw",
                   fetch: { _ in self.video(cues: 3) },
                   translate: { _, from, to in (from..<to).map { "en \($0)" } },
                   save: { saved.append($0) })
        await settle(flow)

        XCTAssertGreaterThanOrEqual(saved.count, 2, "rangée une fois sans anglais, puis avec")
        XCTAssertEqual(saved.first?.text.sentences.map(\.en), ["", "", ""], "le coréen seul suffit à ranger")
        XCTAssertEqual(saved.last?.text.sentences.map(\.en), ["en 0", "en 1", "en 2"])
        XCTAssertEqual(saved.last?.text.sentences.map(\.ko), ["줄 0", "줄 1", "줄 2"])
        guard case .filed(let title, let note) = flow.step else { return XCTFail("pas rangé : \(flow.step)") }
        XCTAssertEqual(title, "항공사 뉴스")
        XCTAssertNil(note)
    }

    func testALongTranscriptIsTranslatedInSlicesAndProgressFollows() async {
        let flow = CaptureFlow()
        var asked: [(Int, Int)] = []
        flow.begin("https://youtu.be/zC4aRaHI-yw",
                   fetch: { _ in self.video(cues: 450) },
                   translate: { _, from, to in
                       asked.append((from, to))
                       return (from..<to).map { "en \($0)" }
                   },
                   save: { _ in })
        await settle(flow)

        XCTAssertEqual(asked.map(\.0), [0, 200, 400], "des tranches, pas un bloc")
        XCTAssertEqual(asked.map(\.1), [200, 400, 450])
        XCTAssertEqual(flow.progress.done, 450)
        XCTAssertEqual(flow.progress.total, 450)
    }

    func testAFailedTranslationStillLeavesAWatchableVideoBehind() async {
        enum Failure: Error { case unavailable }
        let flow = CaptureFlow()
        var saved: [Molago.LibraryItem] = []
        flow.begin("https://youtu.be/zC4aRaHI-yw",
                   fetch: { _ in self.video(cues: 3) },
                   translate: { _, _, _ in throw Failure.unavailable },
                   save: { saved.append($0) })
        await settle(flow)

        XCTAssertEqual(saved.last?.text.sentences.map(\.ko), ["줄 0", "줄 1", "줄 2"], "la vidéo reste")
        guard case .filed(_, let note) = flow.step else { return XCTFail("attendu rangée quand même : \(flow.step)") }
        XCTAssertEqual(note, "The English is still missing. Import it again later to finish it.")
    }

    func testStoppingKeepsWhatIsAlreadyThereAndReturnsToTheChoice() async {
        let flow = CaptureFlow()
        var saved: [Molago.LibraryItem] = []
        flow.begin("https://youtu.be/zC4aRaHI-yw",
                   fetch: { _ in self.video(cues: 450) },
                   translate: { [weak flow] _, from, to in
                       // Arrêté juste après la première tranche.
                       if from > 0 { XCTFail("la boucle continue après Stop") }
                       defer { flow?.stop() }
                       return (from..<to).map { "en \($0)" }
                   },
                   save: { saved.append($0) })
        await settle(flow)

        guard case .choosing = flow.step else { return XCTFail("Stop ramène au choix : \(flow.step)") }
        XCTAssertEqual(saved.first?.text.sentences.count, 450, "rangée dès les sous-titres")
    }

    func testAnUnreachableServiceSaysSoRatherThanSpin() async {
        let flow = CaptureFlow()
        flow.begin("https://youtu.be/zC4aRaHI-yw",
                   fetch: { _ in throw YouTubeImport.ImportError.unavailable },
                   translate: { _, _, _ in [] },
                   save: { _ in })
        await settle(flow)

        guard case .nothing(let message) = flow.step else { return XCTFail("attendu une erreur : \(flow.step)") }
        XCTAssertTrue(message.contains("transcript service"))
    }

    func testAVideoWithoutCaptionsIsStillFiled() async {
        let flow = CaptureFlow()
        var saved: Molago.LibraryItem?
        flow.begin("https://youtu.be/zC4aRaHI-yw",
                   fetch: { _ in self.video(cues: 0) },
                   translate: { _, _, _ in XCTFail("rien à traduire"); return [] },
                   save: { saved = $0 })
        await settle(flow)

        XCTAssertEqual(saved?.text.sentences.count, 0)
        guard case .filed = flow.step else { return XCTFail("pas rangé : \(flow.step)") }
    }
}
