// LocalClonePage.swift

import SwiftUI

struct LocalClonePage: View {
    @Environment(HomeViewCoordinator.self) private var homeViewCoordinator
    
    @Binding var navigationPath: NavigationPath
    
    @Bindable var repositoryClone: Musubi.RepositoryClone
    
    @State private var showSheetEditor = false
    @State private var showSheetNewCommit = false
    
    var body: some View {
        @Bindable var homeViewCoordinator = homeViewCoordinator
        
        AudioTrackListPage(
            navigationPath: $navigationPath,
            audioTrackList: repositoryClone.stagedAudioTrackList,
            showAudioTrackThumbnails: true,
            customToolbarPrimaryItems: [
                .init(title: "Edit local clone", sfSymbolName: "pencil", action: { showSheetEditor = true }),
                .init(title: "Create new commit", sfSymbolName: "icloud.and.arrow.up", action: { showSheetNewCommit = true }),
                .init(title: "Show commit history", sfSymbolName: "clock.arrow.circlepath", action: { homeViewCoordinator.showSheetCommitHistory = true })
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
        .sheet(isPresented: $homeViewCoordinator.showSheetCommitHistory) {
            CommitHistoryPage(
                showSheet: $homeViewCoordinator.showSheetCommitHistory,
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
