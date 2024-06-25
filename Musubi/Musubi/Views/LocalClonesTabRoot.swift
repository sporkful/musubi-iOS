// LocalClonesTabRoot.swift

import SwiftUI

struct LocalClonesTabRoot: View {
    @Environment(Musubi.User.self) private var currentUser
    @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
    @Environment(HomeViewCoordinator.self) private var homeViewCoordinator
    
    var body: some View {
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
                Divider()
                    .id(HomeViewCoordinator.ScrollAnchor.bottom)
                if spotifyPlaybackManager.currentTrack != nil {
                    Rectangle()
                        .frame(height: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
                        .padding(6.30 + 3.30)
                        .hidden()
                }
            }
            .onChange(of: homeViewCoordinator.myReposDesiredScrollAnchor) { _, newState in
                withAnimation {
                    scrollProxy.scrollTo(newState)
                }
            }
        }
    }
}

#Preview {
    LocalClonesTabRoot()
}
