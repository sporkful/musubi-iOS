// LoginView.swift

import SwiftUI
import WebKit

struct LoginView: View {
    @State var showSheetWebLogin = false
    @State var showAlertLoginError = false
    
    @State var loggedInUser: Spotify.CurrentUser?
    
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
        .alert(
            "Error when signing in with Spotify.",
            isPresented: $showAlertLoginError,
            actions: {},
            message: { Text(Musubi.errorAlertMessage(suggestedFix: .reopen)) }
        )
        .sheet(isPresented: $showSheetWebLogin) {
            SpotifyAuthWebView(
                showSheetWebLogin: $showSheetWebLogin,
                showAlertLoginError: $showAlertLoginError
            )
        }
    }
}

struct SpotifyAuthWebView: UIViewRepresentable {
    @Binding var showSheetWebLogin: Bool
    @Binding var showAlertLoginError: Bool

    let webView = WKWebView()
    let pkceVerifier = Musubi.newPKCEVerifier()

    func makeUIView(context: UIViewRepresentableContext<SpotifyAuthWebView>) -> WKWebView {
        self.webView.navigationDelegate = context.coordinator
        self.webView.load(Spotify.createAuthRequest(pkceChallenge: pkceVerifier))
        return self.webView
    }

    func updateUIView(_ uiView: WKWebView, context: UIViewRepresentableContext<SpotifyAuthWebView>) {
        return
    }
    
    func makeCoordinator() -> SpotifyAuthWebView.Coordinator {
        Coordinator(
            showSheetWebLogin: $showSheetWebLogin,
            showAlertErrorPKCEGen: $showAlertLoginError,
            pkceVerifier: pkceVerifier
        )
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding private var showSheetWebLogin: Bool
        @Binding private var showAlertLoginError: Bool
        
        private let pkceVerifier: String
        
        init(
            showSheetWebLogin: Binding<Bool>,
            showAlertErrorPKCEGen: Binding<Bool>,
            pkceVerifier: String
        ) {
            _showSheetWebLogin = showSheetWebLogin
            _showAlertLoginError = showAlertErrorPKCEGen
            self.pkceVerifier = pkceVerifier
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            guard let redirectedURL = webView.url else {
                showAlertLoginError = true
                showSheetWebLogin = false
                return
            }

            guard let authCode = URLComponents(string: redirectedURL.absoluteString)?
                .queryItems?
                .first(where: { $0.name == "code" })?
                .value
            else {
                showAlertLoginError = true
                showSheetWebLogin = false
                return
            }

            Task {
                do {
                    try await Spotify.fetchToken(authCode: authCode, pkceVerifier: pkceVerifier)
                } catch {
                    showAlertLoginError = true
                }
                showSheetWebLogin = false
            }
        }
    }
}
