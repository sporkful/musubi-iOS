// LoginView.swift

import SwiftUI
import WebKit

struct LoginView: View {
    @State private var userManager = Musubi.UserManager.shared
    
    @State var showSheetWebLogin = false
    @State var showAlertLoginError = false
    
    // This trivial custom binding allows userManager.currentUser to be private(set) and still be a
    // valid fullScreenCover item. Safe since this fullScreenCover is non-dismissable.
    var currentUser: Binding<Musubi.User?> {
        Binding(
            get: { userManager.currentUser },
            set: { _ in }
        )
    }
    
    var body: some View {
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
            Spacer()
        }
        // TODO: better way to specify exchange of these two sheets?
        .sheet(isPresented: $showSheetWebLogin) {
            // TODO: make sure a new WebView is instantiated every time this sheet is presented
            // i.e. prevent view caching here.
            SpotifyLoginWebView(
                showSheetWebLogin: $showSheetWebLogin,
                showAlertLoginError: $showAlertLoginError,
                pkceVerifier: Musubi.Cryptography.newPKCEVerifier()
            )
        }
        .fullScreenCover(item: currentUser) { currentUser in
            HomeView(
                currentUser: currentUser,
                spotifyPlaybackManager: SpotifyPlaybackManager(),
                homeViewCoordinator: HomeViewCoordinator()
            )
            .interactiveDismissDisabled()
        }
        .alert(
            "Error when logging in with Spotify.",
            isPresented: $showAlertLoginError,
            actions: {},
            message: { Text(Musubi.UI.ErrorMessage(suggestedFix: .reopen).string) }
        )
    }
}

struct SpotifyLoginWebView: UIViewRepresentable {
    @Binding var showSheetWebLogin: Bool
    @Binding var showAlertLoginError: Bool
    
    let pkceVerifier: String
    
    let webView = WKWebView()
    
    func makeUIView(context: UIViewRepresentableContext<SpotifyLoginWebView>) -> WKWebView {
        guard let pkceChallenge = try? Musubi.Cryptography.newPKCEChallenge(pkceVerifier: pkceVerifier) else {
            showAlertLoginError = true
            showSheetWebLogin = false
            return self.webView
        }
        
        self.webView.navigationDelegate = context.coordinator
        self.webView.load(Musubi.UserManager.shared.createWebLoginRequest(pkceChallenge: pkceChallenge))
        return self.webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: UIViewRepresentableContext<SpotifyLoginWebView>) {
        return
    }
    
    func makeCoordinator() -> SpotifyLoginWebView.Coordinator {
        Coordinator(
            showSheetWebLogin: $showSheetWebLogin,
            showAlertLoginError: $showAlertLoginError,
            pkceVerifier: pkceVerifier
        )
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding private var showSheetWebLogin: Bool
        @Binding private var showAlertLoginError: Bool
        
        private let pkceVerifier: String
        
        init(
            showSheetWebLogin: Binding<Bool>,
            showAlertLoginError: Binding<Bool>,
            pkceVerifier: String
        ) {
            _showSheetWebLogin = showSheetWebLogin
            _showAlertLoginError = showAlertLoginError
            self.pkceVerifier = pkceVerifier
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // Spotify's login flow includes multiple redirections.
            // We only care about the one with the auth code.
            guard let oauthRedirectedURL = webView.url,
                  let authCode = URLComponents(string: oauthRedirectedURL.absoluteString)?
                .queryItems?
                .first(where: { $0.name == "code" })?
                .value
            else {
                return
            }
            
            Task {
                do {
                    try await Musubi.UserManager.shared.handleNewLogin(
                        authCode: authCode,
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
