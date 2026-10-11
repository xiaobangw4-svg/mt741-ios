import Foundation

enum YidunClient {
    static let captchaId741 = "1e1ea52963a94c21b0babc42b2b5b910"
    static let verifyURL = URL(string: "https://h5.moutai519.com.cn/xhr/front/trade/priority/verify/code")!

    static func verify(validate: String, priorityRecordId: String, session: Session, captchaId: String = captchaId741, gdxid: String = "") async -> String {
        let trimmed = validate.trimmingCharacters(in: .whitespacesAndNewlines)
        let rid = priorityRecordId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "validate 为空，先完成点选" }
        if rid.isEmpty { return "没有 priorityRecordId，点选结果会写入 ydToken，下次异步带上重发" }
        let bodyObj: [String: Any] = [
            "captchaId": captchaId,
            "validate": trimmed,
            "priorityUserRecordId": rid,
        ]
        do {
            let json = try await postJSON(url: verifyURL, body: bodyObj, session: session, gdxid: gdxid)
            let code = AuthClient.jsonCode(json)
            if code == 2000 {
                return "易盾已提交 code=2000"
            }
            return (json["message"] as? String) ?? "verify code=\(code.map(String.init) ?? "nil")"
        } catch {
            return AuthClient.describe(error)
        }
    }

    private static func postJSON(url: URL, body: [String: Any], session: Session, gdxid: String = "") async throws -> [String: Any] {
        let token = session.cookie.isEmpty ? session.token : session.cookie
        let mtK = String(Int64(Date().timeIntervalSince1970 * 1000))
        let mtV = AuthDigest.mtV(
            timestamp: mtK,
            deviceId: session.deviceId,
            version: AuthDigest.appVersion,
            suffix: AuthDigest.randomSuffix()
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.httpShouldHandleCookies = false
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        for (key, value) in HeaderBuilder.headers(
            deviceId: session.deviceId,
            token: token,
            mtK: mtK,
            mtV: mtV,
            cwb: "",
            gdxid: gdxid
        ) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, resp) = try await URLSession.shared.data(for: request)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "Yidun", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "HTTP \(http.statusCode)",
            ])
        }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}
