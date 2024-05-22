// AddToSelectableLocalClonesSheet.swift

import SwiftUI

// TODO: design
// - "un/select all" checkbox
// - ability to collapse sections (or if that's not possible, make each section a one-shallow navdest)
// - show confirmation page with (frozen) selections
// - include ability to search through selection possibilities
struct AddToSelectableLocalClonesSheet: View {
    @Environment(Musubi.User.self) private var currentUser
    
    @Bindable var audioTrackList: Musubi.ViewModel.AudioTrackList
    
    @Binding var showSheet: Bool
    
    @State private var selectedAudioTracks = Set<Musubi.ViewModel.AudioTrackList.UniquifiedElement>()
    @State private var selectedRepoReferences = Set<Musubi.RepositoryReference>()
    
    @State private var showAlertErrorExecuteAdd = false
    @State private var isViewDisabled = false
    
    @State private var editMode = EditMode.active // intended to be always-active
    
    @State private var dummyNavigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack {
            List {
                SelectableListSection(
                    sectionTitle: "Add Audio Tracks",
                    selectableList: audioTrackList.contents,
                    listCellBuilder: { element in
                        AudioTrackListCell(
                            isNavigable: false,
                            navigationPath: $dummyNavigationPath,
                            audioTrackListElement: element,
                            showThumbnail: true,
                            customTextStyle: .defaultStyle
                        )
                    },
                    selectedElements: $selectedAudioTracks
                )
                SelectableListSection(
                    sectionTitle: "To Local Clones",
                    selectableList: currentUser.localClonesIndex,
                    listCellBuilder: { repositoryReference in
                        ListCellWrapper(
                            item: repositoryReference,
                            showThumbnail: true,
                            customTextStyle: .defaultStyle
                        )
                    },
                    selectedElements: $selectedRepoReferences
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text("Add Tracks To Local Clones")
                            .font(.headline)
                    }
                    .padding(.vertical, 5)
                }
                ToolbarItem(placement: .cancellationAction) {
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
                ToolbarItem(placement: .confirmationAction) {
                    Button(
                        action: executeAdd,
                        label: {
                            Text("Done")
                                .bold()
                        }
                    )
                }
            }
            .environment(\.editMode, $editMode)
            .disabled(isViewDisabled)
            .alert("Musubi - failed to execute add action", isPresented: $showAlertErrorExecuteAdd, actions: {})
            .interactiveDismissDisabled(true)
            // TODO: better way to do this? (onAppear gets called too many times)
            .onChange(of: audioTrackList.contents, initial: true) { _, audioTrackListContents in
                // default to all audio tracks selected
                selectedAudioTracks = Set(audioTrackListContents)
            }
        }
    }
    
    // TODO: better error handling (e.g. rollback for atomicity)
    private func executeAdd() {
        isViewDisabled = true
        Task {
            do {
                // TODO: clean this - Swift's built-in map doesn't support async closures yet :(
//                let newAudioTracks = try await audioTrackList.contents
//                    .filter { element in
//                        selectedAudioTracks.contains(element)
//                    }
//                    .map { element in
//                        guard let audioTrack = await element.audioTrack else {
//                            throw Musubi.UI.Error.misc(
//                                detail: "[Musubi::AddToSel...] missing audio track data in executeAdd"
//                            )
//                        }
//                        return audioTrack
//                    }
                
                var newAudioTracks: [Spotify.AudioTrack] = []
                for element in await audioTrackList.contents {
                    if selectedAudioTracks.contains(element) {
                        guard let audioTrack = await element.audioTrack else {
                            throw Musubi.UI.Error.misc(
                                detail: "[Musubi::AddToSel...] missing audio track data in executeAdd"
                            )
                        }
                        newAudioTracks.append(audioTrack)
                    }
                }
                
                try await currentUser.addToLocalClones(
                    newAudioTracks: newAudioTracks,
                    destinationHandles: Set(selectedRepoReferences.map({ $0.handle }))
                )
                showSheet = false
                isViewDisabled = false
            } catch {
                print("[Musubi::AddToSelectableLocalClonesSheet] failed to complete add")
                print(error)
                isViewDisabled = false
                showAlertErrorExecuteAdd = true
            }
        }
    }
}

//#Preview {
//    AddToSelectableLocalClonesSheet()
//}
