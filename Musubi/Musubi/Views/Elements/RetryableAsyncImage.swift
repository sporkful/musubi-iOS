// RetryableAsyncImage.swift

import SwiftUI

// TODO: shared image pool/cache

struct RetryableAsyncImage: View {
    let url: URL
    let width: CGFloat
    let height: CGFloat
    
    @State private var image: UIImage?
    
    var body: some View {
        VStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                ProgressView()
                    .frame(width: width, height: height)
            }
        }
        .task { await loadImage() }
    }
    
    private func loadImage() async {
        while true {
            do {
                self.image = try await SpotifyRequests.Read.image(url: url)
                return
            } catch {
//                print("[Musubi::RetryableAsyncImage] failed to load image")
//                print(error)
//                print("[Musubi::RetryableAsyncImage] retrying...")
            }
            do {
                try await Task.sleep(until: .now + .seconds(1), clock: .continuous)
            } catch {
//                print("[Musubi::RetryableAsyncImage] giving up")
                break // task was cancelled
            }
        }
    }
}

//#Preview {
//    RetryableAsyncImage()
//}
