import Foundation

struct LoginResult: Equatable {
    var ok: Bool
    var message: String
    var userId: String = ""
    var userName: String = ""
    var mobile: String = ""
    var token: String = ""
    var cookie: String = ""
    var deviceId: String = ""
}

struct AuthClient {
    var session: URLSession
    var nowMillis: () -> Int64

    static let vcodeURL = URL(string: "https://app.moutai519.com.cn/xhr/front/user/register/vcode")!
    static let loginURL = URL(string: "https://app.moutai519.com.cn/xhr/front/user/register/login")!

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }

    init(session: URLSession = AuthClient.makeSession(), nowMillis: @escaping () -> Int64 = {
        Int64(Date().timeIntervalSince1970 * 1000)
    }) {
        self.session = session
        self.nowMillis = nowMillis
    }

    func sendVCode(mobile: String, deviceId: String, bsDvid: String = "") async -> LoginResult {
        let mobile = AuthDigest.normalizeMobile(mobile)
        if let err = AuthDigest.validateMobile(mobile) {
            return LoginResult(ok: false, message: err, deviceId: deviceId)
        }
        let ts = String(nowMillis())
        let body: [String: String] = [
            "md5": AuthDigest.vcodeMD5(mobile: mobile, timestamp: ts),
            "mobile": mobile,
            "timestamp": ts,
        ]
        do {
            let json = try await postJSON(url: Self.vcodeURL, body: body, deviceId: deviceId, includeMTKV: false, bsDvid: bsDvid)
            let code = Self.jsonCode(json)
            if code == 2000 {
                return LoginResult(ok: true, message: "验证码已发送", mobile: mobile, deviceId: deviceId)
            }
            let msg = (json["message"] as? String) ?? "code=\(code.map(String.init) ?? "nil")"
            return LoginResult(ok: false, message: msg, mobile: mobile, deviceId: deviceId)
        } catch {
            return LoginResult(ok: false, message: Self.describe(error), mobile: mobile, deviceId: deviceId)
        }
    }

    func login(mobile: String, vcode: String, deviceId: String, bsDvid: String = "") async -> LoginResult {
        let mobile = AuthDigest.normalizeMobile(mobile)
        if let err = AuthDigest.validateMobile(mobile) {
            return LoginResult(ok: false, message: err, deviceId: deviceId)
        }
        if let err = AuthDigest.validateVCode(vcode) {
            return LoginResult(ok: false, message: err, deviceId: deviceId)
        }
        let body: [String: String] = [
            "ydToken": "",
            "mobile": mobile,
            "vCode": vcode.trimmingCharacters(in: .whitespacesAndNewlines),
            "ydLogId": "",
        ]
        do {
            let json = try await postJSON(url: Self.loginURL, body: body, deviceId: deviceId, includeMTKV: true, bsDvid: bsDvid)
            let code = Self.jsonCode(json)
            if code != 2000 {
                let msg = (json["message"] as? String) ?? "code=\(code.map(String.init) ?? "nil")"
                return LoginResult(ok: false, message: msg, mobile: mobile, deviceId: deviceId)
            }
            let data = json["data"] as? [String: Any] ?? [:]
            let token = (data["token"] as? String) ?? ""
            let cookie = (data["cookie"] as? String) ?? token
            let userId = String(describing: data["userId"] ?? "")
            let jwtDid = AuthDigest.jwtDeviceId(cookie.isEmpty ? token : cookie)
            return LoginResult(
                ok: true,
                message: "登录成功",
                userId: userId == "nil" ? "" : userId,
                userName: (data["userName"] as? String) ?? "",
                mobile: (data["mobile"] as? String) ?? mobile,
                token: token,
                cookie: cookie,
                deviceId: jwtDid.isEmpty ? deviceId : jwtDid
            )
        } catch {
            return LoginResult(ok: false, message: Self.describe(error), mobile: mobile, deviceId: deviceId)
        }
    }

    static func jsonCode(_ json: [String: Any]) -> Int? {
        if let value = json["code"] as? Int { return value }
        if let value = json["code"] as? NSNumber { return value.intValue }
        if let value = json["code"] as? String { return Int(value) }
        return nil
    }

    static func describe(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorTimedOut {
            return "连接超时：当前是 GitHub 美国模拟器，打不到国内短信接口"
        }
        if ns.domain == NSURLErrorDomain {
            return "网络失败：\(ns.localizedDescription)"
        }
        return error.localizedDescription
    }

    private func postJSON(url: URL, body: [String: String], deviceId: String, includeMTKV: Bool, bsDvid: String = "") async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("zh-Hans-CN;q=1, zh-Hant-CN;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue(deviceId, forHTTPHeaderField: "MT-Device-ID")
        request.setValue(AuthDigest.appVersion, forHTTPHeaderField: "MT-APP-Version")
        request.setValue(AuthDigest.bundleId, forHTTPHeaderField: "MT-Bundle-ID")
        request.setValue("WIFI", forHTTPHeaderField: "MT-Network-Type")
        request.setValue("0", forHTTPHeaderField: "MT-User-Tag")
        request.setValue(AuthDigest.nativeUA, forHTTPHeaderField: "User-Agent")
        request.setValue(AuthDigest.mtR, forHTTPHeaderField: "MT-R")
        CookieBridge.setNativeHeader(&request, bsDvid: bsDvid)
        if includeMTKV {
            let mtK = String(nowMillis())
            let mtV = AuthDigest.mtV(
                timestamp: mtK,
                deviceId: deviceId,
                version: AuthDigest.appVersion,
                suffix: AuthDigest.randomSuffix()
            )
            request.setValue(mtK, forHTTPHeaderField: "MT-K")
            request.setValue(mtV, forHTTPHeaderField: "MT-V")
        }
        request.setValue(String(nowMillis()) + String(format: "%06d", Int.random(in: 0...999_999)), forHTTPHeaderField: "MT-Request-ID")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "AuthClient", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "HTTP \(http.statusCode) \(text.prefix(200))",
            ])
        }
        let obj = try JSONSerialization.jsonObject(with: data)
        return obj as? [String: Any] ?? [:]
    }
}
