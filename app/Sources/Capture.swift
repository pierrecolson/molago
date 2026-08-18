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
        /// Les sous-titres se demandent au serveur.
        case importingVideo
        /// Les sous-titres se traduisent sur l'appareil, réplique par réplique.
        /// C'est l'étape longue d'une vidéo d'une heure : neuf cents lignes.
        case translatingVideo
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

    // ── l'import d'une vidéo, en deux temps ──────────────────────────────────
    //
    // Les deux moitiés ne vivent pas au même endroit, et c'est le fond du
    // problème que cette version répare.
    //
    // La traduction a besoin d'une `TranslationSession`, et seul le modificateur
    // `translationTask` d'une vue sait en ouvrir une. Mais SwiftUI **relance**
    // cette tâche — en annulant la précédente — dès que la vue qui la porte se
    // redessine. Or la vue se redessine précisément au moment où l'écran
    // d'attente s'affiche. Le transcript se demandait depuis l'intérieur de
    // cette tâche : la requête réseau était annulée en vol, l'import mourait
    // avant même que le fournisseur ne soit interrogé — ce qui explique un
    // écran de chargement figé sur l'iPhone et zéro appel côté Supadata.
    //
    // Donc : le transcript se demande dans une tâche ordinaire, qui n'appartient
    // qu'à ce flux. La traduction reste dans `translationTask`, mais elle
    // **reprend où elle s'était arrêtée** : une relance ne perd au pire qu'un
    // lot de cinquante répliques, jamais l'import.

    /// La vidéo dont les répliques attendent d'être traduites, et ce qui en est
    /// déjà traduit. Hors observation : les toucher ne doit redessiner personne,
    /// sous peine de relancer la traduction en boucle.
    @ObservationIgnored private(set) var awaitingTranslation: YouTubeImport.Video?
    @ObservationIgnored private var translated: [String] = []
    @ObservationIgnored private var done = 0
    @ObservationIgnored private var save: (LibraryItem) throws -> Void = { try ImportedLibrary.save($0) }

    /// Change quand une vidéo est prête à traduire. La vue l'observe pour
    /// relancer sa session — elle seule sait en ouvrir une.
    private(set) var readyToTranslate = 0

    /// Combien de répliques sont traduites, sur combien. Lu sans être observé :
    /// l'écran d'attente le relit à son rythme, sans redessiner la vue qui
    /// porte la session — la redessiner la relancerait.
    var translationProgress: (done: Int, total: Int) { (done, translated.count) }

    /// Une réplique du transcript, telle qu'elle apparaît pendant l'attente.
    struct Line: Identifiable {
        let id: Int
        let ko: String
        /// Vide tant que le lot n'est pas revenu : la ligne est là, en gris,
        /// et son anglais s'allume dessous.
        let en: String?
    }

    /// Les quelques lignes autour du front de traduction : celles qui viennent
    /// de s'allumer, et les suivantes qui attendent. C'est l'attente rendue
    /// lisible — on voit ce qu'on est en train de recevoir.
    var visibleLines: [Line] {
        guard let video = awaitingTranslation, !video.cues.isEmpty else { return [] }
        let start = max(0, min(done, video.cues.count - 1) - 6)
        let end = min(done + 2, video.cues.count)
        guard start < end else { return [] }
        return (start..<end).map {
            Line(id: $0, ko: video.cues[$0].text, en: $0 < done ? translated[$0] : nil)
        }
    }

    /// Ce qu'il reste à attendre, en langue de tous les jours. Rien avant cent
    /// répliques : plus tôt, la cadence n'est pas encore une cadence, et
    /// annoncer « huit minutes » puis « une » est pire que se taire.
    var remaining: String? {
        guard let started = translationStarted, done >= 100, done < translated.count else { return nil }
        let perLine = Date().timeIntervalSince(started) / Double(done)
        let left = perLine * Double(translated.count - done)
        if left < 45 { return "Less than a minute left" }
        let minutes = Int((left / 60).rounded())
        return minutes <= 1 ? "About a minute left" : "About \(minutes) minutes left"
    }

    @ObservationIgnored private var translationStarted: Date?
    @ObservationIgnored private var stopped = false

    /// Arrêter, et ne rien garder. Le transcript n'a rien coûté au lecteur —
    /// le serveur le garde en cache —, donc recommencer plus tard est gratuit.
    func stop() {
        stopped = true
        awaitingTranslation = nil
        step = .choosing
    }

    func begin(
        _ pasted: String,
        fetch: @escaping (String) async throws -> YouTubeImport.Video = { try await YouTubeImport.fetch($0) },
        save: @escaping (LibraryItem) throws -> Void = { try ImportedLibrary.save($0) }
    ) {
        let value = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        self.save = save
        awaitingTranslation = nil
        translated = []
        done = 0
        stopped = false
        translationStarted = nil
        step = .importingVideo
        Task { await fetchVideo(value, fetch: fetch) }
    }

    private func fetchVideo(_ value: String, fetch: (String) async throws -> YouTubeImport.Video) async {
        do {
            let video = try await fetch(value)
            translated = Array(repeating: "", count: video.cues.count)
            awaitingTranslation = video
            // Une vidéo sans coréen reste regardable : rien à traduire, on range.
            if video.cues.isEmpty { return await file() }
            step = .translatingVideo
            readyToTranslate += 1
        } catch YouTubeImport.ImportError.invalidURL {
            step = .nothing("Paste a YouTube video link.")
        } catch {
            step = .nothing("Molago couldn’t reach the transcript service. Try again in a moment.")
        }
    }

    /// Traduit ce qui reste, lot par lot. Appelée à chaque relance de la session.
    func translateAwaiting(batch: ([String]) async throws -> [String]) async {
        guard let video = awaitingTranslation, done < video.cues.count else { return }
        if translationStarted == nil { translationStarted = Date() }
        let lines = video.cues.map(\.text)
        do {
            while done < lines.count {
                guard !stopped else { return }
                let end = min(done + 50, lines.count)
                let out = try await batch(Array(lines[done..<end]))
                guard out.count == end - done else { throw YouTubeImport.ImportError.translationCount }
                translated.replaceSubrange(done..<end, with: out)
                done = end
            }
        } catch is CancellationError {
            // La session a été relancée : le prochain passage repart d'ici.
            return
        } catch {
            awaitingTranslation = nil
            step = .nothing("The transcript couldn’t be translated. Download Korean and English in Settings, then try again.")
            return
        }
        await file()
    }

    private func file() async {
        guard let video = awaitingTranslation else { return }
        awaitingTranslation = nil
        do {
            let item = try YouTubeImport.item(from: video, translations: translated)
            try save(item)
            step = .filed(title: item.text.title)
        } catch {
            step = .nothing("The transcript was translated but couldn’t be saved. Check that Molago can use iCloud, then try again.")
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
