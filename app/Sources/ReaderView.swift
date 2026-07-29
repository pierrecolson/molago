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
    /// La traduction est-elle affichée sous chaque phrase ?
    ///
    /// La spec §4.4 voulait la traduction *disponible* et jamais *proposée*, d'où
    /// l'appui long d'origine. L'intention était juste, le geste ne l'était pas :
    /// la main occupait l'écran, on ne pouvait plus faire défiler en lisant, et
    /// la friction punissait au lieu d'aider. Le principe tient autrement — la
    /// traduction est éteinte à chaque ouverture et il faut la demander.
    ///
    /// Elle ne remplace pas le coréen, elle se pose dessous : quand on bloque,
    /// c'est cette phrase-là qu'on veut, pas le texte entier dans l'autre langue.
    ///
    /// Pas de compteur : le principe P4 les interdit parce qu'ils créent une
    /// dette, et « tu as lu en anglais quatre fois » serait un reproche déguisé.
    ///
    /// Elle ne se souvient de rien d'un texte à l'autre : chaque lecture
    /// recommence en coréen.
    @State private var english = false
    /// La phrase visée pendant qu'on déplace le curseur. Le texte la surligne et
    /// s'y rend avant même qu'on ait lâché : on voit où l'on va, on n'y arrive
    /// pas par surprise.
    @State private var scrubbing: Int?
    @State private var showingOriginal = false
    @Environment(\.modelContext) private var context

    init(text: Day.Text) {
        self.text = text
        _player = State(initialValue: SentencePlayer(
            urls: text.audioURLs,
            wordStarts: text.sentences.map { ($0.words ?? []).map(\.t) }
        ))
    }

    /// Le document d'origine, quand il y en a un.
    ///
    /// La photo n'a jamais quitté le téléphone : elle ne sert qu'à celui qui
    /// l'a prise, et c'est la seule chose de cette app qui puisse contenir ce
    /// qu'on n'a pas choisi de partager.
    private var originalImage: UIImage? {
        guard let url = Paths.captureImage(text.slot) else { return nil }
        return UIImage(contentsOfFile: url.path(percentEncoded: false))
    }

    /// La bascule texte ↔ document. Le document remplace la lecture, il ne se
    /// pose pas dessus : on le regarde pour vérifier ce que disait le papier,
    /// pas pour le lire avec la voix ou la traduction.
    @ViewBuilder
    private var originalButton: some View {
        if Paths.captureImage(text.slot) != nil {
            Button {
                withAnimation(.easeOut(duration: 0.22)) { showingOriginal.toggle() }
                if showingOriginal { player.pause() }
            } label: {
                Image(systemName: showingOriginal ? "text.justify.left" : "doc.text.image")
            }
            .accessibilityLabel(showingOriginal ? "Back to the text" : "See the original document")
        }
    }

    private var universe: (color: Color, name: String, icon: String) {
        Dancheong.universe(text.slot)
    }

    var body: some View {
        VStack(spacing: 0) {
            universe.color.frame(height: 5)

            if showingOriginal, let image = originalImage {
                DocumentView(image: image)
            } else {
                readingView
            }
        }
        .overlay(alignment: .bottom) {
            // Pas de barre de lecture sur le document : on le regarde, la voix
            // et la traduction appartiennent au texte.
            if !showingOriginal {
                PlayerBar(player: player, tint: universe.color, scrubbing: $scrubbing)
            }
        }
        .background(Dancheong.paper)
        .navigationTitle(text.universe)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                originalButton
                // Une pastille devient deux.
                //
                // L'ancien bouton demandait de garder le doigt appuyé : la main
                // occupait l'écran, on ne pouvait plus faire défiler en lisant,
                // et la friction punissait au lieu d'aider.
                //
                // Il disait aussi la destination — « EN » — alors qu'activer la
                // traduction ne donne pas l'anglais, ça donne **les deux**. Le
                // bouton décrit donc l'état : un drapeau, tu lis en coréen ;
                // deux drapeaux, les deux langues sont à l'écran.
                if !showingOriginal {
                    Button {
                        withAnimation(.easeOut(duration: 0.22)) { english.toggle() }
                    } label: {
                        LanguageToggle(english: english)
                    }
                    .accessibilityLabel(english ? "Korean only" : "Show English too")
                }
            }
        }
        // On lit : la barre d'onglets n'a rien à faire là. Elle sert à changer
        // de section, pas à meubler le bas de l'écran pendant qu'on est dedans.
        .toolbar(.hidden, for: .tabBar)
        .task {
            // `simctl` ne sait pas appuyer sur un bouton : sans ça, aucune
            // capture du lecteur traduit ou du document n'est possible en
            // ligne de commande.
            if ProcessInfo.processInfo.arguments.contains("--english") { english = true }
            if ProcessInfo.processInfo.arguments.contains("--document") { showingOriginal = true }
            // Un texte d'une journée passée n'a que son texte : son audio n'a
            // jamais été téléchargé. On le récupère en ouvrant, sinon la voix
            // reste muette sans rien dire.
            await DayStore.downloadAudio(for: text)
            openCardForScreenshotIfAsked()
            // La voix ne démarre plus toute seule. La spec §4.4 la voulait
            // automatique, mais à l'usage c'est une agression : on ouvre parfois
            // un texte pour le parcourir des yeux, dans un endroit où on ne veut
            // pas de son. Le bouton est là, il ne réclame rien.
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

    private var readingView: some View {
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
                    // De quoi lire la dernière phrase sans que la barre la couvre.
                    .padding(.bottom, 78)
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
            slot: text.slot,
            sourceTitle: text.title,
            sourceDate: text.day
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
        // Le coréen reste le texte. L'anglais se glisse **dessous**, plus petit
        // et en retrait : quand on bloque sur une phrase, c'est celle-là qu'il
        // faut sous les yeux, pas tout le texte traduit ailleurs. On ne perd
        // jamais sa ligne, et on peut masquer l'anglais pour se tester.
        VStack(alignment: .leading, spacing: 5) {
            korean
            if english {
                Text(sentence.en)
                    .font(.subheadline)
                    .lineSpacing(3)
                    .foregroundStyle(Dancheong.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 10)
                    .overlay(alignment: .leading) {
                        // Un filet plutôt qu'un décrochage : il rattache la
                        // traduction à sa phrase sans creuser l'interligne.
                        Rectangle()
                            .fill(Dancheong.separator)
                            .frame(width: 2)
                    }
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
    }

    @ViewBuilder
    private var korean: some View {
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
                    // Interligne 2,0 : le hangul empile deux à trois traits par
                    // syllabe et étouffe à un interligne prévu pour l'alphabet
                    // latin. C'est souvent tout le problème de lisibilité.
                    .lineSpacing(9)
                    .foregroundStyle(Dancheong.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { onTapSentence() }
            }
        }
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
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.30), in: Circle())
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
                    .frame(minWidth: 38, minHeight: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Playback speed")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // Du verre, pas un pan opaque. Le texte continue de défiler dessous et
        // reste devinable : la barre se pose sur la lecture au lieu d'en amputer
        // le bas. La teinte de l'univers est adoucie — à pleine opacité elle
        // faisait un bloc aussi présent qu'une carte, alors qu'elle n'est qu'une
        // commande.
        //
        // Le verre du système sur iOS 26, qui réfracte et suit ce qui passe
        // dessous ; ailleurs, un matériau translucide ordinaire. On ne remonte
        // pas le socle de l'app pour un effet : mieux vaut qu'il soit un peu
        // moins beau sur les versions plus anciennes que pas installable.
        .modifier(GlassPill(tint: tint))
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
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

/// La bascule de langue : une pastille, puis deux.
///
/// Le drapeau coréen seul dit « tu lis en coréen ». Le drapeau anglais qui vient
/// se poser à côté dit « les deux sont là » — pas « passe à l'anglais ». Le
/// bouton décrit donc ce qui est à l'écran, jamais où il t'emmène : c'est ce qui
/// rendait l'ancien libellé « EN » trompeur, puisque activer la traduction ne
/// remplace pas le coréen, elle s'ajoute dessous.
private struct LanguageToggle: View {
    let english: Bool

    var body: some View {
        HStack(spacing: -11) {
            Image("FlagKR").resizable().frame(width: 27, height: 27).clipShape(Circle())
            if english {
                Image("FlagEN")
                    .resizable().frame(width: 27, height: 27).clipShape(Circle())
                    // Le liseré est de la couleur du papier, pas blanc : sur un
                    // fond crème, un blanc franc se voit comme une erreur.
                    .overlay(Circle().stroke(Dancheong.paper, lineWidth: 2))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 4)
    }
}


/// La pilule de verre de la barre de lecture.
private struct GlassPill: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                .regular.tint(tint.opacity(0.72)).interactive(),
                in: .rect(cornerRadius: 24)
            )
        } else {
            content.background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(tint.opacity(0.82))
                    .background(.ultraThinMaterial,
                                in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }
}


/// La photo d'origine, entière dans l'écran.
///
/// Fond noir : une photo de document est un objet qu'on regarde, et un fond
/// clair autour ferait concurrence au papier qu'elle montre.
private struct DocumentView: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
    }
}
