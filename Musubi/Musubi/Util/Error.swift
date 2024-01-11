// Error.swift

import Foundation

extension Musubi {
    enum StorageError: LocalizedError {
        case local(detail: String)
        case remote(detail: String)
        case keychain(detail: String)

        var errorDescription: String? {
            let description = switch self {
                case let .local(detail): "(local) \(detail)"
                case let .remote(detail): "(remote) \(detail)"
                case let .keychain(detail): "(keychain) \(detail)"
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

extension Musubi {
    enum ErrorSuggestedFix {
        case reopen, reinstall, none
        
        var text: String {
            switch self {
            case .reinstall:
                return "Please try deleting and re-installing the Musubi app."
            case .reopen:
                return "Please try quitting and re-opening the Musubi app."
            case .none:
                return ""
            }
        }
    }
    
    static func errorAlertMessage(suggestedFix: ErrorSuggestedFix) -> String {
        return errorAlertMessage(suggestedFix: suggestedFix.text)
    }
    
    static func errorAlertMessage(suggestedFix: String) -> String {
        """
        Apologies for the inconvenience! \
        We're still working out the kinks in this early release. \
        \(suggestedFix) \
        If the same error keeps popping up, please let us know so we can fix it!
        We appreciate your patience :)
        """
    }
}
