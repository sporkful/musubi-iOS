// SpotifyDivergedPage.swift

// TODO: dedup with NewCommitPage

import SwiftUI

struct SpotifyDivergedPage: View {
    let remoteSpotifyBlob: Musubi.Model.Blob
    let localHeadBlob: Musubi.Model.Blob
    
    @Binding var showSheet: Bool
    @State private var isSheetDisabled = false
    
    @Bindable var repositoryClone: Musubi.RepositoryClone
    
    @State private var commitMessage = ""
    @State private var showAlertEmptyMessage = false
    @FocusState private var messageFieldIsFocused: Bool
    
    @State private var showAlertConfirmDiscard = false
    
    @State private var visualDiffFromHead: [Musubi.ViewModel.AudioTrackList.VisualChange] = []
    @State private var headAudioTrackList: Musubi.ViewModel.AudioTrackList? = nil
    @State private var spotifyAudioTrackList: Musubi.ViewModel.AudioTrackList? = nil
    
    @State private var showAlertErrorDiff = false
    @State private var showAlertErrorCommit = false
    @State private var showAlertErrorSyncSpotifyToLocalHead = false
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                List {
                    Text(
                        """
                        Musubi has detected **external edits - edits you made directly on the Spotify \
                        app instead of the Musubi app**. These external edits have been summarized in \
                        the diff below.
                        
                        
                        Musubi gives you two ways to handle this (choose at the bottom of this page):
                        
                        a) Save these external edits as the new "latest commit". Your current local Musubi \
                        version will remain uncommitted and untouched - you can decide what to do with it \
                        after this popup closes (e.g. discard it by checking-out the new "latest commit", \
                        or manually incorporate these external edits then commit the merged version).
                        
                        b) Discard these external edits and proceed with committing your current local \
                        Musubi version. Note these external edits will be lost forever - Spotify will be \
                        updated to mirror your current local Musubi version.
                        """
                    )
                    .padding(.vertical)
                    .opacity(0.8)
                    Section("External edits on Spotify (compared to most recent previous commit)") {
                        ForEach(visualDiffFromHead, id: \.self) { visualChange in
                            // TODO: will this react to updates in relevantAudioTrackData?
                            // TODO: row numbers and +/- annotations
                            // TODO: moves
                            // TODO: undo by row?
                            switch visualChange.change {
                            case .none:
                                ListCellWrapper(
                                    item: visualChange.element,
                                    showThumbnail: true,
                                    customTextStyle: .defaultStyle,
                                    showAudioTrackMenu: false
                                )
                                
                            case .inserted(associatedWith: let associatedWith):
                                HStack {
                                    if associatedWith != nil {
                                        Image(systemName: "arrow.right")
                                            .foregroundStyle(Color.green)
                                            .frame(width: Musubi.UI.ImageDimension.cellThumbnail.rawValue * 0.81)
                                    } else {
                                        Image(systemName: "plus")
                                            .foregroundStyle(Color.green)
                                            .frame(width: Musubi.UI.ImageDimension.cellThumbnail.rawValue * 0.81)
                                    }
                                    ListCellWrapper(
                                        item: visualChange.element,
                                        showThumbnail: true,
                                        customTextStyle: .init(color: .green, bold: true),
                                        showAudioTrackMenu: false
                                    )
                                }
                                .listRowBackground(Color.green.opacity(0.180))
                                
                            case .removed(associatedWith: let associatedWith):
                                HStack {
                                    if let associatedWith = associatedWith {
                                        if associatedWith < visualDiffFromHead.firstIndex(of: visualChange)! {
                                            Image(systemName: "arrow.up")
                                                .foregroundStyle(Color.red)
                                                .frame(width: Musubi.UI.ImageDimension.cellThumbnail.rawValue * 0.81)
                                        } else {
                                            Image(systemName: "arrow.down")
                                                .foregroundStyle(Color.red)
                                                .frame(width: Musubi.UI.ImageDimension.cellThumbnail.rawValue * 0.81)
                                        }
                                    } else {
                                        Image(systemName: "minus")
                                            .foregroundStyle(Color.red)
                                            .frame(width: Musubi.UI.ImageDimension.cellThumbnail.rawValue * 0.81)
                                    }
                                    ListCellWrapper(
                                        item: visualChange.element,
                                        showThumbnail: true,
                                        customTextStyle: .init(color: .red, bold: true),
                                        showAudioTrackMenu: false
                                    )
                                }
                                .listRowBackground(Color.red.opacity(0.180))
                            }
                        }
                    }
                    Section("Commit message") {
                        TextField("Enter a commit message for these external edits", text: $commitMessage)
                            .focused($messageFieldIsFocused)
                    }
                    Button {
                        commit(message: commitMessage)
                    } label: {
                        ZStack {
                            // for spacing purposes only
                            Text("1\n2")
                                .bold()
                                .hidden()
                            HStack(alignment: .center) {
                                Spacer()
                                Text("Create new commit for these external edits")
                                    .bold()
                                    .multilineTextAlignment(.center)
                                Spacer()
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    Button {
                        showAlertConfirmDiscard = true
                    } label: {
                        ZStack {
                            // for spacing purposes only
                            Text("1\n2")
                                .bold()
                                .hidden()
                            HStack(alignment: .center) {
                                Spacer()
                                Text("Discard these external edits")
                                    .bold()
                                Spacer()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .interactiveDismissDisabled(true)
                .withCustomSheetNavbar(
                    caption: "External edits detected",
                    title: repositoryClone.repositoryReference.name,
                    cancellationControl: .init(title: "Cancel", action: { showSheet = false }),
                    primaryControl: nil
                )
                .alert(
                    "Are you sure you want to discard these external edits?",
                    isPresented: $showAlertConfirmDiscard,
                    actions: {
                        Button("Yes", role: .destructive, action: { discardExternalEdits() } )
                        Button("Cancel", role: .cancel, action: { showAlertConfirmDiscard = false })
                    },
                    message: {
                        Text("If you proceed with \"Yes\", Spotify will be updated to mirror your current local Musubi version.")
                    }
                )
                .alert(
                    "Please enter a commit message!",
                    isPresented: $showAlertEmptyMessage,
                    actions: {
                        Button("OK", action: { messageFieldIsFocused = true })
                    }
                )
                .alert(
                    "Error when generating diff from head",
                    isPresented: $showAlertErrorDiff,
                    actions: {
                        Button("OK", action: { showSheet = false } )
                    },
                    message: {
                        Text(Musubi.UI.ErrorMessage(suggestedFix: .contactDev).string)
                    }
                )
                .alert(
                    "Error when creating commit",
                    isPresented: $showAlertErrorCommit,
                    actions: {
                        Button("OK", action: { showSheet = false } )
                    },
                    message: {
                        Text(Musubi.UI.ErrorMessage(suggestedFix: .contactDev).string)
                    }
                )
                // necessary since SwiftUI caches sheets even after dismissal.
                .onChange(of: showSheet, initial: true) { _, newValue in
                    if newValue == true {
                        Task { await loadVisualDiffFromHead() }
                    }
                }
                .withCustomDisablingOverlay(isDisabled: $isSheetDisabled)
            }
        }
    }
    
    private func loadVisualDiffFromHead() async {
        isSheetDisabled = true
        defer { isSheetDisabled = false }
        
        do {
            let playlistMetadata = try await SpotifyRequests.Read.playlistMetadata(playlistID: repositoryClone.repositoryReference.handle.playlistID)
            let spotifyAudioTrackList = await Musubi.ViewModel.AudioTrackList(playlistMetadata: playlistMetadata)
            try await spotifyAudioTrackList.initialHydrationTask.value
            
            let headAudioTrackList = await Musubi.ViewModel.AudioTrackList(
                repositoryCommit: try Musubi.RepositoryCommit(
                    repositoryReference: repositoryClone.repositoryReference,
                    commitID: repositoryClone.headCommitID
                ),
                knownAudioTrackData: self.repositoryClone.stagedAudioTrackList.audioTrackData()
            )
            try await headAudioTrackList.initialHydrationTask.value
            
            self.visualDiffFromHead = try await spotifyAudioTrackList.visualDifference(from: headAudioTrackList)
            
            self.headAudioTrackList = headAudioTrackList // need to keep this content alive
        } catch {
            print("[Musubi::SpotifyDivergedPage] failed to diff from head")
            print(error.localizedDescription)
            showAlertErrorDiff = true
        }
    }
    
    private func commit(message: String) {
        if message.isEmpty {
            showAlertEmptyMessage = true
            return
        }
        
        isSheetDisabled = true
        Task {
            defer { isSheetDisabled = false }
            
            do {
                try await repositoryClone.makeCommit(
                    message: message,
                    proposedCommitBlob: remoteSpotifyBlob
                )
                showSheet = false
            } catch {
                print("[Musubi::SpotifyDivergedPage] failed to commit")
                print(error.localizedDescription)
                showAlertErrorCommit = true
            }
        }
    }
    
    private func discardExternalEdits() {
        isSheetDisabled = true
        Task {
            defer { isSheetDisabled = false }
            
            do {
                try await repositoryClone.syncSpotifyToLocalHead()
                showSheet = false
            } catch {
                print("[Musubi::SpotifyDivergedPage] failed to sync spotify to local head")
                print(error.localizedDescription)
                showAlertErrorSyncSpotifyToLocalHead = true
            }
        }
    }
}

//#Preview {
//    SpotifyDivergedPage()
//}
