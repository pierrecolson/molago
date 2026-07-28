import UIKit

extension UIImage {
    /// Le + de la capture, dessiné plutôt qu'emprunté aux symboles système.
    ///
    /// Un `systemImage` dans une barre d'onglets se voit imposer sa taille et sa
    /// teinte : ni `.font(...)` ni `.foregroundStyle(...)` n'y peuvent rien. Une
    /// image marquée `.alwaysOriginal`, elle, garde ses couleurs — et en
    /// remplissant tout le carré on obtient un bouton visuellement plus gros que
    /// ce que la barre accorde à un glyphe.
    static let captureGlyph: UIImage = {
        let side: CGFloat = 30
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { context in
            let cg = context.cgContext
            // 장단, l'orange du 단청 — la couleur de marque.
            cg.setFillColor(UIColor(red: 0.824, green: 0.376, blue: 0.102, alpha: 1).cgColor)
            cg.fillEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))

            // La croix, en blanc, en creux dans le disque.
            let arm: CGFloat = side * 0.42
            let thickness: CGFloat = side * 0.12
            cg.setFillColor(UIColor.white.cgColor)
            cg.fill(CGRect(x: (side - arm) / 2, y: (side - thickness) / 2, width: arm, height: thickness))
            cg.fill(CGRect(x: (side - thickness) / 2, y: (side - arm) / 2, width: thickness, height: arm))
        }
        return image.withRenderingMode(.alwaysOriginal)
    }()
}
