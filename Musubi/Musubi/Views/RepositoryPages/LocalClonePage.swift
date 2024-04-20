// LocalClonePage.swift

import SwiftUI

struct LocalClonePage: View {
    @Binding var navigationPath: NavigationPath
    
    @Binding var repositoryReference: Musubi.RepositoryReference
    
    @State var repositoryClone: Musubi.RepositoryClone
    
    var body: some View {
        @Bindable var repositoryClone = repositoryClone // TODO: check this
        
        AudioTrackListPage(
            navigationPath: $navigationPath,
            contentType: .musubiLocalClone,
            name: $repositoryReference.externalMetadata.name,
            description: $repositoryReference.externalMetadata.description,
            coverImageURLString: $repositoryReference.externalMetadata.coverImageURLString,
            audioTrackList: $repositoryClone.stagedAudioTrackList,
            associatedPeople: .users([]),
            date: "",
            toolbarBuilder: {
                HStack {
                    Menu {
                        Button {
                            // TODO: impl
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add all tracks in this collection to playlist")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: Musubi.UI.MENU_SYMBOL_SIZE))
                            .frame(height: Musubi.UI.MENU_SYMBOL_SIZE)
                            .contentShape(Rectangle())
                    }
                    Spacer()
                    Button {
                        // TODO: impl
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: Musubi.UI.SHUFFLE_SYMBOL_SIZE))
                        // TODO: opacity depending on toggle state
                    }
                    Button {
                        // TODO: impl
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: Musubi.UI.PLAY_SYMBOL_SIZE))
                    }
                }
            }
        )
        .alert(
            "Failed to open local clone: \(repositoryReference.externalMetadata.name)",
            isPresented: $repositoryClone.stagingAreaHydrationError,
            actions: {
                Button(
                    "OK",
                    action: {
                        navigationPath.removeLast()
                    }
                )
            },
            message: {
                Text(
                    """
                    Don't worry, your data isn't corrupted! There was just an error when fetching \
                    individual track details from Spotify. Please try opening again.
                    """
                )
            }
        )
    }
}

//#Preview {
//    LocalClonePage()
//}
