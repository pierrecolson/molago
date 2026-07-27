import Foundation
import SwiftData

/// Un mot que l'utilisateur a choisi de garder.
///
/// **C'est la seule chose irremplaçable du produit.** Les textes se
/// régénèrent chaque nuit, l'audio aussi ; une collection de mots, non. C'est
/// pour elle que la sauvegarde vers le serveur existera.
///
/// Distinction structurante de la spec §5.4 : *taper* un mot alimente le moteur,
/// c'est automatique et invisible ; le Notebook est une **collection choisie**.
/// Si tout ce qui est tapé y atterrissait, ce serait huit cents mots en trois
/// semaines et plus un carnet de mémoire.
@Model
final class KeptWord {
    /// La forme de dictionnaire. C'est l'identité du mot.
    @Attribute(.unique) var lemma: String
    var meaning: String
    var pos: String
    /// Le slug de l'icône Thiings, quand le mot en a mérité une.
    var icon: String?
    /// La phrase où il a été rencontré. Un mot sans son contexte redevient une
    /// liste de vocabulaire (spec §5.5).
    var context: String
    /// L'univers d'où il vient — c'est lui qui donne sa couleur dans le carnet.
    var slot: String
    var keptAt: Date

    init(lemma: String, meaning: String, pos: String, icon: String?, context: String, slot: String) {
        self.lemma = lemma
        self.meaning = meaning
        self.pos = pos
        self.icon = icon
        self.context = context
        self.slot = slot
        self.keptAt = .now
    }
}

/// Ce que le moteur de vocabulaire observe, sans jamais rien demander (spec §6.1).
///
/// Rien ne s'en sert encore — le contrôle de niveau attend une liste de
/// fréquence coréenne. On l'enregistre quand même, parce que c'est la seule
/// donnée du produit qu'on ne peut pas reconstituer après coup : un tap qu'on
/// n'a pas noté est perdu pour toujours.
@Model
final class WordSignal {
    var lemma: String
    /// `tap` — il ne connaissait pas le mot.
    /// `knew` — il le connaissait, le tap venait de la curiosité : ça annule le
    /// signal précédent, faute de quoi le système resservirait pendant des
    /// semaines un mot maîtrisé.
    var kind: String
    var at: Date

    init(lemma: String, kind: String) {
        self.lemma = lemma
        self.kind = kind
        self.at = .now
    }
}
