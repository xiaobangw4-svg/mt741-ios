import XCTest
@testable import MT741

final class CookieBridgeTests: XCTestCase {
    func testLoggedInCookiesCarryTokenAndDevice() {
        let session = Session(
            mobile: "19000811875",
            deviceId: "DEV-1",
            userId: "9",
            token: "tok",
            cookie: "wap-cookie"
        )
        let cookies = CookieBridge.cookies(from: session)
        let names = Set(cookies.map(\.name))
        XCTAssertEqual(names, ["MT-Token-Wap", "MT-Device-ID-Wap", "YX_SUPPORT_WEBP"])
        XCTAssertTrue(cookies.contains { $0.name == "MT-Token-Wap" && $0.value == "wap-cookie" })
        XCTAssertTrue(cookies.contains { $0.name == "MT-Device-ID-Wap" && $0.value == "DEV-1" })
        XCTAssertTrue(cookies.contains { $0.name == "YX_SUPPORT_WEBP" && $0.value == "0" && $0.domain == CookieBridge.h5Host })
        XCTAssertTrue(cookies.contains { $0.domain == "h5.moutai519.com.cn" })
        XCTAssertFalse(cookies.contains { $0.name == "idCode" })
        XCTAssertFalse(cookies.contains { CookieBridge.isRushDropCookie($0.name) })
    }

    func testEmptySessionKeepsDeviceAndWebpZero() {
        let cookies = CookieBridge.cookies(from: Session(deviceId: "DEV-2"))
        let names = Set(cookies.map(\.name))
        XCTAssertEqual(names, ["MT-Device-ID-Wap", "YX_SUPPORT_WEBP"])
        XCTAssertTrue(cookies.contains { $0.name == "MT-Device-ID-Wap" && $0.value == "DEV-2" })
        XCTAssertTrue(cookies.contains { $0.name == "YX_SUPPORT_WEBP" && $0.value == "0" })
    }

    func testCookiesUseJWTDeviceIdWhenSessionFieldDrifted() {
        let jwt = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJtdCIsImV4cCI6MTc5MzQ1MTE5NCwidXNlcklkIjoxMDY1NTAzNTAzLCJkZXZpY2VJZCI6IjAzRjMxQzdBLUVFNDctNDI4Ny1CNzFGLUE3ODdDNjlBMkExQiIsImlhdCI6MTc5MDg1OTE5NH0.h6_StStFuJ8V-0F5aqXeCSG8AYG5emqpa0sTqHo3uU0"
        let cookies = CookieBridge.cookies(from: Session(
            deviceId: "WRONG",
            userId: "1",
            token: "app",
            cookie: jwt
        ))
        XCTAssertTrue(cookies.contains {
            $0.name == "MT-Device-ID-Wap" && $0.value == "03F31C7A-EE47-4287-B71F-A787C69A2A1B"
        })
        XCTAssertTrue(cookies.contains { $0.name == "MT-Token-Wap" && $0.value == jwt })
    }

    func testUserAgentLooksLikeOfficialAppWebView() {
        let ua = CookieBridge.userAgent(deviceId: "DEV-1")
        XCTAssertTrue(ua.contains("moutaiapp/\(AuthDigest.appVersion)"))
        XCTAssertTrue(ua.contains("device-id/\(AuthDigest.md5Hex("DEV-1"))"))
        XCTAssertFalse(ua.contains("BS-DVID"))
        let token = String(repeating: "A", count: 86)
        let withDvid = CookieBridge.userAgent(deviceId: "DEV-1", bsDvid: token)
        XCTAssertTrue(withDvid.contains("BS-DVID/\(token)"))
        XCTAssertTrue(CookieBridge.h5UA.contains("device-id/"))
        XCTAssertFalse(CookieBridge.h5UA.contains("BS-DVID"))
        let sessionUA = CookieBridge.userAgent(from: Session(deviceId: "DEV-1", bsDvid: token))
        XCTAssertTrue(sessionUA.contains("BS-DVID/\(token)"))
    }

    func testSanitizeBsDvidRejectsBidAndAcceptsLongTokenOrUA() {
        XCTAssertEqual(CookieBridge.sanitizeBsDvid(""), "")
        XCTAssertEqual(CookieBridge.sanitizeBsDvid("tok"), "")
        XCTAssertEqual(CookieBridge.sanitizeBsDvid("bid-3860976371971-fb35-850f"), "")
        XCTAssertEqual(CookieBridge.sanitizeBsDvid("BID-3860976371971-fb35-850f"), "")
        let token = String(repeating: "B", count: 86)
        XCTAssertEqual(CookieBridge.sanitizeBsDvid("  \(token)  "), token)
        let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 moutaiapp/1.9.14 device-id/ca35c580c5c1cf5ec4b5bbd06b39843b BS-DVID/\(token) extra"
        XCTAssertEqual(CookieBridge.sanitizeBsDvid(ua), token)
        XCTAssertFalse(CookieBridge.userAgent(deviceId: "DEV-1", bsDvid: "bid-short").contains("BS-DVID"))
        var request = URLRequest(url: URL(string: "https://app.moutai519.com.cn/")!)
        CookieBridge.setNativeHeader(&request, bsDvid: "bid-nope")
        XCTAssertNil(request.value(forHTTPHeaderField: "BS-DVID"))
        CookieBridge.setNativeHeader(&request, bsDvid: token)
        XCTAssertEqual(request.value(forHTTPHeaderField: "BS-DVID"), token)
    }

    func testRushDropsOfficialOmittedCookies() {
        XCTAssertTrue(CookieBridge.isRushDropCookie("gdxidpyhxdE"))
        XCTAssertTrue(CookieBridge.isRushDropCookie("_bs_device_id"))
        XCTAssertTrue(CookieBridge.isRushDropCookie("__snaker__id"))
        XCTAssertFalse(CookieBridge.isRushDropCookie("_d_u"))
        XCTAssertFalse(CookieBridge.isRushDropCookie("MT-Token-Wap"))
        XCTAssertFalse(CookieBridge.isRushDropCookie("YX_SUPPORT_WEBP"))
    }
}
