// LocalCloneEditorPage.swift

import SwiftUI

struct LocalCloneEditorPage: View {
    @Binding var repositoryReference: Musubi.RepositoryReference
    
    @State var repositoryClone: Musubi.RepositoryClone
    
    @State private var dummyNavigationPath = NavigationPath()
    
    @State private var editMode = EditMode.active // intended to be always-active
    
    var body: some View {
        @Bindable var repositoryClone = repositoryClone
        
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
                            .font(.headline)
                        Text(repositoryReference.externalMetadata.name)
                            .font(.subheadline)
                    }
                }
            }
            .environment(\.editMode, $editMode)
        }
    }
}

//#Preview {
//    LocalCloneEditorPage()
//}
