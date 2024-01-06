// Error.swift

import Foundation

extension Musubi {
    enum StorageError: LocalizedError {
        case local(detail: String)
        case remote(detail: String)

        var errorDescription: String? {
            let description = switch self {
                case let .local(detail): "(local) \(detail)"
                case let .remote(detail): "(remote) \(detail)"
            }
            return "[Musubi::Storage] \(description)"
        }

        // TODO: add `failureReason` and `recoverySuggestion`?
    }
    
    enum CryptoError: LocalizedError {
        case pkce(detail: String)

        var errorDescription: String? {
            let description = switch self {
                case let .pkce(detail): "(pkce) \(detail)"
            }
            return "[Musubi::Cryptography] \(description)"
        }
    }
}

extension Spotify {
    enum AuthError: LocalizedError {
        case any(detail: String)

        var errorDescription: String? {
            let description = switch self {
                case let .any(detail): "\(detail)"
            }
            return "[SpotifyWebClient::Auth] \(description)"
        }
    }
}

//extension Musubi {
//    private enum CommonSuggestedFix {
//        case reopen, reinstall
//        
//        var text: String {
//            switch self {
//            case .reinstall:
//                return "deleting and re-installing the app"
//            case .reopen:
//                return "quitting and re-opening the app"
//            }
//        }
//    }
//    
//    private static func longMessage(suggestedFix: CommonSuggestedFix) -> String {
//        return longMessage(suggestedFix: suggestedFix.text)
//    }
//    
//    private static func longMessage(suggestedFix: String) -> String {
//    """
//    Apologies for the inconvenience! \
//    We're still working out the kinks in this early release. \
//    Please try \(suggestedFix), \
//    and let us know if the issue persists!
//    """
//    }
//}
