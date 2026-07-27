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

    /// La couleur d'un univers, et le caractère chinois qui le désigne.
    static func universe(_ slot: String) -> (color: Color, hanja: String) {
        switch slot {
        case "tech": (samcheong, "科")
        case "korea": (hayeop, "韓")
        default: (jangdan, "常")
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
        case "korea": Color(red: 0.796, green: 0.890, blue: 0.808)
        default: Color(red: 0.973, green: 0.855, blue: 0.749)
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
