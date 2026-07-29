import SwiftUI

/// L'accueil : ce qu'il y a à lire ce matin, puis tout le reste.
///
/// Trois bandes et une règle. **Aujourd'hui** défile horizontalement — les
/// textes du matin sont côte à côte, aucun plus important qu'un autre. **My
/// content** rassemble ce que l'utilisateur a capturé lui-même, tous jours
/// confondus : c'est le sien, il ne doit pas se noyer dans le fil. **Previously**
/// est une liste calme : ce qui est passé reste disponible sans réclamer
/// l'attention de ce qui vient d'arriver.
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

    /// Les textes du matin. Les captures n'y sont pas : elles ont leur bande.
    ///
    /// `hasPrefix` et non l'égalité : chaque capture porte un identifiant
    /// unique — `capture-ms5z0tto` — et l'égalité stricte ne trouvait jamais
    /// rien. C'est le bug qui rendait l'ancien filtre All/Captures inerte.
    private var todayTexts: [Day.Text] {
        day.texts.filter { !$0.slot.hasPrefix("capture") }
    }

    /// Tout ce que l'utilisateur a capturé lui-même, tous jours confondus,
    /// le plus récent d'abord.
    private var myContent: [PastItem] {
        ([day] + previously.filter { $0.date != day.date })
            .flatMap { d in
                d.texts.filter { $0.slot.hasPrefix("capture") }
                    .map { PastItem(day: d, text: $0) }
            }
    }

    /// Une ligne de « Previously » par texte du matin, la plus récente d'abord.
    /// Les captures n'y sont plus : elles vivent dans « My content ».
    private var past: [PastItem] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return previously
            .filter { $0.date != day.date }
            .flatMap { d in d.texts.map { PastItem(day: d, text: $0) } }
            .filter { !$0.text.slot.hasPrefix("capture") }
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
                    // Rien capturé : pas de bande vide qui réclame — la section
                    // apparaît avec la première capture.
                    if !myContent.isEmpty { myContentSection }
                    previouslySection
                }
                .padding(.bottom, 32)
            }
            .background(Dancheong.ground)
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
            SectionLabel("Today", date: day.shortLabel)
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

    // ── my content ───────────────────────────────────────────────────────────

    private var myContentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("My content")
            VStack(spacing: 8) {
                ForEach(myContent) { item in
                    NavigationLink { ReaderView(text: item.text) } label: {
                        CaptureRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    // ── previously ───────────────────────────────────────────────────────────

    private var previouslySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Previously")

            if past.isEmpty {
                Text("Yesterday's texts will show up here.")
                    .font(.footnote)
                    .foregroundStyle(Dancheong.inkSoft)
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(past.enumerated()), id: \.element.id) { i, item in
                        NavigationLink { ReaderView(text: item.text) } label: {
                            PastRow(item: item)
                        }
                        .buttonStyle(.plain)
                        // Entre les lignes, jamais après la dernière : un filet
                        // qui pend sous le bloc annonce une ligne qui n'existe pas.
                        if i < past.count - 1 { Divider().padding(.leading, 16) }
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
    var date: String? = nil
    var inset = true
    init(_ title: String, date: String? = nil, inset: Bool = true) {
        self.title = title
        self.date = date
        self.inset = inset
    }
    var body: some View {
        // La date se range derrière le mot, en gris, sur la même ligne.
        //
        // Elle occupait une barre à elle en capitales centrées — MARDI 28 JUILLET
        // — ce qui donnait à un simple repère le poids d'un titre. Le titre, lui,
        // est « Today » : c'est ce qu'on vient chercher. La date le précise sans
        // le disputer, et une barre entière disparaît de l'écran.
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Dancheong.ink)
            if let date {
                Text(date)
                    .font(.title3)
                    .foregroundStyle(Dancheong.inkSoft)
            }
        }
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
            // L'icône de l'univers, en grand dans le coin. Fixe : cinq icônes
            // qu'on reconnaît sans les lire valent mieux qu'une image
            // différente par article, qu'il faut déchiffrer.
            //
            // Elle déborde volontairement du bord et le découpage la rogne :
            // c'est ce rognage qui lui permet d'être un vrai pan de l'image
            // sans voler la place du titre ni grandir la carte.
            Image(universe.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .shadow(color: .black.opacity(0.22), radius: 9, x: 0, y: 4)
                .offset(x: 14, y: 14)
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

/// Une capture dans « My content » : la vignette du document, son titre, son jour.
///
/// La vignette montre le document photographié lui-même, pas une icône : ce
/// contenu vient de la vie de celui qui lit, et c'est en reconnaissant SA
/// facture ou SON avis de copropriété qu'il le retrouve. Le liseré pourpre
/// reste la marque de ce qui vient de lui (자주, comme partout dans l'app).
private struct CaptureRow: View {
    let item: HomeView.PastItem

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            Text(item.text.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Dancheong.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            Text(item.day.shortLabel)
                .font(.caption2)
                .foregroundStyle(Dancheong.inkSoft)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Dancheong.paper)
        // Le liseré est posé avant le découpage : c'est lui qui épouse l'arrondi.
        .overlay(alignment: .leading) { Dancheong.jaju.frame(width: 5) }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// La photo réduite, ou l'icône de capture quand il n'y a pas de photo
    /// (une capture peut arriver par le partage de texte, sans image).
    @ViewBuilder
    private var thumbnail: some View {
        if let url = Paths.captureImage(item.text.slot),
           let image = UIImage(contentsOfFile: url.path()) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Image("UniverseCapture")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .frame(width: 44, height: 44)
                .background(Dancheong.jaju, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

/// Une ligne de « Previously » : le titre et le jour, rien d'autre.
///
/// Plus d'icône d'univers à gauche : dans une liste où chaque ligne en portait
/// une, elles ne distinguaient plus rien — elles faisaient du bruit. Le titre
/// et la date suffisent, et l'œil file plus droit.
private struct PastRow: View {
    let item: HomeView.PastItem
    var body: some View {
        HStack(spacing: 12) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

/// La ligne qui désigne un texte : son icône d'univers dans un carré de sa
/// couleur, son titre, et de quoi le situer à droite.
///
/// Un seul composant pour les deux endroits où l'on désigne un texte — les
/// lignes de « Previously » et la provenance d'un mot. Ils disaient la même
/// chose de deux façons différentes, ce qui obligeait à réapprendre le même
/// objet d'un écran à l'autre.
struct SourceRow: View {
    let slot: String
    let title: String
    var trailing: String? = nil
    var chevron = false
    /// La marge autour de la ligne. Réglable plutôt qu'annulée après coup : la
    /// fiche du mot l'avait mise à zéro avec un rembourrage négatif, ce qui
    /// collait l'icône au bord du bloc au lieu de la poser dedans.
    ///
    /// Les deux axes se règlent séparément parce qu'ils ne servent pas la même
    /// chose : dans une liste, la marge verticale sépare deux lignes ; dans un
    /// bloc qui a déjà la sienne, elle s'y ajoute et creuse un trou en haut.
    var padding: CGFloat = 15
    var verticalPadding: CGFloat = 11

    private var universe: (color: Color, name: String, icon: String) {
        Dancheong.universe(slot)
    }

    var body: some View {
        HStack(spacing: 12) {
            // La forme est donnée AVEC le fond, et non découpée après : posé
            // dans un bouton, un découpage séparé se fait écraser en rond par le
            // style que le système applique aux commandes.
            Image(universe.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .frame(width: 36, height: 36)
                .background(universe.color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(title)
                .font(.subheadline)
                .foregroundStyle(Dancheong.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            if let trailing {
                Text(trailing)
                    .font(.caption2)
                    .foregroundStyle(Dancheong.inkSoft)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Dancheong.inkSoft)
            }
        }
        .padding(.horizontal, padding)
        .padding(.vertical, verticalPadding)
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
