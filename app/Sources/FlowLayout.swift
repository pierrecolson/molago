import SwiftUI

/// Coule des vues les unes après les autres et passe à la ligne quand la place
/// manque — ce qu'un paragraphe de texte fait naturellement, mais appliqué à des
/// vues séparées.
///
/// Pourquoi ne pas garder un simple `Text` : parce qu'un mot doit être **visé du
/// doigt**. Un `Text` unique s'écoule parfaitement mais ne dit pas sur quel mot
/// on a tapé. Une vue par mot répond à la question, à condition de savoir les
/// disposer — c'est tout ce que fait ce fichier.
struct FlowLayout: Layout {
    /// L'espace entre deux mots. C'est l'espace typographique du texte, pas une
    /// marge : trop grand, la phrase cesse de se lire comme une phrase.
    var spacing: CGFloat = 5
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
