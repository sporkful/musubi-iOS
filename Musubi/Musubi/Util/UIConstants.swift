// UIConstants.swift

import Foundation

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
    
    static let MENU_SYMBOL_SIZE: Double = 25
}
