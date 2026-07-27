import SwiftUI

@main
struct MolagoApp: App {
    @State private var store = DayStore()

    var body: some Scene {
        WindowGroup {
            Group {
                switch store.state {
                case .loading:
                    ProgressView()
                        .controlSize(.large)
                        .tint(Dancheong.jangdan)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Dancheong.ground)

                case .ready(let day):
                    // `simctl` ne sait pas taper sur un écran. Pour régler le
                    // lecteur depuis la ligne de commande, on l'ouvre
                    // directement : `simctl launch … --open-text daily`.
                    if let slot = launchSlot,
                       let text = day.texts.first(where: { $0.slot == slot }) {
                        NavigationStack { ReaderView(text: text) }
                            .tint(Dancheong.jangdan)
                    } else {
                        LibraryView(day: day)
                    }

                case .nothing(let message):
                    // L'app le dit franchement plutôt que de faire semblant.
                    // Aucun reproche, aucun rattrapage à faire (spec §12).
                    ContentUnavailableView(
                        "Nothing this morning",
                        systemImage: "sun.horizon",
                        description: Text(message)
                    )
                    .background(Dancheong.ground)
                }
            }
            .task { await store.load() }
        }
    }

    /// Uniquement pour piloter le simulateur pendant le développement.
    private var launchSlot: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--open-text"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}
