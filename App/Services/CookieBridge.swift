import Foundation
import WebKit

enum CookieBridge {
    static let h5Host = "h5.moutai519.com.cn"
    static let appHost = "app.moutai519.com.cn"
    static let h5UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 moutaiapp/1.9.14"

    static func cookies(from session: Session) -> [HTTPCookie] {
        let token = session.cookie.isEmpty ? session.token : session.cookie
        var specs: [(String, String, String)] = [
            ("MT-Device-ID-Wap", session.deviceId, h5Host),
            ("MT-Device-ID-Wap", session.deviceId, appHost),
        ]
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
}
