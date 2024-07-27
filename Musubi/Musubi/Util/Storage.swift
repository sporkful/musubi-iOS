// Storage.swift

import Foundation

// namespaces
extension Musubi {
  struct Storage {
    private init() {}
    
    struct Keychain {
      private init() {}
    }
    
    struct LocalFS {
      private init() {}
    }
    
    struct Cloud {
      private init() {}
    }
    
    enum Error: LocalizedError {
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
    }
  }
}

extension Musubi.Storage.Keychain {
  struct KeyIdentifier {
    let string: String
    
    init(keyName: KeyName) {
      self.string = "com.musubi-app.keys.\(keyName.rawValue)"
    }
    
    // TODO: support multiple concurrent users?
    // complicated by fact that we don't get user id until after successful oauth login
    //        init(keyName: KeyName, userID: Spotify.ID) {
    //            self.string = "com.musubi-app.keys.\(userID).\(keyName.rawValue)"
    //        }
    
    enum KeyName: String {
      case oauthToken, oauthRefreshToken, oauthExpirationDate
    }
  }
  
  static func save(keyIdentifier: KeyIdentifier, value: Data) throws {
    do {
      try update(keyIdentifier: keyIdentifier, value: value)
    } catch Musubi.Storage.Error.keychain {
      try insert(keyIdentifier: keyIdentifier, value: value)
    }
  }
  
  static func retrieve(keyIdentifier: KeyIdentifier) throws -> Data {
    let query = [
      kSecClass: kSecClassGenericPassword,
      //            kSecAttrService: service,
      kSecAttrAccount: keyIdentifier.string,
      kSecMatchLimit: kSecMatchLimitOne,
      kSecReturnData: true
    ] as CFDictionary
    
    var result: AnyObject?
    let status = SecItemCopyMatching(query, &result)
    guard status == errSecSuccess else {
      throw Musubi.Storage.Error.keychain(detail: "failed to retrieve \(keyIdentifier.string)")
    }
    return result as! Data
  }
  
  static func delete(keyIdentifier: KeyIdentifier) throws {
    let query = [
      kSecClass: kSecClassGenericPassword,
      //            kSecAttrService: service,
      kSecAttrAccount: keyIdentifier.string
    ] as CFDictionary
    
    let status = SecItemDelete(query)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw Musubi.Storage.Error.keychain(detail: "failed to delete \(keyIdentifier.string)")
    }
  }
  
  private static func insert(keyIdentifier: KeyIdentifier, value: Data) throws {
    let attributes = [
      kSecClass: kSecClassGenericPassword,
      //            kSecAttrService: service,
      kSecAttrAccount: keyIdentifier.string,
      kSecValueData: value
    ] as CFDictionary
    
    let status = SecItemAdd(attributes, nil)
    guard status == errSecSuccess else {
      //            if status == errSecDuplicateItem {
      //                throw Musubi.StorageError.keychain(detail: "\(keyName.rawValue) already exists")
      //            }
      throw Musubi.Storage.Error.keychain(detail: "failed to insert \(keyIdentifier.string)")
    }
  }
  
  private static func update(keyIdentifier: KeyIdentifier, value: Data) throws {
    let query = [
      kSecClass: kSecClassGenericPassword,
      //            kSecAttrService: service,
      kSecAttrAccount: keyIdentifier.string
    ] as CFDictionary
    
    let attributes = [
      kSecValueData: value
    ] as CFDictionary
    
    let status = SecItemUpdate(query, attributes)
    guard status == errSecSuccess else {
      //            if status == errSecItemNotFound {
      //                throw Musubi.StorageError.keychain(detail: "update nonexistent \(keyName.rawValue)")
      //            }
      throw Musubi.Storage.Error.keychain(detail: "failed to update \(keyIdentifier.string)")
    }
  }
}

extension Musubi.Storage.LocalFS {
  static var BASE_DIR: URL {
    URL.libraryDirectory.appending(path: "MusubiLocal", directoryHint: .isDirectory)
  }
  
  // Essentially a filesystem-backed cache for Musubi's CAS3, which stores all commits and blobs
  // across all users.
  // **MARK: Note an object's local cache representation is not guaranteed to match the representation on CAS3.**
  static func GLOBAL_OBJECT_FILE(objectID: String) throws -> URL {
    // Since Musubi object IDs are SHA-256 hex digests (16 possibilities for each character, well-distributed),
    // this local cache hierarchically "buckets" objects by pairs of characters in the object's ID.
    // Using pairs of characters ensures that all non-leaf directories have size <= 16^2=256.
    // Using a hierarchy of buckets lets us get away with not doing compaction (like Git) for now...
    // TODO: implement compaction.
    
    // TODO: better way to do this?
    let idIndex2 = objectID.index(objectID.startIndex, offsetBy: 2)
    let idIndex4 = objectID.index(objectID.startIndex, offsetBy: 4)
    let firstBucket = objectID[objectID.startIndex..<idIndex2]
    let secondBucket = objectID[idIndex2..<idIndex4]
    
    let dirURL = BASE_DIR
      .appending(path: "MusubiGlobalObjects", directoryHint: .isDirectory)
      .appending(path: firstBucket, directoryHint: .isDirectory)
      .appending(path: secondBucket, directoryHint: .isDirectory)
    if !doesDirExist(at: dirURL) {
      try createNewDir(at: dirURL, withIntermediateDirectories: true)
    }
    return dirURL.appending(path: objectID, directoryHint: .notDirectory)
  }
  
  // TODO: rename this and its derivatives to "LOCAL_CLONES" for clarity
  static func USER_CLONES_DIR(userID: Spotify.ID) -> URL {
    BASE_DIR
      .appending(path: "Users", directoryHint: .isDirectory)
      .appending(path: userID, directoryHint: .isDirectory)
      .appending(path: "Clones", directoryHint: .isDirectory)
  }
  
  /*
   // TODO: finish integrating this later. will need to check:
   //     - successful new clones in MusubiUser
   //     - modifications to stagedAudioTrackList in MusubiRepository
   // Essentially an embedded key-value store mapping (userID, audioTrackID) to
   // Multiset { repositoryHandle of local clone whose stage includes audioTrackID (multiplicity=numOccurrences) }
   static func USER_STAGED_AUDIO_TRACK_INDEX_FILE(userID: Spotify.ID, audioTrackID: Spotify.ID) throws -> URL {
   // Similar implementation as MUSUBI_GLOBAL_OBJECT_FILE above, but bucketing by single characters
   // instead of pairs, since Spotify audio track IDs are not constrained to hex characters.
   // **MARK: This assumes that the local iOS filesystem can handle Spotify IDs, including case-sensitivity.**
   
   // TODO: better way to do this?
   let idIndex1 = audioTrackID.index(after: audioTrackID.startIndex)
   let idIndex2 = audioTrackID.index(after: idIndex1)
   let firstBucket = audioTrackID[audioTrackID.startIndex..<idIndex1]
   let secondBucket = audioTrackID[idIndex1..<idIndex2]
   
   let dirURL = USER_CLONES_DIR(userID: userID)
   .appending(path: "AudioTrackIndex", directoryHint: .isDirectory)
   .appending(path: firstBucket, directoryHint: .isDirectory)
   .appending(path: secondBucket, directoryHint: .isDirectory)
   if !doesDirExist(at: dirURL) {
   try createNewDir(at: dirURL, withIntermediateDirectories: true)
   }
   return dirURL.appending(path: audioTrackID, directoryHint: .notDirectory)
   }
   */
  
  static func USER_CLONES_INDEX_FILE(userID: Spotify.ID) -> URL {
    USER_CLONES_DIR(userID: userID)
      .appending(path: "Index", directoryHint: .notDirectory)
  }
  
  static func CLONE_DIR(repositoryHandle: Musubi.RepositoryHandle) -> URL {
    USER_CLONES_DIR(userID: repositoryHandle.userID)
      .appending(path: repositoryHandle.playlistID, directoryHint: .isDirectory)
  }
  
  static func CLONE_STAGING_AREA_FILE(repositoryHandle: Musubi.RepositoryHandle) -> URL {
    CLONE_DIR(repositoryHandle: repositoryHandle)
      .appending(path: "index", directoryHint: .notDirectory)
  }
  
  static func CLONE_HEAD_FILE(repositoryHandle: Musubi.RepositoryHandle) -> URL {
    CLONE_DIR(repositoryHandle: repositoryHandle)
      .appending(path: "HEAD", directoryHint: .notDirectory)
  }
  
  static func CLONE_FORK_PARENT_FILE(repositoryHandle: Musubi.RepositoryHandle) -> URL {
    CLONE_DIR(repositoryHandle: repositoryHandle)
      .appending(path: "FORK_PARENT", directoryHint: .notDirectory)
  }
}

extension Musubi.Storage.LocalFS {
  static func doesDirExist(at dirURL: URL) -> Bool {
    return (try? dirURL.checkResourceIsReachable()) ?? false
    && (try? dirURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
  }
  
  static func createNewDir(at dirURL: URL, withIntermediateDirectories: Bool) throws {
    try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: withIntermediateDirectories)
  }
  
  static func contentsOf(dirURL: URL) throws -> [URL] {
    return try FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil)
  }
  
  static func doesFileExist(at fileURL: URL) -> Bool {
    return (try? fileURL.checkResourceIsReachable()) ?? false
    && (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
  }
}

extension Musubi.Storage.LocalFS {
  // Parameter `commitID` is necessary since there may be differences in encoding (for hashing)
  // across platforms.
  static func save(commit: Musubi.Model.Commit, commitID: String) throws {
    try JSONEncoder().encode(commit).write(
      to: GLOBAL_OBJECT_FILE(objectID: commitID),
      options: .atomic
    )
  }
  
  static func save(blob: Musubi.Model.Blob, blobID: String) throws {
    try Data(blob.utf8).write(
      to: GLOBAL_OBJECT_FILE(objectID: blobID),
      options: .atomic
    )
  }
  
  static func loadCommit(commitID: String) throws -> Musubi.Model.Commit {
    return try JSONDecoder().decode(
      Musubi.Model.Commit.self,
      from: Data(contentsOf: GLOBAL_OBJECT_FILE(objectID: commitID))
    )
  }
  
  static func loadBlob(blobID: String) throws -> Musubi.Model.Blob {
    return try String(contentsOf: GLOBAL_OBJECT_FILE(objectID: blobID), encoding: .utf8)
  }
}

/*
 // TODO: if can't find locally (e.g. if eviction is introduced for "cache"), try cas3 directly
 extension Musubi.Storage {
 static func loadCommit(commitID: String) throws -> Musubi.Model.Commit {
 do {
 return try LocalFS.loadCommit(commitID: commitID)
 } catch {
 // TODO: try cas3 directly
 }
 }
 
 static func loadBlob(blobID: String) throws -> Musubi.Model.Blob {
 do {
 return try LocalFS.loadBlob(blobID: blobID)
 } catch {
 // TODO: try cas3 directly
 }
 }
 }
 */
