// LocalClonesTabRoot.swift

import SwiftUI

// TODO: categorize clones as owned vs forks
struct LocalClonesTabRoot: View {
    @Environment(Musubi.UserManager.self) private var userManager
    @Environment(Musubi.User.self) private var currentUser
    
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                ForEach(currentUser.localClones, id: \.self) { repositoryHandle in
                    NavigationLink(value: repositoryHandle) {
                        ListCell(item: currentUser.localClonesIndex[repositoryHandle]!)
                    }
                }
            }
            .navigationDestination(for: Musubi.RepositoryHandle.self) { repositoryHandle in
                LocalClonePage(navigationPath: $navigationPath, repositoryHandle: repositoryHandle)
            }
            .navigationTitle("My Local Repositories")
            .task {
                // TODO: better error handling?
                try? await currentUser.refreshClonesExternalMetadata(userManager: userManager)
            }
        }
    }
}

#Preview {
    LocalClonesTabRoot()
}
