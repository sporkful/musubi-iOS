// UIConstants.swift

import Foundation
import UIKit

// namespaces
extension Musubi {
    struct UIConstants {
        private init() {}
    }
}

extension Musubi.UIConstants {
    // TODO: clip by device dimensions
    enum ImageDimension: CGFloat {
        case cellThumbnail = 42
        case albumCover = 262
        case artistCover = 162
        case trackCover = 286
    }
    
    static let IMAGE_SHADOW_RADIUS: CGFloat = 5
    
    static let SCROLLVIEW_BACKGROUND_CUTOFF = 0.5
//        = ImageDimension.albumCover.rawValue / UIScreen.main.bounds.size.height
    
    static let MENU_SYMBOL_SIZE: Double = 25
}
