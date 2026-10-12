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
