import SwiftUI
import UIKit

/// 단청 — la polychromie des avant-toits de palais coréens.
///
/// Trois règles tenues partout, et ce sont elles qui font que l'app ne ressemble
/// à rien d'autre :
///   1. la couleur occupe des **pans entiers**, jamais des accents ;
///   2. chaque pan porte un **filet clair à l'intérieur du bord** — c'est la
///      grammaire du 단청, la bande peinte est toujours cernée ;
///   3. **aucune ombre, aucun dégradé.** C'est peint à plat sur du bois.
enum Dancheong {
    /// 호분 — le fond, un blanc franc plutôt qu'un parchemin.
    static let ground = dancheong((0.957, 0.945, 0.918), (0.078, 0.075, 0.090))
    /// La surface de lecture, plus claire que le fond.
    static let paper = dancheong((0.984, 0.976, 0.961), (0.118, 0.110, 0.133))
    /// 먹 — l'encre.
    static let ink = dancheong((0.090, 0.086, 0.102), (0.941, 0.929, 0.902))
    static let inkSoft = dancheong((0.553, 0.522, 0.475), (0.604, 0.573, 0.537))
    static let separator = dancheong((0.902, 0.882, 0.843), (0.204, 0.192, 0.224))

    /// 삼청 — le bleu.
    static let samcheong = dancheong((0.169, 0.345, 0.463), (0.239, 0.451, 0.588))
    /// 하엽 — le vert feuille.
    static let hayeop = dancheong((0.247, 0.420, 0.290), (0.318, 0.529, 0.376))
    /// 장단 — l'orange dominant du 단청, et la couleur de marque de Molago.
    static let jangdan = dancheong((0.824, 0.376, 0.102), (0.878, 0.451, 0.176))
    /// 자주 — le pourpre, réservé à ce que l'utilisateur attrape lui-même.
    ///
    /// Les trois autres pigments disent **d'où vient le texte** : bleu pour la
    /// tech, vert pour la Corée, orange pour le quotidien. Un mot photographié
    /// sur une facture ne vient d'aucun article — il vient de la vie de celui
    /// qui lit —, et lui donner l'orange du quotidien effaçait cette
    /// différence. Le pourpre est le seul pigment de la palette qu'on ne
    /// confonde avec aucun des trois du coin de l'œil.
    static let jaju = dancheong((0.400, 0.243, 0.451), (0.522, 0.365, 0.588))

    /// 소황 — le jaune d'or, le quatrième pigment. Il arrive avec l'univers Fun,
    /// et c'est le seul de la palette qui reste lisible à côté des trois autres
    /// sans virer au brun.
    static let sohwang = dancheong((0.722, 0.525, 0.169), (0.784, 0.612, 0.259))

    /// Un univers : sa couleur, son nom, et l'icône qui le désigne.
    ///
    /// L'icône est **fixe par univers**, plus cherchée par article. Une image qui
    /// tente d'illustrer un texte demande de déchiffrer un dessin ; cinq icônes
    /// qui ne changent jamais se reconnaissent sans les lire. C'est aussi une
    /// recherche de moins par article chaque nuit.
    ///
    /// `korea` et `daily` sont les anciens noms de News et Life : les journées
    /// déjà fabriquées les portent encore, et une journée passée ne se réécrit
    /// pas. Les deux graphies mènent donc au même univers.
    static func universe(_ slot: String) -> (color: Color, name: String, icon: String) {
        // Une capture porte un identifiant unique — `capture-ms5z0tto` — parce
        // qu'on en photographie plusieurs par jour. La comparaison exacte la
        // renvoyait donc au cas par défaut, et l'article prenait l'orange de
        // Life : la couleur mentait sur la provenance, ce que toute l'app
        // s'interdit ailleurs.
        if slot.hasPrefix("capture") { return (jaju, "Capture", "UniverseCapture") }
        return switch slot {
        case "tech":              (samcheong, "Tech", "UniverseTech")
        case "korea", "news":     (hayeop, "News", "UniverseNews")
        case "fun":               (sohwang, "Fun", "UniverseFun")
        case "capture":           (jaju, "Capture", "UniverseCapture")
        default:                  (jangdan, "Life", "UniverseLife")
        }
    }

    /// Le surlignage de la phrase lue.
    ///
    /// Ce ne peut pas être la couleur de l'univers atténuée : les trois pigments
    /// n'ont pas la même clarté, et le bleu comme le vert, déjà sombres, virent
    /// au gris une fois délavés — le surlignage cessait de se lire comme une
    /// couleur. Chaque univers a donc sa teinte claire propre, réglée pour être
    /// aussi présente que les deux autres.
    private static let captureHighlight = dancheong((0.878, 0.831, 0.906), (0.192, 0.137, 0.227))
    private static let captureWordhighlight = dancheong((0.729, 0.647, 0.784), (0.310, 0.227, 0.365))

    static func highlight(_ slot: String) -> Color {
        if slot.hasPrefix("capture") { return captureHighlight }
        return switch slot {
        case "tech": dancheong((0.784, 0.867, 0.933), (0.110, 0.196, 0.271))
        case "korea", "news": dancheong((0.796, 0.890, 0.808), (0.118, 0.216, 0.145))
        case "fun": dancheong((0.965, 0.886, 0.706), (0.235, 0.184, 0.075))
        case "capture": dancheong((0.878, 0.831, 0.906), (0.192, 0.137, 0.227))
        default: dancheong((0.973, 0.855, 0.749), (0.259, 0.153, 0.055))
        }
    }

    /// Le mot prononcé à l'instant même, dans la phrase déjà surlignée.
    ///
    /// Deux niveaux plutôt qu'un : la phrase claire dit *où on en est* dans le
    /// texte, le mot plus soutenu dit *ce qu'on entend*. Avec un seul niveau on
    /// perd l'un ou l'autre.
    static func wordHighlight(_ slot: String) -> Color {
        if slot.hasPrefix("capture") { return captureWordhighlight }
        return switch slot {
        case "tech": dancheong((0.553, 0.729, 0.855), (0.180, 0.322, 0.443))
        case "korea", "news": dancheong((0.565, 0.780, 0.596), (0.192, 0.361, 0.239))
        case "fun": dancheong((0.914, 0.792, 0.514), (0.373, 0.294, 0.118))
        case "capture": dancheong((0.729, 0.647, 0.784), (0.310, 0.227, 0.365))
        default: dancheong((0.949, 0.671, 0.451), (0.416, 0.251, 0.094))
        }
    }
}


/// Une couleur qui change avec le mode de l'appareil.
///
/// Les cinq pigments du 단청 ne s'inversent pas : ils ont été mélangés pour être
/// posés sur du bois clair, et un orange réglé pour le 호분 vibre sur du noir.
/// Chacun reçoit donc sa version sombre, choisie à l'œil — plus claire et moins
/// saturée, pour tenir le même écart avec son fond que l'original avec le sien.
private func dancheong(_ light: (Double, Double, Double), _ dark: (Double, Double, Double)) -> Color {
    Color(UIColor { traits in
        let c = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
    })
}

extension View {
    /// Le filet clair à l'intérieur du bord, à 7 pt — la signature du 단청.
    /// Il donne au pan une présence d'objet peint plutôt que de rectangle.
    func dancheongKeyline(cornerRadius: CGFloat) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius - 7, style: .continuous)
                .strokeBorder(.white.opacity(0.42), lineWidth: 1)
                .padding(7)
        )
    }
}
