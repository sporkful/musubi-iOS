// LocalClonesTabRoot.swift

import SwiftUI

// TODO: categorize clones as owned vs forks
struct LocalClonesTabRoot: View {
    @Environment(Musubi.UserManager.self) private var userManager
    @Environment(Musubi.User.self) private var currentUser
    
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        @Bindable var currentUser = currentUser
        NavigationStack(path: $navigationPath) {
            List {
                ForEach($currentUser.localClonesIndex, id: \.self) { $repositoryReference in
                    NavigationLink(value: repositoryReference.handle) {
                        // TODO: change this to binding? (probably won't get significant perf boost)
                        ListCell(repositoryReference: repositoryReference)
                    }
                }
            }
            .navigationDestination(for: Musubi.RepositoryHandle.self) { repositoryHandle in
                LocalClonePage(
                    navigationPath: $navigationPath,
                    repositoryReference: $currentUser.localClonesIndex.first(where: { $0.wrappedValue.handle == repositoryHandle })!
                )
            }
            .navigationTitle("My Local Repositories")
            .task {
                // TODO: periodic background refresh?
                await currentUser.refreshClonesExternalMetadata(userManager: userManager)
            }
        }
    }
}

#Preview {
    LocalClonesTabRoot()
}
