// LocalClonePage.swift

import SwiftUI

struct LocalClonePage: View {
    @Binding var navigationPath: NavigationPath
    
    @Bindable var repositoryClone: Musubi.RepositoryClone
    
    @State private var showSheetEditor = false
    @State private var showSheetNewCommit = false
    
    var body: some View {
        AudioTrackListPage(
            navigationPath: $navigationPath,
            audioTrackList: repositoryClone.stagedAudioTrackList,
            showAudioTrackThumbnails: true,
            customToolbarAdditionalItems: [
                .init(title: "Edit local clone", sfSymbolName: "pencil", action: { showSheetEditor = true }),
                .init(title: "Create new commit", sfSymbolName: "icloud.and.arrow.up", action: { showSheetNewCommit = true }),
                .init(title: "Show commit history", sfSymbolName: "clock.arrow.circlepath", action: { /* TODO: impl */ })
            ]
        )
        // TODO: put this on navstack so users can keep edit page open while adding tracks via search tab
        .sheet(isPresented: $showSheetEditor) {
            LocalCloneEditorPage(
                showSheet: $showSheetEditor,
                repositoryClone: repositoryClone
            )
            .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showSheetNewCommit) {
            NewCommitPage(
                showSheet: $showSheetNewCommit,
                repositoryClone: repositoryClone
            )
        }
        // TODO: impl
//        .alert(
//            "Failed to open local clone: \(repositoryClone.repositoryReference.name)",
//            isPresented: $repositoryClone.stagingAreaHydrationError,
//            actions: {
//                Button(
//                    "OK",
//                    action: {
//                        navigationPath.removeLast()
//                    }
//                )
//            },
//            message: {
//                Text(
//                    """
//                    Don't worry, your data isn't corrupted! There was just an error when fetching \
//                    individual track details from Spotify. Please try opening again.
//                    """
//                )
//            }
//        )
    }
}

//#Preview {
//    LocalClonePage()
//}
