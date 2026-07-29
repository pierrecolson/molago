import SwiftUI
import SwiftData

/// Trois questions, et rien à la fin.
///
/// Elles sont tirées du **carnet**, pas du texte qu'on vient de lire : c'est ce
/// qui permet de le lancer dans le métro sans avoir rien ouvert. Les mots qu'on
/// a attrapés reviennent chercher celui qui les a pris.
///
/// La règle de la spec §5 est tenue à la lettre : **juste et faux reçoivent
/// exactement le même traitement.** Pas de vert, pas de rouge, pas de son, pas
/// de score, pas de récapitulatif, pas de « bravo ». On voit la bonne réponse,
/// on passe. Un quiz qui félicite transforme la lecture en performance, et c'est
/// précisément ce que ce produit refuse (P4 : aucun compteur, aucune dette).
struct QuizView: View {
    let words: [KeptWord]

    @Environment(\.dismiss) private var dismiss
    @State private var questions: [Question] = []
    @State private var step = 0
    @State private var chosen: String?

    struct Question: Identifiable {
        let word: KeptWord
        /// La phrase où le mot a été rencontré, son trou déjà creusé.
        let before: String
        let after: String
        let choices: [String]
        var id: String { word.lemma }
    }

    var body: some View {
        Group {
            if let question = questions[safe: step] {
                ask(question)
            } else {
                // Fin de parcours : on ne dit rien et on s'en va. L'absence de
                // conclusion EST la conclusion.
                Color.clear.onAppear { dismiss() }
            }
        }
        .background(Dancheong.paper)
        .navigationTitle("Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("\(min(step + 1, max(questions.count, 1))) / \(max(questions.count, 1))")
                    .font(.footnote.monospaced())
                    .foregroundStyle(Dancheong.inkSoft)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .task { if questions.isEmpty { questions = Self.build(from: words) } }
    }

    private func ask(_ question: Question) -> some View {
        VStack(alignment: .leading, spacing: 26) {
            (Text(question.before)
             + Text(chosen ?? "　　　　").foregroundStyle(chosen == nil ? Dancheong.inkSoft : Dancheong.ink)
             + Text(question.after))
                .font(.title3)
                .lineSpacing(9)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(question.choices, id: \.self) { choice in
                    Button { pick(choice) } label: {
                        Text(choice)
                            .font(.body)
                            .foregroundStyle(Dancheong.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    // Le seul retour visuel possible : la bonne
                                    // réponse s'éclaire, quelle qu'ait été la
                                    // tienne. On n'entoure pas ton erreur.
                                    .fill(chosen != nil && choice == question.word.lemma
                                          ? Dancheong.highlight(question.word.slot)
                                          : Dancheong.ground)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(chosen != nil)
                }
            }

            if chosen != nil {
                Text(question.word.meaning)
                    .font(.subheadline)
                    .foregroundStyle(Dancheong.inkSoft)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func pick(_ choice: String) {
        guard chosen == nil else { return }
        withAnimation(.easeOut(duration: 0.2)) { chosen = choice }
        // Le temps de voir la bonne réponse, puis on avance. Sans bouton
        // « suivant » : il n'y a rien à valider, on a déjà répondu.
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeOut(duration: 0.2)) {
                chosen = nil
                step += 1
            }
        }
    }

    /// Fabrique trois questions à trous à partir du carnet.
    ///
    /// Les distracteurs sont pris **dans le carnet lui-même** : des mots que le
    /// lecteur a vraiment rencontrés, donc plausibles, et jamais un mot inventé
    /// qu'on écarterait pour la seule raison qu'il est inconnu.
    ///
    /// ponytail : on tire au hasard parmi les mots gardés. La répétition espacée
    /// — les mots fragiles plus souvent — arrivera quand `WordSignal` sera
    /// exploité ; c'est la même fonction, avec un tri au lieu d'un tirage.
    static func build(from words: [KeptWord], count: Int = 3) -> [Question] {
        let usable = words.filter { $0.context.contains($0.lemma) }
        guard usable.count >= 4 else { return [] }

        return usable.shuffled().prefix(count).compactMap { word -> Question? in
            guard let range = word.context.range(of: word.lemma) else { return nil }
            let others = words
                .filter { $0.lemma != word.lemma }
                .shuffled()
                .prefix(3)
                .map(\.lemma)
            guard others.count == 3 else { return nil }
            return Question(
                word: word,
                before: String(word.context[..<range.lowerBound]),
                after: String(word.context[range.upperBound...]),
                choices: (others + [word.lemma]).shuffled()
            )
        }
    }
}

private extension Array {
    /// Lire hors des bornes est la façon normale de finir le quiz, pas une
    /// erreur : le pas dépasse la dernière question et on s'en va.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
