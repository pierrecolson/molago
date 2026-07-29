import SwiftUI

/// L'accueil : ce qu'il y a à lire ce matin, puis tout le reste.
///
/// Deux bandes et une règle. **Aujourd'hui** défile horizontalement — les textes
/// du matin sont côte à côte, aucun plus important qu'un autre, et la quatrième
/// carte ne coûte rien à l'œil puisqu'on fait glisser. **Previously** est une
/// liste calme : ce qui est passé reste disponible sans réclamer l'attention de
/// ce qui vient d'arriver.
///
/// La règle : **un pan de couleur est un article, jamais un mot.** Elle vaut
/// pour tout l'écran, et c'est elle qui rend le carnet impossible à confondre
/// avec la bibliothèque d'un coup d'œil.
struct HomeView: View {
    let day: Day
    /// Les journées passées. Portées par le magasin : le rattrapage des journées
    /// manquantes finit après le premier rendu, et l'écran doit le voir arriver.
    let previously: [Day]

    @State private var morning = MorningCall()
    @State private var showingMorning = false
    @State private var search = ""
    @State private var capturesOnly = false

    /// Les textes du matin. La capture du jour n'y est pas : elle a sa bande.
    private var todayTexts: [Day.Text] {
        day.texts.filter { $0.slot != "capture" }
    }

    private var todayCaptures: [Day.Text] {
        day.texts.filter { $0.slot == "capture" }
    }

    /// Une ligne de « Previously » par texte, la plus récente d'abord.
    private var past: [PastItem] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return previously
            .filter { $0.date != day.date }
            .flatMap { d in d.texts.map { PastItem(day: d, text: $0) } }
            .filter { !capturesOnly || $0.text.slot == "capture" }
            .filter { q.isEmpty || $0.text.title.lowercased().contains(q) }
    }

    struct PastItem: Identifiable {
        let day: Day
        let text: Day.Text
        var id: String { "\(day.date)-\(text.slot)" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    todaySection
                    if !todayCaptures.isEmpty { captureSection }
                    previouslySection
                }
                .padding(.bottom, 32)
            }
            .background(Dancheong.ground)
            .navigationTitle(day.dayLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingMorning = true } label: { Image(systemName: "bell") }
                        .accessibilityLabel("Morning time")
                }
            }
            .sheet(isPresented: $showingMorning) {
                MorningSheet(morning: morning).presentationDetents([.height(300)])
            }
        }
        .tint(Dancheong.jangdan)
        .task {
            // Après que la journée s'est affichée, jamais avant : une app qui
            // réclame une permission sans avoir montré à quoi elle sert se fait
            // refuser, et iOS ne laisse pas redemander.
            await morning.enable()
        }
    }

    // ── aujourd'hui ──────────────────────────────────────────────────────────

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Today")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(todayTexts) { text in
                        NavigationLink { ReaderView(text: text) } label: {
                            UniverseCard(text: text)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
            }
            // Le défilement déborde volontairement des marges : une carte
            // coupée au bord dit « ça continue » mieux qu'un indicateur.
            .scrollClipDisabled()
        }
    }

    private var captureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(todayCaptures) { text in
                NavigationLink { ReaderView(text: text) } label: {
                    CaptureStrip(text: text)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
    }

    // ── previously ───────────────────────────────────────────────────────────

    private var previouslySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Previously", inset: false)
                Spacer()
                Picker("", selection: $capturesOnly) {
                    Text("All").tag(false)
                    Text("Captures").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 168)
            }
            .padding(.horizontal, 18)

            if past.isEmpty {
                Text(capturesOnly ? "Nothing captured yet." : "Yesterday's texts will show up here.")
                    .font(.footnote)
                    .foregroundStyle(Dancheong.inkSoft)
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(past) { item in
                        NavigationLink { ReaderView(text: item.text) } label: {
                            PastRow(item: item)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 66)
                    }
                }
                .background(Dancheong.paper)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 18)
            }
        }
    }
}

/// Un titre de bande.
///
/// Gros et gras, en casse normale — pas de petites capitales espacées : un titre
/// qui se lit d'un coup laisse le regard filer vers les cartes, une étiquette en
/// capitales grises se déchiffre et vole une seconde à ce qu'elle annonce.
///
/// `inset` existe parce que le titre est tantôt seul, tantôt dans une rangée qui
/// porte déjà la marge — et l'appliquer aux deux décalait « Previously » de deux
/// fois 18 points, ce qui se voyait immédiatement contre les cartes.
private struct SectionLabel: View {
    let title: String
    var inset = true
    init(_ title: String, inset: Bool = true) {
        self.title = title
        self.inset = inset
    }
    var body: some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(Dancheong.ink)
            .padding(.leading, inset ? 18 : 0)
    }
}

/// Un pan de couleur pleine. Pas une carte blanche portant une étiquette
/// colorée : la carte **est** la couleur.
private struct UniverseCard: View {
    let text: Day.Text

    private var universe: (color: Color, name: String, icon: String) {
        Dancheong.universe(text.slot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(universe.name.uppercased())
                .font(.caption2.weight(.heavy))
                .kerning(1.6)
                .foregroundStyle(.white.opacity(0.85))

            Text(text.title)
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 6)

            Text(text.meta)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
        }
        // Des cartes rigoureusement égales, quelle que soit la longueur du
        // titre : aucun texte du jour ne doit paraître plus important qu'un
        // autre (spec §4.3).
        .frame(width: 208, height: 176, alignment: .topLeading)
        .padding(16)
        .background(alignment: .bottomTrailing) {
            // L'icône de l'univers, posée dans le coin. Fixe : cinq icônes
            // qu'on reconnaît sans les lire valent mieux qu'une image
            // différente par article, qu'il faut déchiffrer.
            Image(universe.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .shadow(color: .black.opacity(0.22), radius: 9, x: 0, y: 4)
                .padding(11)
        }
        .background(universe.color)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .dancheongKeyline(cornerRadius: 22)
        // Posée sur le fond, pas incrustée dedans. Le 단청 interdit les ombres
        // DANS le pan — c'est peint à plat sur du bois — mais rien n'interdit
        // que la planche elle-même projette la sienne.
        .shadow(color: .black.opacity(0.16), radius: 14, x: 0, y: 7)
    }
}

/// La capture du jour : même famille que les cartes, volume réduit.
///
/// Elle est là, elle se lit comme un article, mais elle ne dispute pas
/// l'attention aux textes du matin — c'est une bande, pas un pan.
private struct CaptureStrip: View {
    let text: Day.Text

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CAPTURE")
                    .font(.caption2.weight(.heavy))
                    .kerning(1.5)
                    .foregroundStyle(.white.opacity(0.8))
                Text(text.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image("UniverseCapture")
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Dancheong.jaju)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

/// Une ligne de « Previously ». Pas de pan de couleur : un carré qui porte
/// l'icône de sa provenance, et c'est tout ce qu'il faut pour la reconnaître.
private struct PastRow: View {
    let item: HomeView.PastItem

    private var universe: (color: Color, name: String, icon: String) {
        Dancheong.universe(item.text.slot)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(universe.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .frame(width: 36, height: 36)
                .background(universe.color)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(item.text.title)
                .font(.subheadline)
                .foregroundStyle(Dancheong.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            Text(item.day.shortLabel)
                .font(.caption2)
                .foregroundStyle(Dancheong.inkSoft)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

/// Le seul réglage de l'app : à quelle heure elle vous dit qu'il y a à lire.
private struct MorningSheet: View {
    @Bindable var morning: MorningCall
    @Environment(\.dismiss) private var dismiss

    private var time: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    from: DateComponents(hour: morning.hour, minute: morning.minute)
                ) ?? Date()
            },
            set: { new in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: new)
                morning.hour = parts.hour ?? 7
                morning.minute = parts.minute ?? 0
            }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                Text(morning.isAuthorized
                     ? "One notification a day, and nothing else. It tells you the texts are there \u{2014} it never asks you for anything."
                     : "Notifications are off. Turn them on in Settings if you want Molago to tell you when the morning texts arrive.")
                    .font(.footnote)
                    .foregroundStyle(Dancheong.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Dancheong.ground)
            .navigationTitle("Every morning at " + morning.timeLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
