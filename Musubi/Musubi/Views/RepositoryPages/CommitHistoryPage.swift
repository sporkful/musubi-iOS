// CommitHistoryPage.swift

import SwiftUI

// TODO: forking history

struct CommitHistoryPage: View {
  // TODO: improve safety wrt showSheet
  // MARK: showSheet being bound to HomeViewController means all modifications to it must be done on MainActor.
  @Binding var showSheet: Bool
  @State private var isSheetDisabled = false
  
  @Bindable var repositoryClone: Musubi.RepositoryClone
  
  @State private var commitHistory: [Musubi.RepositoryCommit] = []
  
  @State private var showAlertErrorLoadHistory = false
  
  var body: some View {
    NavigationStack {
      List {
        ForEach(commitHistory) { commit in
          NavigationLink(value: commit) {
            ListCellWrapper(
              item: commit,
              showThumbnail: false,
              customTextStyle: .defaultStyle
            )
          }
        }
      }
      .navigationDestination(for: Musubi.RepositoryCommit.self) { commit in
        CommitDetailPage(
          commit: commit,
          repositoryClone: repositoryClone,
          showParentSheet: $showSheet,
          isParentSheetDisabled: $isSheetDisabled
        )
      }
      .interactiveDismissDisabled(true)
      .withCustomSheetNavbar(
        caption: "Commit history",
        title: repositoryClone.repositoryReference.name,
        cancellationControl: .init(title: "Close", action: { showSheet = false }),
        primaryControl: nil
      )
      .alert(
        "Error when loading commit history",
        isPresented: $showAlertErrorLoadHistory,
        actions: {
          Button("OK", action: { showSheet = false })
        }, message: {
          Text(Musubi.UI.ErrorMessage(suggestedFix: .contactDev).string)
        }
      )
      .onAppear {
        Task { await loadCommitHistory() }
      }
      .withCustomDisablingOverlay(isDisabled: $isSheetDisabled)
    }
  }
  
  private func loadCommitHistory() async {
    do {
      self.commitHistory = []
      self.commitHistory.append(
        try Musubi.RepositoryCommit(
          repositoryReference: repositoryClone.repositoryReference,
          commitID: await repositoryClone.headCommitID
        )
      )
      while let nextCommitID = self.commitHistory.last!.commit.parentCommitIDs.first {
        self.commitHistory.append(
          try Musubi.RepositoryCommit(
            repositoryReference: repositoryClone.repositoryReference,
            commitID: nextCommitID
          )
        )
      }
    } catch {
      print("[Musubi::CommitHistoryPage] failed to load commit history")
      print(error.localizedDescription)
      showAlertErrorLoadHistory = true
    }
  }
}

fileprivate struct CommitDetailPage: View {
  let commit: Musubi.RepositoryCommit
  
  @Bindable var repositoryClone: Musubi.RepositoryClone
  
  @Binding var showParentSheet: Bool
  @Binding var isParentSheetDisabled: Bool
  
  @State private var audioTrackList: Musubi.ViewModel.AudioTrackList? = nil
  
  @State private var showAlertErrorLoad = false
  @State private var showAlertErrorCheckout = false
  
  var body: some View {
    List {
      if let audioTrackList = self.audioTrackList {
        ForEach(audioTrackList.contents, id: \.self) { audioTrack in
          ListCellWrapper(
            item: audioTrack,
            showThumbnail: true,
            customTextStyle: .defaultStyle,
            showAudioTrackMenu: true
          )
        }
        if audioTrackList.contents.isEmpty {
          if audioTrackList.initialHydrationCompleted {
            VStack(alignment: .center) {
              Text("(No tracks)")
                .font(.headline)
                .padding(.vertical)
                .opacity(0.81)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          } else {
            VStack(alignment: .center) {
              ProgressView()
                .padding(.vertical)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          }
        }
      }
    }
    .interactiveDismissDisabled(true)
    .withCustomSheetNavbar(
      caption: commit.repositoryReference.name,
      title: commit.commit.message,
      cancellationControl: nil,
      primaryControl: .init(title: "Checkout", action: { checkoutCommit() })
    )
    .alert(
      "Error when loading contents",
      isPresented: $showAlertErrorLoad,
      actions: {},
      message: {
        Text(Musubi.UI.ErrorMessage(suggestedFix: .contactDev).string)
      }
    )
    .alert(
      "Error when checking out commit",
      isPresented: $showAlertErrorCheckout,
      actions: {},
      message: {
        Text(Musubi.UI.ErrorMessage(suggestedFix: .contactDev).string)
      }
    )
    .task {
      await loadAudioTrackList()
    }
  }
  
  private func loadAudioTrackList() async {
    isParentSheetDisabled = true
    defer { isParentSheetDisabled = false }
    
    do {
      let audioTrackList = await Musubi.ViewModel.AudioTrackList(
        repositoryCommit: self.commit,
        knownAudioTrackData: self.repositoryClone.stagedAudioTrackList.audioTrackData()
      )
      try await audioTrackList.initialHydrationTask.value
      self.audioTrackList = audioTrackList
    } catch {
      print("[Musubi::CommitHistoryPage::CommitDetailPage] failed to load audioTrackList")
      print(error.localizedDescription)
      showAlertErrorLoad = true
    }
  }
  
  private func checkoutCommit() {
    guard let audioTrackList = self.audioTrackList else {
      return
    }
    
    // TODO: warn user if they have uncommitted changes (but allow case where user checks out commits in succession)
    isParentSheetDisabled = true
    Task { @MainActor in
      defer { isParentSheetDisabled = false }
      
      do {
        try await repositoryClone.checkoutCommit(audioTrackList: audioTrackList)
        showParentSheet = false
      } catch {
        print("[Musubi::CommitHistoryPage::CommitDetailPage] failed to check out commit")
        print(error.localizedDescription)
        showAlertErrorCheckout = true
      }
    }
  }
}

//#Preview {
//    CommitHistoryPage()
//}
