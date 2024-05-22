// LocalClonesTabRoot.swift

import SwiftUI

// TODO: categorize clones as owned vs forks
struct LocalClonesTabRoot: View {
    @Environment(Musubi.User.self) private var currentUser
    
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        @Bindable var currentUser = currentUser
        NavigationStack(path: $navigationPath) {
            List {
                ForEach(currentUser.localClonesIndex) { repositoryReference in
                    NavigationLink(value: repositoryReference) {
                        // TODO: change this to binding? (probably won't get significant perf boost)
                        ListCellWrapper(
                            item: repositoryReference,
                            showThumbnail: true,
                            customTextStyle: .defaultStyle
                        )
                    }
                }
            }
            .navigationDestination(for: Musubi.RepositoryReference.self) { repositoryReference in
                // TODO: better error handling?
                if let repositoryClone = currentUser.openLocalClone(repositoryHandle: repositoryReference.handle) {
                    LocalClonePage(
                        navigationPath: $navigationPath,
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
        }
    }
}

#Preview {
    LocalClonesTabRoot()
}
