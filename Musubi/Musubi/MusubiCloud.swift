// MusubiCloud.swift

import Foundation

// namespaces
extension Musubi {
    struct Cloud {
        private init() {}
        
        struct Request {
            private init() {}
        }
        
        struct Response {
            private init() {}
        }
        
        enum Error: LocalizedError {
            case request(detail: String)
            case response(detail: String)

            var errorDescription: String? {
                let description = switch self {
                    case let .request(detail): "(request) \(detail)"
                    case let .response(detail): "(response) \(detail)"
                }
                return "[Musubi::Cloud] \(description)"
            }
        }
    }
}

protocol MusubiCloudRequest: Encodable {
    var httpPath: String { get }
}

protocol MusubiCloudResponse: Decodable { }

extension Musubi.Cloud {
    static func make<RequestType: MusubiCloudRequest, ResponseType: MusubiCloudResponse>(
        request: RequestType
    ) async throws -> ResponseType {
        var components = URLComponents()
        components.scheme = "https"
        components.host = API_HOSTNAME
        components.path = request.httpPath
        guard let url = components.url else {
            throw Error.request(detail: "failed to create valid request URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 30
        
        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try jsonEncoder.encode(request)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        urlRequest.setValue(
            try await Musubi.UserManager.shared.getAuthToken(),
            forHTTPHeaderField: "X-Musubi-SpotifyAuth"
        )
        
        let (responseData, responseMetadata) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = responseMetadata as? HTTPURLResponse else {
            throw Musubi.Cloud.Error.response(detail: "unable to parse response as HTTP")
        }
        guard httpResponse.statusCode == 200 else {
            throw Musubi.Cloud.Error.response(detail: "failed - \(httpResponse.statusCode)")
        }
        
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        return try jsonDecoder.decode(ResponseType.self, from: responseData)
    }
}

extension Musubi.Cloud.Request {
    struct InitOrClone: MusubiCloudRequest {
        let httpPath = "/init-or-clone"
        
        let playlistID: String
    }
    
    struct ForkOrClone: MusubiCloudRequest {
        let httpPath = "/fork-or-clone"
    }
    
    struct Commit: MusubiCloudRequest {
        let httpPath = "/commit"
        
        let playlistID: String
        let latestSyncCommitID: String
        let proposedCommit: Musubi.Model.Commit
        let proposedCommitBlob: Musubi.Model.Blob
    }
    
    struct Pull: MusubiCloudRequest {
        let httpPath = "/pull"
    }
    
    struct PullFromForkParent: MusubiCloudRequest {
        let httpPath = "/pull-from-fork-parent"
    }
    
    struct MakePullRequest: MusubiCloudRequest {
        let httpPath = "/make-pull-request"
    }
    
    struct AcceptPullRequest: MusubiCloudRequest {
        let httpPath = "/accept-pull-request"
    }
    
    struct RejectPullRequest: MusubiCloudRequest {
        let httpPath = "/reject-pull-request"
    }
}

extension Musubi.Cloud.Response {
    struct Clone: MusubiCloudResponse {
        let commits: [String: Musubi.Model.Commit]
        let blobs: [String: Musubi.Model.Blob]
        
        let headCommitID: String
        let forkParent: RelatedRepository?
        
        struct RelatedRepository: Decodable {
            let userID: String
            let playlistID: String
            // Note omission of remotely-mutable `LatestSyncCommitID`, which is handled by backend.
        }
    }
    
    enum Commit: MusubiCloudResponse {
        case success(
            newCommitID: String,
            newCommit: Musubi.Model.Commit
        )
        case remoteUpdates(
            commits: [String: Musubi.Model.Commit],
            blobs: [String: Musubi.Model.Blob]
        )
        case spotifyUpdates
    }
}
