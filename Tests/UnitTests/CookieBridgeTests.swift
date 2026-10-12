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
        let withDvid = CookieBridge.userAgent(deviceId: "DEV-1", bsDvid: "tok")
        XCTAssertTrue(withDvid.contains("BS-DVID/tok"))
        XCTAssertTrue(CookieBridge.h5UA.contains("device-id/"))
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
