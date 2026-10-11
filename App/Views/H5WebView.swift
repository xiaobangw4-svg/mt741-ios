import SwiftUI
import WebKit

struct H5WebView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var cwbStore: CWBStore
    private let url = Product.sku741.h5URL

    var body: some View {
        NavigationStack {
            WebViewContainer(url: url, session: sessionStore.session, cwbStore: cwbStore)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("官方 H5")
                .navigationBarTitleDisplayMode(.inline)
                .accessibilityIdentifier("h5.container")
                .toolbar {
                    ToolbarItem(placement: .status) {
                        Text(cwbStore.cwb.isEmpty ? "CWB 未捕获" : "CWB \(cwbStore.cwb.count)")
                            .font(.caption.monospaced())
                            .accessibilityIdentifier("h5.cwb")
                    }
                }
        }
    }
}

struct WebViewContainer: UIViewRepresentable {
    let url: URL
    let session: Session
    let cwbStore: CWBStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: cwbStore)
    }

    func makeUIView(context: Context) -> WKWebView {
        let content = WKUserContentController()
        content.add(context.coordinator, name: CWBHook.handlerName)
        let script = WKUserScript(
            source: CWBHook.javaScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        content.addUserScript(script)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.userContentController = content
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.customUserAgent = CookieBridge.h5UA
        view.accessibilityIdentifier = "h5.webview"
        context.coordinator.webView = view
        reload(view)
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.store = cwbStore
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

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var fingerprint = ""
        weak var webView: WKWebView?
        var store: CWBStore

        init(store: CWBStore) {
            self.store = store
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            DispatchQueue.main.async {
                self.store.ingest(message.body)
            }
        }
    }
}
