import SwiftUI
import SwiftData
import PhotosUI
import Vision

/// La capture : photographier, voir, toucher.
///
/// C'est la boucle qui distingue Molago d'un lecteur. Un mot attrapé sur une
/// facture mardi devient le sujet de mercredi (spec §8.2) — sans elle, le
/// troisième texte tourne indéfiniment sur un fonds de situations inventées.
///
/// L'écran montre **la photo elle-même**, avec les mots qui valent la peine
/// surlignés là où ils sont. C'est ce que la spec §5.7 décrivait — « le texte
/// extrait s'affiche avec les mots inconnus surlignés » — et ce qui la rend
/// utile avant même d'apprendre : trois secondes pour voir ce qui bloque sur un
/// papier administratif.
///
/// L'OCR est natif (Vision, coréen depuis iOS 16) : gratuit, hors ligne,
/// instantané. Sa seule faiblesse est le manuscrit.
@Observable
@MainActor
final class CaptureFlow {
    enum Step {
        case choosing
        case reading
        case marked(UIImage, [Word])
        case nothing(String)
    }

    /// Un mot vu par l'OCR, avec sa place dans l'image et son sens.
    struct Word: Identifiable, Hashable {
        let surface: String
        let lemma: String
        let pos: String
        let en: String
        /// La ligne entière où il a été lu. C'est ce qui deviendra sa phrase au
        /// carnet — un mot sans son contexte redevient une liste de vocabulaire.
        let line: String
        /// Rectangle normalisé, origine en haut à gauche — comme une vue.
        let box: CGRect
        var id: String { "\(lemma)-\(box.minX)-\(box.minY)" }
    }

    private(set) var step: Step = .choosing

    func reset() { step = .choosing }

    func read(_ photo: UIImage) async {
        step = .reading

        // Une photo prise à l'iPhone est stockée telle que le capteur l'a vue,
        // avec une consigne de rotation à part. Vision travaille sur les pixels
        // bruts : sans redressement, les rectangles tombent à côté des mots.
        let image = photo.upright
        let seen = await Self.recognise(image)
        guard !seen.isEmpty else {
            step = .nothing("No Korean text found in that photo.")
            return
        }

        do {
            let glossed = try await Self.gloss(seen)
            guard !glossed.isEmpty else {
                step = .nothing("Nothing worth keeping in there.")
                return
            }
            step = .marked(image, glossed)
        } catch {
            step = .nothing("Couldn't look those words up. Try again in a moment.")
        }
    }

    // ── lecture de l'image ───────────────────────────────────────────────────

    private struct Seen {
        let text: String
        let line: String
        let box: CGRect
    }

    /// `nonisolated` volontairement : le gestionnaire de Vision s'exécute sur une
    /// file d'arrière-plan, et reprendre depuis là une continuation isolée au
    /// main actor arrête l'app — Swift 6 vérifie l'isolation à l'exécution. Rien
    /// ici ne touche à l'état de la classe.
    private nonisolated static func recognise(_ image: UIImage) async -> [Seen] {
        guard let cg = image.cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                var out: [Seen] = []
                for observation in request.results as? [VNRecognizedTextObservation] ?? [] {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    let line = candidate.string
                    // Chaque mot séparément : c'est le mot qu'on veut pouvoir
                    // toucher, pas la ligne entière.
                    for range in line.tokenRanges {
                        let token = String(line[range])
                        guard token.contains(where: { $0.isHangul }) else { continue }
                        guard let piece = try? candidate.boundingBox(for: range) else { continue }
                        out.append(Seen(text: token, line: line, box: piece.boundingBox.flippedToViewSpace))
                    }
                }
                continuation.resume(returning: out)
            }
            request.recognitionLanguages = ["ko-KR", "en-US"]
            request.recognitionLevel = .accurate
            // Le coréen d'une facture n'est pas de la prose : la correction
            // automatique y fait plus de mal que de bien.
            request.usesLanguageCorrection = false

            DispatchQueue.global(qos: .userInitiated).async {
                try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
            }
        }
    }

    // ── le sens, tout de suite ───────────────────────────────────────────────

    /// La spec §5.7 est explicite : « on capture souvent parce qu'on a besoin de
    /// comprendre **maintenant**, devant sa facture. »
    ///
    /// Les mots partent numérotés et reviennent numérotés : c'est ce qui garde
    /// le sens aligné sur le rectangle à surligner. Un appariement par forme se
    /// casserait dès qu'un mot apparaît deux fois sur la photo.
    private static func gloss(_ seen: [Seen]) async throws -> [Word] {
        var request = URLRequest(url: Config.baseURL.appending(path: "gloss"))
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(["tokens": seen.map(\.text)])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }

        struct Reply: Decodable {
            struct Word: Decodable {
                let index: Int
                let surface: String
                let lemma: String
                let pos: String
                let en: String
            }
            let words: [Word]
        }
        return try JSONDecoder().decode(Reply.self, from: data).words
            .filter { seen.indices.contains($0.index) }
            .map {
                Word(surface: $0.surface, lemma: $0.lemma, pos: $0.pos, en: $0.en,
                     line: seen[$0.index].line, box: seen[$0.index].box)
            }
    }

    /// Remonte au serveur ce qui a été gardé, pour que la fabrique de la nuit
    /// suivante en fasse le troisième texte. Sans `throws` : un envoi raté ne
    /// doit pas empêcher le mot d'entrer au carnet — il y est déjà.
    static func report(_ kept: [Word]) async {
        guard !kept.isEmpty else { return }
        struct Payload: Encodable {
            struct Word: Encodable { let lemma: String; let en: String; let context: String }
            let words: [Word]
        }
        let payload = Payload(words: kept.map { .init(lemma: $0.lemma, en: $0.en, context: $0.line) })
        var request = URLRequest(url: Config.baseURL.appending(path: "captures"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try? JSONEncoder().encode(payload)
        _ = try? await URLSession.shared.data(for: request)
    }
}

// ── conversions ──────────────────────────────────────────────────────────────

private extension Character {
    var isHangul: Bool { unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) } }
}

private extension String {
    /// Les plages des mots, séparés par des espaces. Vision veut des plages
    /// dans la chaîne d'origine pour rendre la boîte d'un morceau de ligne.
    var tokenRanges: [Range<String.Index>] {
        var out: [Range<String.Index>] = []
        var i = startIndex
        while i < endIndex {
            while i < endIndex, self[i].isWhitespace { i = index(after: i) }
            guard i < endIndex else { break }
            var j = i
            while j < endIndex, !self[j].isWhitespace { j = index(after: j) }
            out.append(i..<j)
            i = j
        }
        return out
    }
}

private extension UIImage {
    /// La même image, pixels déjà tournés dans le bon sens.
    var upright: UIImage {
        guard imageOrientation != .up else { return self }
        return UIGraphicsImageRenderer(size: size).image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }
}

private extension CGRect {
    /// Vision compte depuis le bas à gauche, une vue depuis le haut à gauche.
    var flippedToViewSpace: CGRect {
        CGRect(x: minX, y: 1 - minY - height, width: width, height: height)
    }
}
