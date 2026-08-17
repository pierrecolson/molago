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
    @State private var pendingYouTubeURL: String?
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
                waiting("Preparing the transcript…", detail: "The first translation may download Korean and English.")
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
        }
        .task(id: picking) {
            guard let picking,
                  let data = try? await picking.loadTransferable(type: Data.self) else { return }
            await flow.read(data: data)
        }
        .translationTask(translationConfiguration) { session in
            guard let value = pendingYouTubeURL else { return }
            pendingYouTubeURL = nil
            await flow.importYouTube(value) { lines in
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

    // ── 1. d'où vient la photo ───────────────────────────────────────────────

    private var chooser: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                CloseButton(onDark: false) { close() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Text("Catch something")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Dancheong.ink)
                Text("A photo or video in Korean.")
                    .font(.body)
                    .foregroundStyle(Dancheong.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.bottom, 28)

            VStack(spacing: 14) {
                Button { shooting = true } label: {
                    SourceBlock(title: "Take a photo", icon: "camera.fill", filled: true)
                }
                // Le second bouton ne prend pas le 삼청 : ce bleu veut dire
                // « tech », et le poser ici ferait dire à la couleur quelque
                // chose de faux. Même pigment que le premier, creusé.
                PhotosPicker(selection: $picking, matching: .images, photoLibrary: .shared()) {
                    SourceBlock(title: "Choose a photo", icon: "photo.on.rectangle.angled", filled: false)
                }

                HStack(spacing: 10) {
                    TextField("Paste a YouTube video URL", text: $youtubeURL)
                        .accessibilityLabel("YouTube video URL")
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit { importVideo() }
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(Dancheong.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button("Add") { importVideo() }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 64, minHeight: 52)
                        .background(Dancheong.jaju, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .disabled(youtubeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(youtubeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                }
                .accessibilityElement(children: .contain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
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

    private func importVideo() {
        pendingYouTubeURL = youtubeURL
        translationConfiguration.invalidate()
    }

    private nonisolated static func translate(_ lines: [String], with session: TranslationSession) async throws -> [String] {
        var translated = Array(repeating: "", count: lines.count)
        for offset in stride(from: 0, to: lines.count, by: 50) {
            let end = min(offset + 50, lines.count)
            let requests = lines[offset..<end].enumerated().map { relative, text in
                TranslationSession.Request(sourceText: text, clientIdentifier: String(offset + relative))
            }
            for response in try await session.translations(from: requests) {
                guard let id = response.clientIdentifier, let index = Int(id), translated.indices.contains(index) else {
                    continue
                }
                translated[index] = response.targetText
            }
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
private struct SourceBlock: View {
    let title: String
    let icon: String
    let filled: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
        }
        .foregroundStyle(filled ? .white : Dancheong.jaju)
        .padding(.horizontal, 24)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .background(filled ? Dancheong.jaju : Dancheong.jaju.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            if filled {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .strokeBorder(.white.opacity(0.42), lineWidth: 1)
                    .padding(7)
            } else {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Dancheong.jaju.opacity(0.42), lineWidth: 1)
            }
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
