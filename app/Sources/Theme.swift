import SwiftUI

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
    static let ground = Color(red: 0.957, green: 0.945, blue: 0.918)
    /// La surface de lecture, plus claire que le fond.
    static let paper = Color(red: 0.984, green: 0.976, blue: 0.961)
    /// 먹 — l'encre.
    static let ink = Color(red: 0.090, green: 0.086, blue: 0.102)
    static let inkSoft = Color(red: 0.553, green: 0.522, blue: 0.475)
    static let separator = Color(red: 0.902, green: 0.882, blue: 0.843)

    /// 삼청 — le bleu.
    static let samcheong = Color(red: 0.169, green: 0.345, blue: 0.463)
    /// 하엽 — le vert feuille.
    static let hayeop = Color(red: 0.247, green: 0.420, blue: 0.290)
    /// 장단 — l'orange dominant du 단청, et la couleur de marque de Molago.
    static let jangdan = Color(red: 0.824, green: 0.376, blue: 0.102)
    /// 자주 — le pourpre, réservé à ce que l'utilisateur attrape lui-même.
    ///
    /// Les trois autres pigments disent **d'où vient le texte** : bleu pour la
    /// tech, vert pour la Corée, orange pour le quotidien. Un mot photographié
    /// sur une facture ne vient d'aucun article — il vient de la vie de celui
    /// qui lit —, et lui donner l'orange du quotidien effaçait cette
    /// différence. Le pourpre est le seul pigment de la palette qu'on ne
    /// confonde avec aucun des trois du coin de l'œil.
    static let jaju = Color(red: 0.400, green: 0.243, blue: 0.451)

    /// 소황 — le jaune d'or, le quatrième pigment. Il arrive avec l'univers Fun,
    /// et c'est le seul de la palette qui reste lisible à côté des trois autres
    /// sans virer au brun.
    static let sohwang = Color(red: 0.722, green: 0.525, blue: 0.169)

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
        switch slot {
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
    static func highlight(_ slot: String) -> Color {
        switch slot {
        case "tech": Color(red: 0.784, green: 0.867, blue: 0.933)
        case "korea", "news": Color(red: 0.796, green: 0.890, blue: 0.808)
        case "fun": Color(red: 0.965, green: 0.886, blue: 0.706)
        case "capture": Color(red: 0.878, green: 0.831, blue: 0.906)
        default: Color(red: 0.973, green: 0.855, blue: 0.749)
        }
    }

    /// Le mot prononcé à l'instant même, dans la phrase déjà surlignée.
    ///
    /// Deux niveaux plutôt qu'un : la phrase claire dit *où on en est* dans le
    /// texte, le mot plus soutenu dit *ce qu'on entend*. Avec un seul niveau on
    /// perd l'un ou l'autre.
    static func wordHighlight(_ slot: String) -> Color {
        switch slot {
        case "tech": Color(red: 0.553, green: 0.729, blue: 0.855)
        case "korea", "news": Color(red: 0.565, green: 0.780, blue: 0.596)
        case "fun": Color(red: 0.914, green: 0.792, blue: 0.514)
        case "capture": Color(red: 0.729, green: 0.647, blue: 0.784)
        default: Color(red: 0.949, green: 0.671, blue: 0.451)
        }
    }
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
