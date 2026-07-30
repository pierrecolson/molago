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
    private(set) var isPlaying: Bool = false

    /// L'avancement dans la phrase en cours, de 0 à 1.
    ///
    /// Calculé à la demande plutôt que publié : c'est l'horloge d'affichage de
    /// la barre (TimelineView) qui vient le lire tant que ça joue. Sans lui, la
    /// barre n'avance qu'au changement de phrase — quinze secondes immobile sur
    /// une phrase longue, elle a l'air en panne.
    var fraction: Double {
        guard let item = player?.currentItem else { return 0 }
        let total = item.duration.seconds
        let elapsed = item.currentTime().seconds
        guard total.isFinite, total > 0, elapsed.isFinite else { return 0 }
        return min(max(elapsed / total, 0), 1)
    }

    /// La vitesse de lecture, gardée d'un texte à l'autre.
    ///
    /// C'est un réglage de confort, pas un réglage de session : celui qui a
    /// besoin de 0,8× en a besoin tous les matins.
    var rate: Float = UserDefaults.standard.object(forKey: "molago.rate") as? Float ?? 1.0 {
        didSet {
            UserDefaults.standard.set(rate, forKey: "molago.rate")
            player?.defaultRate = rate
            if isPlaying { player?.rate = rate }
        }
    }

    /// Les vitesses proposées. Cinq crans, pas un curseur : on choisit un débit,
    /// on ne l'ajuste pas au centième.
    static let rates: [Float] = [0.7, 0.85, 1.0, 1.15, 1.3]

    func cycleRate() {
        let i = Self.rates.firstIndex(of: rate) ?? 2
        rate = Self.rates[(i + 1) % Self.rates.count]
    }

    /// Les pistes du texte, une par phrase.
    let urls: [URL]
    private var player: AVQueuePlayer?
    private var observation: NSKeyValueObservation?

    init(urls: [URL]) {
        self.urls = urls
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
            player.defaultRate = rate
            player.play()
            player.rate = rate
            isPlaying = true
            return
        }

        activateAudioSession()
        index = start

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

        player = queue
        queue.defaultRate = rate
        queue.play()
        queue.rate = rate
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
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
