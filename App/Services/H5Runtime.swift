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
    @Published var styleStatus = "Style未挂"
    @Published var fk1Beats = 0
    @Published var lastRush = "rush无"
    @Published var lastFk1 = "fk1无"
    @Published var lastH5Did = ""
    private var fk1WaitedAt: Date?

    private var fingerprint = ""
    private var pendingJS: [String: CheckedContinuation<Any?, Error>] = [:]
    private let proxy = BridgeProxy()
    fileprivate static let jsHandlerName = "mt741js"
    private var didClearSdkBlock = false
    private var sdkInstallTask: Task<Void, Never>?
    private var bridgeSession: Session?

    override init() {
        let content = WKUserContentController()
        H5Runtime.addPageScripts(to: content, session: nil)
        content.add(proxy, name: CWBHook.handlerName)
        content.add(proxy, name: CWBHook.fk1HandlerName)
        content.add(proxy, name: CWBHook.netHandlerName)
        content.add(proxy, name: H5Runtime.jsHandlerName)
        content.add(proxy, name: JSBridge.wvjbHandlerName)
        content.add(proxy, name: JSBridge.jxbHandlerName)
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
        sdkInstallTask = Task { [weak self] in
            await self?.clearSdkBlockOnce()
        }
    }

    private func installStyleSDK() async {
        if let sdkInstallTask {
            await sdkInstallTask.value
        }
        if !didClearSdkBlock {
            await clearSdkBlockOnce()
        }
    }

    /// Hosting Bangcle in a UserScript / inline script leaves CWB empty on device.
    /// Official parser-inserted `bs_h5.min.js` is what actually starts wasm.
    /// Drop leftover `mt741-block-bs-h5` rules from earlier IPAs.
    private func clearSdkBlockOnce() async {
        if didClearSdkBlock { return }
        await StyleTotalSDK.removeContentRules(from: webView.configuration.userContentController)
        didClearSdkBlock = true
    }

    var isLive: Bool {
        guard let host = webView.url?.host else { return false }
        return host.contains("moutai519.com.cn")
    }

    func keepInWindow() {
        HiddenWebHost.attachIfIdle(webView)
    }

    func park() {
        HiddenWebHost.attachIfIdle(webView)
    }

    func resetSite() {
        fingerprint = ""
        ready = false
        pageURL = ""
        lastProbe = ""
        styleStatus = "Style未挂"
        lastRush = "rush无"
        lastFk1 = "fk1无"
        lastH5Did = ""
        bridgeSession = nil
        webView.evaluateJavaScript("try { window.__FORCE_DID__ = ''; } catch (e) {}")
        installPageScripts(session: nil)
        keepInWindow()
        if let url = URL(string: "about:blank") {
            webView.load(URLRequest(url: url))
        }
    }

    func bindIfNeeded(session: Session, cwbStore: CWBStore, product: Product = .sku741, forceLoad: Bool = false) {
        self.cwbStore = cwbStore
        self.bridgeSession = session
        keepInWindow()
        webView.customUserAgent = CookieBridge.userAgent(from: session)
        let shouldLoad = forceLoad || session.isLoggedIn
        guard shouldLoad else { return }
        let next = session.cookie + "|" + session.token + "|" + session.authDeviceId + "|" + session.userId + "|" + session.bsDvid + "|" + product.sku
        if fingerprint == next, webView.url != nil, !forceLoad { return }
        fingerprint = next
        fk1Beats = 0
        fk1WaitedAt = nil
        lastRush = "rush无"
        lastFk1 = "fk1无"
        installPageScripts(session: session)
        webView.customUserAgent = CookieBridge.userAgent(from: session)
        Task { [weak self] in
            guard let self else { return }
            if !self.didClearSdkBlock {
                await self.installStyleSDK()
            }
            CookieBridge.apply(session) { [weak self] in
                self?.keepInWindow()
                self?.webView.load(URLRequest(url: product.h5URL))
            }
        }
    }

    func fire(request: BurstRequest, session: Session) async -> BurstStats {
        var session = session
        if session.bsDvid.isEmpty {
            let token = CookieBridge.ingestPasteboard()
            if !token.isEmpty {
                session.bsDvid = token
            }
        }
        webView.customUserAgent = CookieBridge.userAgent(from: session)
        keepInWindow()
        let already = await fireFunctionReady()
        if !already, let err = await waitUntilReady(seconds: 8, product: request.product, session: session) {
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
        let signed = await waitForSign(seconds: 12)
        _ = await waitForCWB(seconds: signed ? 2 : 1)
        session = await syncH5Did(session)
        await CookieBridge.applyAsync(session)
        let bsDeviceId = await pageBsDeviceCookie()
        await CookieBridge.pinBsDeviceCookieAsync(bsDeviceId)
        let product = request.product
        let deviceId = session.authDeviceId
        let plain = RushPlain(
            amount: product.clampAmount(request.amount),
            itemCode: product.sku,
            itemPriorityActId: request.actId,
            deviceId: deviceId,
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
            "deviceId": deviceId,
            "wapToken": session.wapToken,
            "userId": session.userId,
            "bsDeviceId": bsDeviceId,
            "headers": H5Fire.pageHeaders(deviceId: deviceId, product: product),
            "kv": H5Fire.kvPairs(count: n, deviceId: deviceId),
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
        _ = await waitUntilLive(seconds: 8)
        if let captured = await capturedPurchaseJSON() {
            let info = CatalogClient.parse(captured, sku: product.sku)
            if info.ok {
                lastProbe = info.message
                return info
            }
        }
        _ = await waitForCWB(seconds: 8)
        if let err = pageError() {
            return PurchaseInfo(ok: false, message: err)
        }
        if let captured = await capturedPurchaseJSON() {
            let info = CatalogClient.parse(captured, sku: product.sku)
            if info.ok {
                lastProbe = info.message
                return info
            }
        }
        let bodyObj: [String: Any] = ["hot": true, "spuId": product.spu]
        let body = String(data: (try? JSONSerialization.data(withJSONObject: bodyObj)) ?? Data(), encoding: .utf8) ?? ""
        do {
            let json = try await requestJSON(
                method: "POST",
                url: CatalogClient.purchaseInfoURL.absoluteString,
                body: body,
                session: session,
                timeoutMs: 8000,
                product: product
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

    func verifyCode(validate: String, priorityRecordId: String, session: Session, product: Product) async -> String {
        let trimmed = validate.trimmingCharacters(in: .whitespacesAndNewlines)
        let rid = priorityRecordId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "validate 为空，先完成点选" }
        if rid.isEmpty { return "没有 priorityRecordId，点选结果会写入 ydToken，下次异步带上重发" }
        let bodyObj: [String: Any] = [
            "captchaId": product.captchaId,
            "validate": trimmed,
            "priorityUserRecordId": rid,
        ]
        let body = String(data: (try? JSONSerialization.data(withJSONObject: bodyObj)) ?? Data(), encoding: .utf8) ?? ""
        do {
            let json = try await requestJSON(
                method: "POST",
                url: YidunClient.verifyURL.absoluteString,
                body: body,
                session: session,
                timeoutMs: 12000,
                product: product
            )
            let code = AuthClient.jsonCode(json)
            if code == 2000 {
                return "易盾已提交 code=2000"
            }
            return (json["message"] as? String) ?? "verify code=\(code.map(String.init) ?? "nil")"
        } catch {
            return error.localizedDescription
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
        if isLive, await requestFunctionReady() {
            ready = true
            return nil
        }
        let deadline = Date().addingTimeInterval(seconds)
        var last = "H5 页未就绪"
        while Date() < deadline {
            if Task.isCancelled { return last }
            reinstallHooks()
            if isLive, await requestFunctionReady() {
                ready = true
                return nil
            }
            last = pageError() ?? "H5 页未就绪（先登录，等商品页起来）"
            try? await Task.sleep(nanoseconds: 200_000_000)
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
        if await fireFunctionReady() {
            return nil
        }
        let deadline = Date().addingTimeInterval(min(3, max(0, seconds)))
        while Date() < deadline {
            if Task.isCancelled { return nil }
            if await fireFunctionReady() {
                return nil
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return nil
    }

    func waitForSign(seconds: Double) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if Task.isCancelled { return await signReady() }
            if await signReady() { return true }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return await signReady()
    }

    private func signReady() async -> Bool {
        await withCheckedContinuation { cont in
            webView.evaluateJavaScript("window.__mt741signReady ? window.__mt741signReady() : false") { val, _ in
                let ok = (val as? Bool) ?? ((val as? NSNumber)?.boolValue ?? false)
                cont.resume(returning: ok)
            }
        }
    }

    func waitForCWB(seconds: Double) async -> Bool {
        if (cwbStore?.cwb.count ?? 0) > 0 { return true }
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if Task.isCancelled { return (cwbStore?.cwb.count ?? 0) > 0 }
            if (cwbStore?.cwb.count ?? 0) > 0 { return true }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return (cwbStore?.cwb.count ?? 0) > 0
    }

    func noteFk1() {
        fk1Beats += 1
        lastFk1 = "fk1×\(fk1Beats)"
    }

    func noteNet(_ body: Any) {
        let dict: [String: Any]
        if let row = body as? [String: Any] {
            dict = row
        } else if let s = body as? String, let data = s.data(using: .utf8),
                  let row = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            dict = row
        } else {
            return
        }
        let kind = JSONText.string(dict["kind"])
        let status = JSONText.int(dict["status"]) ?? 0
        let snippet = JSONText.string(dict["body"])
        if kind == "rush" {
            let code = snippet.contains("\"code\":") ? snippet : ""
            lastRush = "rush \(status)" + (code.isEmpty ? "" : " \(String(code.prefix(48)))")
        } else if kind == "fk1" {
            lastFk1 = "fk1×\(max(fk1Beats, 1)) HTTP\(status)"
        }
    }

    func waitForFk1(seconds: Double) async -> Bool {
        if fk1Beats > 0 { return true }
        if let waited = fk1WaitedAt, Date().timeIntervalSince(waited) < 15 {
            return fk1Beats > 0
        }
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if Task.isCancelled { return fk1Beats > 0 }
            if fk1Beats > 0 { return true }
            let n = await pageFk1Count()
            if n > 0 {
                fk1Beats = max(fk1Beats, n)
                return true
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        fk1WaitedAt = Date()
        return fk1Beats > 0
    }

    private func pageFk1Count() async -> Int {
        await withCheckedContinuation { cont in
            webView.evaluateJavaScript("window.__mt741fk1||0") { val, _ in
                if let n = val as? Int {
                    cont.resume(returning: n)
                } else if let n = val as? Double {
                    cont.resume(returning: Int(n))
                } else {
                    cont.resume(returning: 0)
                }
            }
        }
    }

    func refreshStyleStatus() async {
        keepInWindow()
        for _ in 0..<12 {
            _ = await captureH5Did()
            let raw = await styleProbeJSON()
            styleStatus = StyleTotalPatch.statusLabel(fromJSON: raw)
            if (cwbStore?.cwb.count ?? 0) > 0 { return }
            if raw.contains("\"wasm\":true") { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
    }

    @discardableResult
    func captureH5Did() async -> String {
        var did = CookieBridge.sanitizeH5Did(await pageH5Did())
        if did.isEmpty {
            did = BangcleBlob.did(from: await cookieValue("_d_u"))
        }
        if did.isEmpty {
            did = BangcleBlob.did(from: cwbStore?.cwb ?? "")
        }
        guard !did.isEmpty else { return lastH5Did }
        if lastH5Did != did {
            lastH5Did = did
        }
        if var session = bridgeSession {
            if session.h5Did != did {
                session.h5Did = did
                bridgeSession = session
            }
            webView.customUserAgent = CookieBridge.userAgent(from: session)
        } else {
            webView.customUserAgent = CookieBridge.userAgent(h5Did: did)
        }
        return did
    }

    func pageBsDeviceCookie() async -> String {
        let existing = CookieBridge.sanitizeBsDeviceCookie(await cookieValue("_bs_device_id"))
        if !existing.isEmpty { return existing }
        return CookieBridge.sanitizeBsDeviceCookie(BangcleBlob.hp(from: await cookieValue("_d_u")))
    }

    private func syncH5Did(_ session: Session) async -> Session {
        var session = session
        let did = await captureH5Did()
        if !did.isEmpty {
            session.h5Did = did
        }
        webView.customUserAgent = CookieBridge.userAgent(from: session)
        return session
    }

    private func pageH5Did() async -> String {
        await withCheckedContinuation { cont in
            webView.evaluateJavaScript("window.__mt741h5Did ? window.__mt741h5Did() : ''") { val, _ in
                cont.resume(returning: (val as? String) ?? "")
            }
        }
    }

    private func styleProbeJSON() async -> String {
        let script = """
        (function(){
          var st = {};
          try { st = window.__mt741hookStyle ? window.__mt741hookStyle() : {}; } catch (e) { st.err = String(e); }
          try { window.__mt741hookCWB && window.__mt741hookCWB(); } catch (e) {}
          st.wrapped = window.__mt741styleWrapped || 0;
          st.from = window.__mt741styleFrom || 0;
          st.bump = window.__mt741styleBump || 0;
          st.patched = !!window.__mt741stylePatched;
          st.gcs = !!window.__mt741gcs;
          st.rewritten = !!window.__mt741sdkRewritten;
          st.cs = !!window.__mt741currentScript;
          st.wasm = !!(window.__SIGN_WASM_OK__ || window.__wasm_sign_ok__ || window.__SIGN_WASM_VERSION__);
          return JSON.stringify(st);
        })()
        """
        let raw = try? await webView.evaluateJavaScript(script)
        return (raw as? String) ?? ""
    }

    func capturedPurchaseJSON() async -> [String: Any]? {
        let raw = try? await webView.evaluateJavaScript("window.__mt741purchaseInfo || ''")
        guard let text = raw as? String, !text.isEmpty,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    private func requestJSON(method: String, url: String, body: String?, session: Session?, timeoutMs: Int, product: Product = .sku741) async throws -> [String: Any] {
        var payload: [String: Any] = ["method": method, "url": url, "timeoutMs": timeoutMs]
        if let body, !body.isEmpty {
            payload["body"] = body
        }
        if let session {
            let session = await syncH5Did(session)
            await CookieBridge.applyAsync(session)
            let bsDeviceId = await pageBsDeviceCookie()
            await CookieBridge.pinBsDeviceCookieAsync(bsDeviceId)
            payload["headers"] = H5Fire.pageHeaders(deviceId: session.authDeviceId, product: product)
            payload["deviceId"] = session.authDeviceId
            payload["wapToken"] = session.wapToken
            payload["userId"] = session.userId
            payload["bsDeviceId"] = bsDeviceId
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
            let status = JSONText.int(row["status"]) ?? 0
            var hint = err
            if hint.isEmpty {
                if text.contains("429") {
                    hint = "H5 HTTP \(status) ESA 拦了（CWB 还没签上）"
                } else if text.isEmpty {
                    hint = "H5 请求无返回（页内 JS 未跑起来）"
                } else {
                    hint = String(text.prefix(120))
                }
            }
            throw NSError(domain: "H5", code: status, userInfo: [
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

    private func installPageScripts(session: Session?) {
        let content = webView.configuration.userContentController
        content.removeAllUserScripts()
        H5Runtime.addPageScripts(to: content, session: session)
    }

    static func addPageScripts(to content: WKUserContentController, session: Session?) {
        for source in H5PageStart.scripts {
            content.addUserScript(WKUserScript(
                source: source,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false,
                in: .page
            ))
        }
        if let session, !session.userId.isEmpty {
            content.addUserScript(WKUserScript(
                source: JSBridge.identityJavaScript(session: session),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false,
                in: .page
            ))
        }
    }

    fileprivate func handleBridge(_ message: WKScriptMessage) {
        guard let decision = JSBridge.decide(name: message.name, body: message.body, session: bridgeSession) else {
            return
        }
        let js = JSBridge.callbackJavaScript(decision)
        if !js.isEmpty {
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        if !decision.pinUserId.isEmpty {
            webView.evaluateJavaScript(JSBridge.pinJavaScript(userId: decision.pinUserId), completionHandler: nil)
        }
    }

    fileprivate func pushBridgeIdentity() {
        guard let session = bridgeSession, !session.userId.isEmpty else { return }
        webView.evaluateJavaScript(JSBridge.pushUserIdJavaScript(userId: session.userId), completionHandler: nil)
    }
}

enum H5PageStart {
    static let scripts = [
        StyleTotalPatch.javaScript,
        CWBHook.javaScript,
        H5Fire.javaScript,
        JSBridge.javaScript,
    ]
}

/// Fallback host used by unit tests and the brief window before SwiftUI parents
/// the WK. ContentView's on-screen stage is the real layout surface.
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
            if JSBridge.isHandler(message.name) {
                DispatchQueue.main.async {
                    self.owner?.handleBridge(message)
                }
                return
            }
            if message.name == CWBHook.fk1HandlerName {
                DispatchQueue.main.async {
                    self.owner?.noteFk1()
                }
                return
            }
            if message.name == CWBHook.netHandlerName {
                DispatchQueue.main.async {
                    self.owner?.noteNet(body)
                }
                return
            }
            guard message.name == CWBHook.handlerName else { return }
            DispatchQueue.main.async {
                self.owner?.cwbStore?.ingest(body)
                Task { _ = await self.owner?.captureH5Did() }
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.owner?.pushBridgeIdentity()
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.owner?.pageURL = webView.url?.absoluteString ?? ""
                self.owner?.ready = self.owner?.isLive ?? false
                self.owner?.keepInWindow()
                self.owner?.pushBridgeIdentity()
                Task {
                    _ = await self.owner?.captureH5Did()
                    await self.owner?.refreshStyleStatus()
                }
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
