import SwiftUI
import SwiftData

@main
struct MolagoApp: App {
    @State private var store = DayStore()
    @State private var tab = 0
    /// La dernière vraie section. La capture n'en est pas une : en revenir doit
    /// ramener là où on était, et pas sur la vue vide qui lui sert de coquille.
    @State private var lastSection = 0
    @State private var capturing = false

    /// Le lien vers l'onglet sélectionné, qui refuse celui de la capture.
    ///
    /// La capture est **un bouton, pas une section** : on intercepte sa
    /// sélection, on ouvre l'écran modal, et on remet l'onglet précédent. Il n'a
    /// donc jamais d'état sélectionné et n'affiche aucune vue — la règle « un
    /// onglet est une section, jamais une action » reste tenue.
    private var tabBinding: Binding<Int> {
        Binding(
            get: { tab },
            set: { new in
                if new == Self.captureTab {
                    capturing = true
                    // On remet aussitôt la section précédente : selon la façon
                    // dont le système applique la sélection d'un onglet à rôle,
                    // elle peut passer outre ce lien — et l'écran vide de la
                    // capture reste alors affiché en refermant l'appareil photo.
                    tab = lastSection
                } else {
                    tab = new
                    lastSection = new
                }
            }
        )
    }

    /// Le rôle `.search` est le seul que le système détache de la pilule, à la
    /// façon d'Apple Music. On le donne à la capture parce que c'est elle qu'on
    /// veut isolée à droite — le geste qui *ajoute* n'appartient pas à la rangée
    /// de ceux qui *naviguent*. La recherche, elle, redevient un onglet normal.
    private static let captureTab = 3

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

                default:
                    // `simctl` ne sait pas taper sur un écran. Pour régler le
                    // lecteur depuis la ligne de commande, on l'ouvre
                    // directement : `simctl launch … --open-text daily`.
                    if let slot = launchSlot, let day = store.day,
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
                                // La journée manquante ne vide plus que cet
                                // onglet. Le carnet est la seule chose
                                // irremplaçable du produit : le rendre
                                // inatteignable les matins où la fabrique n'a
                                // rien produit était exactement l'inverse de ce
                                // qu'il fallait faire.
                                if let day = store.day {
                                    HomeView(day: day, previously: store.previously)
                                } else {
                                    ContentUnavailableView(
                                        "Nothing this morning",
                                        systemImage: "sun.horizon",
                                        description: Text(store.message ?? "")
                                    )
                                    .background(Dancheong.ground)
                                }
                            }
                            Tab("Notebook", systemImage: "text.book.closed", value: 1) {
                                NotebookView()
                            }
                            Tab("Search", systemImage: "magnifyingglass", value: 2) {
                                SearchView(day: store.day, previously: store.previously)
                            }
                            // Détaché de la pilule, seul à droite.
                            Tab(value: Self.captureTab, role: .search) {
                                Color.clear
                            } label: {
                                // Un symbole système, de la même encre que les
                                // autres. Le glyphe orange dessiné à la main
                                // servait à exister AU MILIEU de la pilule, où
                                // rien ne ressort ; détaché sur sa propre
                                // pastille, il ressort déjà par sa position, et
                                // la couleur en plus faisait un bouton qui crie.
                                Label("Catch a word", systemImage: "plus")
                            }
                        }
                        .tint(Dancheong.jangdan)
                        .fullScreenCover(isPresented: $capturing, onDismiss: { tab = lastSection }) {
                            CaptureView()
                        }
                    }
                }
            }
            .task {
                await store.load()
                if ProcessInfo.processInfo.arguments.contains("--open-notebook") { tab = 1 }
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
