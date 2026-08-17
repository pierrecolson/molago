import Foundation
import YouTubeTranscript

enum YouTubeImport {
    struct Cue: Sendable {
        let text: String
        let start: Double
        let end: Double
    }

    struct Video: Sendable {
        let videoID: String
        let title: String
        let channel: String
        let duration: Int
        let thumbnail: String?
        let sourceURL: String
        let cues: [Cue]
    }

    enum ImportError: Error {
        case invalidURL
        case translationCount
    }

    static func videoID(from pasted: String) throws -> String {
        let value = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            throw ImportError.invalidURL
        }
        let host = (url.host ?? "").lowercased()
        let id: String?
        switch host {
        case "youtu.be":
            id = url.pathComponents.dropFirst().first
        case "youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com":
            if let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "v" })?.value {
                id = query
            } else if ["shorts", "live", "embed"].contains(url.pathComponents.dropFirst().first) {
                id = url.pathComponents.dropFirst(2).first
            } else {
                id = nil
            }
        default:
            id = nil
        }
        guard let id, id.range(of: #"^[A-Za-z0-9_-]{11}$"#, options: .regularExpression) != nil else {
            throw ImportError.invalidURL
        }
        return id
    }

    static func fetch(_ pasted: String) async throws -> Video {
        let id = try videoID(from: pasted)
        do {
            let transcript = try await YouTubeTranscript.fetch(pasted, languages: ["ko"])
            let metadata = transcript.video
            return Video(
                videoID: id,
                title: metadata?.title.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "YouTube video",
                channel: metadata?.author.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "YouTube",
                duration: metadata?.lengthSeconds ?? Int(transcript.duration.rounded()),
                thumbnail: metadata?.thumbnailUrl,
                sourceURL: metadata?.url ?? "https://www.youtube.com/watch?v=\(id)",
                cues: transcript.segments.map { .init(text: $0.text, start: $0.start, end: $0.end) }
            )
        } catch let error as YouTubeTranscriptError {
            switch error {
            case .transcriptsDisabled, .noTranscriptFound, .emptyTranscript:
                return Video(
                    videoID: id, title: "YouTube video", channel: "YouTube", duration: 0,
                    thumbnail: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg",
                    sourceURL: "https://www.youtube.com/watch?v=\(id)", cues: []
                )
            default:
                throw error
            }
        }
    }

    static func item(from video: Video, translations: [String], now: Date = Date()) throws -> LibraryItem {
        guard translations.count == video.cues.count else { throw ImportError.translationCount }

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.string(from: now)
        let importedAt = ISO8601DateFormatter().string(from: now)
        let slot = "youtube-\(video.videoID)"

        return LibraryItem(
            date: date,
            text: Day.Text(
                slot: slot,
                universe: "YouTube",
                title: String(video.title.prefix(120)),
                minutes: max(1, Int((Double(video.duration) / 60).rounded())),
                icon: nil,
                kind: "youtube",
                importedAt: importedAt,
                videoID: video.videoID,
                sourceURL: video.sourceURL,
                sourceName: video.channel,
                thumbnail: video.thumbnail,
                durationSeconds: video.duration,
                sentences: video.cues.enumerated().map { index, cue in
                    Day.Sentence(
                        ko: cue.text,
                        en: translations[index],
                        audio: "\(date)-\(slot)-\(String(format: "%04d", index + 1))",
                        start: cue.start,
                        end: cue.end,
                        words: cue.text.split(whereSeparator: \.isWhitespace).map { Day.Word(w: String($0)) }
                    )
                }
            )
        )
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
