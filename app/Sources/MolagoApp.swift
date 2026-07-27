import SwiftUI
import SwiftData

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
                        // Deux onglets, et c'est tout. Pas d'onglet réglages —
                        // la cloche les ouvre. Pas d'onglet bibliothèque —
                        // l'archive est la suite du fil d'aujourd'hui, et les
                        // séparer créerait un endroit où s'accumule ce qu'on n'a
                        // pas fait (spec §5.1).
                        ZStack(alignment: .bottomTrailing) {
                            TabView(selection: .constant(
                                ProcessInfo.processInfo.arguments.contains("--open-notebook") ? 1 : 0
                            )) {
                                Tab("Library", systemImage: "book.pages", value: 0) {
                                    LibraryView(day: day)
                                }
                                Tab("Notebook", systemImage: "text.book.closed", value: 1) {
                                    NotebookView()
                                }
                            }
                            .tint(Dancheong.jangdan)

                            // Le bouton de capture, au centre de la barre —
                            // l'endroit que le pouce atteint le plus facilement
                            // sur un grand iPhone, alors que le coin haut-droit
                            // est le plus difficile. Pour un geste qu'on fait
                            // debout avec une facture dans l'autre main, ça
                            // décide de tout.
                            //
                            // Trois détails l'empêchent de passer pour un
                            // troisième onglet, ce qu'iOS interdit : aucun
                            // libellé, aucun état sélectionné, et il ouvre un
                            // écran modal sans changer d'onglet.
                            CaptureButton()
                        }
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
            // Le carnet est la seule chose irremplaçable du produit : les textes
            // se régénèrent, une collection de mots non.
            .modelContainer(for: [KeptWord.self, WordSignal.self])
        }
    }

    /// Uniquement pour piloter le simulateur pendant le développement.
    private var launchSlot: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--open-text"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}

/// Le bouton de capture, posé au centre de la barre d'onglets.
private struct CaptureButton: View {
    @State private var capturing = false

    var body: some View {
        Button { capturing = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Dancheong.jangdan, in: Circle())
                .shadow(color: Dancheong.jangdan.opacity(0.45), radius: 10, y: 4)
        }
        .accessibilityLabel("Capture a word")
        // À droite de la barre, aligné avec elle. Le « centre de la barre
        // d'onglets » qu'on avait dessiné supposait une barre pleine largeur ;
        // celle d'iOS 26 est une pilule étroite et flottante, et un bouton posé
        // en son centre la chevauche. À côté, il reste dans la zone du pouce et
        // se lit comme une action, pas comme un troisième onglet.
        .padding(.trailing, 26)
        .padding(.bottom, 30)
        .fullScreenCover(isPresented: $capturing) { CaptureView() }
    }
}
