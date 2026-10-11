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

    private var fingerprint = ""
    private let proxy = BridgeProxy()

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
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.userContentController = content
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 8, height: 8), configuration: config)
        view.customUserAgent = CookieBridge.h5UA
        view.accessibilityIdentifier = "h5.webview"
        webView = view
        super.init()
        proxy.owner = self
        content.add(proxy, name: CWBHook.handlerName)
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
        if fingerprint == next, webView.url != nil { return }
        fingerprint = next
        CookieBridge.apply(session) { [weak self] in
            self?.keepInWindow()
            self?.webView.load(URLRequest(url: product.h5URL))
        }
    }

    func fire(request: BurstRequest, session: Session) async -> BurstStats {
        keepInWindow()
        if let err = await waitUntilReady(seconds: 18) {
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
            let result = try await webView.callAsyncJavaScript(
                "return await window.__mt741fire(payload);",
                arguments: ["payload": payload],
                in: nil,
                in: .page
            )
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

    func fetchActId(product: Product = .sku741) async -> PurchaseInfo {
        if pageError() != nil {
            return PurchaseInfo(ok: false, message: pageError() ?? "H5 未就绪")
        }
        let bodyObj: [String: Any] = ["hot": true, "spuId": product.spu]
        let body = String(data: (try? JSONSerialization.data(withJSONObject: bodyObj)) ?? Data(), encoding: .utf8) ?? ""
        do {
            let json = try await requestJSON(
                method: "POST",
                url: CatalogClient.purchaseInfoURL.absoluteString,
                body: body,
                session: nil
            )
            return CatalogClient.parse(json, sku: product.sku)
        } catch {
            return PurchaseInfo(ok: false, message: error.localizedDescription)
        }
    }

    func fetchAddress() async -> (message: String, address: [String: Any]?) {
        if pageError() != nil {
            return (pageError() ?? "H5 未就绪", nil)
        }
        let ts = String(Int64(Date().timeIntervalSince1970 * 1000))
        let url = CatalogClient.addressURL.absoluteString + "?__timestamp=" + ts
        do {
            let json = try await requestJSON(method: "GET", url: url, body: nil, session: nil)
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

    private func requestJSON(method: String, url: String, body: String?, session: Session?) async throws -> [String: Any] {
        var payload: [String: Any] = ["method": method, "url": url, "timeoutMs": 12000]
        if let body, !body.isEmpty {
            payload["body"] = body
        }
        if let session {
            payload["headers"] = H5Fire.pageHeaders(deviceId: session.deviceId)
        }
        let result = try await webView.callAsyncJavaScript(
            "return await window.__mt741request(payload);",
            arguments: ["payload": payload],
            in: nil,
            in: .page
        )
        let row = (result as? [String: Any]) ?? [:]
        let text = JSONText.string(row["body"])
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw NSError(domain: "H5", code: JSONText.int(row["status"]) ?? 0, userInfo: [
                NSLocalizedDescriptionKey: JSONText.string(row["error"]).isEmpty ? String(text.prefix(120)) : JSONText.string(row["error"]),
            ])
        }
        return json
    }

    private func waitUntilReady(seconds: Double) async -> String? {
        keepInWindow()
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if isLive, await fireFunctionReady() {
                ready = true
                return nil
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        if isLive, await fireFunctionReady() {
            ready = true
            return nil
        }
        return pageError() ?? "H5 页未就绪（先登录，等商品页 wasm 起来）"
    }

    private func fireFunctionReady() async -> Bool {
        await withCheckedContinuation { cont in
            webView.evaluateJavaScript("typeof window.__mt741fire === 'function'") { result, _ in
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
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 8))
        view.isUserInteractionEnabled = false
        view.alpha = 0.02
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
        host.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
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
            guard message.name == CWBHook.handlerName else { return }
            let body = message.body
            DispatchQueue.main.async {
                self.owner?.cwbStore?.ingest(body)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.owner?.pageURL = webView.url?.absoluteString ?? ""
                self.owner?.ready = self.owner?.isLive ?? false
                self.owner?.keepInWindow()
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
