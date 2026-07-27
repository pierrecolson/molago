import SwiftUI

@main
struct MolagoApp: App {
    var body: some Scene {
        WindowGroup {
            if let day = DayStore.today {
                // `simctl` ne sait pas taper sur un écran. Pour pouvoir régler
                // le lecteur depuis la ligne de commande, on l'ouvre
                // directement : `simctl launch … --open-text daily`.
                if let slot = DayStore.slotFromLaunchArguments,
                   let text = day.texts.first(where: { $0.slot == slot }) {
                    NavigationStack { ReaderView(text: text) }
                        .tint(Dancheong.jangdan)
                } else {
                    LibraryView(day: day)
                }
            } else {
                // L'app le dit franchement plutôt que de faire semblant. Aucun
                // reproche, aucun rattrapage à faire (spec §12).
                ContentUnavailableView(
                    "Nothing this morning",
                    systemImage: "sun.horizon",
                    description: Text("Today's texts haven't arrived yet.")
                )
            }
        }
    }
}

/// Charge la journée.
///
/// En M1 elle est embarquée dans l'app : ça permet de construire et de régler
/// l'interface contre du vrai coréen avant que le serveur existe. Le
/// téléchargement à l'ouverture arrive juste après, et ne change que cette
/// poignée de lignes.
enum DayStore {
    static let today: Day? = {
        guard
            let url = Bundle.main.url(forResource: "day", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(Day.self, from: data)
    }()

    /// Uniquement pour piloter le simulateur pendant le développement.
    static var slotFromLaunchArguments: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--open-text"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}

extension Day.Text {
    /// Les pistes du texte, dans l'ordre des phrases.
    ///
    /// On cherche par nom de fichier plutôt que par chemin : la mise à plat des
    /// ressources dans le bundle est une affaire d'Xcode, et les noms sont déjà
    /// uniques (`2026-07-27-tech-01.mp3`).
    var audioURLs: [URL] {
        sentences.compactMap { sentence in
            let name = (sentence.audio as NSString).lastPathComponent
            return Bundle.main.url(
                forResource: (name as NSString).deletingPathExtension,
                withExtension: "mp3"
            )
        }
    }
}
