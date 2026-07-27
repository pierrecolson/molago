import SwiftUI
import SwiftData

/// Le carnet — un journal, pas une liste de vocabulaire.
///
/// Chaque mot porte **sa vignette, sa phrase de contexte et son jour** (spec
/// §5.5). C'est le contexte qui fait la différence : une colonne de mots avec
/// leur traduction redevient exactement le par-cœur que ce produit refuse.
///
/// Ce qui n'y figure pas, et volontairement : aucun tri par état — `New 12` est
/// un compteur, donc une dette — et aucun mur de mots, dense mais sans contexte.
struct NotebookView: View {
    @Query(sort: \KeptWord.keptAt, order: .reverse) private var words: [KeptWord]
    @State private var search = ""
    @Environment(\.modelContext) private var context

    /// La recherche remplace les filtres. Elle accepte du coréen, de l'anglais,
    /// ou une nature grammaticale — trois façons de retrouver le même mot.
    private var filtered: [KeptWord] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return words }
        return words.filter {
            $0.lemma.lowercased().contains(q)
                || $0.meaning.lowercased().contains(q)
                || $0.pos.lowercased().contains(q)
        }
    }

    /// Groupé par jour, le plus récent en haut. On descend dans le temps.
    private var byDay: [(day: Date, words: [KeptWord])] {
        Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.keptAt) }
            .map { (day: $0.key, words: $0.value) }
            .sorted { $0.day > $1.day }
    }

    /// `simctl` ne sait pas taper : sans ça, aucune capture de la fiche n'est
    /// possible en ligne de commande.
    @State private var path: [KeptWord] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if words.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing kept yet", systemImage: "book.closed")
                    } description: {
                        Text("Tap a word while reading, then swipe right to keep it.")
                    }
                } else {
                    List {
                        ForEach(byDay, id: \.day) { group in
                            Section(Self.dayLabel(group.day)) {
                                ForEach(group.words) { word in
                                    NavigationLink {
                                        WordDetailView(word: word)
                                    } label: {
                                        KeptRow(word: word)
                                    }
                                }
                                .onDelete { offsets in
                                    for i in offsets { context.delete(group.words[i]) }
                                    try? context.save()
                                }
                            }
                        }
                    }
                    // Le style groupé encarté d'iOS : des blocs blancs arrondis
                    // sur le fond, séparés par des respirations. C'est la
                    // grammaire de Réglages, et elle sépare les journées bien
                    // mieux qu'un simple filet.
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $search, prompt: "Search your words")
                }
            }
            .navigationDestination(for: KeptWord.self) { WordDetailView(word: $0) }
            .background(Dancheong.ground)
            .navigationTitle("Notebook")
            .task {
                if ProcessInfo.processInfo.arguments.contains("--open-word"),
                   let first = words.first { path = [first] }
            }
        }
        .tint(Dancheong.jangdan)
    }

    private static func dayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "TODAY" }
        if calendar.isDateInYesterday(date) { return "YESTERDAY" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: date).uppercased()
    }
}

private struct KeptRow: View {
    let word: KeptWord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(icon: word.icon, lemma: word.lemma, slot: word.slot, size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(word.lemma)
                    .font(.headline)
                Text(word.meaning)
                    .font(.subheadline)
                    .foregroundStyle(Dancheong.inkSoft)
                Text(word.context)
                    .font(.caption)
                    .foregroundStyle(Dancheong.inkSoft.opacity(0.75))
                    .lineLimit(1)
                    .padding(.top, 1)
            }
        }
        .padding(.vertical, 5)
        .listRowBackground(Dancheong.paper)
    }
}
