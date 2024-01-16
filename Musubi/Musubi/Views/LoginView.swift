// LoginView.swift

import SwiftUI
import WebKit

struct LoginView: View {
    @Environment(Musubi.UserManager.self) private var userManager
    
    @State var showSheetWebLogin = false
    @State var showAlertLoginError = false
    
    var body: some View {
        @Bindable var userManager = userManager
        
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
        .fullScreenCover(item: $userManager.loggedInUser) { _ in
            Text(userManager.loggedInUser?.display_name ?? "errored")
            // TODO: create a new view model instance passing in this (immutable) loggedInUser
            // TODO: create HomeView with above view model as environment object
        }
    }
}

struct SpotifyLoginWebView: UIViewRepresentable {
    @Environment(Musubi.UserManager.self) private var userManager
    
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
        self.webView.load(Spotify.createWebLoginRequest(pkceChallenge: pkceChallenge))
        return self.webView
    }

    func updateUIView(_ uiView: WKWebView, context: UIViewRepresentableContext<SpotifyLoginWebView>) {
        return
    }
    
    func makeCoordinator() -> SpotifyLoginWebView.Coordinator {
        Coordinator(
            userManager: userManager,
            showSheetWebLogin: $showSheetWebLogin,
            showAlertLoginError: $showAlertLoginError,
            pkceVerifier: pkceVerifier
        )
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        private var userManager: Musubi.UserManager
        
        @Binding private var showSheetWebLogin: Bool
        @Binding private var showAlertLoginError: Bool
        
        private let pkceVerifier: String
        
        init(
            userManager: Musubi.UserManager,
            showSheetWebLogin: Binding<Bool>,
            showAlertLoginError: Binding<Bool>,
            pkceVerifier: String
        ) {
            self.userManager = userManager
            _showSheetWebLogin = showSheetWebLogin
            _showAlertLoginError = showAlertLoginError
            self.pkceVerifier = pkceVerifier
        }
        
//        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
            Task {
                do {
                    try await Spotify.handleNewLogin(
                        oauthRedirectedURL: webView.url,
                        pkceVerifier: pkceVerifier,
                        userManager: userManager
                    )
                } catch {
                    showAlertLoginError = true
                }
                showSheetWebLogin = false
            }
        }
    }
}
