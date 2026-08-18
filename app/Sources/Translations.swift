import Foundation

/// La traduction d'un transcript, poursuivie hors de tout écran.
///
/// Elle appartenait à l'écran de capture, qui la portait dans une session
/// SwiftUI : quitter l'écran l'annulait, et il fallait donc regarder une barre
/// avancer avant de pouvoir faire quoi que ce soit. Ici, elle vit dans l'app.
/// L'import ouvre la vidéo tout de suite — coréen lisible, vidéo regardable —
/// et l'anglais arrive dessous pendant qu'on lit.
///
/// Rien ne se perd et rien ne se repaye : chaque tranche revenue est écrite
/// dans l'import, et le serveur garde sa traduction. Rouvrir une vidéo laissée
/// à moitié la reprend là où elle en était.
@MainActor
@Observable
final class Translations {
    struct Job: Equatable {
        var done: Int
        var total: Int
        /// Une tranche a échoué. Le bouton du lecteur le montre, et le toucher
        /// réessaie — plutôt qu'un anglais qui ne vient jamais sans rien dire.
        var failed: Bool

        var isRunning: Bool { done < total && !failed }
        /// Plus rien à attendre : tout est traduit, et rien n'a échoué.
        var isSettled: Bool { !isRunning && !failed }
    }

    /// Une tranche par aller-retour : assez grande pour que le serveur ait de
    /// quoi paralléliser, assez petite pour qu'une coupure ne coûte pas tout.
    private static let slice = 200

    private(set) var jobs: [String: Job] = [:]
    /// Les lignes déjà traduites, en mémoire, pour que le lecteur les montre
    /// sans relire le fichier à chaque tranche.
    private(set) var english: [String: [String]] = [:]

    @ObservationIgnored private var running: Set<String> = []

    func job(for videoID: String) -> Job? { jobs[videoID] }
    func lines(for videoID: String) -> [String]? { english[videoID] }

    /// Reprend la traduction de cet import là où elle s'est arrêtée. Sans effet
    /// si elle est complète ou déjà en cours.
    func start(
        _ item: LibraryItem,
        translate: @escaping (String, Int, Int) async throws -> [String] = { try await YouTubeImport.translation($0, from: $1, to: $2) },
        save: @escaping (LibraryItem) throws -> Void = { try ImportedLibrary.save($0) }
    ) {
        let text = item.text
        guard let videoID = text.videoID, let url = text.sourceURL, !running.contains(videoID) else { return }

        var lines = english[videoID] ?? text.sentences.map(\.en)
        guard lines.count == text.sentences.count else { return }
        guard let first = lines.firstIndex(where: \.isEmpty) else {
            jobs[videoID] = Job(done: lines.count, total: lines.count, failed: false)
            return
        }

        running.insert(videoID)
        english[videoID] = lines
        jobs[videoID] = Job(done: lines.count { !$0.isEmpty }, total: lines.count, failed: false)

        Task { [weak self] in
            var from = first
            var failed = false
            while from < lines.count {
                let to = min(from + Self.slice, lines.count)
                // Une tranche déjà pleine ne se redemande pas.
                if lines[from..<to].contains(where: \.isEmpty) {
                    do {
                        let out = try await translate(url, from, to)
                        guard out.count == to - from else { throw YouTubeImport.ImportError.translationCount }
                        lines.replaceSubrange(from..<to, with: out)
                    } catch {
                        failed = true
                        break
                    }
                    guard let self else { return }
                    self.english[videoID] = lines
                    self.jobs[videoID] = Job(done: lines.count { !$0.isEmpty }, total: lines.count, failed: false)
                    try? save(Self.filled(item, with: lines))
                }
                // On avance par tranche, jamais en cherchant le prochain trou :
                // une tranche que le modèle a rendue vide bouclerait sans fin.
                from = to
            }
            guard let self else { return }
            self.running.remove(videoID)
            let complete = lines.count { !$0.isEmpty }
            self.jobs[videoID] = Job(done: complete, total: lines.count, failed: failed || complete < lines.count)
        }
    }

    /// Le même import, avec l'anglais qu'on vient de recevoir.
    static func filled(_ item: LibraryItem, with lines: [String]) -> LibraryItem {
        LibraryItem(
            date: item.date,
            text: Day.Text(
                slot: item.text.slot,
                universe: item.text.universe,
                title: item.text.title,
                minutes: item.text.minutes,
                icon: item.text.icon,
                kind: item.text.kind,
                importedAt: item.text.importedAt,
                videoID: item.text.videoID,
                sourceURL: item.text.sourceURL,
                sourceName: item.text.sourceName,
                thumbnail: item.text.thumbnail,
                durationSeconds: item.text.durationSeconds,
                sentences: item.text.sentences.enumerated().map { index, sentence in
                    Day.Sentence(
                        ko: sentence.ko,
                        en: index < lines.count && !lines[index].isEmpty ? lines[index] : sentence.en,
                        audio: sentence.audio,
                        start: sentence.start,
                        end: sentence.end,
                        words: sentence.words
                    )
                }
            )
        )
    }
}
