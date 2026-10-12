import CryptoKit
import Foundation

enum AuthDigest {
    static let vcodeSalt = "2af72f100c356273d46284f6fd1dfc08"
    static let appVersion = "1.9.14"
    static let bundleId = "com.moutai.mall"
    static let nativeUA = "iOS;18.7;Apple;iPhone"
    static let randCharset = Array("0123456789abcdefghijklmnopqrstuvwxyz")

    static func md5Hex(_ raw: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func vcodeMD5(mobile: String, timestamp: String) -> String {
        md5Hex(vcodeSalt + mobile + timestamp)
    }

    static func bubbleSort(_ s: String) -> String {
        var chars = Array(s)
        let n = chars.count
        guard n > 1 else { return s }
        for i in 0..<(n - 1) {
            for j in 0..<(n - 1 - i) {
                if chars[j] > chars[j + 1] {
                    chars.swapAt(j, j + 1)
                }
            }
        }
        return String(chars)
    }

    static func mtV(timestamp: String, deviceId: String, version: String, suffix: Character) -> String {
        let combined = "iOS" + timestamp + deviceId + version
        let digest = md5Hex(bubbleSort(combined) + String(suffix))
        return String(digest.prefix(26)) + String(suffix)
    }

    static func randomSuffix() -> Character {
        randCharset.randomElement() ?? "0"
    }

    static func normalizeMobile(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: " ", with: "")
        s = s.replacingOccurrences(of: "-", with: "")
        if s.hasPrefix("+86") {
            s = String(s.dropFirst(3))
        } else if s.hasPrefix("86"), s.count == 13 {
            s = String(s.dropFirst(2))
        }
        return s
    }

    static func validateMobile(_ mobile: String) -> String? {
        let trimmed = normalizeMobile(mobile)
        if trimmed.count != 11 || trimmed.contains(where: { !$0.isNumber }) {
            return "手机号须为 11 位数字"
        }
        return nil
    }

    static func validateVCode(_ vcode: String) -> String? {
        let trimmed = vcode.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "请填写验证码"
        }
        return nil
    }

    /// ianus JWT payload: `{"iss":"mt","exp":…,"userId":…,"deviceId":"<UUID>","iat":…}`.
    static func jwtPayload(_ token: String) -> [String: Any] {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return [:] }
        var s = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = (4 - s.count % 4) % 4
        if pad > 0 {
            s += String(repeating: "=", count: pad)
        }
        guard let data = Data(base64Encoded: s),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return obj
    }

    static func jwtDeviceId(_ token: String) -> String {
        let raw = jwtPayload(token)["deviceId"]
        if let s = raw as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        return ""
    }
}
