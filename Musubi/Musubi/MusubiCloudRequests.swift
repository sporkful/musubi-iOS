// MusubiCloudRequests.swift

import Foundation

struct MusubiCloudRequests {
    private init() {}
}

extension MusubiCloudRequests {
    private enum CommandPath: String {
        case InitOrClone
        case ForkOrClone
        case Push
        case Pull
        case PullFromForkParent
        case MakePullRequest
        case AcceptPullRequest
        case RejectPullRequest
    }
    
    private static func createRequest(
        cmdPath: CommandPath,
        bodyData: Data
    ) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = API_HOSTNAME
        components.path = "/\(cmdPath.rawValue)"
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
}

extension MusubiCloudRequests {
    struct CloneMetadata_Response: Codable {
        let HeadHash: String  // "owned" by this local clone
        let ForkParent: RelatedRepo?  // immutable so safe to "cache" locally for UI
        
        struct RelatedRepo: Codable {
            let OwnerID: String
            let PlaylistID: String
            // note omission of the mutable `LatestSyncCommitHash`
        }
    }
    
    struct InitOrClone_RequestBody: Codable {
        let playlistID: String
    }
    
    static func initOrClone(
        requestBody: InitOrClone_RequestBody,
        userManager: Musubi.UserManager
    ) async throws -> CloneMetadata_Response {
        var request = try MusubiCloudRequests.createRequest(
            cmdPath: .InitOrClone,
            bodyData: try JSONEncoder().encode(requestBody)
        )
        let data = try await userManager.makeAuthdMusubiCloudRequest(request: &request)
        return try JSONDecoder().decode(CloneMetadata_Response.self, from: data)
    }
    
    // TODO: forkOrClone
}

extension MusubiCloudRequests {
    struct Push_RequestBody: Codable {
        let playlistID: String
        let proposedCommitHash: String
        let proposedCommit: Musubi.Model.Commit
        let latestSyncCommitHash: String
    }
    
    enum Push_Response: Codable {
        case success
        case remoteUpdates(commits: [Musubi.Model.Commit])
        case spotifyUpdates(audioTrackIDList: Musubi.Model.AudioTrackList)
    }
    
    static func push(
        requestBody: Push_RequestBody,
        userManager: Musubi.UserManager
    ) async throws -> Push_Response {
        var request = try MusubiCloudRequests.createRequest(
            cmdPath: .Push,
            bodyData: try JSONEncoder().encode(requestBody)
        )
        let data = try await userManager.makeAuthdMusubiCloudRequest(request: &request)
        return try JSONDecoder().decode(Push_Response.self, from: data)
    }
}
