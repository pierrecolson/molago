import SwiftUI
import SwiftData
import PhotosUI
import Vision
import ImageIO

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
        /// La reconnaissance du texte, sur l'appareil. Quelques secondes.
        case reading
        /// La mise en forme, sur le serveur. C'est l'étape longue, et c'est
        /// celle qui vaut l'attente : remettre en ordre, recoller, traduire.
        case filing
        /// Le document est devenu un article, rangé dans la journée.
        case filed(title: String)
        /// Les sous-titres se demandent au serveur. Trois secondes.
        case importingVideo
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
        var id: String { lemma }
    }

    private(set) var step: Step = .choosing

    /// Envoie les lignes lues au serveur, qui en fait un article.
    ///
    /// Les lignes brutes, pas les mots : c'est le serveur qui décide de l'ordre
    /// de lecture, et il lui faut le document entier pour ça. L'app ne
    /// comprend rien à ce qu'elle a photographié, et c'est très bien ainsi.
    private static func file(_ lines: [String]) async throws -> (title: String, slot: String) {
        var request = URLRequest(url: Config.baseURL.appending(path: "document"))
        request.httpMethod = "POST"
        // Long, et volontairement : la mise en forme par le bon modèle prend
        // une bonne minute sur un document dense. C'est le prix d'un texte
        // juste, et on a choisi de l'accepter plutôt que de rendre une bouillie.
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(["lines": lines])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        struct Reply: Decodable { let title: String; let slot: String }
        let reply = try JSONDecoder().decode(Reply.self, from: data)
        return (reply.title, reply.slot)
    }

    // ── l'import d'une vidéo ─────────────────────────────────────────────────
    //
    // Les sous-titres, et c'est tout : trois secondes, la vidéo est rangée et
    // s'ouvre. L'anglais arrive ensuite, par `Translations`, pendant qu'on lit.
    //
    // La traduction a d'abord été tentée sur l'appareil : Apple Translation
    // tenait 0,55 seconde par ligne sur un iPhone 15 Pro Max, mesuré sans
    // démarrage lent — 8 minutes 40 pour une heure de vidéo, écran allumé, app
    // au premier plan, et des lots plus gros font tomber l'app au lieu d'aller
    // plus vite. Elle est repartie au serveur, et surtout : elle n'est plus une
    // attente. Un import interrompu laisse une vidéo regardable, en coréen.

    @ObservationIgnored private var save: (LibraryItem) throws -> Void = { try ImportedLibrary.save($0) }

    func begin(
        _ pasted: String,
        fetch: @escaping (String) async throws -> YouTubeImport.Video = { try await YouTubeImport.fetch($0) },
        save: @escaping (LibraryItem) throws -> Void = { try ImportedLibrary.save($0) },
        opened: @escaping (LibraryItem) -> Void = { _ in }
    ) {
        let value = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        self.save = save
        step = .importingVideo
        Task { await run(value, fetch: fetch, opened: opened) }
    }

    private func run(
        _ value: String,
        fetch: (String) async throws -> YouTubeImport.Video,
        opened: (LibraryItem) -> Void
    ) async {
        let video: YouTubeImport.Video
        do {
            video = try await fetch(value)
        } catch YouTubeImport.ImportError.invalidURL {
            step = .nothing("Paste a YouTube video link.")
            return
        } catch {
            step = .nothing("Molago couldn’t reach the transcript service. Try again in a moment.")
            return
        }

        do {
            // Rangée sans une ligne d'anglais : c'est ce qui permet de l'ouvrir
            // tout de suite, et ce qui fait qu'une traduction ratée ne coûte
            // jamais l'import.
            let item = try YouTubeImport.item(from: video, translations: [])
            try save(item)
            step = .choosing
            opened(item)
        } catch {
            step = .nothing("The video couldn’t be saved. Check that Molago can use iCloud, then try again.")
        }
    }

    func reset() { step = .choosing }

    /// Lit une photo **sans jamais la décoder en entier**.
    ///
    /// C'est ici que l'app se faisait tuer. Une photo d'iPhone fait douze
    /// mégapixels ; `UIImage(data:)` la décode à taille pleine avant qu'on ait
    /// pu la réduire, et la reconnaissance en mode précis travaille ensuite sur
    /// cette taille-là. Mesuré sur l'appareil au moment de l'exécution :
    /// **114 727 pages, soit près de 1,8 Go** — iOS coupe bien avant.
    ///
    /// ImageIO sait produire directement une version réduite depuis les octets
    /// du fichier : la version pleine n'existe à aucun moment. C'est la seule
    /// façon de faire baisser le pic, réduire après coup ne sert à rien.
    func read(data: Data) async {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: 2000,
                  kCGImageSourceCreateThumbnailWithTransform: true,
              ] as CFDictionary)
        else { return }
        await read(UIImage(cgImage: cg))
    }

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

        // Les lignes distinctes, dans l'ordre où l'OCR les a vues. Le doublon
        // est fréquent : un mot et sa ligne remontent séparément.
        var lines: [String] = []
        for item in seen where !lines.contains(item.line) { lines.append(item.line) }

        step = .filing
        do {
            let filed = try await Self.file(lines)
            // La photo est rangée sous le nom que le serveur vient de donner à
            // l'article : c'est ce qui les rattache l'un à l'autre sans qu'aucun
            // des deux n'ait à connaître l'autre.
            if let jpeg = image.jpegData(compressionQuality: 0.8) {
                try? jpeg.write(to: Paths.captures.appending(path: "\(filed.slot).jpg"))
            }
            step = .filed(title: filed.title)
        } catch {
            step = .nothing("Couldn't turn that into an article. Try again in a moment.")
        }
    }

    // ── lecture de l'image ───────────────────────────────────────────────────

    private struct Seen {
        let text: String
        let line: String
    }

    /// `nonisolated` volontairement : le gestionnaire de Vision s'exécute sur une
    /// file d'arrière-plan, et reprendre depuis là une continuation isolée au
    /// main actor arrête l'app — Swift 6 vérifie l'isolation à l'exécution. Rien
    /// ici ne touche à l'état de la classe.
    private nonisolated static func recognise(_ image: UIImage) async -> [Seen] {
        guard let cg = downscaled(image) else { return [] }
        return await withCheckedContinuation { continuation in
            // Reprise garantie une fois et une seule. Le gestionnaire de Vision
            // n'est pas appelé quand `perform` échoue — sur une affiche dense,
            // c'est la mémoire qui lâche — et la tâche restait alors suspendue
            // pour toujours : l'écran de capture se figeait sur son chargement.
            let once = OnceResume(continuation)
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
                        out.append(Seen(text: token, line: line))
                    }
                }
                once.resume(out)
            }
            request.recognitionLanguages = ["ko-KR", "en-US"]
            request.recognitionLevel = .accurate
            // Le coréen d'une facture n'est pas de la prose : la correction
            // automatique y fait plus de mal que de bien.
            request.usesLanguageCorrection = false

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
                } catch {
                    once.resume([])
                }
            }
        }
    }

    /// Réduit l'image avant de la lire.
    ///
    /// Une photo d'iPhone fait douze mégapixels ; décodée, elle occupe déjà une
    /// cinquantaine de mégaoctets, et la reconnaissance en mode « précis » en
    /// demande plusieurs fois autant. Sur une affiche couverte de texte — celle
    /// qui a fait tomber l'app — le pic dépasse ce qu'iOS accorde et le système
    /// tue l'application sans un mot.
    ///
    /// Deux mille pixels sur le grand côté suffisent largement : Vision lit du
    /// texte de cette taille sans effort, et c'est la résolution à laquelle le
    /// hangul d'un panneau photographié à un mètre reste net. En dessous, les
    /// caractères composés commencent à se confondre.
    private nonisolated static func downscaled(_ image: UIImage, max side: CGFloat = 2000) -> CGImage? {
        guard let cg = image.cgImage else { return nil }
        let longest = CGFloat(Swift.max(cg.width, cg.height))
        guard longest > side else { return cg }
        let scale = side / longest
        let size = CGSize(width: CGFloat(cg.width) * scale, height: CGFloat(cg.height) * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return small.cgImage
    }

    /// Une continuation qu'on ne peut reprendre qu'une fois.
    ///
    /// Reprendre deux fois arrête le programme, ne jamais reprendre le fige. Les
    /// deux chemins d'erreur de Vision rendent les deux possibles, donc on ne
    /// compte pas dessus.
    private final class OnceResume: @unchecked Sendable {
        private var continuation: CheckedContinuation<[Seen], Never>?
        private let lock = NSLock()
        init(_ c: CheckedContinuation<[Seen], Never>) { continuation = c }
        func resume(_ value: [Seen]) {
            lock.lock()
            let c = continuation
            continuation = nil
            lock.unlock()
            c?.resume(returning: value)
        }
    }

    // ── le sens, tout de suite ───────────────────────────────────────────────


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
