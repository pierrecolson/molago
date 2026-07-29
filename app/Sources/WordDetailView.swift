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
/// La forme suit celle des fiches de dictionnaire qui tiennent : un **pan de
/// couleur plein** porte le mot en tête, puis le contenu se lit en sections
/// sobres dessous. Le pan donne un visage à la fiche — sans lui, un mot centré
/// sur du gris flotte —, et c'est la grammaire du 단청 : couleur par surfaces,
/// filet clair à l'intérieur du bord, type blanc, aucune ombre.
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
            VStack(alignment: .leading, spacing: 22) {
                hero
                metSection
                if let family = word.family, !family.isEmpty { familySection(family) }
                footer
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 44)
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

    // ── le pan de couleur ────────────────────────────────────────────────────

    /// Le mot, son icône et son sens sur un seul pan plein.
    ///
    /// Aligné à gauche et non centré : centrer trois lignes de longueurs très
    /// différentes donne une pile molle, et le coréen — qui se lit à gauche —
    /// perd son point d'appui. L'icône occupe le coin opposé, ce qui tient la
    /// diagonale du bloc.
    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                if !word.pos.isEmpty {
                    Text(word.pos.uppercased())
                        .font(.caption2.weight(.bold))
                        .kerning(1.2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .overlay(Capsule().strokeBorder(.white.opacity(0.45), lineWidth: 1))
                }
                Spacer(minLength: 12)
                if word.icon != nil {
                    IconTile(icon: word.icon, lemma: word.lemma, slot: word.slot, size: 76)
                }
            }

            Spacer(minLength: 24)

            Text(word.lemma)
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.55)
                .lineLimit(1)

            Text(word.meaning)
                .font(.system(size: 19))
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .leading)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .dancheongKeyline(cornerRadius: 30)
        .padding(.top, 4)
    }

    // ── où on l'a rencontré ──────────────────────────────────────────────────

    private var metSection: some View {
        InsetSection(title: "Where you met it") {
            VStack(alignment: .leading, spacing: 0) {
                // La provenance vit ici, et nulle part ailleurs. Elle a été
                // retirée de la liste du carnet : savoir qu'un mot vient de
                // « tech » n'aide pas à le réviser. Sur la fiche, en revanche,
                // c'est ce qui permet de remonter au texte d'origine.
                HStack(spacing: 8) {
                    Image(Dancheong.universe(word.slot).icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 17, height: 17)
                        .frame(width: 25, height: 25)
                        .background(tint)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Text(Dancheong.universe(word.slot).name)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Dancheong.inkSoft)
                    Spacer()
                }
                .padding(.bottom, 12)

                // Le mot est mis en évidence dans sa phrase : c'est ce qui fait
                // le lien entre la fiche et le souvenir de la lecture.
                Text(highlighted(word.context, around: word.lemma))
                    .font(.system(size: 17))
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)

                // On teste seulement qu'une piste est référencée, pas qu'elle
                // est trouvable à l'instant du rendu : la vérification se fait
                // au moment de jouer. Sinon le bouton disparaît sur un détail
                // de chemin, sans explication.
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
                            .foregroundStyle(tint)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(tint.opacity(0.12), in: Capsule())
                    }
                    .padding(.top, 16)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// La phrase, avec le mot en gras et dans la couleur de son univers.
    ///
    /// Le coréen fléchit : 관리비 apparaît en 관리비를, 밝히다 en 밝혔다. On cherche
    /// donc la forme entière, puis à défaut le radical — le mot sans son 다 final.
    /// Si rien ne s'y trouve, la phrase reste telle quelle : mieux vaut pas de
    /// surlignage qu'un surlignage à côté.
    private func highlighted(_ sentence: String, around lemma: String) -> AttributedString {
        var out = AttributedString(sentence)
        let stem = lemma.count > 2 && lemma.hasSuffix("다") ? String(lemma.dropLast()) : lemma
        for needle in [lemma, stem] where !needle.isEmpty {
            if let range = out.range(of: needle) {
                out[range].font = .system(size: 17, weight: .semibold)
                out[range].foregroundColor = tint
                return out
            }
        }
        return out
    }

    // ── la famille de racine ─────────────────────────────────────────────────

    /// L'étage 3 du panneau de mot (spec §5.3).
    ///
    /// C'est là que le rangement mental se fait : découvrir que 관리자 et
    /// 관리하다, employés tous les jours, sont le même bloc que le mot sur lequel
    /// on séchait.
    ///
    /// Le caractère chinois reste **discret** : le lecteur ne lit pas le chinois,
    /// ce qu'on lui montre c'est le sens partagé. Le hanja est là pour ancrer,
    /// pas pour être appris.
    private func familySection(_ family: [Day.Relative]) -> some View {
        InsetSection(title: "Same root", trailing: word.hanja, tint: tint, note: word.root) {
            VStack(spacing: 0) {
                ForEach(Array(family.enumerated()), id: \.offset) { i, relative in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(relative.k)
                            .font(.system(size: 17, weight: .medium))
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
                    .padding(.vertical, 13)

                    if i < family.count - 1 {
                        Divider().padding(.leading, 18)
                    }
                }
            }
        }
    }

    private var footer: some View {
        Text(Self.keptLabel(word.keptAt))
            .font(.footnote)
            .foregroundStyle(Dancheong.inkSoft)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 10)
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

/// Un groupe encarté, comme dans Réglages : un titre discret au-dessus, le
/// contenu dans un bloc clair aux bords arrondis qui ne touche pas le bord de
/// l'écran. C'est ce qui fait qu'une suite de sections se lit comme des
/// paragraphes plutôt que comme un mur.
private struct InsetSection<Content: View>: View {
    let title: String
    var trailing: String? = nil
    var tint: Color = Dancheong.inkSoft
    var note: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .kerning(1.3)
                    .foregroundStyle(Dancheong.inkSoft)
                if let trailing {
                    Text(trailing)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(tint)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 4)

            if let note, !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(Dancheong.inkSoft)
                    .padding(.leading, 4)
                    .padding(.bottom, 2)
            }

            content
                .background(Dancheong.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
