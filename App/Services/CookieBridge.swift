import Foundation
import UIKit
import WebKit

enum CookieBridge {
    static let h5Host = "h5.moutai519.com.cn"
    static let appHost = "app.moutai519.com.cn"

    /// Official iOS WebView UA: moutaiapp/1.9.14 device-id/<32hex> BS-DVID/<haoTian long token>.
    /// Sideload has no HaoTian SDK; paste the same-phone official-app token. CWB 800 is StyleTotal / ext_142.
    static let minBsDvidLength = 60

    /// Device-level HaoTian token. Rejects short `bid-` (瑞数) and garbage. Empty means omit the UA suffix.
    /// Accepts a bare token, official UA `BS-DVID/<tok>`, or rush_capture `H BS-DVID = <tok>`.
    static func sanitizeBsDvid(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return "" }
        if let range = text.range(of: "BS-DVID/", options: .caseInsensitive) {
            text = String(text[range.upperBound...])
            if let end = text.firstIndex(where: { $0.isWhitespace }) {
                text = String(text[..<end])
            }
        } else if let range = text.range(of: "BS-DVID", options: .caseInsensitive) {
            var rest = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if rest.hasPrefix("=") {
                rest = String(rest.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            text = rest.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("bid-") { return "" }
        guard text.count >= minBsDvidLength else { return "" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        if text.unicodeScalars.contains(where: { !allowed.contains($0) }) { return "" }
        return text
    }

    /// Fill from a pasted string or the system pasteboard. Does not overwrite a caller-owned value.
    static func ingestPasteboard(_ raw: String? = nil) -> String {
        let text = raw ?? UIPasteboard.general.string ?? ""
        return sanitizeBsDvid(text)
    }

    static func userAgent(deviceId: String, bsDvid: String = "") -> String {
        let raw = deviceId.isEmpty ? "MT741" : deviceId
        let did = AuthDigest.md5Hex(raw)
        var ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 moutaiapp/\(AuthDigest.appVersion) device-id/\(did)"
        let dvid = sanitizeBsDvid(bsDvid)
        if !dvid.isEmpty {
            ua += " BS-DVID/\(dvid)"
        }
        return ua
    }

    static func userAgent(from session: Session) -> String {
        let device = session.authDeviceId.isEmpty ? "MT741" : session.authDeviceId
        return userAgent(deviceId: device, bsDvid: session.bsDvid)
    }

    static var h5UA: String { userAgent(deviceId: "MT741") }

    static func setNativeHeader(_ request: inout URLRequest, bsDvid: String) {
        let token = sanitizeBsDvid(bsDvid)
        if !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "BS-DVID")
        }
    }

    /// Official 08-29 iOS rush Cookie has no 顶象 / short Bangcle / snaker ids.
    static let rushDropNames: Set<String> = [
        "gdxidpyhxdE",
        "_bs_device_id",
        "__snaker__id",
    ]

    static func isRushDropCookie(_ name: String) -> Bool {
        rushDropNames.contains(name)
    }

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
        specs.append(("YX_SUPPORT_WEBP", "0", h5Host))
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
            let stale = existing.filter { cookie in
                cookie.name == "MT-Token-Wap"
                    || cookie.name == "MT-Device-ID-Wap"
                    || cookie.name == "YX_SUPPORT_WEBP"
                    || isRushDropCookie(cookie.name)
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

    /// Shared WK store keeps _u_id_, Bangcle cookies, and the previous JWT.
    /// Wipe before the next login or CWB/4011 mix the two numbers.
    static func wipeWebsiteData() async {
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            store.removeData(ofTypes: types, modifiedSince: .distantPast) {
                cont.resume()
            }
        }
    }
}
