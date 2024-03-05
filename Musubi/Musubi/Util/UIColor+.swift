// UIColor+.swift

import Foundation
import UIKit

extension UIColor {
    // TODO: mute near-white colors but keep brightness of darker colors (e.g. La La Land cover)
    func muted() -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        self.getHue(
            &hue,
            saturation: &saturation,
            brightness: &brightness,
            alpha: &alpha
        )
        return UIColor(
            hue: hue,
            saturation: saturation,
            brightness: min(brightness, 0.420),
            alpha: alpha
        )
    }
}
