// LocalCloneEditorPage.swift

import SwiftUI

struct LocalCloneEditorPage: View {
    @Binding var showSheet: Bool
    
    @Binding var repositoryReference: Musubi.RepositoryReference
    
    @Bindable var repositoryClone: Musubi.RepositoryClone
    
    @State private var editMode = EditMode.active // intended to be always-active
    
    @State private var dummyNavigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(repositoryClone.stagedAudioTrackList) { audioTrack in
                    AudioTrackListCell(
                        isNavigable: false,
                        navigationPath: $dummyNavigationPath,
                        audioTrack: audioTrack.audioTrack,
                        showThumbnail: true
                    )
                }
                .onDelete { repositoryClone.stagedAudioTrackListRemove(atOffsets: $0) }
                .onMove { repositoryClone.stagedAudioTracklistMove(fromOffsets: $0, toOffset: $1) }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text("Editing Local Clone")
                            .font(.caption)
                        Text(repositoryReference.externalMetadata.name)
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
