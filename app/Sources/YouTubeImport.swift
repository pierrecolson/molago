import Foundation

// L'app ne connaît qu'une adresse : `POST /u/<id>/transcript`. Quel fournisseur
// lit les sous-titres derrière — Supadata aujourd'hui — ne la regarde pas, et
// en changer ne demandera pas une nouvelle version sur l'App Store.
//
// Les deux tentatives précédentes ont échoué pour la même raison, à deux
// endroits : lire les sous-titres soi-même. `yt-dlp` sur le VPS reçoit « Sign
// in to confirm you're not a bot » (adresse de centre de données), et
// swift-youtube-metadata sur l'iPhone interrogeait `timedtext` à nu, la surface
// exacte que YouTube a durcie.
enum YouTubeImport {
    struct Cue: Sendable, Decodable {
        let text: String
        let start: Double
        let end: Double

        private enum CodingKeys: String, CodingKey {
            case text = "ko", start, end
        }
    }

    struct Video: Sendable, Decodable {
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
        case unavailable
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
        // L'URL est validée ici, avant tout accès réseau : un lien qui n'est pas
        // une vidéo YouTube ne dépense jamais un crédit chez le fournisseur.
        _ = try videoID(from: pasted)

        var request = URLRequest(url: Config.baseURL.appending(path: "transcript"))
        // Plus long que la bibliothèque : le serveur attend deux fournisseurs,
        // et un transcript d'une heure met plus de temps qu'une liste.
        request.timeoutInterval = 60
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(["url": pasted.trimmingCharacters(in: .whitespacesAndNewlines)])

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status != 400 else { throw ImportError.invalidURL }
        guard status == 200 else { throw ImportError.unavailable }
        return try JSONDecoder().decode(Video.self, from: data)
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
