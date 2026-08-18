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
                if items.isEmpty {
                    ContentUnavailableView(
                        "Nothing here yet",
                        systemImage: "tray",
                        description: Text("Add a photo or YouTube video to start your library.")
                    )
                    .frame(minHeight: 520)
                } else {
                    VStack(alignment: .leading, spacing: 34) {
                        recentSection
                        if !sections.older.isEmpty { olderSection }
                    }
                    .padding(.bottom, 32)
                }
            }
            .background(Dancheong.ground)
            .navigationTitle("Library")
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
        .padding(.top, 8)
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
                    if index < sections.older.count - 1 { Divider().padding(.leading, 16) }
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

/// Photo et YouTube partagent exactement ce gabarit.
private struct ImportCard: View {
    let item: LibraryItem

    private var tint: Color { item.text.isYouTube ? Dancheong.jangdan : Dancheong.hayeop }

    var body: some View {
        VStack(spacing: 0) {
            artwork
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

    @ViewBuilder private var artwork: some View {
        if item.text.isPhoto,
           let url = Paths.captureImage(item.text.slot),
           let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let url = Paths.thumbnail(item.text.slot),
                  let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let remote = item.text.thumbnailURL {
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
            tint.opacity(0.18)
            Image(systemName: item.text.isYouTube ? "play.rectangle" : "photo")
                .font(.title2)
                .foregroundStyle(tint)
        }
    }
}

private struct ImportRow: View {
    let item: LibraryItem

    var body: some View {
        HStack(spacing: 12) {
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
