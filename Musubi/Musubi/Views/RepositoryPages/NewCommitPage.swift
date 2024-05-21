// NewCommitPage.swift

import SwiftUI

struct NewCommitPage: View {
    @Binding var showSheet: Bool
    
    @Binding var repositoryReference: Musubi.RepositoryReference
    
    @Bindable var repositoryClone: Musubi.RepositoryClone
    
    @State private var commitMessage = ""
    
    @State private var visualDiffFromHead: [Musubi.ViewModel.AudioTrackList.VisualChange] = []
    
    // TODO: impl
    @State private var showPlaceholderOverlay = false
    
    @State private var showAlertErrorDiff = false
    
    @State private var dummyNavigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                List {
                    Section("Diff from most recent previous commit") {
                        ForEach(visualDiffFromHead, id: \.self) { visualChange in
                            // TODO: will this react to updates in relevantAudioTrackData?
                            // TODO: row numbers and +/- annotations
                            // TODO: moves
                            // TODO: undo by row?
                                switch visualChange.change {
                                case .none:
                                    AudioTrackListCell(
                                        isNavigable: false,
                                        navigationPath: $dummyNavigationPath,
                                        audioTrackListElement: visualChange.element,
                                        showThumbnail: true,
                                        customTextStyle: .defaultStyle
                                    )
                                case .inserted(associatedWith: let associatedWith):
                                    AudioTrackListCell(
                                        isNavigable: false,
                                        navigationPath: $dummyNavigationPath,
                                        audioTrackListElement: visualChange.element,
                                        showThumbnail: true,
                                        customTextStyle: .init(color: .green, bold: true)
                                    )
                                    .listRowBackground(Color.green.opacity(0.180))
                                case .removed(associatedWith: let associatedWith):
                                    AudioTrackListCell(
                                        isNavigable: false,
                                        navigationPath: $dummyNavigationPath,
                                        audioTrackListElement: visualChange.element,
                                        showThumbnail: true,
                                        customTextStyle: .init(color: .red, bold: true)
                                    )
                                    .listRowBackground(Color.red.opacity(0.180))
                            }
                        }
                    }
                    Section("Commit message") {
                        TextField("Enter a message for your new commit here", text: $commitMessage)
                    }
                    Button {
                        commit(message: commitMessage)
                    } label: {
                        HStack {
                            Spacer()
                            Text("Create new commit")
                                .bold()
                                .listRowBackground(Color.white.opacity(0.280))
                            Spacer()
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack {
                            Text("New commit")
                                .font(.caption)
                            Text(repositoryReference.externalMetadata.name)
                                .font(.headline)
                        }
                        .padding(.vertical, 5)
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button(
                            role: .cancel,
                            action: {
                                showSheet = false
                            },
                            label: {
                                Text("Cancel")
                            }
                        )
                    }
                    // balances out above
                    ToolbarItem(placement: .topBarTrailing) {
                        Text("Cancel")
                            .hidden()
//                        Button(
//                            action: {
//                                withAnimation {
//                                    scrollProxy.scrollTo(bottom)
//                                }
//                            },
//                            label: {
//                                Text("Create")
//                                    .bold()
//                            }
//                        )
                    }
                }
                .interactiveDismissDisabled(true)
                .alert(
                    "Failed to generate diff from head",
                    isPresented: $showAlertErrorDiff,
                    actions: {
                        Button(
                            "OK",
                            action: {
                                showSheet = false
                            }
                        )
                    }, message: {
                        Text(Musubi.UI.ErrorMessage(suggestedFix: .contactDev).string)
                    }
                )
                .task {
                    await loadVisualDiffFromHead()
                }
            }
        }
    }
    
    private func loadVisualDiffFromHead() async {
        do {
            let headCommit = try Musubi.Storage.LocalFS.loadCommit(
                commitID: await repositoryClone.headCommitID
            )
            let headAudioTrackIDList: [Spotify.ID] = try Musubi.Storage.LocalFS.loadBlob(blobID: headCommit.blobID)
                .components(separatedBy: ",")
            
            var relevantAudioTrackData = await self.repositoryClone.stagedAudioTrackList.audioTrackData
            for try await sublist in SpotifyRequests.Read.audioTracks(
                audioTrackIDs: Set(headAudioTrackIDList)
                    .subtracting(relevantAudioTrackData.keys)
                    .joined(separator: ",")
            ) {
                sublist.forEach { audioTrack in
                    relevantAudioTrackData[audioTrack.id] = audioTrack
                }
            }
            
            let headAudioTrackList = try await Musubi.ViewModel.AudioTrackList(
                audioTracks: headAudioTrackIDList.map { id in
                    guard let audioTrack = relevantAudioTrackData[id] else {
                        throw Musubi.UI.Error.misc(
                            detail: "[Musubi::NewCommitPage] missing audio track data in loadVisualDiffFromHead"
                        )
                    }
                    return audioTrack
                }
            )
            
            self.visualDiffFromHead = try await self.repositoryClone.stagedAudioTrackList
                .visualDifference(from: headAudioTrackList)
        } catch {
            print("[Musubi::NewCommitPage] failed to diff from head")
            print(error.localizedDescription)
            showAlertErrorDiff = true
        }
    }
    
    private func commit(message: String) {
        showPlaceholderOverlay = true
        // TODO: check message is not empty
        Task {
            do {
                try await repositoryClone.makeCommit(message: message)
            } catch {
                print("[Musubi::LocalClonePage] commit and push failed")
                print(error)
                // TODO: trigger alert
            }
            showPlaceholderOverlay = false
        }
    }
}

//#Preview {
//    NewCommitPage()
//}
