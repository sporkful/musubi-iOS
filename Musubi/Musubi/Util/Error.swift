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
    
    enum RequestError: LocalizedError {
        case creation(detail: String)
        case response(detail: String)

        var errorDescription: String? {
            let description = switch self {
                case let .creation(detail): "(creation) \(detail)"
                case let .response(detail): "(response) \(detail)"
            }
            return "[SpotifyWebClient::Request] \(description)"
        }
    }
}

extension Musubi {
    struct ErrorMessage {
        private let suggestedFix: SuggestedFix
        
        init(suggestedFix: SuggestedFix) {
            self.suggestedFix = suggestedFix
        }
        
        var text: String {
            """
            Apologies for the inconvenience! \
            We're still working out the kinks in this early release of Musubi. \
            Please try again. \
            \
            If the same error keeps popping up, \(suggestedFix) \
            We appreciate your patience and feedback - it helps us improve your future experience :)
            """
        }
        
        enum SuggestedFix {
            case reopen, relogin, reinstall, none
            
            var text: String {
                return switch self {
                    case .reopen: "try quitting and re-opening the Musubi app."
                    case .relogin: "try logging out and logging back in."
                    case .reinstall: "try deleting and re-installing the Musubi app."
                    case .none: "please let us know so we can fix it."
                }
            }
        }
    }
}
