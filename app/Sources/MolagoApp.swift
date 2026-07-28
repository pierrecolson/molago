import SwiftUI
import SwiftData

@main
struct MolagoApp: App {
    @State private var store = DayStore()
    @State private var tab = 0
    @State private var capturing = false

    /// Le lien vers l'onglet sélectionné, qui refuse celui du milieu.
    private var tabBinding: Binding<Int> {
        Binding(
            get: { tab },
            set: { new in
                if new == 1 { capturing = true } else { tab = new }
            }
        )
    }

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
                        // Le bouton de capture est un onglet du milieu — mais
                        // il ne sélectionne jamais rien : on intercepte la
                        // sélection, on ouvre l'écran de capture, et on remet
                        // l'onglet précédent.
                        //
                        // C'est la seule façon d'être vraiment AU MILIEU de la
                        // barre d'iOS 26. Celle-ci est une pilule étroite que le
                        // système centre lui-même : un bouton posé par-dessus la
                        // chevauche, un bouton posé à côté la déséquilibre. À
                        // l'intérieur, l'espacement est celui du système.
                        //
                        // La règle « un onglet est une section, jamais une
                        // action » reste tenue : il n'a pas d'état sélectionné,
                        // il n'affiche aucune vue, et il ouvre un écran modal
                        // dont on revient exactement là où on était.
                        TabView(selection: tabBinding) {
                            Tab("Library", systemImage: "newspaper", value: 0) {
                                LibraryView(day: day)
                            }
                            Tab(value: 1) {
                                Color.clear
                            } label: {
                                // Une image dessinée à la main plutôt qu'un
                                // symbole système : la barre impose sa taille et
                                // sa teinte à `systemImage`, mais respecte une
                                // image marquée « garde tes couleurs ». C'est le
                                // seul moyen d'avoir un + orange et plein sans
                                // sortir de la barre.
                                Image(uiImage: .captureGlyph)
                            }
                            Tab("Notebook", systemImage: "text.book.closed", value: 2) {
                                NotebookView()
                            }
                        }
                        .tint(Dancheong.jangdan)
                        .fullScreenCover(isPresented: $capturing) { CaptureView() }
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
            .task {
                await store.load()
                if ProcessInfo.processInfo.arguments.contains("--open-notebook") { tab = 2 }
            }
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
