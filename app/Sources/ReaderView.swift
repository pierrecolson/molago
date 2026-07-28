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
    /// Bascule vers l'anglais, derrière une friction volontaire.
    ///
    /// La spec §4.4 veut la traduction *disponible* et jamais *proposée* : à un
    /// tap elle devient un réflexe, et on finit par lire l'anglais plutôt que le
    /// coréen. La friction est donc **asymétrique** — un appui long pour
    /// l'allumer, un simple tap pour l'éteindre. Passer à l'anglais demande une
    /// intention ; en revenir n'en demande aucune.
    ///
    /// Pas de compteur : le principe P4 interdit les compteurs parce qu'ils
    /// créent une dette, et « tu as lu en anglais quatre fois » serait un
    /// reproche déguisé. L'app n'a pas d'avis sur la façon dont on lit.
    ///
    /// Elle ne se souvient de rien d'un texte à l'autre : chaque lecture
    /// recommence en coréen.
    @State private var english = false
    @State private var hinting = false
    /// La phrase visée pendant qu'on déplace le curseur. Le texte la surligne et
    /// s'y rend avant même qu'on ait lâché : on voit où l'on va, on n'y arrive
    /// pas par surprise.
    @State private var scrubbing: Int?
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
                                    english: english,
                                    isCurrent: i == (scrubbing ?? player.index)
                                        && (player.isPlaying || scrubbing != nil),
                                    wordIndex: scrubbing == nil && i == player.index ? player.wordIndex : -1,
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
                    guard scrubbing == nil else { return }
                    withAnimation(.easeOut(duration: 0.35)) {
                        proxy.scrollTo(new, anchor: .center)
                    }
                }
                .onChange(of: scrubbing) { _, new in
                    guard let new else { return }
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo(new, anchor: .center)
                    }
                }
            }

            PlayerBar(player: player, tint: universe.color, scrubbing: $scrubbing)
        }
        .background(Dancheong.paper)
        .navigationTitle(text.universe)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text(english ? "한" : "EN")
                    .font(.subheadline.weight(.bold))
                    .monospaced()
                    .foregroundStyle(english ? Dancheong.jangdan : Dancheong.inkSoft)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                    // Éteindre : un tap. Allumer : un appui long.
                    .onTapGesture {
                        if english {
                            withAnimation(.easeOut(duration: 0.2)) { english = false }
                        } else {
                            // On ne laisse pas le tap sans réponse : sinon on
                            // croit le bouton cassé plutôt que protégé.
                            withAnimation(.easeOut(duration: 0.15)) { hinting = true }
                        }
                    }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            english = true
                            hinting = false
                        }
                    }
                    .accessibilityLabel(english ? "Show Korean" : "Hold to show English")
            }
        }
        // On lit : la barre d'onglets n'a rien à faire là. Elle sert à changer
        // de section, pas à meubler le bas de l'écran pendant qu'on est dedans.
        .toolbar(.hidden, for: .tabBar)
        .task {
            openCardForScreenshotIfAsked()
            // La voix ne démarre plus toute seule. La spec §4.4 la voulait
            // automatique, mais à l'usage c'est une agression : on ouvre parfois
            // un texte pour le parcourir des yeux, dans un endroit où on ne veut
            // pas de son. Le bouton est là, il ne réclame rien.
        }
        .onDisappear { player.pause() }
        .overlay(alignment: .top) {
            if hinting && !english {
                Text("Hold to read it in English")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Dancheong.ink.opacity(0.9), in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation(.easeOut(duration: 0.25)) { hinting = false }
                    }
            }
        }
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
    let english: Bool
    let isCurrent: Bool
    let wordIndex: Int
    let tint: Color
    let wordTint: Color
    let onTapSentence: () -> Void
    let onTapWord: (Day.Word) -> Void

    var body: some View {
        Group {
            if english {
                // En anglais on ne peut plus viser un mot : les repères
                // temporels portent sur les 어절 coréens. La phrase reste
                // tapable, donc la voix se déplace toujours.
                Text(sentence.en)
                    .font(.body)
                    .lineSpacing(6)
                    .foregroundStyle(Dancheong.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { onTapSentence() }
            } else if let words = sentence.words, !words.isEmpty {
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
    @Binding var scrubbing: Int?

    /// « 1× » et non « 1.0× » : le zéro n'apprend rien et allonge l'étiquette.
    static func label(_ rate: Float) -> String {
        rate == 1.0 ? "1×" : String(format: "%.2g×", rate)
    }

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

            Scrubber(
                count: player.urls.count,
                index: scrubbing ?? player.index,
                onScrub: { scrubbing = $0 },
                onCommit: { i in
                    scrubbing = nil
                    player.play(from: i)
                }
            )

            // La vitesse était affichée sans être cliquable, ce qui est pire
            // que de ne pas l'afficher : on croit pouvoir la changer.
            Button {
                player.cycleRate()
            } label: {
                Text(Self.label(player.rate))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .frame(minWidth: 44, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Playback speed")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(tint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

/// La barre de progression, et le moyen de s'y déplacer.
///
/// L'unité est la **phrase**, pas la seconde : c'est celle dans laquelle on lit,
/// et chaque phrase est déjà sa propre piste. Se déplacer revient donc à choisir
/// une phrase, ce qui tombe toujours juste — on n'atterrit jamais au milieu d'un
/// mot.
private struct Scrubber: View {
    let count: Int
    let index: Int
    let onScrub: (Int) -> Void
    let onCommit: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let progress = count > 1 ? Double(index) / Double(count - 1) : 0

            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.28))
                Capsule().fill(.white).frame(width: max(6, width * progress))
                Circle()
                    .fill(.white)
                    .frame(width: 13, height: 13)
                    .offset(x: max(0, width * progress - 6.5))
            }
            .frame(height: 5)
            .frame(maxHeight: .infinity)
            // La zone tapable fait toute la hauteur de la barre : viser un trait
            // de cinq points avec le pouce est un jeu d'adresse, pas une
            // commande. `minimumDistance: 0` fait qu'un simple tap déplace aussi.
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { onScrub(sentence(at: $0.location.x, width: width)) }
                    .onEnded { onCommit(sentence(at: $0.location.x, width: width)) }
            )
        }
        .frame(height: 36)
    }

    private func sentence(at x: CGFloat, width: CGFloat) -> Int {
        guard count > 1, width > 0 else { return 0 }
        let ratio = min(max(x / width, 0), 1)
        return Int((ratio * Double(count - 1)).rounded())
    }
}
