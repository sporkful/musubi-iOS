// LocalClonePage.swift

import SwiftUI

struct LocalClonePage: View {
    @Binding var navigationPath: NavigationPath
    
    // TODO: make these environment variables rooted at parent navDest?
    @Binding var repositoryReference: Musubi.RepositoryReference
    
    @Bindable var repositoryClone: Musubi.RepositoryClone
    
    @State private var showSheetEditor = false
    
    @State private var showSheetNewCommit = false
    
    @State private var showSheetAddToSelectableClones = false
    
    // TODO: placeholder view in lieu of all `isViewDisabled`s
    @State private var isViewDisabled = false
    
    var body: some View {
        AudioTrackListPage(
            navigationPath: $navigationPath,
            contentType: .musubiLocalClone,
            name: $repositoryReference.externalMetadata.name,
            description: $repositoryReference.externalMetadata.description,
            coverImageURLString: $repositoryReference.externalMetadata.coverImageURLString,
            audioTrackList: $repositoryClone.stagedAudioTrackList,
            showAudioTrackThumbnails: true,
            associatedPeople: .users([]),
            miscCaption: nil,  // TODO: last modified?
            toolbarBuilder: {
                HStack {
                    Button {
                        showSheetEditor = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    Button {
                        showSheetNewCommit = true
                    } label: {
                        Image(systemName: "icloud.and.arrow.up")
                    }
                    Button {
                        // TODO: show commit history / checkout page
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    Menu {
                        Button {
                            showSheetAddToSelectableClones = true
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add tracks from this collection to")
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
        // TODO: put this on navstack so users can keep edit page open while adding tracks via search tab
        .sheet(isPresented: $showSheetEditor) {
            LocalCloneEditorPage(
                showSheet: $showSheetEditor,
                repositoryReference: $repositoryReference,
                repositoryClone: repositoryClone
            )
            .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showSheetNewCommit) {
            NewCommitPage(
                showSheet: $showSheetNewCommit,
                repositoryReference: $repositoryReference,
                repositoryClone: repositoryClone
            )
        }
        .sheet(isPresented: $showSheetAddToSelectableClones) {
            AddToSelectableLocalClonesSheet(
                audioTrackList: $repositoryClone.stagedAudioTrackList,
                showSheet: $showSheetAddToSelectableClones
            )
        }
        .disabled(isViewDisabled)
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
