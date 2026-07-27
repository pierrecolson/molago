import SwiftUI
import SwiftData
import AVFoundation

/// La fiche d'un mot du carnet (spec §5.6).
///
/// Ce qu'on y trouve tient en une phrase : **le mot, ce qu'il veut dire, et
/// l'endroit où on l'a rencontré.** Cette dernière partie fait le travail — un
/// mot sans sa phrase redevient une ligne de liste de vocabulaire, et c'est
/// exactement ce que ce produit refuse.
///
/// La phrase se réécoute. On l'a entendue une fois en lisant ; la réentendre
/// avec le mot déjà en tête est un autre exercice, et il ne coûte rien puisque
/// la piste est déjà sur l'appareil.
///
/// La jauge de confiance à quatre paliers décrite en §5.6 n'y est pas encore :
/// elle demande l'auto-évaluation **et** l'estimation du système, et le moteur
/// n'estime rien tant qu'il n'a pas de profil de vocabulaire.
struct WordDetailView: View {
    let word: KeptWord

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var confirmingDelete = false

    private var tint: Color { Dancheong.universe(word.slot).color }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                IconTile(icon: word.icon, lemma: word.lemma, slot: word.slot, size: 88)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)

                Text(word.lemma)
                    .font(.system(size: 40, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)

                Text(word.meaning)
                    .font(.title3)
                    .foregroundStyle(Dancheong.inkSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)

                if !word.pos.isEmpty {
                    Text(word.pos.uppercased())
                        .font(.caption2.weight(.bold))
                        .kerning(1.2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(tint, in: Capsule())
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 12)
                }

                sectionTitle("WHERE YOU MET IT")

                VStack(alignment: .leading, spacing: 0) {
                    Text(word.context)
                        .font(.body)
                        .lineSpacing(7)
                        .fixedSize(horizontal: false, vertical: true)

                    // On teste seulement qu'une piste est référencée, pas
                    // qu'elle est trouvable à l'instant du rendu : la
                    // vérification se fait au moment de jouer. Sinon le bouton
                    // disparaît sur un détail de chemin, sans explication.
                    if word.contextAudio != nil {
                        Button {
                            guard let name = word.contextAudio,
                                  let url = Paths.audioFile(name) else { return }
                            let item = AVPlayer(url: url)
                            player = item
                            item.play()
                        } label: {
                            Label("Hear it again", systemImage: "speaker.wave.2.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 11)
                                .background(tint, in: Capsule())
                        }
                        .padding(.top, 16)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Dancheong.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if let family = word.family, !family.isEmpty {
                    familySection(family)
                }

                Text(Self.keptLabel(word.keptAt) + " · " + word.slot)
                    .font(.footnote)
                    .foregroundStyle(Dancheong.inkSoft)
                    .padding(.top, 34)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Fond gris, blocs clairs : c'est ce contraste qui fait exister les
        // sections. Sur un fond clair uniforme, un bloc clair ne se voit pas.
        .background(Dancheong.ground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Remove from Notebook", systemImage: "trash", role: .destructive) {
                        confirmingDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .confirmationDialog("Remove \(word.lemma)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                context.delete(word)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("It stays in the texts you've read — you just won't see it here.")
        }
        .onDisappear { player?.pause() }
    }

    /// La famille de racine — l'étage 3 du panneau de mot (spec §5.3).
    ///
    /// C'est là que le rangement mental se fait : découvrir que 관리자 et
    /// 관리하다, employés tous les jours, sont le même bloc que le mot sur lequel
    /// on séchait.
    ///
    /// Le caractère chinois reste **discret** : le lecteur ne lit pas le chinois,
    /// ce qu'on lui montre c'est le sens partagé. Le hanja est là pour ancrer,
    /// pas pour être appris.
    @ViewBuilder
    private func familySection(_ family: [Day.Relative]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                sectionTitle("SAME ROOT")
                if let hanja = word.hanja {
                    Text(hanja)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(tint)
                }
                Spacer(minLength: 0)
            }

            if let root = word.root, !root.isEmpty {
                Text(root)
                    .font(.subheadline)
                    .foregroundStyle(Dancheong.inkSoft)
                    .padding(.bottom, 12)
            }

            // Un bloc encarté, comme les groupes de Réglages : le filet ne va
            // pas jusqu'au bord, et la famille se lit comme une liste tenue
            // ensemble plutôt que comme des lignes empilées.
            VStack(spacing: 0) {
                ForEach(Array(family.enumerated()), id: \.offset) { i, relative in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(relative.k)
                            .font(.body.weight(.medium))
                        if let h = relative.h {
                            Text(h)
                                .font(.caption)
                                .foregroundStyle(tint.opacity(0.7))
                        }
                        Spacer(minLength: 12)
                        Text(relative.e)
                            .font(.subheadline)
                            .foregroundStyle(Dancheong.inkSoft)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)

                    if i < family.count - 1 {
                        Divider().padding(.leading, 18)
                    }
                }
            }
            .background(Dancheong.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.top, 34)
    }

    /// Le titre d'une section, dans la graisse et l'espacement des groupes iOS.
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .kerning(1.3)
            .foregroundStyle(Dancheong.inkSoft)
            .padding(.bottom, 10)
    }

    private static func keptLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Kept today" }
        if calendar.isDateInYesterday(date) { return "Kept yesterday" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "'Kept on' EEEE d MMMM"
        return f.string(from: date)
    }
}
