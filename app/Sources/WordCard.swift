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

    /// Où en est le geste, de 0 à 1. Le fond et l'annonce le suivent tous les
    /// deux : on sent qu'on approche de la décision, on n'apprend pas qu'on l'a
    /// franchie.
    private var progress: Double {
        min(abs(Double(drag.width)) / Double(threshold), 1)
    }

    /// Vers quoi on tire, même avant d'avoir franchi le seuil.
    private var leaning: Decision? {
        if drag.width > 12 { .keep }
        else if drag.width < -12 { .knew }
        else { nil }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Le fond répond au geste, et c'est **lui** qui annonce la décision.
            // L'annonce était d'abord tamponnée sur la carte : elle couvrait le
            // mot coréen, c'est-à-dire la seule chose qu'on est venu lire.
            ZStack {
                Color.black.opacity(0.18)
                (leaning == .keep ? tint : Dancheong.inkSoft)
                    .opacity(progress * 0.42)
            }
            .ignoresSafeArea()
            .onTapGesture { onClose() }

            announcement

            card
                .padding(.horizontal, 14)
                .padding(.bottom, 26)
                .offset(x: drag.width, y: min(drag.height, 0) * 0.2)
                .rotationEffect(.degrees(Double(drag.width) / 22), anchor: .bottom)
                .gesture(swipe)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: drag)
    }

    /// Ce qu'on est en train de décider, écrit en grand dans le fond — au-dessus
    /// de la carte, jamais dessus.
    @ViewBuilder private var announcement: some View {
        if let leaning {
            VStack(spacing: 10) {
                Image(systemName: leaning == .keep ? "bookmark.fill" : "checkmark")
                    .font(.system(size: 34, weight: .semibold))
                Text(leaning == .keep ? "KEEP" : "I KNEW THIS")
                    .font(.system(size: 22, weight: .heavy))
                    .kerning(2)
            }
            .foregroundStyle(.white)
            // L'annonce n'apparaît qu'en approchant, et devient franche au
            // moment où le seuil est atteint.
            .opacity(progress)
            .scaleEffect(0.9 + progress * 0.1)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 90)
            .allowsHitTesting(false)
        }
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
        .shadow(color: .black.opacity(0.22), radius: 26, x: 0, y: 14)
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

