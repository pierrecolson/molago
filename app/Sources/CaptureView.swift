import SwiftUI
import SwiftData
import PhotosUI

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
            case .filed(let title):
                filed(title)
            case .nothing(let message):
                empty(message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backdrop)
        .animation(.snappy(duration: 0.3), value: chosen)
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
                Text("Catch a word")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(Dancheong.ink)
                Text("A bill, a sign, a menu, a message.\nMolago reads the Korean on it.")
                    .font(.system(size: 17))
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
    private func waiting(_ label: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(Dancheong.jaju)
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Dancheong.inkSoft)
            Text("This can take a minute. The voice comes later.")
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
            Text("Added to your library, with today's texts.")
                .font(.subheadline)
                .foregroundStyle(Dancheong.inkSoft)
            Button("Read it") { close() }
                .font(.system(size: 17, weight: .semibold))
                .tint(Dancheong.jaju)
                .padding(.top, 4)
        }
        .padding(.horizontal, 32)
    }

    private func empty(_ message: String) -> some View {
        VStack(spacing: 20) {
            ContentUnavailableView("Nothing to read", systemImage: "text.viewfinder", description: Text(message))
            Button("Try another photo") { flow.reset(); picking = nil }
                .font(.system(size: 17, weight: .semibold))
                .tint(Dancheong.jaju)
        }
        .overlay(alignment: .topTrailing) {
            CloseButton(onDark: false) { close() }
                .padding(.horizontal, 20)
                .padding(.top, 8)
        }
    }

    // ── 2. la photo, avec ses mots allumés ───────────────────────────────────

    private func marked(_ image: UIImage, _ words: [CaptureFlow.Word]) -> some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton(onDark: true) { finish() }
                Spacer()
                Text(kept.isEmpty ? count(words.count, "found") : count(kept.count, "kept"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .contentTransition(.numericText())
                Spacer()
                Button("Done") { finish() }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Dancheong.jaju)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Photo(image: image, words: words, kept: Set(kept.map(\.lemma))) { word in
                chosen = chosen?.id == word.id ? nil : word
            }

            // Le sens vient sous la photo, jamais par-dessus : ce qu'on veut
            // voir en même temps que le mot, c'est le mot dans son papier.
            //
            // La hauteur est réservée d'avance, même quand rien n'est
            // sélectionné. Sinon la photo rétrécit à l'ouverture de la fiche et
            // le mot qu'on vient de toucher se déplace sous le doigt.
            Group {
                if let word = chosen {
                    WordSheet(
                        word: word,
                        isKept: kept.contains { $0.lemma == word.lemma },
                        keep: { keep(word) },
                        drop: { drop(word) }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Text("Tap a highlighted word")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(height: 182, alignment: .bottom)
            .frame(maxWidth: .infinity)
        }
    }

    private func count(_ n: Int, _ verb: String) -> String {
        "\(n) \(n == 1 ? "word" : "words") \(verb)"
    }

    // ── 3. garder ────────────────────────────────────────────────────────────

    private func keep(_ word: CaptureFlow.Word) {
        guard !kept.contains(where: { $0.lemma == word.lemma }) else { return }
        kept.append(word)
        // Écrit tout de suite : un mot gardé ne doit pas dépendre du fait qu'on
        // pense ensuite à toucher « Done ».
        context.insert(KeptWord(
            lemma: word.lemma, meaning: word.en, pos: word.pos, icon: nil,
            context: word.line, contextAudio: nil,
            hanja: nil, root: nil, family: nil,
            // Pas « quotidien » : ce mot ne vient d'aucun des trois textes du
            // matin. Son propre pigment (捉, 자주) le dit d'un coup d'œil dans
            // le carnet.
            slot: "capture"
        ))
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        chosen = nil
    }

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
/// Deux états, et la même grammaire que partout ailleurs dans l'app : un mot
/// disponible est un voile de 장단 cerné d'un filet ; un mot gardé est un **pan
/// plein** avec le coréen redessiné en blanc par-dessus. On voit d'un coup d'œil
/// ce qu'on a pris, sans avoir à lire une liste.
private struct Photo: View {
    let image: UIImage
    let words: [CaptureFlow.Word]
    let kept: Set<String>
    let tap: (CaptureFlow.Word) -> Void

    var body: some View {
        GeometryReader { geo in
            let frame = image.size.fitted(in: geo.size)
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)

                ForEach(words) { word in
                    let box = word.box.placed(in: frame)
                    let isKept = kept.contains(word.lemma)

                    ZStack {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Dancheong.jaju.opacity(isKept ? 1 : 0.34))
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(isKept ? .white.opacity(0.5) : Dancheong.jaju, lineWidth: 1.5)
                        if isKept {
                            Text(word.surface)
                                .font(.system(size: box.height * 0.68, weight: .semibold))
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 2)
                        }
                    }
                    .frame(width: box.width, height: box.height)
                    // La cible du doigt est plus grande que le mot, et posée
                    // avant `position` : après, la vue occupe tout le cadre et
                    // avalerait chaque tap. Sur une facture, un 어절 fait quatre
                    // millimètres de haut.
                    .contentShape(.rect.inset(by: -7))
                    .onTapGesture { tap(word) }
                    .position(x: box.midX, y: box.midY)
                }
            }
        }
    }
}

/// Ce que le mot veut dire, et la seule décision à prendre.
private struct WordSheet: View {
    let word: CaptureFlow.Word
    let isKept: Bool
    let keep: () -> Void
    let drop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(word.lemma)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Dancheong.ink)
                Text(word.en)
                    .font(.system(size: 17))
                    .foregroundStyle(Dancheong.inkSoft)
            }

            Button(action: isKept ? drop : keep) {
                Text(isKept ? "Kept — remove" : "Keep this word")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isKept ? Dancheong.jaju : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isKept ? Dancheong.jaju.opacity(0.12) : Dancheong.jaju)
                    )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Dancheong.paper)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous))
    }
}

private struct SourceBlock: View {
    let title: String
    let icon: String
    let filled: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
            Text(title)
                .font(.system(size: 19, weight: .semibold))
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
                .frame(width: 34, height: 34)
                .background(onDark ? .white.opacity(0.15) : Dancheong.ink.opacity(0.06), in: .circle)
        }
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
