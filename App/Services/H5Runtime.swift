import Combine
import Foundation
import UIKit
import WebKit

@MainActor
final class H5Runtime: NSObject, ObservableObject {
    let webView: WKWebView
    weak var cwbStore: CWBStore?
    @Published var ready = false
    @Published var pageURL = ""
    @Published var lastProbe = ""

    private var fingerprint = ""
    private var pendingJS: [String: CheckedContinuation<Any?, Error>] = [:]
    private let proxy = BridgeProxy()
    fileprivate static let jsHandlerName = "mt741js"

    override init() {
        let content = WKUserContentController()
        content.addUserScript(WKUserScript(
            source: CWBHook.javaScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        content.addUserScript(WKUserScript(
            source: H5Fire.javaScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        content.add(proxy, name: CWBHook.handlerName)
        content.add(proxy, name: H5Runtime.jsHandlerName)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.userContentController = content
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 375, height: 667), configuration: config)
        view.customUserAgent = CookieBridge.userAgent(deviceId: "MT741")
        view.isOpaque = true
        view.backgroundColor = .white
        view.scrollView.backgroundColor = .white
        view.accessibilityIdentifier = "h5.webview"
        webView = view
        super.init()
        proxy.owner = self
        webView.navigationDelegate = proxy
        HiddenWebHost.attach(webView)
    }

    var isLive: Bool {
        guard let host = webView.url?.host else { return false }
        return host.contains("moutai519.com.cn")
    }

    func keepInWindow() {
        HiddenWebHost.attachIfIdle(webView)
    }

    func park() {
        HiddenWebHost.attach(webView)
    }

    func bindIfNeeded(session: Session, cwbStore: CWBStore, product: Product = .sku741, forceLoad: Bool = false) {
        self.cwbStore = cwbStore
        keepInWindow()
        let shouldLoad = forceLoad || session.isLoggedIn
        guard shouldLoad else { return }
        let next = session.cookie + "|" + session.token + "|" + session.deviceId + "|" + product.sku
        if fingerprint == next, webView.url != nil, !forceLoad { return }
        fingerprint = next
        webView.customUserAgent = CookieBridge.userAgent(deviceId: session.deviceId)
        CookieBridge.apply(session) { [weak self] in
            self?.keepInWindow()
            self?.webView.load(URLRequest(url: product.h5URL))
        }
    }

    func fire(request: BurstRequest, session: Session) async -> BurstStats {
        keepInWindow()
        if let err = await waitUntilReady(seconds: 25, product: request.product, session: session) {
            return BurstStats(
                url: request.target.urlString,
                n: BurstClient.clampN(request.n),
                concurrency: BurstClient.clampC(request.concurrency),
                intervalMs: BurstClient.clampInterval(request.intervalMs),
                sku: request.product.sku,
                elapsedMs: 0,
                ok: 0,
                fail: 1,
                status: [:],
                summary: err,
                shots: [BurstShot(idx: 0, ok: false, status: 0, ms: 0, body: "", error: err)]
            )
        }
        let product = request.product
        let plain = RushPlain(
            amount: request.amount.isEmpty ? product.defaultAmount : request.amount,
            itemCode: product.sku,
            itemPriorityActId: request.actId,
            deviceId: session.deviceId,
            ydLogId: request.ydLogId,
            ydToken: request.ydToken,
            userId: session.userId,
            shopId: request.shopId
        )
        let body = RushCrypto.rushBody(plain: plain)
        let n = BurstClient.clampN(request.n)
        let payload: [String: Any] = [
            "url": product.rushURL.absoluteString,
            "body": body,
            "n": n,
            "concurrency": BurstClient.clampC(request.concurrency),
            "intervalMs": BurstClient.clampInterval(request.intervalMs),
            "headers": H5Fire.pageHeaders(deviceId: session.deviceId, product: product),
            "kv": H5Fire.kvPairs(count: n, deviceId: session.deviceId),
        ]
        let t0 = Date()
        do {
            let result = try await callJS("return await window.__mt741fire(payload);", arguments: ["payload": payload])
            let elapsed = Date().timeIntervalSince(t0) * 1000
            return H5Fire.stats(from: result, request: request, elapsedMs: elapsed)
        } catch {
            let elapsed = Date().timeIntervalSince(t0) * 1000
            let msg = error.localizedDescription
            return BurstStats(
                url: request.target.urlString,
                n: n,
                concurrency: BurstClient.clampC(request.concurrency),
                intervalMs: BurstClient.clampInterval(request.intervalMs),
                sku: request.product.sku,
                elapsedMs: elapsed,
                ok: 0,
                fail: 1,
                status: [:],
                summary: msg,
                shots: [BurstShot(idx: 0, ok: false, status: 0, ms: elapsed, body: "", error: msg)]
            )
        }
    }

    func fetchActId(product: Product = .sku741, session: Session? = nil) async -> PurchaseInfo {
        if let err = pageError() {
            return PurchaseInfo(ok: false, message: err)
        }
        let bodyObj: [String: Any] = ["hot": true, "spuId": product.spu]
        let body = String(data: (try? JSONSerialization.data(withJSONObject: bodyObj)) ?? Data(), encoding: .utf8) ?? ""
        do {
            let json = try await requestJSON(
                method: "POST",
                url: CatalogClient.purchaseInfoURL.absoluteString,
                body: body,
                session: session,
                timeoutMs: 8000
            )
            let info = CatalogClient.parse(json, sku: product.sku)
            lastProbe = info.message
            return info
        } catch {
            lastProbe = error.localizedDescription
            return PurchaseInfo(ok: false, message: error.localizedDescription)
        }
    }

    func fetchAddress() async -> (message: String, address: [String: Any]?) {
        if let err = pageError() {
            return (err, nil)
        }
        let ts = String(Int64(Date().timeIntervalSince1970 * 1000))
        let url = CatalogClient.addressURL.absoluteString + "?__timestamp=" + ts
        do {
            let json = try await requestJSON(method: "GET", url: url, body: nil, session: nil, timeoutMs: 12000)
            if let addr = CatalogClient.parseAddress(json) {
                return ("地址 id=\(JSONText.string(addr["shipAddressId"]))", addr)
            }
            return ((json["message"] as? String) ?? "无收货地址", nil)
        } catch {
            return (error.localizedDescription, nil)
        }
    }

    func cookieValue(_ name: String) async -> String {
        await withCheckedContinuation { cont in
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                let match = cookies.first { $0.name == name && ($0.domain.contains("moutai519") || $0.domain.contains("moutai")) }
                cont.resume(returning: match?.value ?? "")
            }
        }
    }

    func waitUntilLive(seconds: Double) async -> String? {
        keepInWindow()
        let deadline = Date().addingTimeInterval(seconds)
        var last = "H5 页未就绪"
        while Date() < deadline {
            reinstallHooks()
            if isLive, await requestFunctionReady() {
                ready = true
                return nil
            }
            last = pageError() ?? "H5 页未就绪（先登录，等商品页起来）"
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
        if isLive, await requestFunctionReady() {
            ready = true
            return nil
        }
        return last
    }

    func waitUntilReady(seconds: Double, product: Product = .sku741, session: Session? = nil) async -> String? {
        if let err = await waitUntilLive(seconds: seconds) {
            return err
        }
        let deadline = Date().addingTimeInterval(min(8, max(0, seconds)))
        while Date() < deadline {
            if await fireFunctionReady(), (cwbStore?.cwb.count ?? 0) >= CWBStore.officialLength - 10 {
                return nil
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
        return nil
    }

    private func requestJSON(method: String, url: String, body: String?, session: Session?, timeoutMs: Int) async throws -> [String: Any] {
        var payload: [String: Any] = ["method": method, "url": url, "timeoutMs": timeoutMs]
        if let body, !body.isEmpty {
            payload["body"] = body
        }
        if let session {
            payload["headers"] = H5Fire.pageHeaders(deviceId: session.deviceId)
        }
        let result = try await callJS(
            "return await window.__mt741request(payload);",
            arguments: ["payload": payload],
            timeoutSeconds: 12
        )
        let row = (result as? [String: Any]) ?? [:]
        let text = JSONText.string(row["body"])
        let err = JSONText.string(row["error"])
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            let hint = err.isEmpty ? (text.isEmpty ? "H5 请求无返回（页内 JS 未跑起来）" : String(text.prefix(120))) : err
            throw NSError(domain: "H5", code: JSONText.int(row["status"]) ?? 0, userInfo: [
                NSLocalizedDescriptionKey: hint,
            ])
        }
        return json
    }

    private func callJS(_ body: String, arguments: [String: Any] = [:], timeoutSeconds: Double = 15) async throws -> Any? {
        let id = UUID().uuidString
        let argsJSON = jsonAtom(arguments)
        let bindings = arguments.keys.map { key in
            "var \(key) = args[\(jsonAtom(key))];"
        }.joined(separator: "\n")
        let script = """
        (function() {
          var id = \(jsonAtom(id));
          var args = \(argsJSON);
          var h = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mt741js;
          if (!h) throw new Error('mt741js missing');
          Promise.resolve().then(async function() {
            \(bindings)
            \(body)
          }).then(function(value) {
            try { h.postMessage({id: id, ok: true, value: value}); }
            catch (e) {
              try { h.postMessage({id: id, ok: true, json: JSON.stringify(value)}); }
              catch (e2) { h.postMessage({id: id, ok: false, error: String(e2)}); }
            }
          }).catch(function(e) {
            h.postMessage({id: id, ok: false, error: String(e)});
          });
        })();
        """
        let ns = UInt64(max(3, timeoutSeconds) * 1_000_000_000)
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Any?, Error>) in
            pendingJS[id] = cont
            webView.evaluateJavaScript(script) { [weak self] _, error in
                guard let error else { return }
                DispatchQueue.main.async {
                    self?.failJS(id: id, message: error.localizedDescription)
                }
            }
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: ns)
                self?.failJS(id: id, message: "H5 JS 超时")
            }
        }
    }

    private func jsonAtom(_ value: Any) -> String {
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let data = try? JSONSerialization.data(withJSONObject: [value]),
           let text = String(data: data, encoding: .utf8), text.count >= 2 {
            return String(text.dropFirst().dropLast())
        }
        return "null"
    }

    fileprivate func finishJS(_ body: Any) {
        guard let dict = body as? [String: Any] else { return }
        let id = JSONText.string(dict["id"])
        guard !id.isEmpty, let cont = pendingJS.removeValue(forKey: id) else { return }
        let ok = (dict["ok"] as? Bool) == true || (dict["ok"] as? NSNumber)?.boolValue == true
        if ok {
            if let json = dict["json"] as? String,
               let data = json.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) {
                cont.resume(returning: obj)
            } else {
                cont.resume(returning: dict["value"])
            }
            return
        }
        let err = JSONText.string(dict["error"])
        cont.resume(throwing: NSError(domain: "H5", code: 0, userInfo: [
            NSLocalizedDescriptionKey: err.isEmpty ? "H5 JS 失败" : err,
        ]))
    }

    fileprivate func failJS(id: String, message: String) {
        guard let cont = pendingJS.removeValue(forKey: id) else { return }
        cont.resume(throwing: NSError(domain: "H5", code: 0, userInfo: [
            NSLocalizedDescriptionKey: message,
        ]))
    }

    private func reinstallHooks() {
        webView.evaluateJavaScript("window.__mt741hookCWB && window.__mt741hookCWB()") { _, _ in }
    }

    private func requestFunctionReady() async -> Bool {
        await jsFunctionExists("__mt741request")
    }

    private func fireFunctionReady() async -> Bool {
        await jsFunctionExists("__mt741fire")
    }

    private func jsFunctionExists(_ name: String) async -> Bool {
        await withCheckedContinuation { cont in
            webView.evaluateJavaScript("typeof window.\(name) === 'function'") { result, _ in
                let ok = (result as? Bool) == true
                    || (result as? NSNumber)?.boolValue == true
                    || (result as? String) == "true"
                cont.resume(returning: ok)
            }
        }
    }

    private func pageError() -> String? {
        if isLive { return nil }
        return "先登录，等 H5 商品页加载完（需要官方 wasm 现签 CWB）"
    }
}

enum HiddenWebHost {
    private static let host: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        view.isUserInteractionEnabled = false
        view.alpha = 1
        view.clipsToBounds = true
        view.accessibilityIdentifier = "h5.hiddenHost"
        return view
    }()

    static func attach(_ webView: WKWebView) {
        install()
        if webView.superview === host { return }
        webView.removeFromSuperview()
        host.addSubview(webView)
        webView.frame = host.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.isHidden = false
        webView.alpha = 1
    }

    static func attachIfIdle(_ webView: WKWebView) {
        install()
        if let parent = webView.superview, parent !== host {
            return
        }
        attach(webView)
    }

    static func install() {
        guard let window = keyWindow else { return }
        if host.superview !== window {
            window.insertSubview(host, at: 0)
        }
        let w = max(window.bounds.width, 375)
        let h = max(window.bounds.height, 667)
        host.frame = CGRect(x: 0, y: 0, width: w, height: h)
        host.alpha = 1
        host.isUserInteractionEnabled = false
    }

    private static var keyWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if let key = scene.windows.first(where: \.isKeyWindow) {
                return key
            }
        }
        return scenes.first?.windows.first
    }
}

extension H5Runtime {
    fileprivate final class BridgeProxy: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        weak var owner: H5Runtime?

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            let body = message.body
            if message.name == H5Runtime.jsHandlerName {
                DispatchQueue.main.async {
                    self.owner?.finishJS(body)
                }
                return
            }
            guard message.name == CWBHook.handlerName else { return }
            DispatchQueue.main.async {
                self.owner?.cwbStore?.ingest(body)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.owner?.pageURL = webView.url?.absoluteString ?? ""
                self.owner?.ready = self.owner?.isLive ?? false
                self.owner?.keepInWindow()
                webView.evaluateJavaScript("window.__mt741hookCWB && window.__mt741hookCWB()") { _, _ in }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.owner?.ready = self.owner?.isLive ?? false
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.owner?.ready = self.owner?.isLive ?? false
                self.owner?.pageURL = error.localizedDescription
            }
        }
    }
}
