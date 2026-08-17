import Foundation

/// Une journée telle que la fabrique nocturne la dépose : trois textes, chacun
/// découpé en phrases, chaque phrase avec sa piste audio.
///
/// La forme suit exactement `pipeline/build-day.mjs`. Rien n'est calculé ici :
/// quand l'app ouvre, tout est déjà décidé, ce qui tient la promesse des cinq
/// secondes (spec §4.3).
struct Day: Codable, Sendable {
    let date: String
    let texts: [Text]

    struct Text: Codable, Sendable, Identifiable, Hashable {
        let slot: String
        let universe: String
        let title: String
        let minutes: Int
        /// L'icône qui représente le texte sur sa carte. Elle remplace le
        /// caractère chinois de l'univers : celui-ci était décoratif, alors que
        /// l'image du sujet apprend quelque chose avant même le titre.
        let icon: String?
        let kind: String?
        let importedAt: String?
        let videoID: String?
        let sourceURL: String?
        let sourceName: String?
        let thumbnail: String?
        let durationSeconds: Int?
        let sentences: [Sentence]

        var id: String { slot }
    }

    struct Sentence: Codable, Sendable, Identifiable, Hashable {
        let ko: String
        let en: String
        let audio: String
        let start: Double?
        let end: Double?
        /// Les 어절 de la phrase, chacun avec sa glose : c'est ce qui rend
        /// chaque mot tappable. Absent quand la fabrique n'a pas pu glosser.
        let words: [Word]?

        var id: String { audio }
    }

    struct Relative: Codable, Sendable, Hashable, Identifiable {
        /// Le mot coréen.
        let k: String
        /// Ses hanja.
        let h: String?
        /// Son sens en anglais.
        let e: String

        var id: String { k }
    }

    struct Morpheme: Codable, Sendable, Hashable, Identifiable {
        let k: String
        let h: String
        let e: String

        var id: String { "\(k)-\(h)" }
    }

    struct Word: Codable, Sendable, Hashable {
        /// Le mot lui-même — sert à vérifier qu'on parle bien du même découpage.
        let w: String
        /// La forme de dictionnaire : taper 관리비를 doit donner 관리비.
        let lemma: String?
        let pos: String?
        let en: String?
        /// Le slug de l'icône Thiings, quand le mot en a mérité une.
        let icon: String?
        /// Les hanja du mot, quand il est sino-coréen.
        let hanja: String?
        /// Sa construction littérale et ses briques sino-coréennes.
        let literal: String?
        let morphemes: [Morpheme]?
        /// Le sens que la racine partage avec toute sa famille.
        let root: String?
        /// Les mots de la même famille. C'est là que le rangement mental se
        /// fait : découvrir que 관리자 et 관리하다, employés tous les jours, sont
        /// le même bloc que le mot sur lequel on séchait (spec §5.3).
        let family: [Relative]?

        /// Tout mot visible peut être choisi. Quand son sens n'a pas été
        /// préparé à l'import, le lecteur le demande au moment du tap.
        var isTappable: Bool { !w.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        /// Écrire un décodeur sur mesure supprime l'initialiseur que Swift
        /// fabrique tout seul. Celui-ci le rend : la capture construit des mots
        /// qui ne viennent d'aucun JSON.
        init(w: String, lemma: String? = nil, pos: String? = nil, en: String? = nil,
             icon: String? = nil, hanja: String? = nil, literal: String? = nil,
             morphemes: [Morpheme]? = nil, root: String? = nil, family: [Relative]? = nil) {
            self.w = w
            self.lemma = lemma
            self.pos = pos
            self.en = en
            self.icon = icon
            self.hanja = hanja
            self.literal = literal
            self.morphemes = morphemes
            self.root = root
            self.family = family
        }

        /// Décodage indulgent sur tout ce qui est facultatif.
        ///
        /// La forme stricte de `Codable` fait échouer **toute** la journée sur
        /// un seul champ mal formé — c'est arrivé : une famille rendue en
        /// tableau au lieu d'objets, sur un mot parmi trois cents, et l'écran
        /// affichait « rien ce matin ». Ce qui vient d'un modèle doit pouvoir
        /// être partiellement faux sans rien emporter.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            w = try c.decode(String.self, forKey: .w)
            lemma = try? c.decodeIfPresent(String.self, forKey: .lemma)
            pos = try? c.decodeIfPresent(String.self, forKey: .pos)
            en = try? c.decodeIfPresent(String.self, forKey: .en)
            icon = try? c.decodeIfPresent(String.self, forKey: .icon)
            hanja = try? c.decodeIfPresent(String.self, forKey: .hanja)
            literal = try? c.decodeIfPresent(String.self, forKey: .literal)
            morphemes = try? c.decodeIfPresent([Morpheme].self, forKey: .morphemes)
            root = try? c.decodeIfPresent(String.self, forKey: .root)
            family = try? c.decodeIfPresent([Relative].self, forKey: .family)
        }
    }
}

enum WordRoots {
    struct Shared: Equatable {
        let korean: String
        let hanja: String
        let meaning: String
    }

    static func shared(in word: Day.Word) -> Shared? {
        guard let family = word.family, !family.isEmpty,
              let meaning = word.root, !meaning.isEmpty else { return nil }
        return word.morphemes?.first { part in
            family.allSatisfy { $0.h?.contains(part.h) == true }
        }.map { Shared(korean: $0.k, hanja: $0.h, meaning: meaning) }
    }
}

extension Day.Text {
    /// Un texte que l'utilisateur a capturé lui-même, par opposition aux textes
    /// du matin. `hasPrefix` et non l'égalité : chaque capture porte un
    /// identifiant unique — `capture-ms5z0tto`.
    ///
    /// Une capture n'a pas de voix : on la lit devant son document, pas dans le
    /// métro. Le lecteur n'affiche donc ni barre de lecture ni geste d'écoute.
    var isCapture: Bool { slot.hasPrefix("capture") }
    var isPhoto: Bool { kind == "photo" || isCapture }
    var isYouTube: Bool { kind == "youtube" || slot.hasPrefix("youtube-") }
    var thumbnailURL: URL? { thumbnail.flatMap(URL.init(string:)) }

    /// La journée d'où vient ce texte, lue dans le nom de sa première piste.
    ///
    /// Un texte ne porte pas sa date : elle vit sur la journée qui le contient,
    /// et la lui faire descendre obligerait à la trimballer à travers tous les
    /// écrans qui n'en ont que faire. Les pistes, elles, s'appellent
    /// `<date>-<slot>-<nn>.mp3` — c'est la fabrique qui les nomme ainsi, et
    /// c'est déjà ce qui garantit qu'elles ne se marchent pas dessus d'un jour
    /// à l'autre. On s'appuie sur ce nom plutôt que d'en dupliquer l'information.
    var day: String? {
        if let importedAt, importedAt.count >= 10 { return String(importedAt.prefix(10)) }
        guard let name = sentences.first?.audio.split(separator: "/").last else { return nil }
        let parts = name.split(separator: "-")
        guard parts.count >= 3 else { return nil }
        return parts.prefix(3).joined(separator: "-")
    }

    /// La ligne d'information sous le titre. `4 min` et rien d'autre quand la
    /// difficulté est ordinaire : le nombre de mots ne varie pas, et le nombre
    /// de mots nouveaux est ambigu (spec §4.3).
    var meta: String { "\(minutes) min" }
}

struct LibraryItem: Codable, Sendable, Identifiable, Hashable {
    let date: String
    let text: Day.Text

    var id: String { "\(date)-\(text.slot)" }

    var shortLabel: String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        input.locale = Locale(identifier: "en_US_POSIX")
        guard let value = input.date(from: date) else { return date }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US")
        output.dateFormat = "d MMM"
        return output.string(from: value)
    }
}

enum LibrarySections {
    static func split(_ items: [LibraryItem]) -> (recent: [LibraryItem], older: [LibraryItem]) {
        (Array(items.prefix(3)), Array(items.dropFirst(3)))
    }
}

extension Day {
    /// `SATURDAY 27 JULY` — le libellé de jour au-dessus des trois cartes.
    var dayLabel: String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let d = parser.date(from: date) else { return date }

        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US")
        out.dateFormat = "EEEE d MMMM"
        return out.string(from: d).uppercased()
    }

    /// `27 Jul` — la date au bout d'une ligne de « Previously ».
    ///
    /// Une forme courte, parce qu'elle est répétée sur chaque ligne : le libellé
    /// complet y prendrait plus de place que le titre qu'il accompagne.
    var shortLabel: String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let d = parser.date(from: date) else { return date }

        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US")
        out.dateFormat = "d MMM"
        return out.string(from: d)
    }
}
