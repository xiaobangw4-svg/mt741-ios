import Foundation
import WebKit

/// Chrome sign pool rewrites `bs_h5.min.js` on the wire. WK ignores JS `src` setters for
/// parser-inserted scripts, so do the same rewrite natively: fetch, patch StyleTotal, block
/// the original script, run the patched copy as a document-start UserScript.
///
/// Bangcle resolves `stub.117.wasm` / `sign.wasm` from `document.currentScript.src`.
/// UserScript and inline `s.text` both leave that empty, so pin the CDN base in the
/// patched body. CSP also blocks classic inline scripts on H5; do not host Bangcle
/// via `script.text`.
enum StyleTotalSDK {
    static let remoteURL = URL(string: "https://resource.moutai519.com.cn/mt-resource/static-union/bs_h5.min.js")!
    static let wasmCDN = "https://resource.moutai519.com.cn/mt-resource/static-union/"
    static let ruleIdentifier = "mt741-block-bs-h5"

    static let wasmBaseFrom = #"s="";try{var u,c="undefined"!=typeof document?null===(u=document.currentScript)||void 0===u?void 0:u.src:undefined;c&&(s=new URL(".",c).href)}catch(d){}"#
    static let wasmBaseTo = #"s="\#(wasmCDN)";"#
    static let wasmScriptFrom = #"p="undefined"!=typeof document?null===(h=document.currentScript)||void 0===h?void 0:h.src:undefined"#
    static let wasmScriptTo = #"p=("undefined"!=typeof document?null===(h=document.currentScript)||void 0===h?void 0:h.src:undefined)||"\#(remoteURL.absoluteString)""#

    static func patch(_ src: String) -> (text: String, hits: Int) {
        let loopHits = src.components(separatedBy: StyleTotalPatch.loopFrom).count - 1
        let baseHits = src.components(separatedBy: wasmBaseFrom).count - 1
        let scriptHits = src.components(separatedBy: wasmScriptFrom).count - 1
        guard loopHits > 0, baseHits > 0, scriptHits > 0 else { return (src, 0) }
        var text = src.replacingOccurrences(of: StyleTotalPatch.loopFrom, with: StyleTotalPatch.loopTo)
        text = text.replacingOccurrences(of: wasmBaseFrom, with: wasmBaseTo)
        text = text.replacingOccurrences(of: wasmScriptFrom, with: wasmScriptTo)
        return (text, loopHits)
    }

    static var contentRuleJSON: String {
        let rules: [[String: Any]] = [[
            "trigger": [
                "url-filter": #".*bs_h5.*\.js"#,
                "resource-type": ["script"],
            ],
            "action": ["type": "block"],
        ]]
        guard let data = try? JSONSerialization.data(withJSONObject: rules),
              let text = String(data: data, encoding: .utf8)
        else {
            return #"[{"trigger":{"url-filter":".*bs_h5.*\.js","resource-type":["script"]},"action":{"type":"block"}}]"#
        }
        return text
    }

    static func jsonString(_ raw: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: [raw])) ?? Data("['']".utf8)
        let text = String(data: data, encoding: .utf8) ?? "\"\""
        return String(text.dropFirst().dropLast())
    }

    /// Run the patched SDK inside the UserScript (CSP allows this; classic `s.text`
    /// on H5 does not). Dummy + currentScript shim stay for Bangcle's script walk.
    static func bootstrap(patchedSDK: String, hits: Int) -> String {
        let url = remoteURL.absoluteString
        let prelude = """
        (function(){
          window.__mt741sdkRewritten=true;
          window.__mt741styleFrom=\(hits);
          window.__mt741stylePatched=true;
          var cdn='\(wasmCDN)';
          try {
            if (!window.__mt741wasmFetch && typeof window.fetch === 'function') {
              window.__mt741wasmFetch = true;
              var origFetch = window.fetch;
              window.fetch = function(input, init) {
                var url = (typeof input === 'string') ? input : ((input && input.url) || '');
                if (/^(stub\\.[0-9]+\\.wasm|sign\\.wasm)$/i.test(String(url))) {
                  var abs = cdn + url;
                  if (typeof input === 'string') input = abs;
                  else try { input = new Request(abs, input); } catch (e) { input = abs; }
                }
                return origFetch.call(this, input, init);
              };
            }
          } catch (e) {}
          var src='\(url)';
          var dummy=document.createElement('script');
          dummy.__mt741sdk=true;
          dummy.type='text/plain';
          dummy.async=false;
          dummy.setAttribute('data-mt741-sdk','1');
          dummy.src=src;
          try { (document.documentElement||document).appendChild(dummy); } catch(e) {}
          function shim(obj){
            try {
              Object.defineProperty(obj,'currentScript',{
                configurable:true,
                enumerable:true,
                get:function(){ return dummy; }
              });
              return true;
            } catch(e) { return false; }
          }
          window.__mt741currentScript=shim(document);
          if(!window.__mt741currentScript){
            try {
              var proto=Document.prototype;
              var desc=Object.getOwnPropertyDescriptor(proto,'currentScript')
                || Object.getOwnPropertyDescriptor(HTMLDocument.prototype,'currentScript');
              if(desc && desc.configurable){
                Object.defineProperty(proto,'currentScript',{
                  configurable:true,
                  enumerable:!!desc.enumerable,
                  get:function(){
                    try { var n=desc.get?desc.get.call(this):null; if(n) return n; } catch(e) {}
                    return dummy;
                  }
                });
                window.__mt741currentScript=true;
              }
            } catch(e) {}
          }
          try {
            var cs=document.currentScript;
            window.__mt741csAtBoot={
              src:(cs&&cs.src)||'',
              dummy:!!(cs&&cs.getAttribute&&cs.getAttribute('data-mt741-sdk')),
              shim:!!window.__mt741currentScript,
              hasDummy:!!document.querySelector('script[data-mt741-sdk]')
            };
          } catch(e) { window.__mt741csAtBoot={err:String(e)}; }
        })();
        """
        return prelude + "\n" + patchedSDK
    }

    private static var cachedPatched: String?

    static func fetchPatched() async -> String? {
        if let cachedPatched { return cachedPatched }
        var req = URLRequest(url: remoteURL)
        req.timeoutInterval = 15
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue(CookieBridge.h5UA, forHTTPHeaderField: "User-Agent")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return nil
            }
            guard let text = String(data: data, encoding: .utf8) else { return nil }
            let out = patch(text)
            guard out.hits > 0 else { return nil }
            let boot = bootstrap(patchedSDK: out.text, hits: out.hits)
            cachedPatched = boot
            return boot
        } catch {
            return nil
        }
    }

    @MainActor
    static func loadContentRules() async -> WKContentRuleList? {
        let json = contentRuleJSON
        guard let store = WKContentRuleListStore.default() else { return nil }
        if let existing = await lookupRules(store) {
            return existing
        }
        return await withCheckedContinuation { cont in
            store.compileContentRuleList(
                forIdentifier: ruleIdentifier,
                encodedContentRuleList: json
            ) { list, _ in
                cont.resume(returning: list)
            }
        }
    }

    @MainActor
    private static func lookupRules(_ store: WKContentRuleListStore) async -> WKContentRuleList? {
        await withCheckedContinuation { cont in
            store.lookUpContentRuleList(forIdentifier: ruleIdentifier) { list, _ in
                cont.resume(returning: list)
            }
        }
    }

}
