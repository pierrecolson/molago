import SwiftUI
import SwiftData
import PhotosUI
@preconcurrency import Translation

/// Photographier, voir, toucher.
///
/// L'écran précédent montrait une liste de mots détachée de la photo : il
/// fallait relire le papier pour savoir de quoi on parlait, et décider vingt
/// fois de suite avant d'avoir rien vu. Ici la photo **reste** le sujet. Les
/// mots qui valent la peine s'allument dessus, à leur place, et il suffit d'en
/// toucher un.
///
/// C'est le geste de Live Text, qu'on connaît déjà d'iOS — mais avec la
/// décision de Molago par-dessus : garder, ou laisser.
struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    /// Comment on s'en va. Vide quand l'écran est présenté par-dessus, rempli
    /// quand il EST un onglet — auquel cas il n'y a rien à refermer, il faut
    /// rendre la main à la section d'où l'on vient.
    var onClose: (() -> Void)?

    private func close() { if let onClose { onClose() } else { dismiss() } }
    @Environment(\.modelContext) private var context
    @Query private var notebook: [KeptWord]

    @State private var flow = CaptureFlow()
    @State private var picking: PhotosPickerItem?
    @State private var shooting = false
    @State private var chosen: CaptureFlow.Word?
    @State private var youtubeURL = ""
    /// La vidéo prête à ajouter : ce qui a été collé, une fois reconnu.
    @State private var pastedVideo: (url: String, id: String)?
    /// Vrai quand le presse-papiers contient probablement une adresse. Su sans
    /// l'avoir lu — donc sans rien demander à personne.
    @State private var clipboardLooksLikeALink = false
    @State private var translationConfiguration = TranslationSession.Configuration(
        source: Locale.Language(identifier: "ko"),
        target: Locale.Language(identifier: "en")
    )
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Ce qui a été gardé pendant cette capture — pour le compte et pour la
    /// remontée au serveur. Le carnet, lui, est déjà écrit.
    @State private var kept: [CaptureFlow.Word] = []

    var body: some View {
        ZStack {
            switch flow.step {
            case .choosing:
                chooser
            case .reading:
                waiting("Reading the photo…")
            case .filing:
                waiting("Putting it in order…")
            case .importingVideo:
                waiting("Fetching the captions…", detail: "This takes a few seconds.")
            case .translatingVideo:
                translating
            case .filed(let title):
                filed(title)
            case .nothing(let message):
                empty(message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backdrop)
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: chosen)
        .task {
            // `simctl` ne sait pas choisir une photo dans le sélecteur. Pour
            // rejouer un plantage signalé sur une image précise, on la dépose
            // dans le conteneur de l'app et on la passe ici : c'est exactement
            // le chemin de la vraie capture, à la sélection près.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "--capture"), i + 1 < args.count,
               let data = try? Data(contentsOf: URL(fileURLWithPath: args[i + 1])) {
                print("[molago] capture d'essai : \(data.count / 1024) Ko")
                await flow.read(data: data)
                print("[molago] capture d'essai terminée")
            }
            if let i = args.firstIndex(of: "--youtube"), i + 1 < args.count {
                print("[molago] import d'essai : \(args[i + 1])")
                youtubeURL = args[i + 1]
                recogniseTypedLink()
                importVideo()
            }
        }
        .task(id: picking) {
            guard let picking,
                  let data = try? await picking.loadTransferable(type: Data.self) else { return }
            await flow.read(data: data)
        }
        // Relancé à chaque vidéo prête. La traduction reprend où elle en était,
        // donc une relance de SwiftUI ne coûte au pire qu'un lot.
        .onChange(of: flow.readyToTranslate) { translationConfiguration.invalidate() }
        .translationTask(translationConfiguration) { session in
            guard flow.awaitingTranslation != nil else { return }
            // Déclenche le téléchargement des langues, avec sa demande système,
            // plutôt que de le laisser surprendre le premier lot. L'échec n'est
            // pas traité ici : le lot suivant rendra la même erreur, une fois.
            try? await session.prepareTranslation()
            await flow.translateAwaiting { lines in
                try await Self.translate(lines, with: session)
            }
        }
        .fullScreenCover(isPresented: $shooting) {
            Camera { image in
                shooting = false
                Task { await flow.read(image) }
            }
            .ignoresSafeArea()
        }
    }

    /// Un fond noir sous une photo : c'est ce qui la laisse être elle-même.
    /// Le fond 호분 revient dès qu'il n'y a plus d'image à regarder.
    private var backdrop: some View {
        Group {
            Dancheong.ground
        }
        .ignoresSafeArea()
    }

    // ── 1. d'où vient le texte ───────────────────────────────────────────────

    /// Le lien d'abord.
    ///
    /// L'écran précédent posait deux pavés « photo » en haut et laissait le
    /// champ YouTube sous eux, gris et large de rien — alors que coller un lien
    /// est le geste le plus fréquent. Ici c'est lui le pan peint, et il porte
    /// l'orange sous lequel ces imports rangent dans la bibliothèque : la
    /// couleur dit déjà où l'on va.
    ///
    /// Le contenu part du HAUT. Avant, tout était tassé contre la barre
    /// d'onglets, titre compris — on lisait vers le haut et on touchait vers le
    /// bas.
    private var chooser: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                CloseButton(onDark: false) { close() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text("Add to your library")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Dancheong.inkSoft)
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Dancheong.ink)
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(Dancheong.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 22)

            if let video = pastedVideo {
                pastedCard(video)
            } else {
                linkPanel
            }

            Text("Or catch it on paper")
                .font(.caption2.weight(.semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Dancheong.inkSoft)
                .padding(.horizontal, 24)
                .padding(.top, 26)
                .padding(.bottom, 10)

            HStack(spacing: 12) {
                Button { shooting = true } label: {
                    PaperTile(title: "Take a photo", icon: "camera.fill")
                }
                PhotosPicker(selection: $picking, matching: .images, photoLibrary: .shared()) {
                    PaperTile(title: "Choose a photo", icon: "photo.on.rectangle.angled")
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .task { await lookAtTheClipboard() }
    }

    /// Le pan à coller.
    ///
    /// Le bouton est celui du système (`PasteButton`) et pas un bouton à nous :
    /// lui seul lit le presse-papiers **sans** la demande modale « Molago
    /// voudrait coller depuis Safari ». Lire tout seul à l'ouverture de l'écran
    /// la faisait apparaître à chaque fois — un carton en travers de l'écran
    /// pour un lien qu'on n'a peut-être même pas copié.
    private var linkPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                TextField("youtube.com/watch?v=…", text: $youtubeURL)
                    .accessibilityLabel("YouTube video URL")
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit { importVideo() }
                    .onChange(of: youtubeURL) { recogniseTypedLink() }
                    .foregroundStyle(Dancheong.ink)
                    .padding(.leading, 14)

                if hasLink {
                    Button("Add") { importVideo() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Dancheong.jangdan, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(4)
                } else {
                    PasteButton(payloadType: String.self) { items in
                        guard let copied = items.first else { return }
                        MainActor.assumeIsolated {
                            youtubeURL = copied.trimmingCharacters(in: .whitespacesAndNewlines)
                            recogniseTypedLink()
                        }
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonBorderShape(.capsule)
                    .tint(Dancheong.jangdan)
                    .padding(.trailing, 6)
                }
            }
            .frame(height: 52)
            .background(Dancheong.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(13)
        .background(Dancheong.jangdan, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .dancheongKeyline(cornerRadius: 20)
        .padding(.horizontal, 20)
    }

    /// Le lien reconnu, montré avant de dépenser quoi que ce soit.
    ///
    /// La vignette vient de l'adresse publique de YouTube — aucun appel d'API,
    /// aucun crédit dépensé. Le titre, lui, n'arrive qu'avec le transcript :
    /// l'app ne connaît toujours qu'une seule adresse, celle du serveur.
    private func pastedCard(_ clip: (url: String, id: String)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: "https://i.ytimg.com/vi/\(clip.id)/hqdefault.jpg")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Dancheong.separator
                }
                .frame(width: 108, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(alignment: .center) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .shadow(radius: 3)
                }

                // L'identifiant seul ne dit rien à personne : c'est la vignette
                // qui fait reconnaître la vidéo. Le lien n'est là que pour
                // confirmer que c'est bien celui qu'on a copié.
                Text("youtu.be/\(clip.id)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Dancheong.inkSoft)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }

            Button {
                youtubeURL = clip.url
                importVideo()
            } label: {
                Text("Add this video")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Dancheong.jangdan, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .dancheongKeyline(cornerRadius: 14)
            }

            Button("Use a different link") {
                pastedVideo = nil
                youtubeURL = ""
            }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Dancheong.jangdan)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(12)
        .background(Dancheong.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Dancheong.separator, lineWidth: 1)
        }
        .padding(.horizontal, 20)
    }

    private var hasLink: Bool {
        !youtubeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func pasteFromClipboard() {
        youtubeURL = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Regarde s'il y a un lien de vidéo qui attend, sans rien lire pour rien.
    ///
    /// `hasURLs` répond « il y a une adresse » **sans** ouvrir le
    /// presse-papiers : on ne le lit que lorsque la réponse est oui, et le
    /// bandeau « Molago a collé depuis Safari » n'apparaît donc que quand on a
    /// vraiment quelque chose à montrer — pas à chaque ouverture de l'écran.
    private var title: String {
        if pastedVideo != nil { return "Ready to add" }
        return clipboardLooksLikeALink ? "You copied a link" : "Paste a YouTube link"
    }

    private var subtitle: String {
        if pastedVideo != nil { return "Nothing is fetched until you add it." }
        return clipboardLooksLikeALink
            ? "Tap Paste to use it."
            : "Korean audio with captions works best."
    }

    /// Reconnaît un lien de vidéo dès qu'il est entré — collé ou tapé — et
    /// montre alors la vignette. Voir la bonne vidéo avant de lancer l'import
    /// est ce qui évite d'attendre une minute pour la mauvaise.
    private func recogniseTypedLink() {
        let value = youtubeURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let id = try? YouTubeImport.videoID(from: value) else { return }
        pastedVideo = (url: value, id: id)
    }

    /// Regarde s'il y a probablement une adresse, **sans ouvrir** le
    /// presse-papiers. Ça ne sert qu'à changer le titre : le lire vraiment est
    /// le geste de l'utilisateur, sur le bouton du système.
    private func lookAtTheClipboard() async {
        clipboardLooksLikeALink = await Self.clipboardHoldsAWebLink()
    }

    /// `@Sendable` sur le gestionnaire n'est pas décoratif : UIKit le rappelle
    /// depuis sa propre file, et une fermeture héritant du main actor y déclenche
    /// la vérification d'isolation de Swift 6 — l'app s'arrête net.
    private static func clipboardHoldsAWebLink() async -> Bool {
        let wanted: Set<UIPasteboard.DetectionPattern> = [.probableWebURL]
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            UIPasteboard.general.detectPatterns(for: wanted) { @Sendable result in
                continuation.resume(returning: (try? result.get())?.contains(.probableWebURL) ?? false)
            }
        }
    }

    // ── 2. pendant que ça travaille ──────────────────────────────────────────

    /// L'attente, rendue lisible.
    ///
    /// Une heure de vidéo, c'est neuf cents répliques traduites sur l'appareil,
    /// cinquante par cinquante. Un tourniquet et une phrase ne suffisaient pas :
    /// on ne savait ni quelle vidéo, ni combien il restait, ni comment sortir.
    ///
    /// `TimelineView` relit l'avancement à son rythme **sans** redessiner la
    /// vue qui porte la session de traduction : la redessiner la relancerait, et
    /// la relance coûte un lot. C'est pour ça que l'avancement vit hors
    /// observation dans le flux.
    private var translating: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let progress = flow.translationProgress
            let fraction = progress.total > 0 ? Double(progress.done) / Double(progress.total) : 0

            VStack(alignment: .leading, spacing: 0) {
                if let video = flow.awaitingTranslation {
                    videoCard(video)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 10) {
                        stepRow(done: true, "Captions ready · \(progress.total) lines")
                        stepRow(done: false, "Translating on your iPhone")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }

                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Dancheong.separator)
                            Capsule().fill(Dancheong.jangdan)
                                .frame(width: max(6, geometry.size.width * fraction))
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Text(flow.remaining ?? "The first translation downloads Korean and English.")
                        Spacer()
                        Text("\(progress.done) / \(progress.total)")
                            .monospacedDigit()
                            .foregroundStyle(Dancheong.ink)
                            .fontWeight(.semibold)
                    }
                    .font(.caption)
                    .foregroundStyle(Dancheong.inkSoft)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Translating the transcript")
                .accessibilityValue("\(progress.done) of \(progress.total) lines")

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(flow.visibleLines) { line in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.ko)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Dancheong.ink.opacity(line.en == nil ? 0.32 : 1))
                            if let en = line.en {
                                Text(en)
                                    .font(.caption)
                                    .foregroundStyle(Dancheong.inkSoft)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(line.en == nil ? Dancheong.separator : Dancheong.jangdan)
                                .frame(width: 2)
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
                // Le bas s'efface : ce qui reste à traduire est là, sans se
                // faire couper net par le bouton.
                .mask {
                    LinearGradient(colors: [.black, .black, .black.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: progress.done)

                // Sortir est un bouton pleine largeur, pas une croix dans un
                // coin : c'est la seule autre chose à faire sur cet écran.
                Button("Stop") { flow.stop() }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Dancheong.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Dancheong.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Dancheong.separator, lineWidth: 1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
    }

    private func videoCard(_ video: YouTubeImport.Video) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: video.thumbnail.flatMap(URL.init(string:))) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Dancheong.separator
            }
            .frame(width: 84, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(video.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Dancheong.ink)
                    .lineLimit(2)
                Text(video.channel)
                    .font(.caption2)
                    .foregroundStyle(Dancheong.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Dancheong.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Dancheong.separator, lineWidth: 1)
        }
    }

    private func stepRow(done: Bool, _ label: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                if done {
                    Circle().fill(Dancheong.hayeop)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Circle().strokeBorder(Dancheong.separator, lineWidth: 2)
                }
            }
            .frame(width: 18, height: 18)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(done ? Dancheong.ink : Dancheong.inkSoft)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(done ? "Done: \(label)" : "In progress: \(label)")
    }

    /// Ce qu'on dit pendant l'attente.
    ///
    /// « Reading the Korean » décrivait ce que la MACHINE faisait, et ne disait
    /// rien de ce qui allait sortir. On annonce l'étape en cours, en langue de
    /// tous les jours — lire la photo, puis la remettre en ordre.
    private func waiting(_ label: String, detail: String = "This can take a minute.") -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(Dancheong.jaju)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Dancheong.inkSoft)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(Dancheong.inkSoft.opacity(0.7))
        }
    }

    /// Le document est devenu un article. On ne le montre pas ici : il est dans
    /// la bibliothèque, avec les textes du matin, et c'est là qu'on le lit.
    private func filed(_ title: String) -> some View {
        VStack(spacing: 18) {
            Image("UniverseCapture")
                .resizable().scaledToFit().frame(width: 76, height: 76)
            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("Added to your library.")
                .font(.subheadline)
                .foregroundStyle(Dancheong.inkSoft)
            Button("Read it") { close() }
                .font(.body.weight(.semibold))
                .tint(Dancheong.jaju)
                .padding(.top, 4)
        }
        .padding(.horizontal, 32)
    }

    private func empty(_ message: String) -> some View {
        VStack(spacing: 20) {
            ContentUnavailableView("Nothing to read", systemImage: "text.viewfinder", description: Text(message))
            Button("Start over") { flow.reset(); picking = nil; youtubeURL = "" }
                .font(.body.weight(.semibold))
                .tint(Dancheong.jaju)
        }
        .overlay(alignment: .topTrailing) {
            CloseButton(onDark: false) { close() }
                .padding(.horizontal, 20)
                .padding(.top, 8)
        }
    }

    // La session de traduction n'est PAS ouverte ici : elle le sera quand le
    // transcript sera arrivé (`readyToTranslate`). C'est tout le fond de la
    // correction — ouvrir la session d'abord faisait annuler la requête réseau.
    private func importVideo() { flow.begin(youtubeURL) }

    /// Un lot de répliques, traduit d'un coup. Le découpage vit dans le flux :
    /// c'est lui qui sait ce qui reste à faire si la session est relancée.
    private nonisolated static func translate(_ lines: [String], with session: TranslationSession) async throws -> [String] {
        var translated = Array(repeating: "", count: lines.count)
        let requests = lines.enumerated().map { index, text in
            TranslationSession.Request(sourceText: text, clientIdentifier: String(index))
        }
        for response in try await session.translations(from: requests) {
            guard let id = response.clientIdentifier, let index = Int(id), translated.indices.contains(index) else {
                continue
            }
            translated[index] = response.targetText
        }
        return translated
    }

    // ── 2. la photo, avec ses mots allumés ───────────────────────────────────

    private func count(_ n: Int, _ verb: String) -> String {
        "\(n) \(n == 1 ? "word" : "words") \(verb)"
    }

    // ── 3. garder ────────────────────────────────────────────────────────────

    private func drop(_ word: CaptureFlow.Word) {
        kept.removeAll { $0.lemma == word.lemma }
        for existing in notebook where existing.lemma == word.lemma {
            context.delete(existing)
        }
        chosen = nil
    }

    private func finish() {
        let words = kept
        // Non structuré volontairement : la remontée ne doit pas être annulée
        // par la fermeture de l'écran, et son échec ne doit rien coûter — le
        // carnet local, lui, est déjà écrit.
        Task { await CaptureFlow.report(words) }
        close()
    }
}

// ── la photo et ses pans de couleur ──────────────────────────────────────────

/// Les mots reconnus, posés sur l'image à leur place exacte.
///
/// Une des deux entrées « papier ». Le 자주 est le pigment de ce que
/// l'utilisateur attrape lui-même — c'est sous cette couleur que les captures
/// rangent —, et le garder ici fait que la couleur annonce déjà l'étagère.
private struct PaperTile: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .medium))
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(Dancheong.jaju)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .padding(14)
        .background(Dancheong.jaju.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Dancheong.jaju.opacity(0.42), lineWidth: 1)
        }
    }
}

private struct CloseButton: View {
    let onDark: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(onDark ? .white : Dancheong.ink)
                .frame(width: 44, height: 44)
                .background(onDark ? .white.opacity(0.15) : Dancheong.ink.opacity(0.06), in: .circle)
        }
        .accessibilityLabel("Close")
    }
}

// ── l'appareil photo ─────────────────────────────────────────────────────────

/// `UIImagePickerController` plutôt qu'une capture maison : Molago prend une
/// photo, il ne fait pas de photographie. Le contrôleur système apporte la mise
/// au point, le flash et le recadrage, gratuitement.
private struct Camera: UIViewControllerRepresentable {
    let taken: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(taken: taken) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let taken: (UIImage) -> Void
        init(taken: @escaping (UIImage) -> Void) { self.taken = taken }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { taken(image) }
        }
    }
}

// ── géométrie ────────────────────────────────────────────────────────────────

private extension CGSize {
    /// Le rectangle que cette image occupe réellement une fois posée « au
    /// contact » dans un cadre — c'est lui, et pas le cadre, qui porte les
    /// coordonnées des mots.
    func fitted(in bounds: CGSize) -> CGRect {
        guard width > 0, height > 0 else { return .zero }
        let scale = min(bounds.width / width, bounds.height / height)
        let size = CGSize(width: width * scale, height: height * scale)
        return CGRect(x: (bounds.width - size.width) / 2,
                      y: (bounds.height - size.height) / 2,
                      width: size.width, height: size.height)
    }
}

private extension CGRect {
    /// Du repère normalisé de l'OCR aux points de l'écran.
    func placed(in frame: CGRect) -> CGRect {
        CGRect(x: frame.minX + minX * frame.width,
               y: frame.minY + minY * frame.height,
               width: width * frame.width,
               height: height * frame.height)
    }
}
