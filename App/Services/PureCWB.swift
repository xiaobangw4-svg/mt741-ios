import Foundation
import Security

/// Local CWB: Murmur data[7] + field141 v1174 + StyleTotal(ext_142) + SM4 envelope.
/// `_d_u` uses the same smk as the burst.
enum PureCWB {
    static let appKey = "10001"
    static let wasmVersion = PureWac.version

    struct Keys: Equatable {
        var smk: String
        var smk1: String
        var smi: String

        static func make() -> Keys {
            let smk = randomHex(32)
            let smk1 = MurmurHash3.x64_128(smk + "_bsdk_", seed: 27)
            let smi = BangcleBlob.xorHexNibbles(smk)
            return Keys(smk: smk, smk1: smk1, smi: smi)
        }
    }

    struct Identity: Equatable {
        var did: String
        var startId: String
        var userId: String
        var hp: String = "0"
        var pageURL: String = HeaderBuilder.referer
        var userAgent: String = ""
        var bsDeviceId: String = ""
        var wasmVersion: String = PureCWB.wasmVersion
    }

    struct Packet: Equatable {
        var cwb: String
        var hh: String
        var dU: String
        var randomId: String
        var ext142: UInt32
        var field141: String
        var ts: Int64
    }

    static func serializePost(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data)
        else { return json }
        return serialize(obj, depth: 0)
    }

    static func sign(
        bodyJSON: String,
        identity: Identity,
        keys: Keys,
        nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        randomId: String? = nil,
        liftStyle: Bool = true
    ) -> Packet? {
        let did = identity.did.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !did.isEmpty else { return nil }
        let rid = randomId?.isEmpty == false ? randomId! : randomHex(32)
        let requestData = serializePost(bodyJSON)
        let sign = MurmurHash3.x64_128(requestData, seed: 27, maxLen: 4096, salt: rid)
        guard let field141 = PureWac.run(did: did, sign: sign, nowMs: nowMs, hasEnv: 0) else { return nil }
        let ext = StyleTotalPatch.hashForSign(rid, liftToFiveDigits: liftStyle)
        let arrJSON = arrayJSON(
            appKey: appKey,
            did: did,
            startId: identity.startId,
            hp: identity.hp.isEmpty ? "0" : identity.hp,
            randomId: rid,
            sign: sign,
            ts: nowMs,
            userId: identity.userId,
            wasmVersion: identity.wasmVersion.isEmpty ? wasmVersion : identity.wasmVersion,
            field141: field141,
            ext142: ext
        )
        guard let cipher = SM4.encryptCBCHex(arrJSON, keyHex: keys.smk1, ivHex: keys.smk1) else { return nil }
        let dU = deviceReport(identity: identity, keys: keys, nowMs: nowMs)
        return Packet(
            cwb: keys.smi + cipher,
            hh: sign,
            dU: dU,
            randomId: rid,
            ext142: ext,
            field141: field141,
            ts: nowMs
        )
    }

    static func deviceReport(identity: Identity, keys: Keys, nowMs: Int64) -> String {
        let ua = shortUA(identity.userAgent)
        let page = identity.pageURL.isEmpty ? HeaderBuilder.referer : identity.pageURL
        let bid = identity.bsDeviceId.isEmpty ? generateBid(did: identity.did, nowMs: nowMs) : identity.bsDeviceId
        let json = "["
            + jsonString(appKey) + ","
            + jsonString(identity.did) + ","
            + jsonString(identity.startId) + ","
            + jsonString(ua) + ","
            + jsonString(page) + ","
            + jsonString(bid) + ","
            + String(nowMs)
            + "]"
        guard let cipher = SM4.encryptCBCHex(json, keyHex: keys.smk1, ivHex: keys.smk1) else { return "" }
        return keys.smi + cipher
    }

    static func generateBid(did: String, nowMs: Int64) -> String {
        let rev = String(nowMs).reversed()
        let tail = did.suffix(4)
        return "bid-\(String(rev))-\(tail)-\(randomHex(4))"
    }

    static func randomHex(_ n: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: (n + 1) / 2)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return String(SM4.hexEncode(bytes).prefix(n)).lowercased()
    }

    static func shortUA(_ ua: String) -> String {
        var s = ua.lowercased()
        if let idx = s.firstIndex(of: ")") {
            s = String(s[..<idx])
        }
        if s.count > 50 { s = String(s.prefix(50)) }
        return s
    }

    private static func arrayJSON(
        appKey: String,
        did: String,
        startId: String,
        hp: String,
        randomId: String,
        sign: String,
        ts: Int64,
        userId: String,
        wasmVersion: String,
        field141: String,
        ext142: UInt32
    ) -> String {
        "["
            + jsonString(appKey) + ","
            + jsonString(did) + ","
            + jsonString(startId) + ","
            + jsonString("") + ","
            + jsonString("0") + ","
            + jsonString(hp) + ","
            + jsonString(randomId) + ","
            + jsonString(sign) + ","
            + String(ts) + ","
            + "[]" + ","
            + jsonString(userId) + ","
            + jsonString(wasmVersion) + ","
            + field141 + ","
            + String(ext142)
            + "]"
    }

    private static func jsonString(_ s: String) -> String {
        RushCrypto.jsonString(s)
    }

    private static func serialize(_ obj: Any, depth: Int) -> String {
        if depth > 10 { return "[]" }
        if obj is NSNull { return "|-|-|" }
        if let s = obj as? String { return s }
        if let b = obj as? Bool {
            if depth == 1 { return "" }
            return b ? "true" : "false"
        }
        if let n = obj as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                if depth == 1 { return "" }
                return n.boolValue ? "true" : "false"
            }
            if depth == 1 { return "" }
            return n.stringValue
        }
        if let arr = obj as? [Any] {
            let parts = arr.map { serialize($0, depth: depth) }.filter { $0 != "|-|-|" }
            return "[" + parts.joined(separator: ",") + "]"
        }
        if let dict = obj as? [String: Any] {
            var result = ""
            for k in dict.keys.sorted() {
                let s = serialize(dict[k] as Any, depth: depth)
                if s != "|-|-|" {
                    result += k + "=" + s + ";"
                }
            }
            return result
        }
        return ""
    }
}
