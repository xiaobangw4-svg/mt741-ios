import Foundation

/// Decrypt Bangcle `_d_u` / Content-Web-Bb (smi + SM4-CBC) and pull did / hp.
enum BangcleBlob {
    static let didIndex = 1
    static let startIdIndex = 2
    static let hpIndex = 5
    static let userIdIndex = 10
    static let wasmVersionIndex = 11
    static let wasmSignIndex = 12
    static let ext142Index = 13

    static func decryptJSONArray(_ blob: String) -> [Any]? {
        let hex = blob.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard hex.count >= 64, hex.count.isMultiple(of: 2) else { return nil }
        guard hex.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789abcdef").contains($0) }) else {
            return nil
        }
        let smi = String(hex.prefix(32))
        let cipher = String(hex.dropFirst(32))
        let smk = xorHexNibbles(smi)
        let smk1 = MurmurHash3.x64_128(smk + "_bsdk_", seed: 27)
        guard let plain = SM4.decryptCBCHex(cipher, keyHex: smk1, ivHex: smk1),
              let data = plain.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [Any]
        else { return nil }
        return arr
    }

    static func did(from blob: String) -> String {
        CookieBridge.sanitizeH5Did(stringField(decryptJSONArray(blob), didIndex))
    }

    static func hp(from blob: String) -> String {
        stringField(decryptJSONArray(blob), hpIndex)
    }

    static func startId(from blob: String) -> String {
        stringField(decryptJSONArray(blob), startIdIndex)
    }

    static func wasmVersion(from blob: String) -> String {
        stringField(decryptJSONArray(blob), wasmVersionIndex)
    }

    static func userId(from blob: String) -> String {
        stringField(decryptJSONArray(blob), userIdIndex)
    }

    static func xorHexNibbles(_ hex: String) -> String {
        let map: [Character: Character] = [
            "0": "1", "1": "0", "2": "3", "3": "2", "4": "5", "5": "4", "6": "7", "7": "6",
            "8": "9", "9": "8", "a": "b", "b": "a", "c": "d", "d": "c", "e": "f", "f": "e",
        ]
        return String(hex.lowercased().map { map[$0] ?? $0 })
    }

    private static func stringField(_ arr: [Any]?, _ index: Int) -> String {
        guard let arr, index < arr.count else { return "" }
        if let s = arr[index] as? String { return s }
        if let n = arr[index] as? NSNumber { return n.stringValue }
        return ""
    }
}
