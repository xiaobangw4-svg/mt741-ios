import Foundation

enum SM4 {
    private static let sbox: [UInt8] = [
        0xD6, 0x90, 0xE9, 0xFE, 0xCC, 0xE1, 0x3D, 0xB7, 0x16, 0xB6, 0x14, 0xC2, 0x28, 0xFB, 0x2C, 0x05,
        0x2B, 0x67, 0x9A, 0x76, 0x2A, 0xBE, 0x04, 0xC3, 0xAA, 0x44, 0x13, 0x26, 0x49, 0x86, 0x06, 0x99,
        0x9C, 0x42, 0x50, 0xF4, 0x91, 0xEF, 0x98, 0x7A, 0x33, 0x54, 0x0B, 0x43, 0xED, 0xCF, 0xAC, 0x62,
        0xE4, 0xB3, 0x1C, 0xA9, 0xC9, 0x08, 0xE8, 0x95, 0x80, 0xDF, 0x94, 0xFA, 0x75, 0x8F, 0x3F, 0xA6,
        0x47, 0x07, 0xA7, 0xFC, 0xF3, 0x73, 0x17, 0xBA, 0x83, 0x59, 0x3C, 0x19, 0xE6, 0x85, 0x4F, 0xA8,
        0x68, 0x6B, 0x81, 0xB2, 0x71, 0x64, 0xDA, 0x8B, 0xF8, 0xEB, 0x0F, 0x4B, 0x70, 0x56, 0x9D, 0x35,
        0x1E, 0x24, 0x0E, 0x5E, 0x63, 0x58, 0xD1, 0xA2, 0x25, 0x22, 0x7C, 0x3B, 0x01, 0x21, 0x78, 0x87,
        0xD4, 0x00, 0x46, 0x57, 0x9F, 0xD3, 0x27, 0x52, 0x4C, 0x36, 0x02, 0xE7, 0xA0, 0xC4, 0xC8, 0x9E,
        0xEA, 0xBF, 0x8A, 0xD2, 0x40, 0xC7, 0x38, 0xB5, 0xA3, 0xF7, 0xF2, 0xCE, 0xF9, 0x61, 0x15, 0xA1,
        0xE0, 0xAE, 0x5D, 0xA4, 0x9B, 0x34, 0x1A, 0x55, 0xAD, 0x93, 0x32, 0x30, 0xF5, 0x8C, 0xB1, 0xE3,
        0x1D, 0xF6, 0xE2, 0x2E, 0x82, 0x66, 0xCA, 0x60, 0xC0, 0x29, 0x23, 0xAB, 0x0D, 0x53, 0x4E, 0x6F,
        0xD5, 0xDB, 0x37, 0x45, 0xDE, 0xFD, 0x8E, 0x2F, 0x03, 0xFF, 0x6A, 0x72, 0x6D, 0x6C, 0x5B, 0x51,
        0x8D, 0x1B, 0xAF, 0x92, 0xBB, 0xDD, 0xBC, 0x7F, 0x11, 0xD9, 0x5C, 0x41, 0x1F, 0x10, 0x5A, 0xD8,
        0x0A, 0xC1, 0x31, 0x88, 0xA5, 0xCD, 0x7B, 0xBD, 0x2D, 0x74, 0xD0, 0x12, 0xB8, 0xE5, 0xB4, 0xB0,
        0x89, 0x69, 0x97, 0x4A, 0x0C, 0x96, 0x77, 0x7E, 0x65, 0xB9, 0xF1, 0x09, 0xC5, 0x6E, 0xC6, 0x84,
        0x18, 0xF0, 0x7D, 0xEC, 0x3A, 0xDC, 0x4D, 0x20, 0x79, 0xEE, 0x5F, 0x3E, 0xD7, 0xCB, 0x39, 0x48,
    ]
    private static let fk: [UInt32] = [0xA3B1BAC6, 0x56AA3350, 0x677D9197, 0xB27022DC]
    private static let ck: [UInt32] = [
        0x00070E15, 0x1C232A31, 0x383F464D, 0x545B6269, 0x70777E85, 0x8C939AA1, 0xA8AFB6BD, 0xC4CBD2D9,
        0xE0E7EEF5, 0xFC030A11, 0x181F262D, 0x343B4249, 0x50575E65, 0x6C737A81, 0x888F969D, 0xA4ABB2B9,
        0xC0C7CED5, 0xDCE3EAF1, 0xF8FF060D, 0x141B2229, 0x30373E45, 0x4C535A61, 0x686F767D, 0x848B9299,
        0xA0A7AEB5, 0xBCC3CAD1, 0xD8DFE6ED, 0xF4FB0209, 0x10171E25, 0x2C333A41, 0x484F565D, 0x646B7279,
    ]

    static func encryptECBBase64(_ plain: String, key: String) -> String {
        encryptECB(Data(plain.utf8), key: Data(key.utf8)).base64EncodedString()
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }

    static func encryptECB(_ plain: Data, key: Data) -> Data {
        var keyBytes = [UInt8](key)
        while keyBytes.count < 16 { keyBytes.append(0) }
        keyBytes = Array(keyBytes.prefix(16))
        var padded = [UInt8](plain)
        let pad = 16 - (padded.count % 16)
        padded.append(contentsOf: repeatElement(UInt8(pad), count: pad))
        let rk = roundKeys(keyBytes)
        var out = [UInt8](repeating: 0, count: padded.count)
        var off = 0
        while off < padded.count {
            let block = Array(padded[off..<(off + 16)])
            let enc = cryptBlock(block, rk: rk)
            for i in 0..<16 { out[off + i] = enc[i] }
            off += 16
        }
        return Data(out)
    }

    /// 16-byte SM4 block encrypt. Bangcle field141 CTR and CWB CBC share this.
    static func encryptBlock(_ block: [UInt8], key: [UInt8]) -> [UInt8] {
        var keyBytes = key
        while keyBytes.count < 16 { keyBytes.append(0) }
        keyBytes = Array(keyBytes.prefix(16))
        var input = block
        while input.count < 16 { input.append(0) }
        return cryptBlock(Array(input.prefix(16)), rk: roundKeys(keyBytes))
    }

    /// Bangcle CWB / `_d_u`: SM4-CBC, PKCS7, key=IV=smk1 hex.
    static func encryptCBCHex(_ plain: String, keyHex: String, ivHex: String) -> String? {
        guard let key = hexDecode(keyHex), let iv = hexDecode(ivHex) else { return nil }
        return hexEncode(encryptCBC(Data(plain.utf8), key: key, iv: iv))
    }

    static func encryptCBC(_ plain: Data, key: Data, iv: Data) -> Data {
        var keyBytes = [UInt8](key)
        while keyBytes.count < 16 { keyBytes.append(0) }
        keyBytes = Array(keyBytes.prefix(16))
        var ivBytes = [UInt8](iv)
        while ivBytes.count < 16 { ivBytes.append(0) }
        ivBytes = Array(ivBytes.prefix(16))
        var padded = [UInt8](plain)
        let pad = 16 - (padded.count % 16)
        padded.append(contentsOf: repeatElement(UInt8(pad), count: pad))
        let rk = roundKeys(keyBytes)
        var out = [UInt8](repeating: 0, count: padded.count)
        var prev = ivBytes
        var off = 0
        while off < padded.count {
            var block = Array(padded[off..<(off + 16)])
            for i in 0..<16 { block[i] ^= prev[i] }
            let enc = cryptBlock(block, rk: rk)
            for i in 0..<16 { out[off + i] = enc[i] }
            prev = enc
            off += 16
        }
        return Data(out)
    }

    static func hexEncode(_ data: Data) -> String {
        hexEncode([UInt8](data))
    }

    static func hexEncode(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Bangcle `_d_u` / CWB body: SM4-CBC, PKCS7, key=IV=smk1 hex.
    static func decryptCBCHex(_ cipherHex: String, keyHex: String, ivHex: String) -> String? {
        guard let cipher = hexDecode(cipherHex),
              let key = hexDecode(keyHex),
              let iv = hexDecode(ivHex),
              let plain = decryptCBC(cipher, key: key, iv: iv)
        else { return nil }
        return String(data: plain, encoding: .utf8)
    }

    static func decryptCBC(_ cipher: Data, key: Data, iv: Data) -> Data? {
        var keyBytes = [UInt8](key)
        while keyBytes.count < 16 { keyBytes.append(0) }
        keyBytes = Array(keyBytes.prefix(16))
        var ivBytes = [UInt8](iv)
        while ivBytes.count < 16 { ivBytes.append(0) }
        ivBytes = Array(ivBytes.prefix(16))
        let bytes = [UInt8](cipher)
        guard !bytes.isEmpty, bytes.count % 16 == 0 else { return nil }
        var rk = roundKeys(keyBytes)
        rk.reverse()
        var out = [UInt8](repeating: 0, count: bytes.count)
        var prev = ivBytes
        var off = 0
        while off < bytes.count {
            let block = Array(bytes[off..<(off + 16)])
            let dec = cryptBlock(block, rk: rk)
            for i in 0..<16 {
                out[off + i] = dec[i] ^ prev[i]
            }
            prev = block
            off += 16
        }
        let pad = Int(out[out.count - 1])
        guard pad >= 1, pad <= 16, out.count >= pad else { return nil }
        let suffix = out.suffix(pad)
        guard suffix.allSatisfy({ $0 == UInt8(pad) }) else { return nil }
        return Data(out.dropLast(pad))
    }

    static func hexDecode(_ hex: String) -> Data? {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.count.isMultiple(of: 2), !s.isEmpty else { return nil }
        var out = [UInt8]()
        out.reserveCapacity(s.count / 2)
        var i = s.startIndex
        while i < s.endIndex {
            let j = s.index(i, offsetBy: 2)
            guard let b = UInt8(s[i..<j], radix: 16) else { return nil }
            out.append(b)
            i = j
        }
        return Data(out)
    }

    private static func rotL(_ x: UInt32, _ n: UInt32) -> UInt32 {
        (x << n) | (x >> (32 - n))
    }

    private static func subBytes(_ x: UInt32) -> UInt32 {
        let b0 = UInt32(sbox[Int((x >> 24) & 0xFF)])
        let b1 = UInt32(sbox[Int((x >> 16) & 0xFF)])
        let b2 = UInt32(sbox[Int((x >> 8) & 0xFF)])
        let b3 = UInt32(sbox[Int(x & 0xFF)])
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }

    private static func loadU32(_ b: [UInt8], _ i: Int) -> UInt32 {
        (UInt32(b[i]) << 24) | (UInt32(b[i + 1]) << 16) | (UInt32(b[i + 2]) << 8) | UInt32(b[i + 3])
    }

    private static func roundKeys(_ key: [UInt8]) -> [UInt32] {
        var k = [UInt32](repeating: 0, count: 36)
        for i in 0..<4 { k[i] = loadU32(key, i * 4) ^ fk[i] }
        var rk = [UInt32](repeating: 0, count: 32)
        for i in 0..<32 {
            let t = subBytes(k[i + 1] ^ k[i + 2] ^ k[i + 3] ^ ck[i])
            k[i + 4] = k[i] ^ t ^ rotL(t, 13) ^ rotL(t, 23)
            rk[i] = k[i + 4]
        }
        return rk
    }

    private static func cryptBlock(_ block: [UInt8], rk: [UInt32]) -> [UInt8] {
        var x = [UInt32](repeating: 0, count: 36)
        for i in 0..<4 { x[i] = loadU32(block, i * 4) }
        for i in 0..<32 {
            let t = subBytes(x[i + 1] ^ x[i + 2] ^ x[i + 3] ^ rk[i])
            x[i + 4] = x[i] ^ t ^ rotL(t, 2) ^ rotL(t, 10) ^ rotL(t, 18) ^ rotL(t, 24)
        }
        var out = [UInt8](repeating: 0, count: 16)
        for i in 0..<4 {
            let v = x[35 - i]
            out[i * 4] = UInt8((v >> 24) & 0xFF)
            out[i * 4 + 1] = UInt8((v >> 16) & 0xFF)
            out[i * 4 + 2] = UInt8((v >> 8) & 0xFF)
            out[i * 4 + 3] = UInt8(v & 0xFF)
        }
        return out
    }
}
