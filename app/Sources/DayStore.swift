import Foundation
import Observation

/// Où vivent les journées téléchargées.
///
/// Hors du `@MainActor` : ce sont des chemins de fichiers, ils n'ont aucune
/// raison d'appartenir à un acteur, et les téléchargements y accèdent depuis
/// d'autres tâches.
///
/// `Application Support` et non `Caches` : le système vide les caches quand le
/// disque se remplit, et perdre la journée parce qu'iOS a fait le ménage
/// pendant la nuit serait une panne qu'on ne saurait pas expliquer.
enum Paths {
    static let root: URL = {
        let base = URL.applicationSupportDirectory.appending(path: "molago", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    static let audio: URL = {
        let dir = root.appending(path: "audio", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let icons: URL = {
        let dir = root.appending(path: "icons", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Une piste audio si elle est encore là. Les anciennes finissent purgées
    /// du serveur, donc un mot ancien peut avoir perdu sa voix.
    static func audioFile(_ name: String) -> URL? {
        let url = audio.appending(path: name)
        return FileManager.default.fileExists(atPath: url.path()) ? url : nil
    }

    /// L'icône d'un mot si elle est déjà sur l'appareil, sinon rien : à défaut
    /// l'app affiche la tuile typographique, jamais une image d'attente.
    static func icon(_ slug: String) -> URL? {
        let url = icons.appending(path: "\(slug).png")
        return FileManager.default.fileExists(atPath: url.path()) ? url : nil
    }
}

/// Récupère la journée et la garde sur l'appareil.
///
/// Deux règles gouvernent tout ce fichier :
///
/// 1. **Ce qui est déjà là s'affiche immédiatement.** On ne fait jamais attendre
///    devant un écran vide pour un texte qu'on a déjà — la promesse est de cinq
///    secondes à l'ouverture (spec §4.3).
/// 2. **Une fois téléchargée, une journée ne dépend plus du réseau.** Textes et
///    audio vivent sur le téléphone. Pas de réseau dans le métro le matin : rien
///    ne change (spec §12).
@Observable
@MainActor
final class DayStore {
    enum State {
        case loading
        case ready(Day)
        case nothing(String)
    }

    private(set) var state: State = .loading


    func load() async {
        let today = Self.dateString(Date())

        // D'abord ce qu'on a. L'écran se remplit avant le moindre appel réseau.
        if let cached = Self.readCached(today) {
            state = .ready(cached)
        }

        do {
            let day = try await Self.fetch(date: today)
            // La journée est écrite AVANT les médias. Un texte lisible mais
            // muet vaut infiniment mieux qu'un écran vide : une piste qui
            // manque se rattrape au prochain lancement, une journée perdue
            // parce qu'un fichier sur cinquante a échoué, non.
            Self.writeCached(day)
            state = .ready(day)
            await Self.downloadAudio(for: day)
            await Self.downloadIcons(for: day)
        } catch {
            print("[molago] chargement impossible : \(error)")
            // Rien de neuf ? Ce qu'on a déjà reste à l'écran. Sinon on le dit
            // franchement, sans reproche ni rattrapage à faire (spec §12).
            if case .ready = state { return }
            if let latest = Self.readMostRecentCached() {
                state = .ready(latest)
            } else {
                state = .nothing(Self.humanMessage(for: error))
            }
        }
    }

    // ── réseau ───────────────────────────────────────────────────────────────

    private static func fetch(date: String) async throws -> Day {
        var request = URLRequest(url: Config.baseURL.appending(path: "\(date).json"))
        request.timeoutInterval = 20
        // Le JSON change chaque nuit : on ne veut pas d'une version d'hier
        // ressortie d'un cache réseau.
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Day.self, from: data)
    }

    /// Télécharge les pistes manquantes.
    ///
    /// Sans `throws` : une piste qui échoue ne doit pas emporter la journée. Une
    /// piste déjà là n'est jamais reprise — son nom porte la date, donc son
    /// contenu ne change jamais.
    private static func downloadAudio(for day: Day) async {
        let fm = FileManager.default
        let missing = day.texts.flatMap(\.sentences).filter { sentence in
            !fm.fileExists(atPath: Paths.audio.appending(path: sentence.fileName).path())
        }
        guard !missing.isEmpty else { return }
        await fetchAll(missing.map { (Config.baseURL.appending(path: $0.audio), Paths.audio.appending(path: $0.fileName)) })
    }

    /// Télécharge un lot, par paquets.
    ///
    /// Six à la fois : c'est ce qu'`URLSession` ouvre par hôte de toute façon, et
    /// lancer cinquante tâches d'un coup ne fait qu'allonger la file en
    /// multipliant les occasions d'expirer.
    private static func fetchAll(_ jobs: [(from: URL, to: URL)]) async {
        for chunk in stride(from: 0, to: jobs.count, by: 6).map({ Array(jobs[$0..<min($0 + 6, jobs.count)]) }) {
            await withTaskGroup(of: Void.self) { group in
                for job in chunk {
                    group.addTask {
                        guard let (temp, response) = try? await URLSession.shared.download(from: job.from),
                              (response as? HTTPURLResponse)?.statusCode == 200
                        else { return }
                        try? FileManager.default.removeItem(at: job.to)
                        try? FileManager.default.moveItem(at: temp, to: job.to)
                    }
                }
            }
        }
    }

    /// Les icônes des mots du jour.
    ///
    /// Sans `throws` : une icône manquante n'empêche pas de lire, le mot montre
    /// simplement sa tuile typographique. Ce serait absurde de refuser toute la
    /// journée pour ça.
    private static func downloadIcons(for day: Day) async {
        let fm = FileManager.default
        let slugs = Set(
            day.texts.compactMap(\.icon)
            + day.texts.flatMap(\.sentences).flatMap { $0.words ?? [] }.compactMap(\.icon))
            .filter { !fm.fileExists(atPath: Paths.icons.appending(path: "\($0).png").path()) }
        guard !slugs.isEmpty else { return }
        await fetchAll(slugs.map {
            (Config.iconsURL.appending(path: "\($0).png"), Paths.icons.appending(path: "\($0).png"))
        })
    }

    // ── disque ───────────────────────────────────────────────────────────────

    private static func file(_ date: String) -> URL { Paths.root.appending(path: "\(date).json") }

    private static func readCached(_ date: String) -> Day? {
        guard let data = try? Data(contentsOf: file(date)) else { return nil }
        return try? JSONDecoder().decode(Day.self, from: data)
    }

    private static func writeCached(_ day: Day) {
        guard let data = try? JSONEncoder().encode(day) else { return }
        try? data.write(to: file(day.date), options: .atomic)
    }

    /// La journée la plus récente qu'on possède.
    ///
    /// Sert quand la fabrique n'a rien produit cette nuit : plutôt qu'un écran
    /// vide, on rouvre sur hier. La bibliothèque reste disponible même quand la
    /// génération a raté (spec §12).
    private static func readMostRecentCached() -> Day? {
        let files = (try? FileManager.default.contentsOfDirectory(at: Paths.root, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .lazy
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? JSONDecoder().decode(Day.self, from: $0) }
            .first
    }

    // ── divers ───────────────────────────────────────────────────────────────

    private static func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    /// Ce que l'app dit quand elle n'a rien.
    ///
    /// Elle le dit franchement et sans s'excuser. Aucune de ces phrases ne
    /// suggère que l'utilisateur aurait dû faire quelque chose.
    private static func humanMessage(for error: Error) -> String {
        if let urlError = error as? URLError,
           [.notConnectedToInternet, .networkConnectionLost, .timedOut].contains(urlError.code) {
            return "No connection, and nothing saved on this phone yet."
        }
        return "Today's texts haven't arrived yet."
    }
}

extension Day.Sentence {
    /// Le nom de fichier seul : les pistes vivent à plat dans un seul dossier,
    /// et leur nom porte déjà la date et le slot, donc il est unique.
    var fileName: String { (audio as NSString).lastPathComponent }
}

extension Day.Text {
    /// Les pistes du texte, dans l'ordre des phrases, telles qu'elles sont sur
    /// l'appareil.
    var audioURLs: [URL] {
        sentences.map { Paths.audio.appending(path: $0.fileName) }
    }
}
