import SwiftUI
import SwiftData
import PhotosUI
import Vision

/// La capture : photographier, lire, trier.
///
/// C'est la boucle qui distingue Molago d'un lecteur. Un mot attrapé sur une
/// facture mardi devient le sujet de mercredi (spec §8.2) — sans elle, le
/// troisième texte tourne indéfiniment sur un fonds de situations inventées.
///
/// L'OCR est **natif** (framework Vision, coréen depuis iOS 16) : gratuit, hors
/// ligne, instantané, aucune dépendance. Sa seule faiblesse est le manuscrit.
@Observable
@MainActor
final class CaptureFlow {
    enum Step {
        case choosing
        case reading
        case sorting([Candidate])
        case nothing(String)
    }

    struct Candidate: Identifiable, Hashable {
        let surface: String
        let lemma: String
        let pos: String
        let en: String
        var id: String { lemma }
    }

    private(set) var step: Step = .choosing
    /// Le texte reconnu, montré au-dessus des cartes. Utile avant même
    /// d'apprendre : trois secondes pour voir ce qui bloque sur un papier
    /// administratif (spec §5.7).
    private(set) var recognised = ""

    func read(_ image: UIImage) async {
        step = .reading
        guard let text = await Self.recogniseKorean(in: image), text.count > 1 else {
            step = .nothing("No Korean text found in that photo.")
            return
        }
        recognised = text

        do {
            let words = try await Self.gloss(text)
            guard !words.isEmpty else {
                step = .nothing("Nothing worth keeping in there.")
                return
            }
            step = .sorting(words)
        } catch {
            step = .nothing("Couldn't look those words up. Try again in a moment.")
        }
    }

    // ── lecture de l'image ───────────────────────────────────────────────────

    private static func recogniseKorean(in image: UIImage) async -> String? {
        guard let cg = image.cgImage else { return nil }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLanguages = ["ko-KR", "en-US"]
            request.recognitionLevel = .accurate
            // Le coréen d'une facture n'est pas de la prose : la correction
            // automatique y fait plus de mal que de bien.
            request.usesLanguageCorrection = false

            DispatchQueue.global(qos: .userInitiated).async {
                try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
            }
        }
    }

    // ── le sens, tout de suite ───────────────────────────────────────────────

    /// La spec §5.7 est explicite : « on capture souvent parce qu'on a besoin de
    /// comprendre **maintenant**, devant sa facture. » Le sens ne peut donc pas
    /// attendre la fabrication de la nuit.
    private static func gloss(_ text: String) async throws -> [Candidate] {
        var request = URLRequest(url: Config.baseURL.appending(path: "gloss"))
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(["text": text])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }

        struct Reply: Decodable {
            struct Word: Decodable { let surface: String; let lemma: String; let pos: String; let en: String }
            let words: [Word]
        }
        return try JSONDecoder().decode(Reply.self, from: data).words
            .map { Candidate(surface: $0.surface, lemma: $0.lemma, pos: $0.pos, en: $0.en) }
    }

    /// Remonte au serveur ce qui a été gardé, pour que la fabrique de la nuit
    /// suivante en fasse le troisième texte. Sans `throws` : un envoi raté ne
    /// doit pas empêcher le mot d'entrer au carnet — il y est déjà.
    static func report(_ kept: [Candidate], context: String) async {
        struct Payload: Encodable {
            struct Word: Encodable { let lemma: String; let en: String; let context: String }
            let words: [Word]
        }
        let payload = Payload(words: kept.map { .init(lemma: $0.lemma, en: $0.en, context: context) })
        var request = URLRequest(url: Config.baseURL.appending(path: "captures"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try? JSONEncoder().encode(payload)
        _ = try? await URLSession.shared.data(for: request)
    }
}

// ── l'écran ──────────────────────────────────────────────────────────────────

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var flow = CaptureFlow()
    @State private var picked: PhotosPickerItem?
    @State private var index = 0
    @State private var kept: [CaptureFlow.Candidate] = []
    @State private var showingCamera = false

    var body: some View {
        NavigationStack {
            Group {
                switch flow.step {
                case .choosing: chooser
                case .reading: reading
                case .sorting(let words): sorting(words)
                case .nothing(let message):
                    ContentUnavailableView("Nothing to keep", systemImage: "text.viewfinder", description: Text(message))
                }
            }
            .background(Dancheong.ground)
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { finish() }
                }
            }
        }
    }

    private var chooser: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "text.viewfinder")
                .font(.system(size: 54))
                .foregroundStyle(Dancheong.jangdan)

            Text("A bill, a sign, a menu, a message")
                .font(.headline)
            Text("Molago reads the Korean and shows you what each word means.")
                .font(.subheadline)
                .foregroundStyle(Dancheong.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            #if !targetEnvironment(simulator)
            Button { showingCamera = true } label: {
                Label("Take a photo", systemImage: "camera.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Dancheong.jangdan, in: Capsule())
            }
            #endif

            // Aussi depuis la photothèque : une capture d'écran de KakaoTalk est
            // une capture comme une autre, et c'est le seul chemin dans le
            // simulateur.
            PhotosPicker(selection: $picked, matching: .images) {
                Label("Choose a photo", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .foregroundStyle(Dancheong.jangdan)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .overlay(Capsule().stroke(Dancheong.jangdan, lineWidth: 1.5))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await flow.read(image)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                showingCamera = false
                Task { await flow.read(image) }
            }
        }
    }

    private var reading: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large).tint(Dancheong.jangdan)
            Text("Reading…").font(.subheadline).foregroundStyle(Dancheong.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func sorting(_ words: [CaptureFlow.Candidate]) -> some View {
        if index >= words.count {
            ContentUnavailableView {
                Label("\(kept.count) kept", systemImage: "checkmark.circle")
            } description: {
                Text(kept.isEmpty
                     ? "Nothing this time — that's fine."
                     : "They're in your Notebook, and tomorrow's Daily life text may use them.")
            }
            .task { finish() }
        } else {
            VStack(spacing: 0) {
                // Le texte reconnu, au-dessus. Utile avant même d'apprendre :
                // trois secondes pour voir ce qui bloque sur un papier.
                ScrollView {
                    Text(flow.recognised)
                        .font(.footnote)
                        .foregroundStyle(Dancheong.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                .frame(maxHeight: 150)

                Text("\(index + 1) of \(words.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Dancheong.inkSoft)
                    .padding(.top, 4)

                Spacer(minLength: 0)

                // Le même geste qu'en lecture : droite je garde, gauche je
                // passe. Un seul langage dans toute l'app, appris une fois.
                WordCard(
                    word: Day.Word(
                        w: words[index].surface, t: 0,
                        lemma: words[index].lemma, pos: words[index].pos,
                        en: words[index].en, icon: nil,
                        hanja: nil, root: nil, family: nil
                    ),
                    context: flow.recognised.replacingOccurrences(of: "\n", with: " "),
                    slot: "daily",
                    onKeep: { keep(words[index]) },
                    onKnew: { index += 1 },
                    onClose: { index += 1 }
                )
                .frame(maxHeight: 420)
            }
        }
    }

    private func keep(_ candidate: CaptureFlow.Candidate) {
        kept.append(candidate)
        context.insert(KeptWord(
            lemma: candidate.lemma,
            meaning: candidate.en,
            pos: candidate.pos,
            icon: nil,
            context: flow.recognised.replacingOccurrences(of: "\n", with: " "),
            contextAudio: nil,
            hanja: nil, root: nil, family: nil,
            slot: "daily"
        ))
        try? context.save()
        index += 1
    }

    private func finish() {
        let toReport = kept
        let where_ = flow.recognised.replacingOccurrences(of: "\n", with: " ")
        if !toReport.isEmpty {
            Task { await CaptureFlow.report(toReport, context: where_) }
        }
        dismiss()
    }
}

/// L'appareil photo. `UIImagePickerController` plutôt que quoi que ce soit de
/// plus moderne : il est natif, il connaît déjà les permissions, et il n'existe
/// pas dans le simulateur — ce que le code appelant sait.
private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        init(onImage: @escaping (UIImage) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onImage(image) }
        }
    }
}
