import AVFoundation
import Observation

/// La voix, et la phrase qu'elle est en train de lire.
///
/// Le point important : **le surlignage n'est pas synchronisé avec l'audio, il
/// EST la piste en cours.** La fabrique produit une piste par phrase (spec §9,
/// étape 9), donc il suffit d'empiler les phrases dans une file et de regarder
/// laquelle joue. Aucun timing à suivre, aucune dérive possible — là où un seul
/// fichier par texte aurait demandé des horodatages mot à mot et une
/// synchronisation continue.
@Observable
@MainActor
final class SentencePlayer {
    /// L'index de la phrase en cours de lecture. C'est ce que le texte surligne.
    private(set) var index: Int = 0
    /// L'index du 어절 prononcé à l'instant, dans la phrase en cours.
    /// Vaut `-1` quand la phrase n'a pas de repères.
    private(set) var wordIndex: Int = -1
    private(set) var isPlaying: Bool = false

    /// Les pistes du texte, une par phrase.
    let urls: [URL]
    /// Les instants de départ de chaque mot, phrase par phrase.
    private let wordStarts: [[Double]]
    private var player: AVQueuePlayer?
    private var observation: NSKeyValueObservation?
    private var ticker: Any?

    init(urls: [URL], wordStarts: [[Double]] = []) {
        self.urls = urls
        self.wordStarts = wordStarts
    }

    // Pas de `deinit` pour invalider l'observation : `NSKeyValueObservation` le
    // fait en se libérant, et un `deinit` n'est pas isolé au main actor, donc il
    // ne peut de toute façon pas toucher à cette propriété.

    /// Démarre — ou reprend — la lecture à partir d'une phrase donnée.
    ///
    /// Taper une phrase déplace la voix à cet endroit (spec §4.4) : on
    /// reconstruit simplement la file à partir de là.
    func play(from start: Int = 0) {
        guard urls.indices.contains(start) else { return }

        if start == index, let player, player.currentItem != nil {
            player.play()
            isPlaying = true
            return
        }

        activateAudioSession()
        if let ticker { player?.removeTimeObserver(ticker) }
        ticker = nil
        index = start
        wordIndex = -1

        let items = urls[start...].map { AVPlayerItem(url: $0) }
        let queue = AVQueuePlayer(items: items)
        queue.actionAtItemEnd = .advance

        // La file se vide au fur et à mesure : la phrase en cours est donc
        // toujours `urls.count - (ce qu'il reste)`.
        observation = queue.observe(\.currentItem, options: [.new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if player.currentItem == nil {
                    // Fin du texte : on se replace au début, sans rien réclamer.
                    self.isPlaying = false
                    self.index = 0
                } else {
                    self.index = self.urls.count - player.items().count
                }
            }
        }

        // Le mot en cours, lui, demande bien une horloge : les repères sont des
        // instants dans la piste. Vingt fois par seconde suffit largement — un
        // mot coréen dure au minimum deux à trois dixièmes.
        ticker = queue.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshWord() }
        }

        player = queue
        queue.play()
        isPlaying = true
    }

    private func refreshWord() {
        guard
            let elapsed = player?.currentItem?.currentTime().seconds,
            elapsed.isFinite,
            wordStarts.indices.contains(index)
        else { wordIndex = -1; return }

        let starts = wordStarts[index]
        guard !starts.isEmpty else { wordIndex = -1; return }
        // Le dernier mot dont l'instant de départ est déjà passé.
        wordIndex = (starts.lastIndex { $0 <= elapsed }) ?? 0
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    /// Le nombre de mots de la phrase en cours, ou zéro si elle n'a pas de repères.
    func wordCount(at sentence: Int) -> Int {
        wordStarts.indices.contains(sentence) ? wordStarts[sentence].count : 0
    }

    func toggle() {
        isPlaying ? pause() : play(from: index)
    }

    /// Lecture même quand le bouton silence est mis, et quand l'écran s'éteint :
    /// on écoute dans le métro, téléphone en poche.
    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
    }
}
