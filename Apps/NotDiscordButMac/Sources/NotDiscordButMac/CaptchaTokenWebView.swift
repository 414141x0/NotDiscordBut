import DiscordKit
import SwiftUI
import WebKit

struct CaptchaTokenWebView: NSViewRepresentable {
    let challenge: CaptchaChallenge
    let onSolved: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSolved: onSolved)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.loadIfNeeded(challenge: challenge, into: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onSolved = onSolved
        context.coordinator.loadIfNeeded(challenge: challenge, into: webView)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var onSolved: (String) -> Void
        private var lastMarkup: String?

        init(onSolved: @escaping (String) -> Void) {
            self.onSolved = onSolved
        }

        func loadIfNeeded(challenge: CaptchaChallenge, into webView: WKWebView) {
            let markup = CaptchaMarkup.document(for: challenge)
            guard markup != lastMarkup else {
                return
            }

            lastMarkup = markup
            webView.loadHTMLString(markup, baseURL: URL(string: "https://discord.com"))
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if url.scheme == "notdiscordbut", url.host == "captcha",
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let key = components.queryItems?.first(where: { $0.name == "key" })?.value,
               !key.isEmpty {
                onSolved(key)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }
    }
}

private enum CaptchaMarkup {
    static func document(for challenge: CaptchaChallenge) -> String {
        switch challenge.service {
        case .hcaptcha:
            return hcaptchaDocument(for: challenge)
        case .recaptcha:
            return recaptchaDocument(for: challenge, enterprise: false)
        case .recaptchaEnterprise:
            return recaptchaDocument(for: challenge, enterprise: true)
        }
    }

    private static func hcaptchaDocument(for challenge: CaptchaChallenge) -> String {
        let siteKey = jsLiteral(challenge.siteKey ?? "")
        let requestData = jsLiteral(challenge.requestData ?? "")
        let size = challenge.shouldServeInvisible ? "invisible" : "normal"

        return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <script src="https://js.hcaptcha.com/1/api.js" async defer></script>
          <style>
            body { margin: 0; font-family: -apple-system; background: transparent; color: white; }
            #captcha { min-height: 300px; display: flex; align-items: center; justify-content: center; }
          </style>
        </head>
        <body>
          <div id="captcha"></div>
          <script>
            function resolveCaptcha(token) {
              window.location.href = "notdiscordbut://captcha?key=" + encodeURIComponent(token);
            }

            function renderCaptcha() {
              const options = {
                sitekey: \(siteKey),
                callback: resolveCaptcha,
                size: "\(size)"
              };
              const rqdata = \(requestData);
              if (rqdata.length > 0) {
                options.rqdata = rqdata;
              }
              const widgetID = hcaptcha.render("captcha", options);
              if (options.size === "invisible") {
                hcaptcha.execute(widgetID);
              }
            }

            window.onload = renderCaptcha;
          </script>
        </body>
        </html>
        """
    }

    private static func recaptchaDocument(for challenge: CaptchaChallenge, enterprise: Bool) -> String {
        let siteKey = jsLiteral(challenge.siteKey ?? "")
        let scriptURL = enterprise
            ? "https://www.google.com/recaptcha/enterprise.js"
            : "https://www.google.com/recaptcha/api.js"
        let widgetClass = enterprise ? "g-recaptcha" : "g-recaptcha"

        return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <script src="\(scriptURL)" async defer></script>
          <style>
            body { margin: 0; font-family: -apple-system; background: transparent; color: white; }
            #captcha { min-height: 300px; display: flex; align-items: center; justify-content: center; }
          </style>
        </head>
        <body>
          <div id="captcha">
            <div class="\(widgetClass)" data-sitekey=\(siteKey) data-callback="resolveCaptcha"></div>
          </div>
          <script>
            function resolveCaptcha(token) {
              window.location.href = "notdiscordbut://captcha?key=" + encodeURIComponent(token);
            }
          </script>
        </body>
        </html>
        """
    }

    private static func jsLiteral(_ string: String) -> String {
        let escaped = string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}
