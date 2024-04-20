// LocalClonesTabRoot.swift

import SwiftUI

// TODO: categorize clones as owned vs forks
struct LocalClonesTabRoot: View {
    @Environment(Musubi.User.self) private var currentUser
    
    @State private var navigationPath = NavigationPath()
    
    @State private var periodicBackgroundTimer: Timer?
    
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
                // TODO: better error handling?
                if let repositoryClone = try? Musubi.RepositoryClone(handle: repositoryHandle) {
                    LocalClonePage(
                        navigationPath: $navigationPath,
                        repositoryReference: $currentUser.localClonesIndex.first(where: { $0.wrappedValue.handle == repositoryHandle })!,
                        repositoryClone: repositoryClone
                    )
                } else {
                    VStack(alignment: .center) {
                        Spacer()
                        Text("Error when loading local clone.\nPlease try again.")
                            .multilineTextAlignment(.center)
                        Button(
                            action: {
                                navigationPath.removeLast()
                            },
                            label: {
                                Text("OK")
                                    .foregroundStyle(.blue)
                            }
                        )
                        .padding()
                        Spacer()
                    }
                }
            }
            .navigationTitle("My Local Repositories")
            .task {
                // TODO: uncomment this when rate limit timeout is over
//                periodicBackgroundTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) {
//                    [weak currentUser] (_) in
//                    Task { [weak currentUser] in
//                        await currentUser?.refreshClonesExternalMetadata(userManager: userManager)
//                    }
//                }
            }
        }
    }
}

#Preview {
    LocalClonesTabRoot()
}
