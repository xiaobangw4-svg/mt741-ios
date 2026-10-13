import CommonCrypto
import Foundation

struct RushPlain: Equatable {
    var amount: String
    var itemCode: String = Product.sku741.sku
    var itemPriorityActId: String
    var deviceId: String
    var appUserAgent: String = AuthDigest.nativeUA
    var mtr: String = AuthDigest.mtR
    var ydLogId: String = ""
    var ydToken: String = ""
    var userId: String = ""
    var shopId: String = ""
}

enum RushCrypto {
    static let aesKey = Data("3a79d$e4c2169a#fbd24c583ae71c0b9".utf8)
    static let aesIV = Data("7392645081974362".utf8)
    static let orderKey = Data("qbhajinldepmucsonaaaccgypwuvcjaa".utf8)
    static let orderIV = Data("2018534749963515".utf8)
    static let vField = "0003"
    static let officialURL = URL(string: "https://h5.moutai519.com.cn/xhr/front/trade/priority/rushPurchase/hot/branch/one")!

    static func marshal(_ plain: RushPlain) -> String {
        var ctx = "{"
        ctx += "\"addressLat\":\"\","
        ctx += "\"addressLng\":\"\","
        ctx += "\"appUserAgent\":\(jsonString(plain.appUserAgent)),"
        ctx += "\"deviceId\":\(jsonString(plain.deviceId)),"
        ctx += "\"mtr\":\(jsonString(plain.mtr))"
        ctx += "}"
        var body = "{"
        body += "\"amount\":\(jsonString(plain.amount)),"
        body += "\"itemCode\":\(jsonString(plain.itemCode)),"
        body += "\"itemPriorityActId\":\(jsonString(plain.itemPriorityActId)),"
        body += "\"userInfoBaseContext\":\(ctx),"
        body += "\"ydLogId\":\(jsonString(plain.ydLogId)),"
        body += "\"ydToken\":\(jsonString(plain.ydToken))"
        if !plain.userId.isEmpty {
            body += ",\"userId\":\(jsonString(plain.userId))"
        }
        if !plain.shopId.isEmpty {
            body += ",\"shopId\":\(jsonString(plain.shopId))"
        }
        body += "}"
        return body
    }

    static func encrypt(_ plaintext: String, key: Data = aesKey, iv: Data = aesIV) -> String {
        crypt(Data(plaintext.utf8), operation: CCOperation(kCCEncrypt), key: key, iv: iv).base64EncodedString()
    }

    static func decrypt(_ b64: String, key: Data = aesKey, iv: Data = aesIV) -> String {
        let flat = b64.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
        guard let data = Data(base64Encoded: flat) else { return "" }
        return String(data: crypt(data, operation: CCOperation(kCCDecrypt), key: key, iv: iv), encoding: .utf8) ?? ""
    }

    static func mimeWrap(_ b64: String) -> String {
        if b64.isEmpty { return "\n" }
        var lines: [String] = []
        var i = b64.startIndex
        while i < b64.endIndex {
            let j = b64.index(i, offsetBy: 76, limitedBy: b64.endIndex) ?? b64.endIndex
            lines.append(String(b64[i..<j]))
            i = j
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func encryptOrderMIME(_ plaintext: String) -> String {
        mimeWrap(encrypt(plaintext, key: orderKey, iv: orderIV))
    }

    private static func crypt(_ data: Data, operation: CCOperation, key: Data = aesKey, iv: Data = aesIV) -> Data {
        let inCount = data.count
        let outCapacity = inCount + kCCBlockSizeAES128
        var out = Data(count: outCapacity)
        var outLen = 0
        let status: CCCryptorStatus = data.withUnsafeBytes { inBytes in
            key.withUnsafeBytes { keyBytes in
                iv.withUnsafeBytes { ivBytes in
                    out.withUnsafeMutableBytes { outBytes in
                        CCCrypt(
                            operation,
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress, kCCKeySizeAES256,
                            ivBytes.baseAddress,
                            inBytes.baseAddress, inCount,
                            outBytes.baseAddress, outCapacity,
                            &outLen
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { return Data() }
        return out.prefix(outLen)
    }

    static func rushBody(plain: RushPlain) -> String {
        let act = encrypt(marshal(plain))
        return "{\"actParam\":\(jsonString(act)),\"v\":\(jsonString(vField))}"
    }

    static func jsonString(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
