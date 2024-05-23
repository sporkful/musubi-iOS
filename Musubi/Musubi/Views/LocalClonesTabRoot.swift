// LocalClonesTabRoot.swift

import SwiftUI

struct LocalClonesTabRoot: View {
    @Environment(Musubi.User.self) private var currentUser
    
    var body: some View {
            List {
                ForEach(currentUser.localClonesIndex) { repositoryReference in
                    NavigationLink(value: repositoryReference.handle) {
                        ListCellWrapper(
                            item: repositoryReference,
                            showThumbnail: true,
                            customTextStyle: .defaultStyle
                        )
                    }
                }
            }
    }
}

#Preview {
    LocalClonesTabRoot()
}
