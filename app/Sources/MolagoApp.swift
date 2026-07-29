import SwiftUI
import SwiftData

@main
struct MolagoApp: App {
    @State private var store = DayStore()
    @State private var tab = 0
    /// La dernière vraie section. La capture n'en est pas une : en revenir doit
    /// ramener là où on était, et pas sur la vue vide qui lui sert de coquille.
    @State private var lastSection = 0

    /// Le lien vers l'onglet sélectionné, qui retient la dernière vraie section.
    ///
    /// La capture n'en est pas une : en sortir doit rendre la main là où on
    /// était, et le système ne s'en souvient pas tout seul.
    private var tabBinding: Binding<Int> {
        Binding(
            get: { tab },
            set: { new in
                if new != Self.captureTab { lastSection = new }
                tab = new
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
                    // La recherche couvre aussi les journées passées : une
                    // capture d'avant-hier doit pouvoir s'ouvrir pareil.
                    if let slot = launchSlot,
                       let text = ([store.day].compactMap { $0 } + store.previously)
                           .flatMap(\.texts).first(where: { $0.slot == slot }) {
                        NavigationStack { ReaderView(text: text) }
                            .tint(Dancheong.jangdan)
                    } else {
                        // Trois sections, et la capture détachée à droite. Pas
                        // d'onglet réglages — la cloche les ouvre. Pas d'onglet
                        // archive — le passé est la suite du fil d'aujourd'hui,
                        // et l'en séparer créerait un endroit où s'accumule ce
                        // qu'on n'a pas fait (spec §5.1).
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
                            //
                            // La capture est le contenu de l'onglet, et non une
                            // feuille posée par-dessus une vue vide. C'est la vue
                            // vide qui restait à l'écran en refermant l'appareil
                            // photo : le lien de sélection ne suffisait pas à
                            // reprendre la main, parce que le système gère seul
                            // la sélection d'un onglet à rôle. En n'ayant plus
                            // rien de vide à montrer, le problème n'existe plus.
                            Tab(value: Self.captureTab, role: .search) {
                                CaptureView(onClose: { tab = lastSection })
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

                    }
                }
            }
            // Revenir de la capture doit montrer l'article qu'on vient d'y
            // ranger. Il a été écrit côté serveur, donc rien ne l'annonce à
            // l'app : c'est le retour dans une section qui vaut signal.
            .onChange(of: tab) { old, new in
                guard old == Self.captureTab, new != Self.captureTab else { return }
                Task { await store.load() }
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
