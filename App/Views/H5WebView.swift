import SwiftUI
import WebKit

/// SwiftUI owns this box; the official product WK lives inside it so StyleTotal
/// sees real laid-out pixels (same as 官网真机 smsp-detail).
struct WebViewContainer: UIViewRepresentable {
    let runtime: H5Runtime
    let session: Session
    let cwbStore: CWBStore
    let product: Product

    func makeUIView(context: Context) -> UIView {
        let box = UIView()
        box.backgroundColor = .white
        box.clipsToBounds = true
        box.accessibilityIdentifier = "h5.stageBox"
        embed(runtime.webView, in: box)
        runtime.bindIfNeeded(session: session, cwbStore: cwbStore, product: product)
        return box
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        embed(runtime.webView, in: uiView)
        runtime.bindIfNeeded(session: session, cwbStore: cwbStore, product: product)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        _ = coordinator
        _ = uiView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(runtime: runtime)
    }

    final class Coordinator {
        let runtime: H5Runtime
        init(runtime: H5Runtime) { self.runtime = runtime }
    }

    private func embed(_ view: WKWebView, in box: UIView) {
        view.isHidden = false
        view.alpha = 1
        view.isUserInteractionEnabled = true
        view.isOpaque = true
        view.backgroundColor = .white
        if view.superview !== box {
            view.removeFromSuperview()
            box.addSubview(view)
        }
        view.frame = box.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
}
