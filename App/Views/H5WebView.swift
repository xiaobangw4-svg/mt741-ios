import SwiftUI
import WebKit

struct H5WebView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var cwbStore: CWBStore
    @EnvironmentObject private var h5Runtime: H5Runtime

    var body: some View {
        NavigationStack {
            WebViewContainer(runtime: h5Runtime, session: sessionStore.session, cwbStore: cwbStore)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("官方 H5")
                .navigationBarTitleDisplayMode(.inline)
                .accessibilityIdentifier("h5.container")
                .toolbar {
                    ToolbarItem(placement: .status) {
                        Text(h5Status)
                            .font(.caption.monospaced())
                            .accessibilityIdentifier("h5.cwb")
                    }
                }
        }
    }

    private var h5Status: String {
        if !cwbStore.cwb.isEmpty {
            return "CWB \(cwbStore.cwb.count)"
        }
        if h5Runtime.ready {
            return "页已加载，等 CWB"
        }
        return "加载商品页…"
    }
}

struct WebViewContainer: UIViewRepresentable {
    let runtime: H5Runtime
    let session: Session
    let cwbStore: CWBStore

    func makeUIView(context: Context) -> WKWebView {
        runtime.bindIfNeeded(session: session, cwbStore: cwbStore, forceLoad: true)
        return runtime.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        runtime.bindIfNeeded(session: session, cwbStore: cwbStore, forceLoad: true)
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        let runtime = coordinator.runtime
        Task { @MainActor in
            runtime.park()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(runtime: runtime)
    }

    final class Coordinator {
        let runtime: H5Runtime
        init(runtime: H5Runtime) { self.runtime = runtime }
    }
}
