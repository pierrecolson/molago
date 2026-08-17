import SwiftUI
import WebKit
import Observation
import Network

enum TranscriptTimeline {
    static func index(at time: Double, in sentences: [Day.Sentence]) -> Int? {
        var low = 0
        var high = sentences.count
        while low < high {
            let middle = (low + high) / 2
            if (sentences[middle].start ?? .infinity) <= time { low = middle + 1 }
            else { high = middle }
        }
        let candidate = low - 1
        guard sentences.indices.contains(candidate),
              let start = sentences[candidate].start,
              let end = sentences[candidate].end,
              start <= time, time < end
        else { return nil }
        return candidate
    }
}

@Observable
@MainActor
final class YouTubePlayerModel {
    enum State: Equatable {
        case loading
        case ready
        case offline
        case unavailable
        case blocked
    }

    private(set) var state: State = .loading
    private(set) var currentTime: Double = 0
    private(set) var isPlaying = false
    private weak var webView: WKWebView?
    private var pendingTime: Double?
    private var shouldResumeAfterWordCard = false
    private let networkMonitor = NWPathMonitor()

    init(startAt: Double? = nil) {
        pendingTime = startAt
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in self?.networkChanged(isConnected: path.status == .satisfied) }
        }
        networkMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    deinit { networkMonitor.cancel() }

    func attach(_ webView: WKWebView) { self.webView = webView }

    func receive(_ message: Any) {
        guard let payload = message as? [String: Any], let type = payload["type"] as? String else { return }
        switch type {
        case "ready":
            state = .ready
            if let pendingTime { seek(to: pendingTime, autoplay: false) }
        case "time":
            if let value = payload["value"] as? Double { currentTime = value }
            else if let value = payload["value"] as? NSNumber { currentTime = value.doubleValue }
        case "state":
            if let value = payload["value"] as? NSNumber { isPlaying = value.intValue == 1 }
            else if let value = payload["value"] as? Int { isPlaying = value == 1 }
        case "error":
            let code = (payload["value"] as? NSNumber)?.intValue
            state = [101, 150, 152, 153].contains(code) ? .blocked : .unavailable
        default:
            break
        }
    }

    func failed(_ error: Error) {
        if let urlError = error as? URLError,
           [.notConnectedToInternet, .networkConnectionLost, .timedOut].contains(urlError.code) {
            state = .offline
        } else {
            state = .unavailable
        }
    }

    func networkChanged(isConnected: Bool) {
        if !isConnected {
            state = .offline
        } else if state == .offline {
            retry()
        }
    }

    func seek(to time: Double, autoplay: Bool = true) {
        let time = max(0, time)
        pendingTime = time
        currentTime = time
        guard state == .ready else { return }
        let play = autoplay ? "player.playVideo();" : ""
        if autoplay { isPlaying = true }
        webView?.evaluateJavaScript("player.seekTo(\(time), true);\(play)")
    }

    func skip(by seconds: Double) {
        seek(to: currentTime + seconds, autoplay: isPlaying)
    }

    func toggle() {
        if isPlaying {
            pause()
        } else {
            guard state == .ready else { return }
            isPlaying = true
            webView?.evaluateJavaScript("player.playVideo();")
        }
    }

    func pause() {
        isPlaying = false
        webView?.evaluateJavaScript("player.pauseVideo();")
    }

    func pauseForWordCard() {
        shouldResumeAfterWordCard = isPlaying
        pause()
    }

    func resumeAfterWordCard() {
        guard shouldResumeAfterWordCard, state == .ready else { return }
        shouldResumeAfterWordCard = false
        isPlaying = true
        webView?.evaluateJavaScript("player.playVideo();")
    }

    func retry() {
        state = .loading
        webView?.reload()
    }
}

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    let model: YouTubePlayerModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "molago")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.allowsInlineMediaPlayback = true

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.scrollView.isScrollEnabled = false
        view.isOpaque = false
        model.attach(view)
        view.loadHTMLString(Self.html(videoID: videoID), baseURL: URL(string: "https://com.molago.app"))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "molago")
    }

    static func html(videoID: String) -> String {
        let encoded = (try? JSONEncoder().encode(videoID)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body,#player{margin:0;width:100%;height:100%;background:#111;overflow:hidden}</style></head>
        <body><div id="player"></div><script>
        var player;
        function send(type,value){window.webkit.messageHandlers.molago.postMessage({type:type,value:value});}
        function onYouTubeIframeAPIReady(){
          player=new YT.Player('player',{videoId:\(encoded),playerVars:{playsinline:1,rel:0},events:{
            onReady:function(){send('ready',0);},
            onStateChange:function(event){send('state',event.data);},
            onError:function(event){send('error',event.data);}
          }});
        }
        var tag=document.createElement('script');tag.src='https://www.youtube.com/iframe_api';document.head.appendChild(tag);
        setInterval(function(){if(player&&player.getCurrentTime){send('time',player.getCurrentTime());}},300);
        </script></body></html>
        """
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let model: YouTubePlayerModel
        init(model: YouTubePlayerModel) { self.model = model }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            Task { @MainActor in model.receive(message.body) }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in model.failed(error) }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in model.failed(error) }
        }
    }
}
