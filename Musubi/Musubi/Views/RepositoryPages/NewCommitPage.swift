// NewCommitPage.swift

import SwiftUI

struct NewCommitPage: View {
    @Binding var showSheet: Bool
    
    @Binding var repositoryReference: Musubi.RepositoryReference
    
    @Bindable var repositoryClone: Musubi.RepositoryClone
    
    @State private var commitMessage = ""
    
    @State private var visualDiffFromHead: [Musubi.Diffing.DiffableList<Spotify.ID>.VisualChange] = []
    @State private var relevantAudioTrackData: [Spotify.ID: Spotify.AudioTrack] = [:]
    
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
                            if let audioTrack = relevantAudioTrackData[visualChange.element.item] {
                                switch visualChange.change {
                                case .none:
                                    AudioTrackListCell(
                                        isNavigable: false,
                                        navigationPath: $dummyNavigationPath,
                                        audioTrack: audioTrack,
                                        showThumbnail: true,
                                        customTextStyle: .defaultStyle
                                    )
                                case .inserted(associatedWith: let associatedWith):
                                    AudioTrackListCell(
                                        isNavigable: false,
                                        navigationPath: $dummyNavigationPath,
                                        audioTrack: audioTrack,
                                        showThumbnail: true,
                                        customTextStyle: .init(color: .green, bold: true)
                                    )
                                    .listRowBackground(Color.green.opacity(0.180))
                                case .removed(associatedWith: let associatedWith):
                                    AudioTrackListCell(
                                        isNavigable: false,
                                        navigationPath: $dummyNavigationPath,
                                        audioTrack: audioTrack,
                                        showThumbnail: true,
                                        customTextStyle: .init(color: .red, bold: true)
                                    )
                                    .listRowBackground(Color.red.opacity(0.180))
                                }
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
            
            let stagedAudioTrackList: [Spotify.AudioTrack] = await repositoryClone.stagedAudioTrackList
                .map { $0.audioTrack }
            let stagedAudioTrackIDList: [Spotify.ID] = stagedAudioTrackList
                .map { $0.id }
            
            self.visualDiffFromHead = try Musubi.Diffing.DiffableList(rawList: stagedAudioTrackIDList)
                .visualDifference(from: Musubi.Diffing.DiffableList(rawList: headAudioTrackIDList))
            
            self.relevantAudioTrackData = Dictionary(
                uniqueKeysWithValues: Set(stagedAudioTrackList).map { ($0.id, $0) }
            )
            
            let audioTrackIDsToFetch: Set<Spotify.ID> = Set(headAudioTrackIDList)
                .subtracting(stagedAudioTrackIDList)
            let audioTrackDataStream = SpotifyRequests.Read.audioTracks(
                audioTrackIDs: audioTrackIDsToFetch.joined(separator: ",")
            )
            for try await sublist in audioTrackDataStream {
                for audioTrack in sublist {
                    self.relevantAudioTrackData[audioTrack.id] = audioTrack
                }
            }
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
