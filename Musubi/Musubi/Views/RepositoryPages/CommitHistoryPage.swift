// CommitHistoryPage.swift

import SwiftUI

// TODO: forking history

struct CommitHistoryPage: View {
    @Binding var showSheet: Bool
    @State private var isSheetDisabled = false
    
    @Bindable var repositoryClone: Musubi.RepositoryClone
    
    @State private var commitHistory: [Musubi.RepositoryCommit] = []
    
    @State private var showAlertErrorLoadHistory = false
    @State private var showAlertErrorCheckout = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(commitHistory) { commit in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(commit.commit.message)
                            Text(commit.commit.date.formatted())
                                .font(.caption)
                        }
                        Spacer()
                        Button {
                            checkoutCommit(commit: commit)
                        } label: {
                            Image(systemName: "tray.and.arrow.up")
                                .contentShape(Rectangle())
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text("Commit history")
                            .font(.caption)
                        Text(repositoryClone.repositoryReference.name)
                            .font(.headline)
                    }
                    .padding(.vertical, 5)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(
                        role: .cancel,
                        action: {
                            showSheet = false
                        },
                        label: {
                            Text("Done")
                        }
                    )
                }
                // balances out above
                ToolbarItem(placement: .topBarLeading) {
                    Text("Done")
                        .hidden()
                }
            }
            .interactiveDismissDisabled(true)
            .alert(
                "Error when loading commit history",
                isPresented: $showAlertErrorLoadHistory,
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
            print("[Musubi::NewCommitPage] failed to diff from head")
            print(error.localizedDescription)
            showAlertErrorLoadHistory = true
        }
    }
    
    private func checkoutCommit(commit: Musubi.RepositoryCommit) {
        // TODO: warn user if they have uncommitted changes (but allow case where user checks out commits in succession)
        
        isSheetDisabled = true
        Task {
            defer { isSheetDisabled = false }
            
            do {
                try await repositoryClone.checkoutCommit(commit: commit.commit)
                showSheet = false
            } catch {
                print("[Musubi::NewCommitPage] failed to commit")
                print(error)
                showAlertErrorCheckout = true
            }
        }
    }
}

//#Preview {
//    CommitHistoryPage()
//}
