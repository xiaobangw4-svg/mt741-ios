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
        let data = Data(plaintext.utf8)
        var out = Data(count: data.count + kCCBlockSizeAES128)
        var outLen = 0
        let status = data.withUnsafeBytes { inBytes in
            aesKey.withUnsafeBytes { keyBytes in
                aesIV.withUnsafeBytes { ivBytes in
                    out.withUnsafeMutableBytes { outBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress, kCCKeySizeAES256,
                            ivBytes.baseAddress,
                            inBytes.baseAddress, data.count,
                            outBytes.baseAddress, out.count,
                            &outLen
                        )
                    }
                }
            }
        }
        precondition(status == kCCSuccess, "AES encrypt failed \(status)")
        return out.prefix(outLen).base64EncodedString()
    }

    static func decrypt(_ b64: String) -> String {
        guard let data = Data(base64Encoded: b64) else { return "" }
        var out = Data(count: data.count + 16)
        var outLen = 0
        let status = data.withUnsafeBytes { inBytes in
            aesKey.withUnsafeBytes { keyBytes in
                aesIV.withUnsafeBytes { ivBytes in
                    out.withUnsafeMutableBytes { outBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress, kCCKeySizeAES256,
                            ivBytes.baseAddress,
                            inBytes.baseAddress, data.count,
                            outBytes.baseAddress, out.count,
                            &outLen
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { return "" }
        return String(data: out.prefix(outLen), encoding: .utf8) ?? ""
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
