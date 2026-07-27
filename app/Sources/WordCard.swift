import SwiftUI
import SwiftData

/// La carte qui s'ouvre quand on tape un mot.
///
/// Elle **flotte** : des marges sur les quatre côtés, jamais collée au bas de
/// l'écran. Une feuille iOS ne peut pas faire ça — elle est ancrée en bas, donc
/// une carte qui part sur le côté laisse un trou, ne peut pas pivoter, et
/// surtout ne laisse pas voir celle qui suit. Or c'est ce qui fait tout le
/// plaisir du geste (decisions.md, direction A).
///
/// Le même composant servira au tri après capture (M3) et à la calibration : un
/// seul langage de geste dans toute l'app, appris une fois.
struct WordCard: View {
    let word: Day.Word
    let context: String
    let slot: String
    let onKeep: () -> Void
    let onKnew: () -> Void
    let onClose: () -> Void

    @State private var drag: CGSize = .zero

    /// Au-delà de cette distance, le geste est décidé. En deçà, la carte revient
    /// en place : un effleurement ne doit jamais valider quoi que ce soit.
    private let threshold: CGFloat = 110

    private var tint: Color { Dancheong.universe(slot).color }
    private var decision: Decision? {
        if drag.width > threshold { .keep }
        else if drag.width < -threshold { .knew }
        else { nil }
    }

    private enum Decision { case keep, knew }

    /// L'opacité du fond suit le geste au lieu de sauter à l'arrivée : on sent
    /// qu'on approche de la décision, on n'apprend pas qu'on l'a franchie.
    private var backdrop: Double {
        min(abs(Double(drag.width)) / Double(threshold), 1) * 0.42
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Le fond répond au geste. Sans ça on ne sait ce qu'on décide qu'en
            // regardant le petit tampon ; ici l'écran entier bascule dans la
            // couleur de l'univers pour « Keep », vers le neutre pour
            // « I knew this ». La décision se voit avant qu'on lâche.
            ZStack {
                Color.black.opacity(0.18)
                (decision == .keep ? tint : Dancheong.inkSoft)
                    .opacity(backdrop)
            }
            .ignoresSafeArea()
            .onTapGesture { onClose() }

            card
                .padding(.horizontal, 14)
                .padding(.bottom, 26)
                .offset(x: drag.width, y: min(drag.height, 0) * 0.2)
                .rotationEffect(.degrees(Double(drag.width) / 22), anchor: .bottom)
                .gesture(swipe)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: drag)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(word.lemma ?? word.w)
                        .font(.system(size: 30, weight: .semibold))
                    if let pos = word.pos {
                        Text(pos)
                            .font(.caption)
                            .foregroundStyle(Dancheong.inkSoft)
                    }
                }
                Spacer(minLength: 0)
                IconTile(icon: word.icon, lemma: word.lemma ?? word.w, slot: slot, size: 54)
            }

            Text(word.en ?? "—")
                .font(.body)
                .foregroundStyle(Dancheong.ink)
                .padding(.top, 13)
                .fixedSize(horizontal: false, vertical: true)

            Text(context)
                .font(.footnote)
                .foregroundStyle(Dancheong.inkSoft)
                .padding(.top, 10)
                .lineLimit(2)

            Divider().padding(.top, 15)

            // Les deux boutons restent visibles en permanence. Le swipe est un
            // raccourci, jamais le seul chemin — sinon on le découvre par
            // accident, ou jamais.
            HStack {
                Button { onKnew() } label: {
                    Label("I knew this", systemImage: "arrow.left")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(Dancheong.inkSoft)

                Spacer()

                Button { onKeep() } label: {
                    Text("Keep")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(tint, in: Capsule())
                }
            }
            .padding(.top, 13)
        }
        .padding(20)
        .background(Dancheong.paper, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(alignment: .topLeading) { stamp }
        .shadow(color: .black.opacity(0.22), radius: 26, x: 0, y: 14)
    }

    /// Le tampon qui apparaît pendant le geste : on voit ce qu'on est en train
    /// de décider avant de lâcher.
    @ViewBuilder private var stamp: some View {
        if let decision {
            Text(decision == .keep ? "KEEP" : "I KNEW IT")
                .font(.system(size: 15, weight: .heavy))
                .kerning(1.4)
                .foregroundStyle(decision == .keep ? tint : Dancheong.inkSoft)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(decision == .keep ? tint : Dancheong.inkSoft, lineWidth: 3)
                )
                .rotationEffect(.degrees(decision == .keep ? -12 : 12))
                .padding(18)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var swipe: some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { _ in
                switch decision {
                case .keep: onKeep()
                case .knew: onKnew()
                case nil: drag = .zero
                }
            }
    }
}

/// L'icône d'un mot, ou sa première syllabe à défaut.
///
/// **Pas d'icône plutôt qu'une icône fausse** : un mot abstrait reçoit une tuile
/// typographique, jamais une image approximative — celle-ci installerait une
/// association erronée dans la mémoire de quelqu'un qui apprend (spec §5.5).
struct IconTile: View {
    let icon: String?
    let lemma: String
    let slot: String
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(icon == nil ? Dancheong.universe(slot).color : Dancheong.highlight(slot))

            if let icon, let url = Paths.icon(icon), let image = UIImage(contentsOfFile: url.path()) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.1)
            } else {
                Text(String(lemma.prefix(1)))
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}
