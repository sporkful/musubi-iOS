// NewCommitPage.swift

import SwiftUI

struct NewCommitPage: View {
    @Binding var showSheet: Bool
    @State private var isSheetDisabled = false
    
    @Bindable var repositoryClone: Musubi.RepositoryClone
    
    @State private var showAlertNoChangesToCommit = false
    
    @State private var commitMessage = ""
    @State private var showAlertEmptyMessage = false
    @FocusState private var messageFieldIsFocused: Bool
    
    @State private var visualDiffFromHead: [Musubi.ViewModel.AudioTrackList.VisualChange] = []
    @State private var headAudioTrackList: Musubi.ViewModel.AudioTrackList? = nil
    
    @State private var showSheetSpotifyDiverged = false
    @State private var remoteSpotifyBlob: Musubi.Model.Blob = ""
    @State private var localHeadBlob: Musubi.Model.Blob = ""
    
    @State private var showAlertErrorDiff = false
    @State private var showAlertErrorCommit = false
    
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
                        TextField("Enter a message for your new commit here", text: $commitMessage)
                            .focused($messageFieldIsFocused)
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
                .interactiveDismissDisabled(true)
                .withCustomSheetNavbar(
                    caption: "New commit",
                    title: repositoryClone.repositoryReference.name,
                    cancellationControl: .init(title: "Cancel", action: { showSheet = false }),
                    primaryControl: nil
                )
                .alert(
                    "No new changes to commit!",
                    isPresented: $showAlertNoChangesToCommit,
                    actions: {
                        Button("OK", action: { showSheet = false } )
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
                .sheet(
                    isPresented: $showSheetSpotifyDiverged,
                    onDismiss: {
                        isSheetDisabled = false
                        showSheet = false
                    },
                    content: {
                        SpotifyDivergedPage(
                            remoteSpotifyBlob: remoteSpotifyBlob,
                            localHeadBlob: localHeadBlob,
                            showSheet: $showSheetSpotifyDiverged,
                            repositoryClone: repositoryClone
                        )
                    }
                )
            }
        }
    }
    
    private func loadVisualDiffFromHead() async {
        isSheetDisabled = true
        defer { isSheetDisabled = false }
        
        do {
            // TODO: make waiting for hydration implicit (as part of ViewModel.AudioTrackList)
            try await self.repositoryClone.stagedAudioTrackList.initialHydrationTask.value
            
            let headAudioTrackList = await Musubi.ViewModel.AudioTrackList(
                repositoryCommit: try Musubi.RepositoryCommit(
                    repositoryReference: repositoryClone.repositoryReference,
                    commitID: repositoryClone.headCommitID
                ),
                knownAudioTrackData: self.repositoryClone.stagedAudioTrackList.audioTrackData()
            )
            
            try await headAudioTrackList.initialHydrationTask.value
            
            if await headAudioTrackList.contents.elementsEqual(
                self.repositoryClone.stagedAudioTrackList.contents,
                by: { ($0.audioTrackID == $1.audioTrackID) && ($0.occurrence == $1.occurrence) }
            ) {
                showAlertNoChangesToCommit = true
                return
            }
            
            self.visualDiffFromHead = try await self.repositoryClone.stagedAudioTrackList
                .visualDifference(from: headAudioTrackList)
            
            self.headAudioTrackList = headAudioTrackList // need to keep this content alive
        } catch {
            print("[Musubi::NewCommitPage] failed to diff from head")
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
                switch try await repositoryClone.checkIfSpotifyDiverged() {
                case .didNotDiverge:
                    try await repositoryClone.makeCommit(
                        message: message,
                        proposedCommitBlob: repositoryClone.stagedAudioTrackList.toBlob()
                    )
                    showSheet = false
                case let .diverged(remoteSpotifyBlob, localHeadBlob):
                    self.remoteSpotifyBlob = remoteSpotifyBlob
                    self.localHeadBlob = localHeadBlob
                    self.showSheetSpotifyDiverged = true
                }
            } catch {
                print("[Musubi::NewCommitPage] failed to commit")
                print(error.localizedDescription)
                showAlertErrorCommit = true
            }
        }
    }
}

//#Preview {
//    NewCommitPage()
//}
