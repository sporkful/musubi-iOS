// LocalClonesTabRoot.swift

import SwiftUI

struct LocalClonesTabRoot: View {
    @Environment(Musubi.User.self) private var currentUser
    @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
    @Environment(HomeViewCoordinator.self) private var homeViewCoordinator
    
    @State private var showSheetCreateNewPlaylist = false
    
    var body: some View {
        if currentUser.localClonesIndex.isEmpty {
            VStack(alignment: .center) {
                Spacer()
                Text("No local repositories yet")
                    .font(.headline)
                    .padding(.vertical)
                Text(
                    """
                    Clone or fork an existing Spotify playlist in the Search tab, \
                    or create a new version-controlled playlist using the + button above!
                    """
                )
                .multilineTextAlignment(.center)
                .frame(width: 262)
                Spacer()
                Spacer()
            }
            .opacity(0.81)
            .toolbar {
                Button(
                    action: { showSheetCreateNewPlaylist = true },
                    label: { Image(systemName: "plus") }
                )
            }
            .sheet(isPresented: $showSheetCreateNewPlaylist) {
                NewPlaylistSheet(showSheet: $showSheetCreateNewPlaylist)
            }
        } else {
        ScrollViewReader { scrollProxy in
            List {
                ForEach(currentUser.localClonesIndex) { repositoryReference in
                    NavigationLink(value: repositoryReference) {
                        ListCellWrapper(
                            item: repositoryReference,
                            showThumbnail: true,
                            customTextStyle: .defaultStyle
                        )
                    }
                }
                if spotifyPlaybackManager.currentTrack != nil {
                    Rectangle()
                        .frame(height: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
                        .padding(6.30 + 3.30)
                        .hidden()
                }
                Rectangle()
                    .frame(height: 1)
                    .hidden()
                    .id(HomeViewCoordinator.ScrollAnchor.bottom)
            }
            .toolbar {
                Button(
                    action: { showSheetCreateNewPlaylist = true },
                    label: { Image(systemName: "plus") }
                )
            }
            .sheet(isPresented: $showSheetCreateNewPlaylist) {
                NewPlaylistSheet(showSheet: $showSheetCreateNewPlaylist)
            }
            .onChange(of: homeViewCoordinator.myReposDesiredScrollAnchor) { _, newState in
                withAnimation {
                    scrollProxy.scrollTo(newState)
                }
            }
            .task {
                // TODO: check for races
                // staggered refresh to stay within rate limit // TODO: tune / organize this
                for repositoryReference in currentUser.localClonesIndex {
                    try? await repositoryReference.refreshExternalMetadata()
                    try? await Task.sleep(until: .now + .seconds(2), clock: .continuous)
                }
            }
        }
        }
    }
}

fileprivate struct NewPlaylistSheet: View {
    @Environment(Musubi.User.self) private var currentUser
    @Environment(HomeViewCoordinator.self) private var homeViewCoordinator
    
    @Binding var showSheet: Bool
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var isPublic: Bool = false
    
    @State private var showAlertError = false
    
    var body: some View {
        @Bindable var homeViewCoordinator = homeViewCoordinator
        
        NavigationStack {
            Form {
                Section("New playlist info") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                        .lineLimit(nil)
                    Toggle("Public", isOn: $isPublic)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                }
                Section {
                    Button(
                        action: createNewPlaylist,
                        label: {
                            HStack {
                                Spacer()
                                Text("Create new Spotify playlist and clone as local repository")
                                    .bold()
                                    .multilineTextAlignment(.center)
                                    .listRowBackground(Color.white.opacity(0.280))
                                Spacer()
                            }
                        }
                    )
                }
            }
            .interactiveDismissDisabled(true)
            .navigationTitle("Create new playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(
                    action: { showSheet = false },
                    label: { Text("Cancel") }
                )
            }
            .alert(
                "Error when creating playlist",
                isPresented: $showAlertError,
                actions: {},
                message: {
                    Text(Musubi.UI.ErrorMessage(suggestedFix: .contactDev).string)
                }
            )
            .withCustomDisablingOverlay(isDisabled: $homeViewCoordinator.disableUI)
        }
    }
    
    private func createNewPlaylist() {
        Task { @MainActor in
            homeViewCoordinator.disableUI = true
            defer { homeViewCoordinator.disableUI = false }
            
            do {
                let newPlaylistMetadata = try await SpotifyRequests.Write.createNewPlaylist(
                    name: name,
                    description: description,
                    public: isPublic
                )
                
                // TODO: deduplicate logic with StaticPlaylistPage
                let repositoryReference = try await self.currentUser.initOrClone(
                    repositoryHandle: Musubi.RepositoryHandle(
                        userID: currentUser.id,
                        playlistID: newPlaylistMetadata.id
                    )
                )
                showSheet = false
                homeViewCoordinator.myReposDesiredScrollAnchor = .bottom
                try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
                homeViewCoordinator.myReposDesiredScrollAnchor = .none
                try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
                homeViewCoordinator.myReposNavPath.append(repositoryReference)
            } catch {
                print("[NewPlaylistSheet] errored")
                print(error)
                showAlertError = true
            }
        }
    }
}

#Preview {
    LocalClonesTabRoot()
}
