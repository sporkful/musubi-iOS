// MusubiCloudRequests.swift

import Foundation

struct MusubiCloudRequests {
    private init() {}
}

extension MusubiCloudRequests {
    enum Command: String {
        // MusubiUser
        case INIT_OR_CLONE
        case FORK_OR_CLONE
        
        // MusubiRepository
        case PUSH
        case PULL
        case PULL_FROM_FORK_PARENT
        case MAKE_PULL_REQUEST
        case ACCEPT_PULL_REQUEST
        case REJECT_PULL_REQUEST
        
        var httpPath: String {
            return "/\(self.rawValue)"
                .lowercased()
                .replacingOccurrences(of: "_", with: "-")
        }
    }
    
    static func createRequest(
        command: Command,
        bodyData: Data
    ) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = API_HOSTNAME
        components.path = command.httpPath
        guard let url = components.url else {
            throw Musubi.CloudRequestError.any(detail: "failed to create valid request URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        return request
    }
    
    // TODO: is there a better way to do this (enforce date en/decoding as iso8601)
    // TODO: wrap this in a single function that encodes the body, creates the request, sends it, and returns the decoded response
    static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    static func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
