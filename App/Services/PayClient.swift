import Foundation
import UIKit

enum PayClient {
    static let orderPayURL = URL(string: "https://app.moutai519.com.cn/xhr/front/trade/order/pay")!
    static let requestPayURL = URL(string: "https://payapi.moutai519.com.cn/settle-api-server/anon/pay/requestPay")!
    static let channel71 = "71"
    static let appId = "MT519IOS"
    static let appKey = "8C79446361034bd2aE98b27E153a2eA8"
    static let sm4Key = "e881E52D7932Cf00"

    static func securityID(tn: String, ts: String) -> String {
        AuthDigest.md5Hex(tn + ts + appKey)
    }

    static func orderPay(orderId: String, session: Session, payChannel: Int = 71) async -> (message: String, tn: String) {
        let oid = orderId.trimmingCharacters(in: .whitespacesAndNewlines)
        if oid.isEmpty { return ("订单号为空", "") }
        let body: [String: Any] = ["payChannel": payChannel, "orderId": oid]
        do {
            let json = try await postJSON(url: orderPayURL, body: body, session: session, appToken: true)
            let code = AuthClient.jsonCode(json)
            let data = json["data"] as? [String: Any] ?? [:]
            let tn = stringValue(data["channelTradeSn"]) ?? stringValue(data["tn"]) ?? ""
            if code == 2000, !tn.isEmpty {
                return ("order/pay 2000 TN=\(tn)", tn)
            }
            return ((json["message"] as? String) ?? "order/pay code=\(code.map(String.init) ?? "nil")", tn)
        } catch {
            return (AuthClient.describe(error), "")
        }
    }

    static func requestPaySalesId(orderId: String, tn: String) -> String {
        let oid = orderId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !oid.isEmpty { return oid }
        return tn.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func requestPay(tn: String, orderId: String = "", channel: String = channel71) async -> (message: String, payURL: URL?) {
        let tn = tn.trimmingCharacters(in: .whitespacesAndNewlines)
        if tn.isEmpty { return ("TN 为空", nil) }
        let salesId = requestPaySalesId(orderId: orderId, tn: tn)
        let ts = String(Int64(Date().timeIntervalSince1970 * 1000))
        let inJson = "{\"PAY_CHANNEL\":\"\(channel)\",\"TN\":\"\(tn)\"}"
        let sec = securityID(tn: tn, ts: ts)
        let cipher = SM4.encryptECBBase64(ts, key: sm4Key)
        var comps = URLComponents(url: requestPayURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "salesId", value: salesId),
            URLQueryItem(name: "payChannel", value: channel),
        ]
        var request = URLRequest(url: comps.url ?? requestPayURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("okhttp/4.9.2", forHTTPHeaderField: "User-Agent")
        let form = [
            "inJson": inJson,
            "cipherText": cipher,
            "appId": appId,
            "securityID": sec,
        ]
        .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
        .joined(separator: "&")
        request.httpBody = Data(form.utf8)
        do {
            let (data, resp) = try await URLSession.shared.data(for: request)
            let http = resp as? HTTPURLResponse
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            let text = String(data: data, encoding: .utf8) ?? ""
            if let http, !(200...299).contains(http.statusCode) {
                return ("requestPay HTTP \(http.statusCode) \(text.prefix(180))", nil)
            }
            let code = AuthClient.jsonCode(obj)
            let payload = obj["data"] as? [String: Any] ?? obj
            let url = extractPayURL(payload) ?? extractPayURL(obj)
            if let url {
                return ("requestPay code=\(code.map(String.init) ?? "?") 可打开支付", url)
            }
            return ("requestPay code=\(code.map(String.init) ?? "?") \(text.prefix(180))", nil)
        } catch {
            return (AuthClient.describe(error), nil)
        }
    }

    static func extractPayURL(_ obj: [String: Any]) -> URL? {
        let keys = ["AUTH_CODE", "payInfo", "alipay_sdk", "orderInfo", "payUrl", "url"]
        var chunks: [String] = []
        for key in keys {
            if let s = obj[key] as? String { chunks.append(s) }
            if let nested = obj[key] as? [String: Any] {
                nested.values.compactMap { $0 as? String }.forEach { chunks.append($0) }
            }
        }
        let blob = chunks.joined(separator: "\n") + ((try? String(data: JSONSerialization.data(withJSONObject: obj), encoding: .utf8)) ?? "")
        if let match = blob.range(of: #"alipays://[^\s\"<>]+"#, options: .regularExpression) {
            let raw = String(blob[match]).replacingOccurrences(of: "\\u0026", with: "&")
            return URL(string: raw)
        }
        if let match = blob.range(of: #"https://mclient\.alipay\.com/[^\s\"<>]+"#, options: .regularExpression) {
            let raw = String(blob[match])
            if raw.contains("cashierRoutePay") { return nil }
            return URL(string: raw)
        }
        return nil
    }

    static func open(_ url: URL) {
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
    }

    private static func stringValue(_ any: Any?) -> String? {
        if let s = any as? String, !s.isEmpty { return s }
        if let n = any as? NSNumber { return n.stringValue }
        return nil
    }

    private static func postJSON(url: URL, body: [String: Any], session: Session, appToken: Bool) async throws -> [String: Any] {
        let token = session.wapToken
        let deviceId = session.authDeviceId
        let mtK = String(Int64(Date().timeIntervalSince1970 * 1000))
        let mtV = AuthDigest.mtV(
            timestamp: mtK,
            deviceId: deviceId,
            version: AuthDigest.appVersion,
            suffix: AuthDigest.randomSuffix()
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.httpShouldHandleCookies = false
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AuthDigest.nativeUA, forHTTPHeaderField: "User-Agent")
        request.setValue(deviceId, forHTTPHeaderField: "MT-Device-ID")
        request.setValue(AuthDigest.appVersion, forHTTPHeaderField: "MT-APP-Version")
        request.setValue(mtK, forHTTPHeaderField: "MT-K")
        request.setValue(mtV, forHTTPHeaderField: "MT-V")
        if appToken, !session.token.isEmpty {
            request.setValue(session.token, forHTTPHeaderField: "MT-Token")
        }
        if !token.isEmpty {
            request.setValue("MT-Token-Wap=\(token); MT-Device-ID-Wap=\(deviceId)", forHTTPHeaderField: "Cookie")
        }
        let (data, resp) = try await URLSession.shared.data(for: request)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "Pay", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "HTTP \(http.statusCode) \(text.prefix(120))",
            ])
        }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}
