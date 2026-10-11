import Foundation
import WebKit

/// Chrome sign pool rewrites `bs_h5.min.js` on the wire. WK ignores JS `src` setters for
/// parser-inserted scripts, so do the same rewrite natively: fetch, patch StyleTotal, block
/// the original script, inject the patched copy at document-start.
enum StyleTotalSDK {
    static let remoteURL = URL(string: "https://resource.moutai519.com.cn/mt-resource/static-union/bs_h5.min.js")!
    static let ruleIdentifier = "mt741-block-bs-h5"

    static func patch(_ src: String) -> (text: String, hits: Int) {
        let hits = src.components(separatedBy: StyleTotalPatch.loopFrom).count - 1
        guard hits > 0 else { return (src, 0) }
        return (src.replacingOccurrences(of: StyleTotalPatch.loopFrom, with: StyleTotalPatch.loopTo), hits)
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

    static func bootstrap(patchedSDK: String, hits: Int) -> String {
        let url = remoteURL.absoluteString
        return """
        (function(){
          try {
            var s=document.createElement('script');
            s.src=\(jsonAtom(url));
            s.async=false;
            (document.documentElement||document).appendChild(s);
          } catch(e) {}
          window.__mt741styleFrom=\(hits);
          window.__mt741stylePatched=true;
          window.__mt741sdkRewritten=true;
        })();
        \(patchedSDK)
        """
    }

    static func fetchPatched() async -> String? {
        var req = URLRequest(url: remoteURL)
        req.timeoutInterval = 12
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
            return bootstrap(patchedSDK: out.text, hits: out.hits)
        } catch {
            return nil
        }
    }

    static func loadContentRules() async -> WKContentRuleList? {
        let json = contentRuleJSON
        let store = WKContentRuleListStore.default()
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

    private static func lookupRules(_ store: WKContentRuleListStore) async -> WKContentRuleList? {
        await withCheckedContinuation { cont in
            store.lookUpContentRuleList(forIdentifier: ruleIdentifier) { list, _ in
                cont.resume(returning: list)
            }
        }
    }

    private static func jsonAtom(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let text = String(data: data, encoding: .utf8), text.count >= 2
        else {
            return "''"
        }
        return String(text.dropFirst().dropLast())
    }
}
