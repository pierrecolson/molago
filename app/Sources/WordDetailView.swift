import SwiftUI
import SwiftData

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
    @State private var confirmingDelete = false
    @State private var opening: Day.Text?
    @State private var previewing: Day.Relative?
    @State private var loadingRoots = false
    @State private var rootsFailed = false

    /// Le texte d'où vient le mot, s'il est encore sur l'appareil.
    ///
    /// Les journées finissent purgées du serveur : la fiche doit continuer
    /// d'afficher le titre quand le texte a disparu, elle perd seulement le lien.
    private var sourceText: Day.Text? {
        let items = DayStore.cachedItems()
        if let text = items.first(where: { $0.text.slot == word.slot })?.text { return text }
        // Les mots gardés avant que le titre soit enregistré n'en ont pas. On
        // les rattrape par leur phrase, qui est unique : plutôt que de leur
        // afficher « Tech » pour toujours, on retrouve le texte qui la contient.
        guard !word.context.isEmpty else { return nil }
        return items.map(\.text).first { text in
            text.sentences.contains { $0.ko == word.context }
        }
    }

    /// Le titre à montrer : celui qu'on a enregistré, sinon celui du texte
    /// retrouvé, et en dernier recours le nom de l'univers.
    private var sourceLabel: String {
        word.sourceTitle ?? sourceText?.title ?? Dancheong.universe(word.slot).name
    }

    private var tint: Color { Dancheong.universe(word.slot).color }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                // Un mot pris dans une famille n'a été rencontré nulle part :
                // on l'a croisé en regardant les cousins d'un autre. Le bloc
                // disparaît plutôt que d'inventer un contexte ou d'en montrer
                // un vide.
                if !word.context.isEmpty { metSection }
                if let morphemes = word.morphemes, !morphemes.isEmpty {
                    morphemeSection(morphemes)
                } else if loadingRoots || rootsFailed {
                    rootsState
                }
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
                    Button("Remove from Wordbook", systemImage: "trash", role: .destructive) {
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
        .navigationDestination(item: $opening) { ReaderView(text: $0, startAt: word.sourceTime) }
        .sheet(item: $previewing) { RelativeSheet(relative: $0, slot: word.slot) }
        .task { await enrichIfNeeded() }
    }

    // ── le mot ───────────────────────────────────────────────────────────────

    /// Le mot, sur du papier.
    ///
    /// Il était posé sur un pan de la couleur de son univers, et c'était faux :
    /// 영역 a été croisé dans un texte tech, mais ce n'est pas un mot tech —
    /// c'est un mot de la langue, qui resservira ailleurs. Le teindre en bleu
    /// enfermait le mot dans le hasard de sa première rencontre.
    ///
    /// La couleur redescend donc là où elle dit vrai : dans « où tu l'as
    /// rencontré », qui parle bien, lui, de ce texte-là. Ici il ne reste que le
    /// mot, en grand, sur le papier de lecture — et c'est aussi ce qui rend une
    /// fiche de mot impossible à confondre avec une carte d'article.
    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !word.pos.isEmpty {
                Text(word.pos.uppercased())
                    .font(.caption2.weight(.bold))
                    .kerning(1.2)
                    .foregroundStyle(Dancheong.inkSoft)
            }

            Text(word.lemma)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Dancheong.ink)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .padding(.top, 2)

            Text(word.meaning)
                .font(.system(size: 19))
                .foregroundStyle(Dancheong.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    // ── où on l'a rencontré ──────────────────────────────────────────────────

    private var metSection: some View {
        InsetSection(title: "Where you met it", tint: tint) {
            VStack(alignment: .leading, spacing: 0) {
                // Le même composant que dans « Previously » : les deux
                // désignent un texte, et le dire de deux façons obligeait à
                // réapprendre le même objet d'un écran à l'autre.
                Button { opening = sourceText } label: {
                    SourceRow(slot: word.slot,
                              title: sourceLabel,
                              chevron: sourceText != nil,
                              padding: 0, verticalPadding: 0)
                }
                .buttonStyle(.plain)
                .disabled(sourceText == nil)
                .padding(.bottom, 10)

                // Le mot est mis en évidence dans sa phrase : c'est ce qui fait
                // le lien entre la fiche et le souvenir de la lecture.
                Text(highlighted(word.context, around: word.lemma))
                    .font(.system(size: 17))
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)

                if sourceText?.isYouTube == true, let time = word.sourceTime {
                    Button {
                        opening = sourceText
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(tint)
                                .frame(width: 30, height: 30)
                                .background(tint.opacity(0.12), in: Circle())

                            Text(Self.timeLabel(time))
                                .font(.footnote.weight(.medium).monospacedDigit())
                                .foregroundStyle(Dancheong.inkSoft)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Play from \(Self.timeLabel(time))")
                    .padding(.top, 8)
                }
            }
            // Le contenu respire à l'intérieur du bloc. Ce rembourrage avait été
            // emporté en supprimant le bouton d'écoute qui le suivait, et le
            // texte s'est retrouvé collé aux bords sans que rien ne le signale :
            // le bloc existait toujours, il était seulement vide de marge.
            .padding(16)
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

    private func morphemeSection(_ morphemes: [Day.Morpheme]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How it’s built")
                .font(.title3.weight(.bold))
                .padding(.leading, 4)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 8)], spacing: 8) {
                ForEach(morphemes) { morpheme in
                    VStack(spacing: 3) {
                        Text(morpheme.k)
                            .font(.title2.weight(.semibold))
                        Text(morpheme.h)
                            .font(.body)
                            .foregroundStyle(tint)
                        Text(morpheme.e)
                            .font(.caption)
                            .foregroundStyle(Dancheong.inkSoft)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 104, alignment: .top)
                    .background(Dancheong.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            if let literal = word.literal, !literal.isEmpty {
                Text("Literally: \(literal)")
                    .font(.subheadline)
                    .foregroundStyle(Dancheong.inkSoft)
                    .padding(.leading, 4)
            }
        }
    }

    @ViewBuilder private var rootsState: some View {
        InsetSection(title: "How it’s built") {
            HStack(spacing: 12) {
                if loadingRoots {
                    ProgressView()
                    Text("Looking for word roots…")
                        .foregroundStyle(Dancheong.inkSoft)
                } else {
                    Text("Word roots aren’t available right now.")
                        .foregroundStyle(Dancheong.inkSoft)
                    Spacer(minLength: 8)
                    Button("Try again") {
                        Task { await enrichIfNeeded(force: true) }
                    }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                }
            }
            .font(.subheadline)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        }
    }

    @MainActor
    private func enrichIfNeeded(force: Bool = false) async {
        guard force || (word.morphemes?.isEmpty != false && word.family?.isEmpty != false) else { return }
        loadingRoots = true
        rootsFailed = false
        defer { loadingRoots = false }
        do {
            let enrichment = try await WordLookup.fetch(word.lemma, context: word.context)
            word.applyEnrichment(enrichment)
            try context.save()
        } catch {
            rootsFailed = true
        }
    }

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
        let enrichment = Day.Word(
            w: word.lemma,
            lemma: word.lemma,
            pos: word.pos,
            en: word.meaning,
            hanja: word.hanja,
            literal: word.literal,
            morphemes: word.morphemes,
            root: word.root,
            family: family
        )
        let shared = WordRoots.shared(in: enrichment)

        return InsetSection(
            title: "Same root",
            trailing: shared.map { "\($0.korean) · \($0.hanja)" },
            tint: tint,
            note: shared?.meaning ?? word.root
        ) {
            VStack(spacing: 0) {
                ForEach(Array(family.enumerated()), id: \.offset) { i, relative in
                    Button { previewing = relative } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(highlighted(relative, shared: shared))
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Dancheong.ink)
                            Spacer(minLength: 12)
                            Text(relative.e)
                                .font(.subheadline)
                                .foregroundStyle(Dancheong.inkSoft)
                                .multilineTextAlignment(.trailing)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Dancheong.inkSoft)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if i < family.count - 1 { Divider().padding(.leading, 18) }
                }
            }
        }
    }

    private func highlighted(_ relative: Day.Relative, shared: WordRoots.Shared?) -> AttributedString {
        var output = AttributedString(relative.k)
        guard let shared,
              let hanja = relative.h,
              let hanjaIndex = hanja.firstIndex(of: Character(shared.hanja)),
              let koreanIndex = relative.k.index(
                relative.k.startIndex,
                offsetBy: hanja.distance(from: hanja.startIndex, to: hanjaIndex),
                limitedBy: relative.k.endIndex
              ),
              koreanIndex < relative.k.endIndex,
              let range = output.range(of: String(relative.k[koreanIndex])) else { return output }
        output[range].foregroundColor = tint
        output[range].font = .system(size: 17, weight: .bold)
        return output
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Text(Self.keptLabel(word.keptAt))
                .font(.footnote)
                .foregroundStyle(Dancheong.inkSoft)
            Button("Remove from Wordbook", systemImage: "trash", role: .destructive) {
                confirmingDelete = true
            }
            .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    private static func timeLabel(_ seconds: Double) -> String {
        String(format: "%02d:%02d", Int(seconds) / 60, Int(seconds) % 60)
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
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Dancheong.ink)
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

/// Un mot croisé dans une famille, qu'on peut garder au passage.
///
/// Il n'a pas de « où tu l'as rencontré » : on ne l'a rencontré nulle part, on
/// l'a croisé en regardant la famille d'un autre. Lui inventer un contexte
/// serait mentir, et un bloc vide serait pire — la fiche montre donc seulement
/// ce qu'elle sait, et propose de le prendre.
private struct RelativeSheet: View {
    let relative: Day.Relative
    let slot: String

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var existing: [KeptWord]

    private var alreadyKept: Bool { existing.contains { $0.lemma == relative.k } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let h = relative.h {
                Text(h)
                    .font(.system(size: 22))
                    .foregroundStyle(Dancheong.universe(slot).color.opacity(0.5))
            }
            Text(relative.k)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Dancheong.ink)
            Text(relative.e)
                .font(.system(size: 18))
                .foregroundStyle(Dancheong.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 18)

            Button {
                context.insert(KeptWord(
                    lemma: relative.k, meaning: relative.e, pos: "", icon: nil,
                    // Pas de phrase : ce mot n'a pas encore été lu quelque part.
                    // La fiche le dira en n'affichant rien plutôt qu'en inventant.
                    context: "", contextAudio: nil, hanja: relative.h,
                    root: nil, family: nil, slot: slot
                ))
                try? context.save()
                dismiss()
            } label: {
                Label(alreadyKept ? "Already in your Wordbook" : "Keep this word",
                      systemImage: alreadyKept ? "checkmark" : "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Dancheong.universe(slot).color, in: Capsule())
            }
            .disabled(alreadyKept)
            .opacity(alreadyKept ? 0.5 : 1)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Dancheong.ground)
        .presentationDetents([.height(320)])
    }
}
