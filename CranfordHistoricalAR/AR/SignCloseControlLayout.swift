import Foundation

/// Hit target for the corner close glyph on the rasterized sign texture.
///
/// The glyph is drawn in a 720 pt-wide texture. Its center sits a fixed number of
/// points in from the top and right edges, and those points map onto the plane
/// using the card width. The geo sign is 1.6 m wide, so a 0.16 m inset still
/// covers that glyph. The plaque card is 0.45 m wide; the same meter inset lands
/// on the body copy, and the 0.22 m hit box then dismisses the sign.
struct SignCloseControlLayout: Equatable {
    var centerX: Float
    var centerY: Float
    var size: Float

    /// `symbolInsetPoints` is the distance from the texture's top-right corner to
    /// the center of `xmark.circle` (padding + half the symbol).
    static func make(
        cardWidth: Float,
        cardHeight: Float,
        planeY: Float,
        forPlaqueCard: Bool,
        textureWidthPoints: Float = 720
    ) -> SignCloseControlLayout {
        if forPlaqueCard {
            let inset = cardWidth * (54 / textureWidthPoints)
            let size = min(Float(0.09), cardWidth * 0.2)
            return SignCloseControlLayout(
                centerX: cardWidth / 2 - inset,
                centerY: planeY + cardHeight / 2 - inset,
                size: size
            )
        }
        return SignCloseControlLayout(
            centerX: cardWidth / 2 - 0.16,
            centerY: planeY + cardHeight / 2 - 0.16,
            size: 0.22
        )
    }

    /// True when a point on the card plane, in the sign's local X/Y, hits this control.
    func contains(x: Float, y: Float) -> Bool {
        abs(x - centerX) <= size / 2 && abs(y - centerY) <= size / 2
    }
}
