import CommonCrypto
import Foundation

struct RushPlain: Equatable {
    var amount: String
    var itemCode: String = Product.sku741.sku
    var itemPriorityActId: String
    var deviceId: String
    var appUserAgent: String = AuthDigest.nativeUA
    var mtr: String = ""
    var ydLogId: String = ""
    var ydToken: String = ""
    var userId: String = ""
    var shopId: String = ""
}

enum RushCrypto {
    static let aesKey = Data("3a79d$e4c2169a#fbd24c583ae71c0b9".utf8)
    static let aesIV = Data("7392645081974362".utf8)
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

    static func encrypt(_ plaintext: String) -> String {
        crypt(Data(plaintext.utf8), operation: CCOperation(kCCEncrypt)).base64EncodedString()
    }

    static func decrypt(_ b64: String) -> String {
        guard let data = Data(base64Encoded: b64) else { return "" }
        return String(data: crypt(data, operation: CCOperation(kCCDecrypt)), encoding: .utf8) ?? ""
    }

    private static func crypt(_ data: Data, operation: CCOperation) -> Data {
        let inCount = data.count
        let outCapacity = inCount + kCCBlockSizeAES128
        var out = Data(count: outCapacity)
        var outLen = 0
        let status: CCCryptorStatus = data.withUnsafeBytes { inBytes in
            aesKey.withUnsafeBytes { keyBytes in
                aesIV.withUnsafeBytes { ivBytes in
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
