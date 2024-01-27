// CardView.swift

import SwiftUI

// TODO: playback ability

struct CardView: View {
    let item: SpotifyModelCardable
    
    private let thumbnailDimension: Double = Musubi.UIConstants.thumbnailDimension
    
    var body: some View {
        HStack {
            if item.images != nil && !(item.images!.isEmpty) {
                AsyncImage(url: URL(string: item.images![0].url)) { image in
                    image.resizable()
                        .scaledToFill()
                        .clipped()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: thumbnailDimension, height: thumbnailDimension)
            }
            Text(item.name)
        }
    }
}

//#Preview {
//    CardView()
//}
