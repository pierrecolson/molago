import SwiftUI
import SwiftData

/// Le texte, et la voix qui le suit.
///
/// La couleur de l'univers n'entre jamais dans la zone de lecture : elle se
/// réduit à un filet en haut, au surlignage de la phrase lue, et à la barre de
/// lecture. **La couleur sert à choisir, jamais à lire.**
struct ReaderView: View {
    let text: Day.Text

    @State private var player: SentencePlayer
    @State private var didStart = false
    @State private var tapped: (word: Day.Word, sentence: Day.Sentence)?
    @Environment(\.modelContext) private var context

    init(text: Day.Text) {
        self.text = text
        _player = State(initialValue: SentencePlayer(
            urls: text.audioURLs,
            wordStarts: text.sentences.map { ($0.words ?? []).map(\.t) }
        ))
    }

    private var universe: (color: Color, hanja: String) {
        Dancheong.universe(text.slot)
    }

    var body: some View {
        VStack(spacing: 0) {
            universe.color.frame(height: 5)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(text.title)
                                .font(.title2.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(text.meta)
                                .font(.subheadline)
                                .foregroundStyle(Dancheong.inkSoft)
                        }

                        // Une phrase par ligne, resserrées : ça se lit comme un
                        // paragraphe, mais chaque phrase reste une cible de tap.
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(Array(text.sentences.enumerated()), id: \.offset) { i, sentence in
                                SentenceLine(
                                    sentence: sentence,
                                    isCurrent: i == player.index && player.isPlaying,
                                    wordIndex: i == player.index ? player.wordIndex : -1,
                                    tint: Dancheong.highlight(text.slot),
                                    wordTint: Dancheong.wordHighlight(text.slot),
                                    onTapSentence: { player.play(from: i) },
                                    onTapWord: { word in
                                        // Taper un mot met la voix en pause : on
                                        // ne lit pas une définition pendant que
                                        // quelqu'un continue de parler (spec §4.4).
                                        player.pause()
                                        tapped = (word, sentence)
                                    }
                                )
                                .id(i)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
                .onChange(of: player.index) { _, new in
                    withAnimation(.easeOut(duration: 0.35)) {
                        proxy.scrollTo(new, anchor: .center)
                    }
                }
            }

            PlayerBar(player: player, tint: universe.color)
        }
        .background(Dancheong.paper)
        .navigationTitle(text.universe)
        .navigationBarTitleDisplayMode(.inline)
        // On lit : la barre d'onglets n'a rien à faire là. Elle sert à changer
        // de section, pas à meubler le bas de l'écran pendant qu'on est dedans.
        .toolbar(.hidden, for: .tabBar)
        .task {
            openCardForScreenshotIfAsked()
            // La voix démarre à l'ouverture : on tape une carte, ça se met à
            // parler. Rien à déclencher (spec §4.4).
            guard !didStart else { return }
            didStart = true
            player.play(from: 0)
        }
        .onDisappear { player.pause() }
        .overlay {
            if let tapped {
                WordCard(
                    word: tapped.word,
                    context: tapped.sentence.ko,
                    slot: text.slot,
                    onKeep: { keep(tapped.word, from: tapped.sentence); close() },
                    onKnew: { signal(tapped.word, "knew"); close() },
                    onClose: { close() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: tapped?.word)
    }

    /// `simctl` ne sait pas taper sur un écran : sans ça, aucune capture de la
    /// carte n'est possible en ligne de commande.
    private func openCardForScreenshotIfAsked() {
        let args = ProcessInfo.processInfo.arguments
        // `--keep-word` garde en plus le mot aussitôt : c'est le seul moyen de
        // vérifier la boucle complète — tap, garde, carnet — sans main humaine.
        let keeping = args.contains("--keep-word")
        let flag = keeping ? "--keep-word" : "--tap-word"
        guard let i = args.firstIndex(of: flag), i + 1 < args.count,
              let n = Int(args[i + 1]) else { return }
        var seen = 0
        for sentence in text.sentences {
            for word in sentence.words ?? [] where word.isTappable {
                if seen == n {
                    if keeping { keep(word, from: sentence) } else { tapped = (word, sentence) }
                    return
                }
                seen += 1
            }
        }
    }

    /// Fermer ne fait rien d'autre que fermer. C'est le cas le plus fréquent, et
    /// c'est normal (spec §5.4).
    private func close() {
        tapped = nil
    }

    private func keep(_ word: Day.Word, from sentence: Day.Sentence) {
        guard let lemma = word.lemma, let meaning = word.en else { return }
        context.insert(KeptWord(
            lemma: lemma,
            meaning: meaning,
            pos: word.pos ?? "",
            icon: word.icon,
            context: sentence.ko,
            contextAudio: sentence.fileName,
            hanja: word.hanja,
            root: word.root,
            family: word.family,
            slot: text.slot
        ))
        try? context.save()
    }

    private func signal(_ word: Day.Word, _ kind: String) {
        guard let lemma = word.lemma else { return }
        context.insert(WordSignal(lemma: lemma, kind: kind))
        try? context.save()
    }
}

private struct SentenceLine: View {
    let sentence: Day.Sentence
    let isCurrent: Bool
    let wordIndex: Int
    let tint: Color
    let wordTint: Color
    let onTapSentence: () -> Void
    let onTapWord: (Day.Word) -> Void

    var body: some View {
        Group {
            if let words = sentence.words, !words.isEmpty {
                // Une vue par mot : c'est ce qui permet de viser un mot du doigt.
                // La disposition les coule comme un paragraphe, donc le texte se
                // lit toujours comme du texte.
                FlowLayout {
                    ForEach(Array(words.enumerated()), id: \.offset) { i, word in
                        Text(word.w)
                            .font(.body)
                            .foregroundStyle(Dancheong.ink)
                            .padding(.horizontal, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(isCurrent && i == wordIndex ? wordTint : .clear)
                            )
                            // La zone tapable dépasse le mot sans écarter les
                            // lignes : au-delà, le texte cesse de se lire comme
                            // un paragraphe et devient une liste. Rater un mot
                            // n'est pas grave — le tap retombe sur la phrase.
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if word.isTappable { onTapWord(word) } else { onTapSentence() }
                            }
                    }
                }
            } else {
                Text(sentence.ko)
                    .font(.body)
                    .lineSpacing(7)
                    .foregroundStyle(Dancheong.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { onTapSentence() }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isCurrent ? tint : .clear)
        )
        .animation(.easeOut(duration: 0.25), value: isCurrent)
    }
}

private struct PlayerBar: View {
    let player: SentencePlayer
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Button {
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.32), in: Circle())
            }
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

            // Une jauge de progression sur les phrases, pas sur les secondes :
            // c'est l'unité dans laquelle on lit.
            ProgressView(
                value: Double(player.index + 1),
                total: Double(max(player.urls.count, 1))
            )
            .tint(.white)
            .background(.white.opacity(0.25))

            Text("1.0×")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(tint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
