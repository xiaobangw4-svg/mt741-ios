import UIKit
import WebKit
import XCTest
@testable import MT741

@MainActor
final class H5SimulatorTests: XCTestCase {
    private static var windowAssoc: UInt8 = 0

    func testCurrentScriptShimDuringUserScript() async throws {
        let probeSDK = """
        window.__sdkProbe = (function(){
          var p = document.currentScript && document.currentScript.src;
          var h = '';
          try { h = new URL('.', p).href; } catch (e) { h = 'ERR'; }
          return {
            p: String(p || ''),
            h: h,
            dummy: !!document.querySelector('script[data-mt741-sdk]'),
            shim: !!window.__mt741currentScript,
            boot: window.__mt741csAtBoot || {}
          };
        })();
        """
        let boot = StyleTotalSDK.bootstrap(patchedSDK: probeSDK, hits: 1)
        let content = WKUserContentController()
        content.addUserScript(WKUserScript(
            source: boot,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true,
            in: .page
        ))
        let config = WKWebViewConfiguration()
        config.userContentController = content
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = makeVisibleWebView(config: config)
        webView.loadHTMLString(
            "<html><head></head><body>shim</body></html>",
            baseURL: URL(string: "https://h5.moutai519.com.cn/")
        )
        try await waitUntil(webView, seconds: 8) { wv in
            (try? await wv.evaluateJavaScript("window.__sdkProbe && window.__sdkProbe.p")) as? String
        }
        let raw = try await webView.evaluateJavaScript("JSON.stringify(window.__sdkProbe || {})")
        let text = (raw as? String) ?? String(describing: raw)
        print("H5SIM shim dump \(text)")
        XCTAssertTrue(text.contains("bs_h5"), "currentScript shim 应指向官方 bs_h5，实际：\(text)")
        XCTAssertTrue(text.contains("\"shim\":true") || text.contains("\"dummy\":true"), "dummy/shim 应生效：\(text)")
    }

    func testStyleTotalProbeMinWidthIsRaisedInWK() async throws {
        let content = WKUserContentController()
        content.addUserScript(WKUserScript(
            source: StyleTotalPatch.javaScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true,
            in: .page
        ))
        let config = WKWebViewConfiguration()
        config.userContentController = content
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = makeVisibleWebView(config: config)
        let page = """
        <html><head></head><body>
        <script>
        (function(){
          var u = document.createElement('div');
          u.style.cssText = 'display:flex;width:10px;height:10px;padding:1px;margin:1px;max-width:20px;min-width:5px;';
          document.body.appendChild(u);
          var st = getComputedStyle(u);
          window.__probeMin = u.style.minWidth;
          window.__probeW = parseInt(st.width, 10);
          window.__probeFrom = window.__mt741styleFrom || 0;
        })();
        </script>
        </body></html>
        """
        webView.loadHTMLString(page, baseURL: URL(string: "https://h5.moutai519.com.cn/"))
        try await waitUntil(webView, seconds: 8) { wv in
            (try? await wv.evaluateJavaScript("window.__probeMin")) as? String
        }
        let raw = try await webView.evaluateJavaScript(
            "JSON.stringify({min:window.__probeMin,w:window.__probeW,from:window.__probeFrom})"
        )
        let text = (raw as? String) ?? String(describing: raw)
        print("H5SIM probe dump \(text)")
        XCTAssertTrue(text.contains("220px"), "StyleTotal 探针 min-width 应抬到 220px，实际：\(text)")
    }

    func testJSONStringifyLiftsCwbArrayInWK() async throws {
        let content = WKUserContentController()
        content.addUserScript(WKUserScript(
            source: StyleTotalPatch.javaScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true,
            in: .page
        ))
        let config = WKWebViewConfiguration()
        config.userContentController = content
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = makeVisibleWebView(config: config)
        let page = """
        <html><head></head><body>
        <script>
        (function(){
          var arr = ['10001','did','sid','','0','0','0a140a64006401ff0000000000000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',1,{},'1','v','',6550];
          window.__jsonOut = JSON.stringify(arr);
          window.__jsonFrom = window.__mt741styleFrom || 0;
        })();
        </script>
        </body></html>
        """
        webView.loadHTMLString(page, baseURL: URL(string: "https://h5.moutai519.com.cn/"))
        try await waitUntil(webView, seconds: 8) { wv in
            (try? await wv.evaluateJavaScript("window.__jsonOut")) as? String
        }
        let raw = try await webView.evaluateJavaScript(
            "JSON.stringify({out:window.__jsonOut,from:window.__jsonFrom})"
        )
        let text = (raw as? String) ?? String(describing: raw)
        print("H5SIM json dump \(text)")
        XCTAssertTrue(text.contains("19130"), "processDataForSign 前 JSON.stringify 应抬 142，实际：\(text)")
    }

    func testObjectKeysLiftsCwbField142InWK() async throws {
        let content = WKUserContentController()
        content.addUserScript(WKUserScript(
            source: StyleTotalPatch.javaScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true,
            in: .page
        ))
        let config = WKWebViewConfiguration()
        config.userContentController = content
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = makeVisibleWebView(config: config)
        let page = """
        <html><head></head><body>
        <script>
        (function(){
          var h = {101:'10001',103:'did',104:'sid',105:'',106:'0',108:'0',109:'0a140a64006401ff',110:'aa',111:1,120:{},130:'1',140:'v',141:'',142:6550};
          Object.keys(h);
          window.__keysOut = h[142];
          window.__keysFrom = window.__mt741styleFrom || 0;
        })();
        </script>
        </body></html>
        """
        webView.loadHTMLString(page, baseURL: URL(string: "https://h5.moutai519.com.cn/"))
        try await waitUntil(webView, seconds: 8) { wv in
            let v = try? await wv.evaluateJavaScript("window.__keysOut")
            if let n = v as? Int, n > 0 { return String(n) }
            if let n = v as? Double, n > 0 { return String(Int(n)) }
            if let n = v as? NSNumber, n.intValue > 0 { return n.stringValue }
            return nil
        }
        let raw = try await webView.evaluateJavaScript(
            "JSON.stringify({out:window.__keysOut,from:window.__keysFrom})"
        )
        let text = (raw as? String) ?? String(describing: raw)
        print("H5SIM keys dump \(text)")
        XCTAssertTrue(text.contains("19130"), "objectToArray 前 Object.keys 应抬 142，实际：\(text)")
    }

    func testEsModuleStyleTotalIsLiftedInWK() async throws {
        let content = WKUserContentController()
        content.addUserScript(WKUserScript(
            source: StyleTotalPatch.javaScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true,
            in: .page
        ))
        let config = WKWebViewConfiguration()
        config.userContentController = content
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = makeVisibleWebView(config: config)
        let page = """
        <html><head></head><body>
        <script>
        (function(){
          var e = {};
          Object.defineProperty(e, '__esModule', { value: true });
          e.StyleTotal = function(t){ return 6550; };
          window.__liftOut = e.StyleTotal('0a140a64006401ff');
          window.__liftWrapped = window.__mt741styleWrapped || 0;
          window.__liftEs = window.__mt741esMod || 0;
        })();
        </script>
        </body></html>
        """
        webView.loadHTMLString(page, baseURL: URL(string: "https://h5.moutai519.com.cn/"))
        try await waitUntil(webView, seconds: 8) { wv in
            let v = try? await wv.evaluateJavaScript("window.__liftOut")
            if let n = v as? Int, n > 0 { return String(n) }
            if let n = v as? Double, n > 0 { return String(Int(n)) }
            if let n = v as? NSNumber, n.intValue > 0 { return n.stringValue }
            return nil
        }
        let raw = try await webView.evaluateJavaScript(
            "JSON.stringify({out:window.__liftOut,wrapped:window.__liftWrapped,es:window.__liftEs})"
        )
        let text = (raw as? String) ?? String(describing: raw)
        print("H5SIM lift dump \(text)")
        XCTAssertTrue(text.contains("19130"), "webpack e.StyleTotal 应抬成五位，实际：\(text)")
    }

    func testBorderBoxLoopMatchesClosedFormInWK() async throws {
        let samples: [(String, UInt32)] = [
            ("34ac841c47f69959", 21376),
            ("4ed236dc495a528c", 39778),
            ("0a140a64006401ff", 19780),
            ("640a1400006401ff", 42970),
            ("c8321000002001aa", 63926),
            ("0d31a45dd42443f6", 26496),
            ("2913985b195cf0d4411d7f73e0b338c6", 23040),
        ]
        let list = samples.map { "\"\($0.0)\"" }.joined(separator: ",")
        let page = """
        <html><head></head><body>
        <script>
        function mt741Closed(token) {
          var t = String(token || '');
          function pair(i) {
            var n = parseInt(t.substr(i, 2), 16);
            return n === n ? n : 0;
          }
          var e = pair(0), n = pair(2), r = pair(4), o = pair(8), a = pair(10), s = pair(12);
          var u = document.createElement('div');
          document.body.appendChild(u);
          \(StyleTotalPatch.loopTo)
        }
        var tokens = [\(list)];
        var out = {};
        for (var i = 0; i < tokens.length; i++) out[tokens[i]] = mt741Closed(tokens[i]);
        window.__bb = out;
        </script>
        </body></html>
        """
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = makeVisibleWebView(config: config)
        webView.loadHTMLString(page, baseURL: URL(string: "https://h5.moutai519.com.cn/"))
        try await waitUntil(webView, seconds: 8) { wv in
            (try? await wv.evaluateJavaScript("window.__bb && JSON.stringify(window.__bb)")) as? String
        }
        let raw = try await webView.evaluateJavaScript("JSON.stringify(window.__bb || {})")
        let text = (raw as? String) ?? String(describing: raw)
        print("H5SIM border-box dump \(text)")
        let data = Data(text.utf8)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        for (token, signed) in samples {
            let value = obj?[token]
            let got: UInt32
            if let n = value as? Int {
                got = UInt32(n)
            } else if let n = value as? Double {
                got = UInt32(n)
            } else if let n = value as? NSNumber {
                got = n.uint32Value
            } else {
                XCTFail("\(token) missing from \(text)")
                continue
            }
            XCTAssertEqual(got, signed, token)
            XCTAssertEqual(got, StyleTotalPatch.hashForSign(token), token)
        }
    }

    func testOfficialH5PageProducesCWBOnSimulator() async throws {
        let store = CWBStore()
        let runtime = H5Runtime()
        let webView = runtime.webView
        attachToWindow(webView)
        runtime.keepInWindow()
        runtime.bindIfNeeded(
            session: Session(deviceId: SessionStore.newDeviceId()),
            cwbStore: store,
            product: .sku741,
            forceLoad: true
        )
        var dump = ""
        var reached = false
        for i in 0..<50 {
            try await Task.sleep(nanoseconds: 400_000_000)
            dump = await liveDump(runtime, store: store)
            print("H5LIVE[\(i)] \(dump)")
            if webView.url?.host?.contains("moutai519") == true {
                reached = true
            }
            if store.cwb.count >= 700 { break }
            if dump.contains("wasm=1"), store.cwb.count > 0 { break }
        }
        if store.cwb.count >= 700 {
            return
        }
        if dump.contains("\"wasm\":true"), store.cwb.isEmpty {
            XCTFail("wasm 已起但 CWB 仍空。dump=\(dump)")
            return
        }
        throw XCTSkip("模拟器未产出 CWB（海外 IP/WAF 常见）。dump=\(dump)")
    }

    private func makeVisibleWebView(config: WKWebViewConfiguration) -> WKWebView {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        attachToWindow(webView)
        return webView
    }

    private func attachToWindow(_ webView: WKWebView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let host = UIViewController()
        window.rootViewController = host
        window.makeKeyAndVisible()
        webView.frame = host.view.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.view.addSubview(webView)
        objc_setAssociatedObject(webView, &H5SimulatorTests.windowAssoc, window, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func waitUntil(
        _ webView: WKWebView,
        seconds: Double,
        probe: (WKWebView) async -> String?
    ) async throws {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if let value = await probe(webView), !value.isEmpty {
                return
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    private func liveDump(_ runtime: H5Runtime, store: CWBStore) async -> String {
        let script = """
        (function(){
          var boot = window.__mt741csAtBoot || {};
          var scripts = [];
          var n = 0;
          var htmlLen = 0;
          try { htmlLen = (document.documentElement && document.documentElement.innerHTML || '').length; } catch (e) {}
          try {
            var list = document.getElementsByTagName('script');
            n = list.length;
            for (var i=0;i<list.length && i<8;i++) scripts.push(list[i].src||'inline');
          } catch (e) {}
          return JSON.stringify({
            href: String(location.href||''),
            n: n,
            htmlLen: htmlLen,
            rewritten: !!window.__mt741sdkRewritten,
            shim: !!window.__mt741currentScript,
            wasm: !!(window.__SIGN_WASM_OK__ || window.__wasm_sign_ok__),
            wasmVer: String(window.__SIGN_WASM_VERSION__||''),
            csSrc: boot.src||'',
            csDummy: !!boot.dummy,
            hasDummy: !!boot.hasDummy,
            dummyNow: !!document.querySelector('script[data-mt741-sdk]'),
            wasmErr: String(window.__mt741wasmErr||''),
            scripts: scripts,
            style: String(window.__mt741styleFrom||0)
          });
        })()
        """
        let raw = (try? await runtime.webView.evaluateJavaScript(script)) as? String ?? ""
        return "cwb=\(store.cwb.count) style=\(runtime.styleStatus) live=\(runtime.isLive) url=\(runtime.pageURL) js=\(raw)"
    }
}
