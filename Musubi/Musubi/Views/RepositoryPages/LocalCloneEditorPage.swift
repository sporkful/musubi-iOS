// LocalCloneEditorPage.swift

import SwiftUI

struct LocalCloneEditorPage: View {
    @Binding var showSheet: Bool
    
    @Bindable var repositoryClone: Musubi.RepositoryClone
    
    @State private var editMode = EditMode.active // intended to be always-active
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(repositoryClone.stagedAudioTrackList.contents, id: \.self) { audioTrack in
                    ListCellWrapper(
                        item: audioTrack,
                        showThumbnail: true,
                        customTextStyle: .defaultStyle,
                        showAudioTrackMenu: false
                    )
                }
                // TODO: any way to enforce well-defined ordering of ops?
                .onDelete { atOffsets in
                    Task {
                        try await repositoryClone.stagedAudioTrackListRemove(atOffsets: atOffsets)
                    }
                }
                .onMove { (fromOffsets, toOffset) in
                    Task {
                        try await repositoryClone.stagedAudioTracklistMove(fromOffsets: fromOffsets, toOffset: toOffset)
                    }
                }
                if repositoryClone.stagedAudioTrackList.contents.isEmpty {
                    if repositoryClone.stagedAudioTrackList.initialHydrationCompleted {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text("Edit Local Clone")
                            .font(.caption)
                        Text(repositoryClone.repositoryReference.name)
                            .font(.headline)
                    }
                    .padding(.vertical, 5)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(
                        action: {
                            showSheet = false
                        },
                        label: {
                            Text("Done")
                                .bold()
                        }
                    )
                }
                // balances out above
                ToolbarItem(placement: .topBarLeading) {
                    Text("Done")
                        .hidden()
                }
            }
            .environment(\.editMode, $editMode)
        }
    }
}

//#Preview {
//    LocalCloneEditorPage()
//}
