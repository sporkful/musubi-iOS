// UI.swift

import Foundation
import UIKit

// namespaces
extension Musubi {
    struct UI {
        private init() {}
        
        enum Error: LocalizedError {
            case misc(detail: String)

            var errorDescription: String? {
                let description = switch self {
                    case let .misc(detail): "\(detail)"
                }
                return "[Musubi::UI] \(description)"
            }
        }
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
        case playerCover = 286
    }
    
//    static let MENU_SYMBOL_SIZE: Double = 25
    static let PLAY_SYMBOL_SIZE: Double = 50
    static let SHUFFLE_SYMBOL_SIZE: Double = 25
    static let CHECKBOX_SYMBOL_SIZE: Double = (ImageDimension.cellThumbnail.rawValue / 2)
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

extension Musubi.UI {
    struct ErrorMessage {
        private let suggestedFix: SuggestedFix
        
        init(suggestedFix: SuggestedFix) {
            self.suggestedFix = suggestedFix
        }
        
        var string: String {
            """
            Apologies for the inconvenience! \
            We're still working out the kinks in this early release of Musubi. \
            Please try again. \
            \
            If the same error keeps popping up, \(suggestedFix) \
            We appreciate your patience and feedback - it helps us improve your future experience!
            """
        }
        
        enum SuggestedFix {
            case reopen, relogin, reinstall, contactDev
            
            var text: String {
                return switch self {
                    case .reopen: "try quitting and re-opening the Musubi app."
                    case .relogin: "try logging out and logging back in."
                    case .reinstall: "try deleting and re-installing the Musubi app."
                    case .contactDev: "please let us know so we can fix it."
                }
            }
        }
    }
}
