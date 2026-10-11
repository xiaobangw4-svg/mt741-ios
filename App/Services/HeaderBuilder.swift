import Foundation

enum HeaderBuilder {
    static let order = [
        "Content-Web-Bb", "Cookie", "X-Requested-With", "User-Agent", "Referer",
        "Origin", "MT-K", "Sec-Fetch-Dest", "Sec-Fetch-Site", "MT-Info",
        "Connection", "x-csrf-token", "MT-APP-Version", "Sdk-Ver-Bb",
        "Accept-Language", "MT-Device-ID", "Content-Hh-Bb", "Accept",
        "Content-Type", "Accept-Encoding", "MT-V", "Sec-Fetch-Mode",
    ]
    static let cookieOrder = [
        "_d_u", "MT-Device-ID-Wap", "MT-Token-Wap", "_sdk_v_",
        "acw_tc", "cdn_sec_tc", "_bs_device_id",
    ]
    static let skipIfEmpty: Set<String> = ["Content-Web-Bb", "Content-Hh-Bb", "Cookie", "MT-Device-ID"]
    static let sdkVer = "V3.5.0_20260928.1_imaotai"
    static let mtInfo = "a3f9c2b8471de05f9b6c4e1287d5a9c1"
    static let origin = "https://h5.moutai519.com.cn"
    static let referer = "https://h5.moutai519.com.cn/mt/item/smsp-detail?appConfig=2_1_2"
    static let h5UA = CookieBridge.h5UA

    static func cookie(deviceId: String, token: String, dU: String = "") -> String {
        let tokenWap = token
        let values: [String: String] = [
            "_d_u": dU,
            "MT-Device-ID-Wap": deviceId,
            "MT-Token-Wap": tokenWap,
            "_sdk_v_": sdkVer,
        ]
        return cookieOrder.compactMap { key in
            let val = values[key] ?? ""
            return val.isEmpty ? nil : "\(key)=\(val)"
        }.joined(separator: "; ")
    }

    static func headers(
        deviceId: String,
        token: String,
        mtK: String,
        mtV: String,
        cwb: String,
        contentHh: String = "",
        dU: String = "",
        referer: String = HeaderBuilder.referer
    ) -> [(String, String)] {
        let raw: [String: String] = [
            "Content-Web-Bb": cwb,
            "Cookie": cookie(deviceId: deviceId, token: token, dU: dU),
            "X-Requested-With": "XMLHttpRequest",
            "User-Agent": h5UA,
            "Referer": referer,
            "Origin": origin,
            "MT-K": mtK,
            "Sec-Fetch-Dest": "empty",
            "Sec-Fetch-Site": "same-origin",
            "MT-Info": mtInfo,
            "Connection": "keep-alive",
            "x-csrf-token": "",
            "MT-APP-Version": AuthDigest.appVersion,
            "Sdk-Ver-Bb": sdkVer,
            "Accept-Language": "zh-CN,zh-Hans;q=0.9",
            "MT-Device-ID": deviceId,
            "Content-Hh-Bb": contentHh,
            "Accept": "application/json, text/javascript, */*; q=0.01",
            "Content-Type": "application/json",
            "Accept-Encoding": "gzip, deflate, br",
            "MT-V": mtV,
            "Sec-Fetch-Mode": "cors",
        ]
        return order.compactMap { key in
            let val = raw[key] ?? ""
            if skipIfEmpty.contains(key), val.isEmpty { return nil }
            return (key, val)
        }
    }
}
