// LoginView.swift

import SwiftUI
import WebKit

struct LoginView: View {
    @Environment(SpotifyWebClient.self) private var spotifyWebClient
    
    @State var showSheetWebLogin = false
    @State var showAlertLoginError = false
    
    var body: some View {
        @Bindable var spotifyWebClient = spotifyWebClient
        
        VStack {
            Spacer()
            Text("Musubi")
                .font(.custom("FontNameRound", fixedSize: 34))
            Spacer()
            Button {
                showSheetWebLogin = true
            } label: {
                Text("Log in with Spotify")
                    .padding()
                    .background(
                        RoundedRectangle(
                            cornerRadius: 20,
                            style: .continuous
                        )
                        .stroke(.white, lineWidth: 2)
                    )
            }
            .sheet(isPresented: $showSheetWebLogin) {
                // TODO: make sure a new WebView is instantiated every time this sheet is presented
                // i.e. prevent view caching here.
                SpotifyLoginWebView(
                    showSheetWebLogin: $showSheetWebLogin,
                    showAlertLoginError: $showAlertLoginError,
                    pkceVerifier: Musubi.newPKCEVerifier()
                )
            }
            Spacer()
        }
        .alert(
            "Error when logging in with Spotify.",
            isPresented: $showAlertLoginError,
            actions: {},
            message: { Text(Musubi.ErrorMessage(suggestedFix: .reopen).text) }
        )
        .fullScreenCover(item: $spotifyWebClient.loggedInUser) { loggedInUser in
            // TODO: create a new view model instance passing in this (immutable) loggedInUser
            // TODO: create HomeView with above view model as environment object
        }
    }
}

struct SpotifyLoginWebView: UIViewRepresentable {
    @Environment(SpotifyWebClient.self) private var spotifyWebClient
    
    @Binding var showSheetWebLogin: Bool
    @Binding var showAlertLoginError: Bool
    
    let pkceVerifier: String

    let webView = WKWebView()

    func makeUIView(context: UIViewRepresentableContext<SpotifyLoginWebView>) -> WKWebView {
        guard let pkceChallenge = try? Musubi.newPKCEChallenge(pkceVerifier: pkceVerifier) else {
            showAlertLoginError = true
            showSheetWebLogin = false
            return self.webView
        }
        
        self.webView.navigationDelegate = context.coordinator
        self.webView.load(spotifyWebClient.createWebLoginRequest(pkceChallenge: pkceChallenge))
        return self.webView
    }

    func updateUIView(_ uiView: WKWebView, context: UIViewRepresentableContext<SpotifyLoginWebView>) {
        return
    }
    
    func makeCoordinator() -> SpotifyLoginWebView.Coordinator {
        Coordinator(
            spotifyWebClient: spotifyWebClient,
            showSheetWebLogin: $showSheetWebLogin,
            showAlertLoginError: $showAlertLoginError,
            pkceVerifier: pkceVerifier
        )
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        private var spotifyWebClient: SpotifyWebClient
        
        @Binding private var showSheetWebLogin: Bool
        @Binding private var showAlertLoginError: Bool
        
        private let pkceVerifier: String
        
        init(
            spotifyWebClient: SpotifyWebClient,
            showSheetWebLogin: Binding<Bool>,
            showAlertLoginError: Binding<Bool>,
            pkceVerifier: String
        ) {
            self.spotifyWebClient = spotifyWebClient
            _showSheetWebLogin = showSheetWebLogin
            _showAlertLoginError = showAlertLoginError
            self.pkceVerifier = pkceVerifier
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task {
                do {
                    try await spotifyWebClient.handleNewLogin(
                        oauthRedirectedURL: webView.url,
                        pkceVerifier: pkceVerifier
                    )
                } catch {
                    showAlertLoginError = true
                }
                showSheetWebLogin = false
            }
        }
    }
}
