// Retry.swift

import Foundation

// namespaces
extension Musubi {
  struct Retry {
    private init() {}
  }
}

extension Musubi.Retry {
  // TODO: check ARC
  static func run(
    failableAction: @escaping () async throws -> Void,
    retryAfter: TimeInterval = 3,
    maxTries: Int = 5,
    verbose: Bool = false
  ) {
    Task { @MainActor in
      var numTries: Int = 0
      while numTries < maxTries {
        do {
          try await failableAction()
          return
        } catch {
          if verbose {
            print("[Musubi::Retry] retrying after error:\n\(error.localizedDescription)")
          }
          numTries += 1
        }
        do {
          try await Task.sleep(until: .now + .seconds(retryAfter), clock: .continuous)
        } catch {
          if verbose {
            print("[Musubi::Retry] giving up")
          }
          break // task was cancelled
        }
      }
    }
  }
}
