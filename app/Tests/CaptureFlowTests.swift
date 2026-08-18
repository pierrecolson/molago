import XCTest
@testable import Molago

/// L'import d'une vidéo, vu du flux.
///
/// Le test qui compte est le dernier : SwiftUI relance `translationTask` — et
/// annule la tâche en cours — dès que la vue se redessine. C'est ce qui tuait
/// l'import en vol quand le transcript se demandait de là. Ici on rejoue cette
/// relance, et l'import doit reprendre au lieu de mourir.
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

    private func waitForTranslation(_ flow: CaptureFlow) async {
        for _ in 0..<1000 {
            if flow.awaitingTranslation != nil { return }
            if case .nothing = flow.step { return }
            if case .filed = flow.step { return }
            await Task.yield()
        }
    }

    func testAVideoIsFetchedThenTranslatedThenFiled() async {
        let flow = CaptureFlow()
        var saved: Molago.LibraryItem?
        flow.begin("https://youtu.be/zC4aRaHI-yw",
                   fetch: { _ in self.video(cues: 3) },
                   save: { saved = $0 })
        await waitForTranslation(flow)

        await flow.translateAwaiting { lines in lines.map { "en: \($0)" } }

        XCTAssertEqual(saved?.text.sentences.map(\.en), ["en: 줄 0", "en: 줄 1", "en: 줄 2"])
        guard case .filed(let title) = flow.step else { return XCTFail("pas rangé : \(flow.step)") }
        XCTAssertEqual(title, "항공사 뉴스")
    }

    func testAnUnreachableServiceSaysSoRatherThanSpin() async {
        let flow = CaptureFlow()
        flow.begin("https://youtu.be/zC4aRaHI-yw",
                   fetch: { _ in throw YouTubeImport.ImportError.unavailable },
                   save: { _ in })
        await waitForTranslation(flow)

        guard case .nothing(let message) = flow.step else { return XCTFail("attendu une erreur : \(flow.step)") }
        XCTAssertTrue(message.contains("transcript service"))
    }

    /// Le cœur de la correction : une session annulée en cours de route ne perd
    /// que son lot, jamais l'import — et ne retraduit pas ce qui est déjà fait.
    func testARestartedSessionResumesInsteadOfLosingTheImport() async {
        let flow = CaptureFlow()
        var saved: Molago.LibraryItem?
        flow.begin("https://youtu.be/zC4aRaHI-yw",
                   fetch: { _ in self.video(cues: 60) },
                   save: { saved = $0 })
        await waitForTranslation(flow)

        var asked: [String] = []
        var lots = 0
        await flow.translateAwaiting { lines in
            lots += 1
            asked.append(contentsOf: lines)
            // Le premier lot passe ; SwiftUI relance la session pendant le second.
            if lots > 1 { throw CancellationError() }
            return lines.map { "en: \($0)" }
        }
        XCTAssertNil(saved, "rien n'est rangé tant que tout n'est pas traduit")
        XCTAssertEqual(asked.count, 60, "les deux lots ont été demandés, le second coupé")

        asked = []
        await flow.translateAwaiting { lines in
            asked.append(contentsOf: lines)
            return lines.map { "en: \($0)" }
        }
        XCTAssertEqual(asked, (50..<60).map { "줄 \($0)" }, "la relance ne retraduit pas le premier lot")
        XCTAssertEqual(saved?.text.sentences.count, 60)
    }

    func testATranslationFailureExplainsHowToRecoverAndSavesNothing() async {
        enum Failure: Error { case unavailable }
        let flow = CaptureFlow()
        flow.begin("https://youtu.be/zC4aRaHI-yw",
                   fetch: { _ in self.video(cues: 3) },
                   save: { _ in XCTFail("une traduction ratée ne se range pas") })
        await waitForTranslation(flow)

        await flow.translateAwaiting { _ in throw Failure.unavailable }

        guard case .nothing(let message) = flow.step else { return XCTFail("attendu une erreur : \(flow.step)") }
        XCTAssertEqual(
            message,
            "The transcript couldn’t be translated. Download Korean and English in Settings, then try again."
        )
    }

    /// L'écran d'attente lit ces deux-là à son rythme : la fenêtre de lignes
    /// suit le front de traduction, et « Stop » ne laisse rien derrière.
    func testTheVisibleLinesFollowTheTranslationAndStopLeavesNothing() async {
        let flow = CaptureFlow()
        flow.begin("https://youtu.be/zC4aRaHI-yw",
                   fetch: { _ in self.video(cues: 60) },
                   save: { _ in XCTFail("un import arrêté ne se range pas") })
        await waitForTranslation(flow)

        XCTAssertEqual(flow.visibleLines.map(\.id), [0, 1])
        XCTAssertTrue(flow.visibleLines.allSatisfy { $0.en == nil })

        var lots = 0
        await flow.translateAwaiting { lines in
            lots += 1
            if lots > 1 { throw CancellationError() }
            return lines.map { "en: \($0)" }
        }

        XCTAssertEqual(flow.visibleLines.map(\.id), Array(44...51), "les six dernières faites, et les deux qui viennent")
        XCTAssertEqual(flow.visibleLines.first?.en, "en: 줄 44")
        XCTAssertNil(flow.visibleLines.last?.en)
        XCTAssertEqual(flow.translationProgress.done, 50)

        flow.stop()
        XCTAssertNil(flow.awaitingTranslation)
        XCTAssertTrue(flow.visibleLines.isEmpty)
        guard case .choosing = flow.step else { return XCTFail("Stop ramène au choix : \(flow.step)") }
    }

    func testAVideoWithoutCaptionsIsStillFiled() async {
        let flow = CaptureFlow()
        var saved: Molago.LibraryItem?
        flow.begin("https://youtu.be/zC4aRaHI-yw",
                   fetch: { _ in self.video(cues: 0) },
                   save: { saved = $0 })
        await waitForTranslation(flow)

        XCTAssertEqual(saved?.text.sentences.count, 0)
        guard case .filed = flow.step else { return XCTFail("pas rangé : \(flow.step)") }
    }
}
