import SwiftUI
import WebKit

enum YidunWidget {
    static func html(captchaId: String = YidunClient.captchaId741) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <script src="https://cstaticdun.126.net/load.min.js"></script>
        <style>
          html,body{margin:0;padding:0;background:#f5f5f5;font-family:-apple-system,sans-serif;color:#222;}
          .wrap{padding:24px 16px 12px;text-align:center;}
          h1{font-size:17px;font-weight:600;margin:0 0 8px;}
          p{font-size:13px;color:#666;margin:0;}
          #captcha{min-height:1px;}
        </style>
        </head>
        <body>
        <div class="wrap">
          <h1>安全验证</h1>
          <p>请完成点选，与官网申购弹层相同</p>
        </div>
        <div id="captcha"></div>
        <script>
        function post(obj) {
          if (window.webkit && window.webkit.messageHandlers.yidun) {
            window.webkit.messageHandlers.yidun.postMessage(obj);
          }
        }
        function gdx() {
          var m = document.cookie.match(/(?:^|; )gdxidpyhxdE=([^;]+)/);
          return m ? decodeURIComponent(m[1]) : "";
        }
        function boot(n) {
          if (typeof initNECaptcha !== "function") {
            if (n > 50) { post({ validate: "", fp: "", error: "易盾 SDK 未加载" }); return; }
            setTimeout(function(){ boot(n + 1); }, 200);
            return;
          }
          initNECaptcha({
            captchaId: "\(captchaId)",
            element: "#captcha",
            mode: "popup",
            width: "320px",
            onVerify: function(err, data) {
              post({
                validate: (data && data.validate) ? data.validate : "",
                fp: gdx(),
                error: err ? String(err) : ""
              });
            }
          }, function(instance) {
            try { instance.popUp(); } catch (e) { post({ validate: "", fp: "", error: String(e) }); }
          }, function(err) {
            post({ validate: "", fp: "", error: String(err) });
          });
        }
        boot(0);
        </script>
        </body>
        </html>
        """
    }
}

struct YidunSheet: View {
    let priorityRecordId: String
    var captchaId: String = YidunClient.captchaId741
    var onValidate: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var status = "请完成点选验证（官网同款弹层）"
    @State private var validate = ""
    @State private var fp = ""
    @State private var didSend = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                YidunWebView(captchaId: captchaId) { value, gdx in
                    guard !didSend, !value.isEmpty else { return }
                    didSend = true
                    validate = value
                    fp = gdx
                    status = "点选完成，正在带回抢购…"
                    onValidate(value, gdx)
                    dismiss()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(status)
                    .font(.footnote)
                    .padding(8)
                    .accessibilityIdentifier("yidun.status")
            }
            .navigationTitle("安全验证")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !priorityRecordId.isEmpty {
                    status = "record \(priorityRecordId) 请完成点选"
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

struct YidunWebView: UIViewRepresentable {
    var captchaId: String = YidunClient.captchaId741
    var onValidate: (String, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onValidate: onValidate)
    }

    func makeUIView(context: Context) -> WKWebView {
        let content = WKUserContentController()
        content.add(context.coordinator, name: "yidun")
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.userContentController = content
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.customUserAgent = CookieBridge.h5UA
        view.loadHTMLString(YidunWidget.html(captchaId: captchaId), baseURL: URL(string: "https://h5.moutai519.com.cn/"))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onValidate = onValidate
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "yidun")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var onValidate: (String, String) -> Void
        init(onValidate: @escaping (String, String) -> Void) {
            self.onValidate = onValidate
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            let validate = body["validate"] as? String ?? ""
            let fp = body["fp"] as? String ?? ""
            if !validate.isEmpty {
                DispatchQueue.main.async { self.onValidate(validate, fp) }
            }
        }
    }
}
