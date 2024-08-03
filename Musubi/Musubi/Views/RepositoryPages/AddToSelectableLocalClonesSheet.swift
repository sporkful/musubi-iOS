// AddToSelectableLocalClonesSheet.swift

import SwiftUI

struct AddToSelectableLocalClonesSheet: View {
    @Environment(Musubi.User.self) private var currentUser
    
    @Binding var showSheet: Bool
    @State private var isSheetDisabled = false
    
    @Bindable var audioTrackList: Musubi.ViewModel.AudioTrackList
    
    @State private var selectedAudioTracks = Set<Musubi.ViewModel.AudioTrack>()
    @State private var selectedRepoReferences = Set<Musubi.RepositoryReference>()
    
    @State private var editMode = EditMode.active // intended to be always-active
    
    // TODO: better way to do this simple static three-layer navigation layout?
    @State private var navigationPath = NavigationPath()
    private struct ShowLocalRepoSelection: Hashable { let _b = false }
    private struct ShowConfirmation: Hashable { let _b = true }
    
    @State private var showAlertNoTracksToSelect = false
    @State private var showAlertNoReposToSelect = false
    
    @State private var showAlertNoTracksSelected = false
    @State private var showAlertNoReposSelected = false
    
    @State private var showAlertErrorHydration = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            SelectableListSection(
                selectableList: audioTrackList.contents,
                listCellBuilder: { audioTrack in
                    ListCellWrapper(
                        item: audioTrack,
                        showThumbnail: true,
                        customTextStyle: .defaultStyle,
                        showAudioTrackMenu: false
                    )
                },
                selectedElements: $selectedAudioTracks
            )
            .interactiveDismissDisabled(true)
            .withCustomSheetNavbar(
                caption: nil,
                title: "Select tracks to add",
                cancellationControl: .init(title: "Cancel", action: { showSheet = false }),
                primaryControl: .init(
                    title: "Next",
                    action: {
                        if selectedAudioTracks.isEmpty {
                            showAlertNoTracksSelected = true
                        } else {
                            navigationPath.append(ShowLocalRepoSelection())
                        }
                    }
                )
            )
            .navigationDestination(for: ShowLocalRepoSelection.self) { _ in
                SelectableListSection(
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
                .withCustomSheetNavbar(
                    caption: nil,
                    title: "Select local repos to add to",
                    cancellationControl: nil, // using back button generated by SwiftUI
                    primaryControl: .init(
                        title: "Next",
                        action: {
                            if selectedRepoReferences.isEmpty {
                                showAlertNoReposSelected = true
                            } else {
                                navigationPath.append(ShowConfirmation())
                            }
                        }
                    )
                )
            }
            .navigationDestination(for: ShowConfirmation.self) { _ in
                ConfirmationPage(
                    showParentSheet: $showSheet,
                    isParentSheetDisabled: $isSheetDisabled,
                    navigationPath: $navigationPath,
                    selectedAudioTracks: $selectedAudioTracks,
                    selectedRepoReferences: $selectedRepoReferences,
                    audioTrackList: audioTrackList
                )
            }
        }
        .onAppear(perform: waitForHydration)
        .alert(
            "No tracks to add",
            isPresented: $showAlertNoTracksToSelect,
            actions: {
                Button("OK", action: { showSheet = false } )
            }
        )
        .alert(
            "No repositories to add to",
            isPresented: $showAlertNoReposToSelect,
            actions: {
                Button("OK", action: { showSheet = false } )
            }
        )
        .alert(
            "No tracks selected",
            isPresented: $showAlertNoTracksSelected,
            actions: {
                Button("OK", action: {} )
            }
        )
        .alert(
            "No repositories selected",
            isPresented: $showAlertNoReposSelected,
            actions: {
                Button("OK", action: {} )
            }
        )
        .alert(
            "Error when loading tracklist",
            isPresented: $showAlertErrorHydration,
            actions: {
                Button("OK", action: { showSheet = false } )
            },
            message: {
                Text(Musubi.UI.ErrorMessage(suggestedFix: .contactDev).string)
            }
        )
        .environment(\.editMode, $editMode)
        .withCustomDisablingOverlay(isDisabled: $isSheetDisabled)
    }
    
    private func waitForHydration() {
        isSheetDisabled = true
        Task { @MainActor in
            defer { isSheetDisabled = false }
            
            do {
                try await audioTrackList.initialHydrationTask.value
                
                if audioTrackList.contents.isEmpty && audioTrackList.initialHydrationCompleted {
                    showAlertNoTracksToSelect = true
                    return
                }
                if currentUser.localClonesIndex.isEmpty {
                    showAlertNoReposToSelect = true
                    return
                }
                
                // default to all selected
                if selectedAudioTracks.isEmpty {
                    selectedAudioTracks.formUnion(audioTrackList.contents)
                }
            } catch {
                print("[Musubi::AddToSelectableLocalClonesSheet] failed to wait for hydration")
                print(error.localizedDescription)
                showAlertErrorHydration = true
            }
        }
    }
}

fileprivate struct ConfirmationPage: View {
    @Environment(Musubi.User.self) private var currentUser
    
    @Binding var showParentSheet: Bool
    @Binding var isParentSheetDisabled: Bool
    
    @Binding var navigationPath: NavigationPath
    
    @Binding var selectedAudioTracks: Set<Musubi.ViewModel.AudioTrack>
    @Binding var selectedRepoReferences: Set<Musubi.RepositoryReference>
    
    @Bindable var audioTrackList: Musubi.ViewModel.AudioTrackList
    
    @State private var selectedAudioTracksOrdered: [Spotify.AudioTrack] = []
    
    @State private var showAlertErrorOrdering = false
    @State private var showAlertErrorExecuteAdd = false
    
    var body: some View {
        List {
            Section("Selected local repos to add to") {
                ForEach(Array(selectedRepoReferences)) { repoReference in
                    ListCellWrapper(
                        item: repoReference,
                        showThumbnail: true,
                        customTextStyle: .defaultStyle
                    )
                }
            }
            Section("Selected tracks to add") {
                ForEach(
                    Array(zip(selectedAudioTracksOrdered.indices, selectedAudioTracksOrdered)),
                    id: \.0
                ) { index, audioTrack in
                    ListCellWrapper(
                        item: Musubi.ViewModel.AudioTrack(audioTrack: audioTrack),
                        showThumbnail: true,
                        customTextStyle: .defaultStyle,
                        showAudioTrackMenu: false
                    )
                }
            }
        }
        .withCustomSheetNavbar(
            caption: nil,
            title: "Confirm selections",
            cancellationControl: nil, // using back button generated by SwiftUI
            primaryControl: .init(title: "Add", action: executeAdd)
        )
        .onAppear(perform: orderSelectedAudioTracks)
        .alert(
            "Error when finding selected audio tracks",
            isPresented: $showAlertErrorOrdering,
            actions: {
                Button("OK", action: { navigationPath.removeLast() } )
            },
            message: {
                Text(Musubi.UI.ErrorMessage(suggestedFix: .contactDev).string)
            }
        )
        .alert(
            "Error when adding selected audio tracks",
            isPresented: $showAlertErrorExecuteAdd,
            actions: {
                Button("OK", action: { showParentSheet = false } )
            },
            message: {
                Text(Musubi.UI.ErrorMessage(suggestedFix: .contactDev).string)
            }
        )
    }
    
    private func orderSelectedAudioTracks() {
        isParentSheetDisabled = true
        Task {
            defer { isParentSheetDisabled = false }
            
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
                
                self.selectedAudioTracksOrdered = []
                for element in await audioTrackList.contents {
                    if selectedAudioTracks.contains(element) {
                        //                        guard let audioTrack = await element.audioTrack else {
                        //                            throw Musubi.UI.Error.misc(
                        //                                detail: "missing audio track data in orderSelectedAudioTracks"
                        //                            )
                        //                        }
                        //                        self.selectedAudioTracksOrdered.append(audioTrack)
                        self.selectedAudioTracksOrdered.append(element.audioTrack)
                    }
                }
                
                // prevent screen flashing
                try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
            } catch {
                print("[Musubi::AddToSelectableLocalClonesSheet] failed to order selected audio tracks")
                print(error.localizedDescription)
                showAlertErrorOrdering = true
            }
        }
    }
    
    
    // TODO: better error handling (e.g. rollback for atomicity)
    private func executeAdd() {
        isParentSheetDisabled = true
        Task { @MainActor in
            defer { isParentSheetDisabled = false }
            
            do {
                try await currentUser.addToLocalClones(
                    newAudioTracks: selectedAudioTracksOrdered,
                    destinationHandles: Set(selectedRepoReferences.map({ $0.handle }))
                )
                
                // prevent screen flashing
                try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
                
                showParentSheet = false
            } catch {
                print("[Musubi::AddToSelectableLocalClonesSheet] failed to complete add")
                print(error.localizedDescription)
                showAlertErrorOrdering = true
            }
        }
    }
}

//#Preview {
//    AddToSelectableLocalClonesSheet()
//}
