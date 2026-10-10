import SwiftUI
import WebKit

struct H5WebView: View {
    private let url = Product.sku741.h5URL

    var body: some View {
        NavigationStack {
            WebViewContainer(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("官方 H5")
                .navigationBarTitleDisplayMode(.inline)
                .accessibilityIdentifier("h5.container")
        }
    }
}

struct WebViewContainer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.accessibilityIdentifier = "h5.webview"
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
