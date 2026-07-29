import SwiftUI
import SwiftData

/// Retrouver quelque chose sans faire défiler.
///
/// Un seul champ pour les deux moitiés du produit : les **textes** qu'on a lus
/// et les **mots** qu'on a gardés. Les séparer en deux recherches obligerait à
/// savoir d'avance dans laquelle chercher — or on cherche « 관리비 » sans se
/// demander si on l'a rencontré dans un article ou attrapé dans le carnet.
struct SearchView: View {
    let day: Day?
    let previously: [Day]

    @Query(sort: \KeptWord.keptAt, order: .reverse) private var kept: [KeptWord]
    @State private var query = ""

    private var q: String { query.trimmingCharacters(in: .whitespaces).lowercased() }

    private var texts: [(day: Day, text: Day.Text)] {
        guard !q.isEmpty else { return [] }
        return ([day].compactMap { $0 } + previously)
            .flatMap { d in d.texts.map { (day: d, text: $0) } }
            .filter { $0.text.title.lowercased().contains(q) }
    }

    private var words: [KeptWord] {
        guard !q.isEmpty else { return [] }
        return kept.filter {
            $0.lemma.lowercased().contains(q) || $0.meaning.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !words.isEmpty {
                    Section("WORDS") {
                        ForEach(words) { word in
                            NavigationLink { WordDetailView(word: word) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(word.lemma).font(.headline)
                                    Text(word.meaning)
                                        .font(.subheadline)
                                        .foregroundStyle(Dancheong.inkSoft)
                                }
                            }
                            .listRowBackground(Dancheong.paper)
                        }
                    }
                }
                if !texts.isEmpty {
                    Section("TEXTS") {
                        ForEach(texts, id: \.text.id) { item in
                            NavigationLink { ReaderView(text: item.text) } label: {
                                HStack(spacing: 11) {
                                    Image(Dancheong.universe(item.text.slot).icon)
                                        .resizable().scaledToFit()
                                        .frame(width: 22, height: 22)
                                        .frame(width: 32, height: 32)
                                        .background(Dancheong.universe(item.text.slot).color)
                                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    Text(item.text.title).font(.subheadline).lineLimit(2)
                                    Spacer(minLength: 6)
                                    Text(item.day.shortLabel)
                                        .font(.caption2)
                                        .foregroundStyle(Dancheong.inkSoft)
                                }
                            }
                            .listRowBackground(Dancheong.paper)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Dancheong.ground)
            .overlay {
                if q.isEmpty {
                    ContentUnavailableView(
                        "Search",
                        systemImage: "magnifyingglass",
                        description: Text("Your texts and the words you kept.")
                    )
                } else if words.isEmpty && texts.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Korean, English, a title\u{2026}")
        }
        .tint(Dancheong.jangdan)
    }
}
