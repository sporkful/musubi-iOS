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
    
    @State private var headAudioTrackList: Musubi.ViewModel.AudioTrackList? = nil
    @State private var visualDiffFromHead: [Musubi.ViewModel.AudioTrackList.VisualChange] = []
    
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
                                    AudioTrackListCell(
                                        isNavigable: false,
                                        navigationPath: Binding.constant(NavigationPath()),
                                        audioTrackListElement: visualChange.element,
                                        showThumbnail: true,
                                        customTextStyle: .defaultStyle
                                    )
                                case .inserted(associatedWith: let associatedWith):
                                    AudioTrackListCell(
                                        isNavigable: false,
                                        navigationPath: Binding.constant(NavigationPath()),
                                        audioTrackListElement: visualChange.element,
                                        showThumbnail: true,
                                        customTextStyle: .init(color: .green, bold: true)
                                    )
                                    .listRowBackground(Color.green.opacity(0.180))
                                case .removed(associatedWith: let associatedWith):
                                    AudioTrackListCell(
                                        isNavigable: false,
                                        navigationPath: Binding.constant(NavigationPath()),
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
                .task {
                    await loadVisualDiffFromHead()
                }
                .withCustomDisablingOverlay(isDisabled: $isSheetDisabled)
            }
        }
    }
    
    private func loadVisualDiffFromHead() async {
        do {
            self.headAudioTrackList = await Musubi.ViewModel.AudioTrackList(
                repositoryCommit: try Musubi.RepositoryCommit(
                    repositoryReference: repositoryClone.repositoryReference,
                    commitID: repositoryClone.headCommitID
                ),
                knownAudioTrackData: self.repositoryClone.stagedAudioTrackList.audioTrackData()
            )
            
            // TODO: make waiting for hydration implicit (as part of ViewModel.AudioTrackList)
            try await self.headAudioTrackList!.initialHydrationTask.value
            if await self.headAudioTrackList!.contents == self.repositoryClone.stagedAudioTrackList.contents {
                showAlertNoChangesToCommit = true
                return
            }
            
            self.visualDiffFromHead = try await self.repositoryClone.stagedAudioTrackList
                .visualDifference(from: self.headAudioTrackList!)
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
                try await repositoryClone.makeCommit(message: message)
                showSheet = false
            } catch {
                print("[Musubi::NewCommitPage] failed to commit")
                print(error)
                showAlertErrorCommit = true
            }
        }
    }
}

//#Preview {
//    NewCommitPage()
//}
