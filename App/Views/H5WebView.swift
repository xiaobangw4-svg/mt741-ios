import SwiftUI
import WebKit

struct H5WebView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    private let url = Product.sku741.h5URL

    var body: some View {
        NavigationStack {
            WebViewContainer(url: url, session: sessionStore.session)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("官方 H5")
                .navigationBarTitleDisplayMode(.inline)
                .accessibilityIdentifier("h5.container")
        }
    }
}

struct WebViewContainer: UIViewRepresentable {
    let url: URL
    let session: Session

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.customUserAgent = CookieBridge.h5UA
        view.accessibilityIdentifier = "h5.webview"
        context.coordinator.webView = view
        reload(view)
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let fingerprint = session.cookie + "|" + session.token + "|" + session.deviceId
        if context.coordinator.fingerprint != fingerprint {
            context.coordinator.fingerprint = fingerprint
            reload(uiView)
        }
    }

    private func reload(_ view: WKWebView) {
        CookieBridge.apply(session) {
            view.load(URLRequest(url: url))
        }
    }

    final class Coordinator {
        var fingerprint = ""
        weak var webView: WKWebView?
    }
}
