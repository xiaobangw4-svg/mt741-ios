import Foundation

/// MurmurHash3 x64 128-bit. Bangcle `DeriveSm4Key` = hash(smk + "_bsdk_", seed=27).
enum MurmurHash3 {
    static func x64_128(_ data: String, seed: UInt32 = 27, maxLen: Int = 0, salt: String = "") -> String {
        var t = Array(data.utf8)
        if maxLen > 0, t.count > maxLen {
            t = Array(t.prefix(maxLen))
        }
        if !salt.isEmpty {
            t += Array(salt.utf8)
        }
        let length = t.count
        let nblocks = length / 16
        var h1 = UInt64(seed)
        var h2 = UInt64(seed)
        let c1: UInt64 = 0x87C37B91114253D5
        let c2: UInt64 = 0x4CF5AD432745937F
        if nblocks > 0 {
            for i in 0..<nblocks {
                let base = i * 16
                var k1 = load64(t, base)
                var k2 = load64(t, base + 8)
                k1 = k1 &* c1
                k1 = rotl(k1, 31)
                k1 = k1 &* c2
                h1 ^= k1
                h1 = rotl(h1, 27)
                h1 = h1 &+ h2
                h1 = h1 &* 5 &+ 0x52DCE729
                k2 = k2 &* c2
                k2 = rotl(k2, 33)
                k2 = k2 &* c1
                h2 ^= k2
                h2 = rotl(h2, 31)
                h2 = h2 &+ h1
                h2 = h2 &* 5 &+ 0x38495AB5
            }
        }
        let tailStart = nblocks * 16
        let rem = length - tailStart
        var k1: UInt64 = 0
        var k2: UInt64 = 0
        if rem >= 15 { k2 ^= UInt64(t[tailStart + 14]) << 48 }
        if rem >= 14 { k2 ^= UInt64(t[tailStart + 13]) << 40 }
        if rem >= 13 { k2 ^= UInt64(t[tailStart + 12]) << 32 }
        if rem >= 12 { k2 ^= UInt64(t[tailStart + 11]) << 24 }
        if rem >= 11 { k2 ^= UInt64(t[tailStart + 10]) << 16 }
        if rem >= 10 { k2 ^= UInt64(t[tailStart + 9]) << 8 }
        if rem >= 9 {
            k2 ^= UInt64(t[tailStart + 8])
            k2 = k2 &* c2
            k2 = rotl(k2, 33)
            k2 = k2 &* c1
            h2 ^= k2
        }
        if rem >= 8 { k1 ^= UInt64(t[tailStart + 7]) << 56 }
        if rem >= 7 { k1 ^= UInt64(t[tailStart + 6]) << 48 }
        if rem >= 6 { k1 ^= UInt64(t[tailStart + 5]) << 40 }
        if rem >= 5 { k1 ^= UInt64(t[tailStart + 4]) << 32 }
        if rem >= 4 { k1 ^= UInt64(t[tailStart + 3]) << 24 }
        if rem >= 3 { k1 ^= UInt64(t[tailStart + 2]) << 16 }
        if rem >= 2 { k1 ^= UInt64(t[tailStart + 1]) << 8 }
        if rem >= 1 {
            k1 ^= UInt64(t[tailStart])
            k1 = k1 &* c1
            k1 = rotl(k1, 31)
            k1 = k1 &* c2
            h1 ^= k1
        }
        h1 ^= UInt64(length)
        h2 ^= UInt64(length)
        h1 = h1 &+ h2
        h2 = h2 &+ h1
        h1 = fmix64(h1)
        h2 = fmix64(h2)
        h1 = h1 &+ h2
        h2 = h2 &+ h1
        return String(format: "%016llx%016llx", h1, h2)
    }

    private static func load64(_ b: [UInt8], _ i: Int) -> UInt64 {
        var v: UInt64 = 0
        for j in 0..<8 {
            v |= UInt64(b[i + j]) << (8 * j)
        }
        return v
    }

    private static func rotl(_ x: UInt64, _ r: UInt32) -> UInt64 {
        let n = r & 63
        if n == 0 { return x }
        return (x << n) | (x >> (64 - n))
    }

    private static func fmix64(_ k: UInt64) -> UInt64 {
        var k = k
        k ^= k >> 33
        k = k &* 0xFF51AFD7ED558CCD
        k ^= k >> 33
        k = k &* 0xC4CEB9FE1A85EC53
        k ^= k >> 33
        return k
    }
}
