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
    /// La piste audio de cette phrase, si on l'a encore.
    ///
    /// Optionnelle, et pas seulement par prudence de migration : l'audio de plus
    /// de soixante jours est purgé du serveur, donc un mot ancien finit par
    /// perdre sa voix. Il garde son sens et sa phrase, qui sont l'essentiel.
    var contextAudio: String?
    /// Les hanja et la famille, figés au moment où le mot est gardé.
    ///
    /// Recopiés plutôt que référencés : le texte d'où ils viennent finira purgé,
    /// et la fiche doit continuer de fonctionner. Le jour où une vraie base
    /// partagée existera (decisions.md §37), c'est elle qui les portera.
    var hanja: String?
    var root: String?
    var family: [Day.Relative]?
    /// L'univers d'où il vient — c'est lui qui donne sa couleur dans le carnet.
    var slot: String
    var keptAt: Date

    init(lemma: String, meaning: String, pos: String, icon: String?, context: String,
         contextAudio: String?, hanja: String?, root: String?, family: [Day.Relative]?, slot: String) {
        self.contextAudio = contextAudio
        self.hanja = hanja
        self.root = root
        self.family = family
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
