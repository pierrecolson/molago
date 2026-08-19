import SwiftUI

/// La bibliothèque personnelle : trois imports riches, puis une archive calme.
struct HomeView: View {
    let items: [LibraryItem]
    /// La vidéo à ouvrir sans qu'on ait touché sa carte — celle qu'on vient
    /// d'ajouter.
    @Binding var opening: Day.Text?

    private var sections: (recent: [LibraryItem], older: [LibraryItem]) {
        LibrarySections.split(items)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Library")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Dancheong.ink)
                        .padding(.horizontal, 18)

                    if items.isEmpty {
                        ContentUnavailableView(
                            "Nothing here yet",
                            systemImage: "tray",
                            description: Text("Add a photo or YouTube video to start your library.")
                        )
                        .frame(minHeight: 440)
                    } else {
                        recentSection
                        if !sections.older.isEmpty { olderSection }
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .background(Dancheong.ground)
            .navigationTitle("Library")
            // Le titre vit dans le fil, pas dans une barre. Une barre de
            // navigation vide occupe une centaine de points en haut de l'écran
            // pour ne rien porter — ni bouton, ni retour : sur la bibliothèque,
            // c'est une carte entière de perdue. Écrit dans le fil, « Library »
            // garde sa taille, commence sous l'heure, et s'en va quand on
            // descend. `navigationTitle` reste posé : c'est lui qui nomme le
            // bouton de retour depuis le lecteur.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $opening) { ReaderView(text: $0) }
        }
        .tint(Dancheong.jangdan)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Recent")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sections.recent) { item in
                        NavigationLink { ReaderView(text: item.text) } label: {
                            ImportCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
            }
            .scrollClipDisabled()
        }
    }

    private var olderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Older")
            LazyVStack(spacing: 0) {
                ForEach(Array(sections.older.enumerated()), id: \.element.id) { index, item in
                    NavigationLink { ReaderView(text: item.text) } label: {
                        ImportRow(item: item)
                    }
                    .buttonStyle(.plain)
                    // Le filet part sous le titre, pas sous la vignette : il
                    // sépare des lignes, et les vignettes forment déjà leur
                    // propre colonne.
                    if index < sections.older.count - 1 { Divider().padding(.leading, 84) }
                }
            }
            .background(Dancheong.paper)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 18)
        }
    }
}

private struct SectionLabel: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(Dancheong.ink)
            .padding(.leading, 18)
    }
}

/// La couleur d'un import : celle de sa provenance, et rien d'autre.
private func importTint(_ text: Day.Text) -> Color {
    text.isYouTube ? Dancheong.jangdan : Dancheong.hayeop
}

/// La vignette d'un import — la photo prise, la miniature téléchargée, ou à
/// défaut le pictogramme de sa provenance.
///
/// Carte et ligne montrent la même image. C'est ce qui fait qu'un import
/// descendu dans `Older` reste reconnaissable : on l'a rangé en le voyant, on
/// le retrouve en le voyant, sans avoir à relire une pile de titres.
private struct Artwork: View {
    let text: Day.Text
    /// La taille du pictogramme de repli : une ligne d'archive n'a pas la place
    /// qu'a une carte.
    var glyph: Font = .title2

    var body: some View {
        if text.isPhoto,
           let url = Paths.captureImage(text.slot),
           let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let url = Paths.thumbnail(text.slot),
                  let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let remote = text.thumbnailURL {
            AsyncImage(url: remote) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                placeholder
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            importTint(text).opacity(0.18)
            Image(systemName: text.isYouTube ? "play.rectangle" : "photo")
                .font(glyph)
                .foregroundStyle(importTint(text))
        }
    }
}

/// Photo et YouTube partagent exactement ce gabarit.
private struct ImportCard: View {
    let item: LibraryItem

    private var tint: Color { importTint(item.text) }

    var body: some View {
        VStack(spacing: 0) {
            Artwork(text: item.text)
                .frame(width: 220, height: 124)
                .clipped()
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.text.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 2)

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
            }
            .padding(14)
            .frame(width: 220, height: 108, alignment: .topLeading)
            .background(tint)
        }
        .frame(width: 220, height: 232)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .dancheongKeyline(cornerRadius: 20)
        .shadow(color: .black.opacity(0.13), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        if item.text.isYouTube {
            return [item.text.sourceName, item.text.sentences.isEmpty ? "No transcript" : "Transcript ready"]
                .compactMap { $0 }.joined(separator: " · ")
        }
        return "Photo · \(item.text.meta)"
    }
}

private struct ImportRow: View {
    let item: LibraryItem

    var body: some View {
        HStack(spacing: 12) {
            Artwork(text: item.text, glyph: .footnote)
                .frame(width: 56, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.text.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Dancheong.ink)
                    .lineLimit(2)
                Text(item.text.isYouTube
                     ? ["YouTube", item.text.sourceName].compactMap { $0 }.joined(separator: " · ")
                     : "Photo")
                    .font(.caption)
                    .foregroundStyle(Dancheong.inkSoft)
            }

            Spacer(minLength: 8)

            Text(item.shortLabel)
                .font(.caption2)
                .foregroundStyle(Dancheong.inkSoft)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

/// Une ligne qui désigne le contenu où un mot a été rencontré.
struct SourceRow: View {
    let slot: String
    let title: String
    var trailing: String? = nil
    var chevron = false
    var padding: CGFloat = 15
    var verticalPadding: CGFloat = 11

    var body: some View {
        HStack(spacing: 12) {
            sourceArtwork
                .frame(width: 44, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.subheadline)
                .foregroundStyle(Dancheong.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 8)
            if let trailing {
                Text(trailing).font(.caption2).foregroundStyle(Dancheong.inkSoft)
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

    @ViewBuilder private var sourceArtwork: some View {
        if let url = Paths.captureImage(slot) ?? Paths.thumbnail(slot),
           let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Image(systemName: slot.hasPrefix("youtube-") ? "play.rectangle.fill" : "photo")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Dancheong.jangdan)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Dancheong.jangdan.opacity(0.1))
        }
    }
}
