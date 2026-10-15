import Foundation

/// field141 纯算 for sign_wasm v1.1.7.4 (blob sha256 ae6e8543…).
/// Port of `node_rush/src/pure_wac_v1174.js`. Constants are per-blob; a new bin needs a re-tear.
enum PureWac {
    static let version = "v1.1.7.4"
    static let plainLen = 64

    private static let hashSeed1: UInt32 = 0x4d5e6f71
    private static let hashSeed2: UInt32 = 0x00026af3
    private static let fkMod: [UInt32] = [0x07a4afdc, 0x07386c60, 0xa4542b35, 0xb5dc0d40]
    private static let scramblePeriod: UInt64 = 15_360_000
    private static let scrambleXor: UInt32 = 0x84a4d3b2
    private static let mixM1: UInt32 = 0x9e3779b1
    private static let mixM2: UInt32 = 0x85ebca77
    private static let swapConsts: [(UInt32, UInt32)] = [
        (0x9e3779b1, 0x00000000),
        (0xffe6cc61, 0x85ebca77),
        (0xcc042811, 0x0821d035),
    ]
    private static let uuidSeedXor: UInt64 = 0xdeadbeefcafebabe
    private static let uuidA: [(UInt64, UInt64)] = [
        (0x5851f42d4c957f2d, 0x0000000000000001),
        (0x685f98a2018fade9, 0x5851f42d4c957f2e),
        (0x0b046976f22528f5, 0xc0b18ccf4e252d17),
        (0xfb4d3ae39272be11, 0xcbb5f646404a560c),
        (0x696d29da565ad7fd, 0xc7033129d2bd141d),
        (0xf08d02b0115f7a79, 0x30705b042917ec1a),
    ]
    private static let wrapLimit = 262_143
    private static let wrapTo = 12_345
    private static let maxSessions = 4096
    private static let lock = NSLock()
    private static var sessions: [String: (next: Int, lastUsed: TimeInterval)] = [:]

    static func resetCallSeq(_ did: String? = nil) {
        lock.lock()
        defer { lock.unlock() }
        if let did, !did.isEmpty {
            sessions.removeValue(forKey: did)
        } else {
            sessions.removeAll()
        }
    }

    static func peekCallSeq(_ did: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return sessions[did]?.next ?? 1
    }

    static func nextCallSeq(_ did: String) -> Int {
        if did.isEmpty { return 1 }
        lock.lock()
        defer { lock.unlock() }
        var s = sessions[did] ?? (next: 1, lastUsed: 0)
        var n = s.next
        if n > wrapLimit { n = wrapTo }
        s.next = n + 1 > wrapLimit ? wrapTo : n + 1
        s.lastUsed = Date().timeIntervalSince1970
        sessions[did] = s
        if sessions.count > maxSessions {
            let stale = sessions.sorted { $0.value.lastUsed < $1.value.lastUsed }
            for i in 0..<(stale.count - maxSessions) {
                sessions.removeValue(forKey: stale[i].key)
            }
        }
        return n
    }

    static func uuid(nowMs: Int64, callSeq: Int) -> String {
        let t = UInt64(bitPattern: nowMs) &* 1000
        let seed = t ^ uuidSeedXor
        let a = uuidA.map { seed &* $0.0 &+ $0.1 }
        let h0 = highByte(a[0])
        let h1 = highByte(a[1])
        let h2 = highByte(a[2])
        let h3 = highByte(a[3])
        let h4 = highByte(a[4])
        let h5 = highByte(a[5])
        let g = UInt32(truncatingIfNeeded: callSeq)
        func tb(_ sh: UInt64) -> UInt8 { UInt8(truncatingIfNeeded: t >> sh) }
        let bytes: [UInt8] = [
            highByte(t ^ a[0]),
            h1 ^ tb(48),
            h2 ^ tb(40),
            h3 ^ tb(32),
            h0,
            h1,
            UInt8((((g >> 8) & 0x0f) | 0x40) & 0xff),
            h4 ^ tb(24),
            UInt8((((g >> 12) & 0x3f) | 0x80) & 0xff),
            UInt8((UInt32(h0) ^ (g & 0xff) ^ UInt32(tb(16))) & 0xff),
            h2,
            h3,
            h5 ^ tb(8),
            h4,
            UInt8(((g & 0xff) ^ UInt32(h0)) & 0xff),
            h5,
        ]
        let hex = bytes.map { String(format: "%02x", $0) }
        return [
            hex[0...3].joined(),
            hex[4...5].joined(),
            hex[6...7].joined(),
            hex[8...9].joined(),
            hex[10...15].joined(),
        ].joined(separator: "-")
    }

    static func callSeq(fromUUID uuid: String) -> Int? {
        let raw = uuid.replacingOccurrences(of: "-", with: "")
        guard raw.count == 32, raw.allSatisfy({ $0.isHexDigit }) else { return nil }
        func at(_ i: Int) -> Int {
            let s = raw.index(raw.startIndex, offsetBy: i * 2)
            let e = raw.index(s, offsetBy: 2)
            return Int(raw[s..<e], radix: 16) ?? 0
        }
        let b4 = at(4), b6 = at(6), b8 = at(8), b14 = at(14)
        return (b4 ^ b14) | ((b6 & 0x0f) << 8) | ((b8 & 0x3f) << 12)
    }

    static func keyBuffer32(_ uuid: String) -> [UInt32] {
        let b = [UInt8](uuid.utf8)
        let n = b.count
        return [
            hashFwd(b, 0), hashFwd(b, 1), hashFwd(b, 2), hashFwd(b, 3),
            hashBwd(b, n - 1), hashBwd(b, n - 2), hashBwd(b, n - 3), hashBwd(b, n - 4),
        ]
    }

    static func keyBufferHex(_ uuid: String) -> String {
        let kb = keyBuffer32(uuid)
        var out = [UInt8](repeating: 0, count: 32)
        for i in 0..<8 {
            let w = kb[i]
            out[i * 4] = UInt8(truncatingIfNeeded: w)
            out[i * 4 + 1] = UInt8(truncatingIfNeeded: w >> 8)
            out[i * 4 + 2] = UInt8(truncatingIfNeeded: w >> 16)
            out[i * 4 + 3] = UInt8(truncatingIfNeeded: w >> 24)
        }
        return SM4.hexEncode(out)
    }

    static func compute(did: String, sign: String, nowMs: Int64, callSeq: Int, hasEnv: Int = 0) -> String {
        let uuid = uuid(nowMs: nowMs, callSeq: callSeq)
        let body = bodyBytes(uuid: uuid, plain: sign + did, nowMs: nowMs).base64EncodedString()
        return "{\"uuid\":\"\(uuid)\",\"body\":\"\(body)\",\"has_env\":\(hasEnv)}"
    }

    static func run(did: String, sign: String, nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000), hasEnv: Int = 0) -> String? {
        if did.isEmpty || sign.isEmpty { return nil }
        return compute(did: did, sign: sign, nowMs: nowMs, callSeq: nextCallSeq(did), hasEnv: hasEnv)
    }

    static func decryptBody(uuid: String, bodyBase64: String, nowMs: Int64) -> String? {
        guard let raw = Data(base64Encoded: bodyBase64), raw.count >= 4 else { return nil }
        let bytes = [UInt8](raw)
        let declared = Int(bytes[0]) | (Int(bytes[1]) << 8) | (Int(bytes[2]) << 16) | (Int(bytes[3]) << 24)
        let body = Array(bytes.dropFirst(4))
        guard declared == body.count else { return nil }
        let ks = keystream(uuid: uuid, len: body.count, nowMs: nowMs)
        var scram = [UInt8](repeating: 0, count: body.count)
        for i in 0..<body.count { scram[i] = body[i] ^ ks[i] }
        let p = scramblePerm(nowMs: nowMs, len: body.count)
        var out = [UInt8](repeating: 0, count: body.count)
        for i in 0..<body.count { out[p[i]] = scram[i] }
        return String(bytes: out, encoding: .isoLatin1)
    }

    private static func highByte(_ v: UInt64) -> UInt8 {
        UInt8(truncatingIfNeeded: v >> 56)
    }

    private static func hashFwd(_ bytes: [UInt8], _ start: Int) -> UInt32 {
        guard start >= 0, start < bytes.count else { return 0 }
        var h = (UInt32(bytes[start]) &+ hashSeed1) ^ hashSeed2
        if start + 1 < bytes.count {
            for i in (start + 1)..<bytes.count {
                let t = h &* 31 &+ UInt32(bytes[i])
                h = t ^ (t >> 13)
            }
        }
        return h
    }

    private static func hashBwd(_ bytes: [UInt8], _ from: Int) -> UInt32 {
        guard from >= 0, from < bytes.count else { return 0 }
        var h = (UInt32(bytes[from]) &+ hashSeed1) ^ hashSeed2
        if from > 0 {
            for i in stride(from: from - 1, through: 0, by: -1) {
                let t = h &* 31 &+ UInt32(bytes[i])
                h = t ^ (t >> 13)
            }
        }
        return h
    }

    private static func key16(_ uuid: String) -> [UInt8] {
        let kb = keyBuffer32(uuid)
        var key = [UInt8](repeating: 0, count: 16)
        for i in 0..<4 {
            let w = kb[i]
            key[i * 4] = UInt8(truncatingIfNeeded: w >> 24)
            key[i * 4 + 1] = UInt8(truncatingIfNeeded: w >> 16)
            key[i * 4 + 2] = UInt8(truncatingIfNeeded: w >> 8)
            key[i * 4 + 3] = UInt8(truncatingIfNeeded: w)
        }
        return key
    }

    private static func nonce12(uuid: String) -> [UInt8] {
        let kb = keyBuffer32(uuid)
        let key = key16(uuid)
        var blk = [UInt8](repeating: 0, count: 16)
        for i in 0..<4 {
            let w = kb[i] ^ fkMod[i]
            blk[i * 4] = UInt8(truncatingIfNeeded: w >> 24)
            blk[i * 4 + 1] = UInt8(truncatingIfNeeded: w >> 16)
            blk[i * 4 + 2] = UInt8(truncatingIfNeeded: w >> 8)
            blk[i * 4 + 3] = UInt8(truncatingIfNeeded: w)
        }
        return Array(SM4.encryptBlock(blk, key: key).prefix(12))
    }

    private static func keystream(uuid: String, len: Int, nowMs: Int64) -> [UInt8] {
        _ = nowMs
        let key = key16(uuid)
        let nc = nonce12(uuid: uuid)
        let blocks = (len + 15) / 16
        var out = [UInt8](repeating: 0, count: blocks * 16)
        var blk = [UInt8](repeating: 0, count: 16)
        for i in 0..<12 { blk[i] = nc[i] }
        for j in 0..<blocks {
            let c = UInt32(j)
            blk[12] = UInt8(truncatingIfNeeded: c >> 24)
            blk[13] = UInt8(truncatingIfNeeded: c >> 16)
            blk[14] = UInt8(truncatingIfNeeded: c >> 8)
            blk[15] = UInt8(truncatingIfNeeded: c)
            let enc = SM4.encryptBlock(blk, key: key)
            for i in 0..<16 { out[j * 16 + i] = enc[i] }
        }
        return Array(out.prefix(len))
    }

    static func scrambleIndex(_ nowMs: Int64) -> Int {
        Int(UInt64(bitPattern: nowMs) / scramblePeriod)
    }

    private static func mix32(_ x: UInt32) -> UInt32 {
        var h = x &* mixM1
        h = h ^ (h >> 13)
        h = h &* mixM2
        return h ^ (h >> 16)
    }

    static func scramblePerm(nowMs: Int64, len: Int = 64) -> [Int] {
        let idx = UInt32(truncatingIfNeeded: scrambleIndex(nowMs))
        let h = mix32(idx ^ scrambleXor)
        var p = Array(0..<len)
        if len < 2 { return p }
        for (mul, add) in swapConsts {
            let t = h &* mul &+ add
            let i = Int(t % UInt32(len))
            var j = Int((UInt32(i) &+ ((t >> 13) % UInt32(len - 1)) &+ 1) % UInt32(len))
            if j == i { j = (j + 1) % len }
            p.swapAt(i, j)
        }
        return p
    }

    private static func bodyBytes(uuid: String, plain: String, nowMs: Int64) -> Data {
        let p = [UInt8](plain.utf8)
        let perm = scramblePerm(nowMs: nowMs, len: p.count)
        var scram = [UInt8](repeating: 0, count: p.count)
        for i in 0..<p.count { scram[i] = p[perm[i]] }
        let ks = keystream(uuid: uuid, len: p.count, nowMs: nowMs)
        var out = [UInt8](repeating: 0, count: 4 + p.count)
        let n = UInt32(p.count)
        out[0] = UInt8(truncatingIfNeeded: n)
        out[1] = UInt8(truncatingIfNeeded: n >> 8)
        out[2] = UInt8(truncatingIfNeeded: n >> 16)
        out[3] = UInt8(truncatingIfNeeded: n >> 24)
        for i in 0..<p.count { out[4 + i] = scram[i] ^ ks[i] }
        return Data(out)
    }
}
