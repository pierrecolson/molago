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
    @State private var byFamily = false

    /// Les mots regroupés par caractère partagé.
    ///
    /// Une famille = **un caractère**. 관리비, 학비, 교통비 tombent ensemble sous
    /// 費 parce qu'ils le contiennent tous. Un mot à trois caractères appartient
    /// donc à trois familles — ce n'est pas un défaut, c'est la façon dont la
    /// langue est construite, et c'est là qu'est le levier : un caractère appris
    /// en éclaire des dizaines d'autres mots.
    ///
    /// Le regroupement se fait ici, à l'affichage, à partir du hanja déjà rangé
    /// avec chaque mot. Rien à fabriquer, rien à demander au réseau.
    private var families: [(character: String, words: [KeptWord])] {
        var groups: [String: [KeptWord]] = [:]
        for word in filtered {
            guard let hanja = word.hanja else { continue }
            for character in hanja where character.isLetter {
                groups[String(character), default: []].append(word)
            }
        }
        return groups
            // Une famille d'un seul mot n'apprend rien : c'est le rapprochement
            // qui fait le déclic, pas l'étiquette.
            .filter { $0.value.count > 1 }
            .map { (character: $0.key, words: $0.value.sorted { $0.keptAt > $1.keptAt }) }
            .sorted { $0.words.count == $1.words.count ? $0.character < $1.character : $0.words.count > $1.words.count }
    }

    /// Les mots qu'aucune famille ne réclame — ils gardent leur place.
    private var orphans: [KeptWord] {
        let placed = Set(families.flatMap { $0.words.map(\.lemma) })
        return filtered.filter { !placed.contains($0.lemma) }
    }

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
                        if byFamily {
                            // Les mêmes mots, rangés autrement. Ce n'est pas un
                            // autre carnet : c'est le même, vu par ce qu'il a de
                            // commun plutôt que par le jour où il est arrivé.
                            ForEach(families, id: \.character) { family in
                                Section {
                                    ForEach(family.words) { word in
                                        NavigationLink { WordDetailView(word: word) } label: {
                                            KeptRow(word: word, compact: true)
                                        }
                                    }
                                } header: {
                                    FamilyHeader(character: family.character, count: family.words.count)
                                }
                            }
                            if !orphans.isEmpty {
                                Section("ON THEIR OWN") {
                                    ForEach(orphans) { word in
                                        NavigationLink { WordDetailView(word: word) } label: {
                                            KeptRow(word: word, compact: true)
                                        }
                                    }
                                }
                            }
                        } else {
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("", selection: $byFamily) {
                        Text("Words").tag(false)
                        Text("Families").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 168)
                }
                ToolbarItem(placement: .topBarLeading) {
                    // Le quiz vit là où sont les mots : il est fait d'eux. Deux
                    // appuis depuis le métro, sans avoir rien lu.
                    NavigationLink { QuizView(words: words) } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .accessibilityLabel("Quiz")
                    .disabled(words.count < 4)
                }
            }
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

/// Le titre d'une famille : le caractère partagé, et combien de mots il tient.
///
/// Le caractère est **décoratif** — personne ici ne lit le chinois. Il sert de
/// clé pour regrouper, et sur l'écran il ne fait qu'annoncer un bloc. Ce qui
/// s'apprend, c'est de voir quatre mots connus tomber ensemble.
private struct FamilyHeader: View {
    let character: String
    let count: Int

    var body: some View {
        HStack(spacing: 9) {
            Text(character)
                .font(.system(size: 21))
                .foregroundStyle(Dancheong.inkSoft.opacity(0.75))
            Text("\(count) words")
            Spacer()
        }
    }
}

private struct KeptRow: View {
    let word: KeptWord
    var compact = false

    /// La première syllabe, posée grand.
    ///
    /// Elle remplace l'ancienne vignette : un dessin censé représenter « 관리비 »
    /// demandait de déchiffrer une image pour retrouver un mot, ce qui est plus
    /// d'effort que le mot lui-même. La syllabe, elle, marche pour tous les mots
    /// — y compris ceux qui n'ont aucun caractère chinois — et ne prétend rien
    /// expliquer.
    private var syllable: String { String(word.lemma.prefix(1)) }

    var body: some View {
        HStack(alignment: compact ? .center : .top, spacing: 12) {
            Text(syllable)
                .font(.system(size: compact ? 19 : 23, weight: .semibold))
                .foregroundStyle(Dancheong.ink)
                .frame(width: compact ? 38 : 46, height: compact ? 38 : 46)
                .background(Dancheong.highlight(word.slot))
                .clipShape(RoundedRectangle(cornerRadius: compact ? 11 : 13, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(word.lemma)
                    .font(.headline)
                Text(word.meaning)
                    .font(.subheadline)
                    .foregroundStyle(Dancheong.inkSoft)
                // La provenance ne figure plus ici : savoir qu'un mot vient de
                // « tech » n'aide pas à le réviser. Elle réapparaît sur la fiche
                // du mot, là où elle sert à retrouver le texte d'origine.
                if !compact {
                    Text(word.context)
                        .font(.caption)
                        .foregroundStyle(Dancheong.inkSoft.opacity(0.75))
                        .lineLimit(1)
                        .padding(.top, 1)
                }
            }
        }
        .padding(.vertical, compact ? 2 : 5)
        .listRowBackground(Dancheong.paper)
    }
}
