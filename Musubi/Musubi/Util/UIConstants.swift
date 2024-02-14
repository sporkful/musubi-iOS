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
        case audioTracklistCover = 262
        case artistCover = 162
        case trackCover = 286
    }
    
    static let COVER_IMAGE_SHADOW_RADIUS: CGFloat = 5
    
    // hack to let background gradient extend beyond ScrollView bounds.
    static let SCROLLVIEW_BACKGROUND_CUTOFF: Double = 0.5
//        = ImageDimension.albumCover.rawValue / UIScreen.main.bounds.size.height
    
    // hack for dynamic navbar blurring.
    // remember scrollPosition=0 at top and increases as user scrolls down.
    static let SCROLLVIEW_COVER_BOTTOM_Y: CGFloat
        = ImageDimension.audioTracklistCover.rawValue + COVER_IMAGE_SHADOW_RADIUS
    static let SCROLLVIEW_TITLE_HEIGHT: CGFloat = 40
    static let SCROLLVIEW_TITLE_SAT_POINT: Double = 0.75 // navtitle.opacity=1 when x of title is covered.
    
    static let MENU_SYMBOL_SIZE: Double = 25
}
