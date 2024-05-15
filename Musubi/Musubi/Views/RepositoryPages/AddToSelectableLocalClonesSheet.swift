// AddToSelectableLocalClonesSheet.swift

import SwiftUI

// TODO: design
// - "un/select all" checkbox
// - ability to collapse sections (or if that's not possible, make each section a one-shallow navdest)
// - show confirmation page with (frozen) selections
// - include ability to search through selection possibilities
struct AddToSelectableLocalClonesSheet: View {
    @Environment(Musubi.User.self) private var currentUser
    
    @Binding var audioTrackList: Musubi.ViewModel.AudioTrackList
    
    @Binding var showSheet: Bool
    
    @State private var selectedAudioTracks = Set<Musubi.ViewModel.UIDableAudioTrack>()
    @State private var selectedRepoReferences = Set<Musubi.RepositoryReference>()
    
    @State private var showAlertErrorExecuteAdd = false
    @State private var isViewDisabled = false
    
    @State private var editMode = EditMode.active // intended to be always-active
    
    @State private var dummyNavigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack {
            List {
                Section("Add Audio Tracks") {
                    ForEach(audioTrackList) { audioTrack in
                        HStack {
                            AudioTrackListCell(
                                isNavigable: false,
                                navigationPath: $dummyNavigationPath,
                                audioTrack: audioTrack.audioTrack,
                                showThumbnail: true
                            )
                            if selectedAudioTracks.contains(audioTrack) {
                                Image(systemName: "checkmark.square.fill")
                                    .font(.system(size: Musubi.UI.CHECKBOX_SYMBOL_SIZE))
                                    .frame(height: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedAudioTracks.remove(audioTrack)
                                    }
                            } else {
                                Image(systemName: "square")
                                    .font(.system(size: Musubi.UI.CHECKBOX_SYMBOL_SIZE))
                                    .frame(height: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedAudioTracks.insert(audioTrack)
                                    }
                            }
                        }
                        .listRowBackground(selectedAudioTracks.contains(audioTrack) ? Color.gray.opacity(0.5) : .none)
                    }
                }
                Section("To Local Clones") {
                    ForEach(currentUser.localClonesIndex, id: \.self) { repositoryReference in
                        HStack {
                            ListCell(repositoryReference: repositoryReference)
                            if selectedRepoReferences.contains(repositoryReference) {
                                Image(systemName: "checkmark.square.fill")
                                    .font(.system(size: Musubi.UI.CHECKBOX_SYMBOL_SIZE))
                                    .frame(height: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedRepoReferences.remove(repositoryReference)
                                    }
                            } else {
                                Image(systemName: "square")
                                    .font(.system(size: Musubi.UI.CHECKBOX_SYMBOL_SIZE))
                                    .frame(height: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedRepoReferences.insert(repositoryReference)
                                    }
                            }
                        }
                        .listRowBackground(selectedRepoReferences.contains(repositoryReference) ? Color.gray.opacity(0.5) : .none)
                    }
                }
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
            .onChange(of: audioTrackList, initial: true) { _, audioTrackList in
                // default to all audio tracks selected
                selectedAudioTracks = Set(audioTrackList)
            }
        }
    }
    
    // TODO: better error handling (e.g. rollback for atomicity)
    private func executeAdd() {
        isViewDisabled = true
        Task {
            do {
                let newAudioTracks = audioTrackList
                    .filter({ selectedAudioTracks.contains($0) })
                    .map({ $0.audioTrack })
                
                let destinationHandles = Set(selectedRepoReferences.map({ $0.handle }))
                
                try await currentUser.addToLocalClones(
                    newAudioTracks: newAudioTracks,
                    destinationHandles: destinationHandles
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
