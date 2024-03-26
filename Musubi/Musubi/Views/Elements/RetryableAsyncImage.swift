// RetryableAsyncImage.swift

import SwiftUI

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
            }
        }
        .task { await loadImage() }
    }
    
    private func loadImage() async {
        while image == nil {
            if let (data, response) = try? await URLSession.shared.data(from: url),
               let httpResponse = response as? HTTPURLResponse,
               SpotifyConstants.HTTP_SUCCESS_CODES.contains(httpResponse.statusCode)
            {
                image = UIImage(data: data)
                break // success
            }
            
            do {
                try await Task.sleep(until: .now + .seconds(1), clock: .continuous)
            } catch {
                break // task was cancelled
            }
        }
    }
}

//#Preview {
//    RetryableAsyncImage()
//}
