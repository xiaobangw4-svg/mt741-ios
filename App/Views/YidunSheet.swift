import SwiftUI
import WebKit

struct YidunSheet: View {
    let session: Session
    let priorityRecordId: String
    var onValidate: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var status = "滑块完成后会填入 ydToken"
    @State private var validate = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                YidunWebView { value in
                    validate = value
                    onValidate(value)
                    status = "已拿到 validate，可提交或带回抢购"
                }
                .frame(minHeight: 280)
                Text(status)
                    .font(.footnote)
                    .padding(8)
                    .accessibilityIdentifier("yidun.status")
            }
            .navigationTitle("易盾验证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("提交验证") { Task { await submit() } }
                        .disabled(busy || validate.isEmpty)
                        .accessibilityIdentifier("yidun.submit")
                }
            }
        }
    }

    private func submit() async {
        busy = true
        defer { busy = false }
        status = await YidunClient.verify(
            validate: validate,
            priorityRecordId: priorityRecordId,
            session: session
        )
        onValidate(validate)
    }
}

struct YidunWebView: UIViewRepresentable {
    var onValidate: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onValidate: onValidate)
    }

    func makeUIView(context: Context) -> WKWebView {
        let content = WKUserContentController()
        content.add(context.coordinator, name: "yidun")
        let config = WKWebViewConfiguration()
        config.userContentController = content
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.customUserAgent = CookieBridge.h5UA
        view.loadHTMLString(Self.html, baseURL: URL(string: "https://h5.moutai519.com.cn/"))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onValidate = onValidate
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var onValidate: (String) -> Void
        init(onValidate: @escaping (String) -> Void) {
            self.onValidate = onValidate
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            if let validate = body["validate"] as? String, !validate.isEmpty {
                DispatchQueue.main.async { self.onValidate(validate) }
            }
        }
    }

    private static let html = """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
    <script src="https://cstaticdun.126.net/load.min.js"></script>
    </head>
    <body style="margin:12px;font-family:-apple-system;background:#fff;">
    <p>SKU 741 易盾滑块</p>
    <div id="captcha"></div>
    <script>
    function post(obj) {
      if (window.webkit && window.webkit.messageHandlers.yidun) {
        window.webkit.messageHandlers.yidun.postMessage(obj);
      }
    }
    initNECaptcha({
      captchaId: "\(YidunClient.captchaId741)",
      element: "#captcha",
      mode: "embed",
      width: "320px",
      onVerify: function(err, data) {
        post({ validate: (data && data.validate) ? data.validate : "", error: err ? String(err) : "" });
      }
    }, function() {}, function(err) {
      post({ validate: "", error: String(err) });
    });
    </script>
    </body>
    </html>
    """
}
