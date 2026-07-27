import SwiftUI

/// Le texte, et la voix qui le suit.
///
/// La couleur de l'univers n'entre jamais dans la zone de lecture : elle se
/// réduit à un filet en haut, au surlignage de la phrase lue, et à la barre de
/// lecture. **La couleur sert à choisir, jamais à lire.**
struct ReaderView: View {
    let text: Day.Text

    @State private var player: SentencePlayer
    @State private var didStart = false

    init(text: Day.Text) {
        self.text = text
        _player = State(initialValue: SentencePlayer(urls: text.audioURLs))
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
                                    korean: sentence.ko,
                                    isCurrent: i == player.index && player.isPlaying,
                                    tint: Dancheong.highlight(text.slot)
                                )
                                .id(i)
                                .onTapGesture { player.play(from: i) }
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
        .task {
            // La voix démarre à l'ouverture : on tape une carte, ça se met à
            // parler. Rien à déclencher (spec §4.4).
            guard !didStart else { return }
            didStart = true
            player.play(from: 0)
        }
        .onDisappear { player.pause() }
    }
}

private struct SentenceLine: View {
    let korean: String
    let isCurrent: Bool
    let tint: Color

    var body: some View {
        Text(korean)
            .font(.body)
            .lineSpacing(7)
            .foregroundStyle(Dancheong.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isCurrent ? tint : .clear)
            )
            .contentShape(Rectangle())
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
