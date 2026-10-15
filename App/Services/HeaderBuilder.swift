import Foundation

enum HeaderBuilder {
    static let order = [
        "Content-Web-Bb", "Cookie", "X-Requested-With", "User-Agent", "Referer",
        "Origin", "MT-K", "Sec-Fetch-Dest", "Sec-Fetch-Site", "MT-Info",
        "Connection", "x-csrf-token", "MT-APP-Version", "Sdk-Ver-Bb",
        "Accept-Language", "MT-Device-ID", "Content-Hh-Bb", "Accept",
        "Content-Type", "Accept-Encoding", "MT-V", "Sec-Fetch-Mode",
    ]
    /// Official 2026-10-03 H5 rush: Device, Token, _d_u, _sdk_v_, acw, cdn, YX=1. `_bs_device_id` comes from WK SDK, not this string.
    static let cookieOrder = [
        "MT-Device-ID-Wap", "MT-Token-Wap", "_d_u", "_sdk_v_",
        "acw_tc", "cdn_sec_tc", "YX_SUPPORT_WEBP",
    ]
    static let skipIfEmpty: Set<String> = ["Content-Web-Bb", "Content-Hh-Bb", "Cookie", "MT-Device-ID"]
    static let sdkVer = "V3.5.0_20260928.1_imaotai"
    static let mtInfo = "a3f9c2b8471de05f9b6c4e1287d5a9c1"
    static let origin = "https://h5.moutai519.com.cn"
    static let referer = "https://h5.moutai519.com.cn/mt/item/smsp-detail?appConfig=2_1_2"
    static let h5UA = CookieBridge.h5UA

    static func cookie(deviceId: String, token: String, dU: String = "", gdxid: String = "", webp: String? = "1") -> String {
        let tokenWap = token
        var values: [String: String] = [
            "MT-Device-ID-Wap": deviceId,
            "MT-Token-Wap": tokenWap,
            "_d_u": dU,
            "_sdk_v_": sdkVer,
        ]
        if let webp, !webp.isEmpty {
            values["YX_SUPPORT_WEBP"] = webp
        }
        _ = gdxid
        return cookieOrder.compactMap { key -> String? in
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
        gdxid: String = "",
        referer: String = HeaderBuilder.referer,
        bsDvid: String = "",
        h5Did: String = ""
    ) -> [(String, String)] {
        let raw: [String: String] = [
            "Content-Web-Bb": cwb,
            "Cookie": cookie(deviceId: deviceId, token: token, dU: dU, gdxid: gdxid),
            "X-Requested-With": "XMLHttpRequest",
            "User-Agent": CookieBridge.userAgent(deviceId: deviceId, bsDvid: bsDvid, h5Did: h5Did),
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
