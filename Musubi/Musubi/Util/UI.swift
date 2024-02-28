// UI.swift

import Foundation
import UIKit

// namespaces
extension Musubi {
    struct UI {
        private init() {}
    }
}

extension Musubi.UI {
    static let SCREEN_HEIGHT = UIScreen.main.bounds.size.height
    static let SCREEN_WIDTH = UIScreen.main.bounds.size.width
    
    // TODO: clip by device dimensions
    enum ImageDimension: CGFloat {
        case cellThumbnail = 42
        case audioTracklistCover = 262
        case artistCover = 162
        case trackCover = 286
    }
    
    static let COVER_IMAGE_SHADOW_RADIUS: CGFloat = 5
    
    static let TITLE_TEXT_HEIGHT: CGFloat = 40
    
    static let MENU_SYMBOL_SIZE: Double = 25
    static let PLAY_SYMBOL_SIZE: Double = 50
    static let SHUFFLE_SYMBOL_SIZE: Double = 33
}

extension Musubi.UI {
    static func lerp(
        x: CGFloat,
        x1: CGFloat,
        y1: CGFloat,
        x2: CGFloat,
        y2: CGFloat,
        minY: CGFloat,
        maxY: CGFloat
    ) -> CGFloat {
        return min(max((y2 - y1) / (x2 - x1) * (x - x1) + y1, minY), maxY)
    }
    
    static func clamp(y: CGFloat, minY: CGFloat, maxY: CGFloat) -> CGFloat {
        return min(max(y, minY), maxY)
    }
}
