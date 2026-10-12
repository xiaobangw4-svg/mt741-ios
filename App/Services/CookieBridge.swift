import Foundation
import WebKit

enum CookieBridge {
    static let h5Host = "h5.moutai519.com.cn"
    static let appHost = "app.moutai519.com.cn"

    /// Official iOS WebView UA from 2026-10-07 capture: moutaiapp/1.9.14 device-id/<32hex> BS-DVID/<token>.
    /// Sideload has no HaoTian BS-DVID harvest; CWB 768 vs 800 is StyleTotal / ext_142 digits.
    static func userAgent(deviceId: String, bsDvid: String = "") -> String {
        let raw = deviceId.isEmpty ? "MT741" : deviceId
        let did = AuthDigest.md5Hex(raw)
        var ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 moutaiapp/\(AuthDigest.appVersion) device-id/\(did)"
        let dvid = bsDvid.trimmingCharacters(in: .whitespacesAndNewlines)
        if !dvid.isEmpty {
            ua += " BS-DVID/\(dvid)"
        }
        return ua
    }

    static var h5UA: String { userAgent(deviceId: "MT741") }

    static func cookies(from session: Session) -> [HTTPCookie] {
        let token = session.wapToken
        let deviceId = session.authDeviceId
        var specs: [(String, String, String)] = []
        if !deviceId.isEmpty {
            specs.append(("MT-Device-ID-Wap", deviceId, h5Host))
            specs.append(("MT-Device-ID-Wap", deviceId, appHost))
        }
        if !token.isEmpty {
            specs.append(("MT-Token-Wap", token, h5Host))
            specs.append(("MT-Token-Wap", token, appHost))
        }
        return specs.compactMap { name, value, host in
            HTTPCookie(properties: [
                .domain: host,
                .path: "/",
                .name: name,
                .value: value,
                .secure: "TRUE",
            ])
        }
    }

    static func apply(_ session: Session, completion: (() -> Void)? = nil) {
        let store = WKWebsiteDataStore.default().httpCookieStore
        let next = cookies(from: session)
        store.getAllCookies { existing in
            let stale = existing.filter {
                $0.name == "MT-Token-Wap" || $0.name == "MT-Device-ID-Wap"
            }
            let group = DispatchGroup()
            for cookie in stale {
                group.enter()
                store.delete(cookie) { group.leave() }
            }
            for cookie in next {
                group.enter()
                store.setCookie(cookie) { group.leave() }
            }
            group.notify(queue: .main) { completion?() }
        }
    }

    static func applyAsync(_ session: Session) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            apply(session) { cont.resume() }
        }
    }
}
