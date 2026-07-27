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

        var id: String { audio }
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
