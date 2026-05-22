import Foundation
import SwiftUI
import WebKit

struct DiscordWebLoginView: NSViewRepresentable {
    let loginURL: URL
    let onAuthenticated: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onAuthenticated: onAuthenticated)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: loginURL))
        context.coordinator.startMonitoring(webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onAuthenticated = onAuthenticated

        if webView.url == nil {
            webView.load(URLRequest(url: loginURL))
        }
        context.coordinator.startMonitoring(webView)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var onAuthenticated: (String) -> Void
        private weak var webView: WKWebView?
        private var tokenTimer: Timer?
        private var didImportToken = false

        init(onAuthenticated: @escaping (String) -> Void) {
            self.onAuthenticated = onAuthenticated
        }

        func startMonitoring(_ webView: WKWebView) {
            self.webView = webView

            guard tokenTimer == nil else {
                return
            }

            tokenTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.checkForToken()
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            startMonitoring(webView)
            checkForToken()
        }

        private func checkForToken() {
            guard let webView, !didImportToken else {
                return
            }

            let js = """
            (function() {
                try {
                    const iframe = document.createElement("iframe");
                    document.body.appendChild(iframe);
                    const token = iframe.contentWindow.localStorage.token || "";
                    iframe.remove();
                    return token;
                } catch (error) {
                    return "";
                }
            })();
            """

            webView.evaluateJavaScript(js) { [weak self] result, _ in
                guard let self else {
                    return
                }

                guard let token = result as? String else {
                    return
                }

                let normalizedToken = token
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\"", with: "")

                guard !normalizedToken.isEmpty else {
                    return
                }

                self.didImportToken = true
                self.tokenTimer?.invalidate()
                self.tokenTimer = nil
                self.onAuthenticated(normalizedToken)
            }
        }
    }
}
