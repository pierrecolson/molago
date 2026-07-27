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

    struct Text: Codable, Sendable, Identifiable {
        let slot: String
        let universe: String
        let title: String
        let minutes: Int
        let sentences: [Sentence]

        var id: String { slot }
    }

    struct Sentence: Codable, Sendable, Identifiable {
        let ko: String
        let en: String
        let audio: String
        /// L'instant où commence chaque 어절, mesuré par la synthèse vocale.
        /// Absent quand les repères n'étaient pas complets : l'app retombe
        /// alors sur le surlignage par phrase, plutôt que de surligner faux.
        let words: [Word]?

        var id: String { audio }
    }

    struct Word: Codable, Sendable, Hashable {
        /// Le mot lui-même — sert à vérifier qu'on parle bien du même découpage.
        let w: String
        /// Secondes depuis le début de la phrase.
        let t: Double
        /// La forme de dictionnaire : taper 관리비를 doit donner 관리비.
        let lemma: String?
        let pos: String?
        let en: String?
        /// Le slug de l'icône Thiings, quand le mot en a mérité une.
        let icon: String?

        /// Un mot sans sens n'est pas tappable : ouvrir une carte vide serait
        /// pire que de ne rien ouvrir.
        var isTappable: Bool { en?.isEmpty == false }
    }
}

extension Day.Text {
    /// La ligne d'information sous le titre. `4 min` et rien d'autre quand la
    /// difficulté est ordinaire : le nombre de mots ne varie pas, et le nombre
    /// de mots nouveaux est ambigu (spec §4.3).
    var meta: String { "\(minutes) min" }
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
}
