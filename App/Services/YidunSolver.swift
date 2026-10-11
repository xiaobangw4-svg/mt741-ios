import Foundation

/// Calls the PC 8889 click/slider solver (same JSON as the desktop `/api/verify`).
/// The iPhone does not run OCR; fill the LAN URL while 一键启动 is up.
enum YidunSolver {
    static let defaultsKey = "mt741.yidunSolverURL"

    struct Result: Equatable {
        var ok: Bool
        var token: String
        var fp: String
        var message: String
    }

    static var storedURL: String {
        get { UserDefaults.standard.string(forKey: defaultsKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    static func normalize(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        if !s.contains("://") {
            s = "http://" + s
        }
        if s.hasSuffix("/") {
            s.removeLast()
        }
        if !s.lowercased().contains("/api/verify") {
            s += "/api/verify"
        }
        return URL(string: s)
    }

    static func requestJSON(
        captchaId: String,
        pageUrl: String,
        priorityRecordId: String,
        deviceId: String,
        userAgent: String,
        gdxid: String
    ) -> [String: String] {
        var body = [
            "captchaId": captchaId,
            "pageUrl": pageUrl,
            "deviceId": deviceId,
            "userAgent": userAgent,
        ]
        if !priorityRecordId.isEmpty {
            body["priorityRecordId"] = priorityRecordId
        }
        if !gdxid.isEmpty {
            body["gdxid"] = gdxid
        }
        return body
    }

    static func parse(_ raw: String) -> Result {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return Result(ok: false, token: "", fp: "", message: "8889 返回无法解析")
        }
        let nested = JSONText.object(obj["data"])
        let token = firstNonEmpty(
            JSONText.string(nested["finalValidate"]),
            JSONText.string(obj["finalValidate"]),
            JSONText.string(nested["validate"]),
            JSONText.string(obj["validate"])
        )
        let fp = firstNonEmpty(JSONText.string(nested["fp"]), JSONText.string(obj["fp"]))
        let err = firstNonEmpty(
            JSONText.string(obj["error"]),
            JSONText.string(obj["message"]),
            JSONText.string(nested["message"])
        )
        if !token.isEmpty {
            return Result(ok: true, token: token, fp: fp, message: "电脑 8889 已出 validate \(token.count) 字")
        }
        let hint = err.isEmpty ? "8889 未出 validate" : err
        return Result(ok: false, token: "", fp: fp, message: hint)
    }

    static func solve(
        endpoint: String,
        captchaId: String,
        pageUrl: String,
        priorityRecordId: String,
        deviceId: String,
        userAgent: String,
        gdxid: String
    ) async -> Result {
        guard let url = normalize(endpoint) else {
            return Result(ok: false, token: "", fp: "", message: "没填电脑 8889 地址")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = requestJSON(
            captchaId: captchaId,
            pageUrl: pageUrl,
            priorityRecordId: priorityRecordId,
            deviceId: deviceId,
            userAgent: userAgent,
            gdxid: gdxid
        )
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, resp) = try await URLSession.shared.data(for: request)
            if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                let text = String(data: data, encoding: .utf8) ?? ""
                return Result(ok: false, token: "", fp: "", message: "8889 HTTP \(http.statusCode) \(text.prefix(80))")
            }
            return parse(String(data: data, encoding: .utf8) ?? "")
        } catch {
            return Result(ok: false, token: "", fp: "", message: "连不上电脑 8889：\(error.localizedDescription)")
        }
    }

    private static func firstNonEmpty(_ values: String...) -> String {
        values.first { !$0.isEmpty } ?? ""
    }
}
