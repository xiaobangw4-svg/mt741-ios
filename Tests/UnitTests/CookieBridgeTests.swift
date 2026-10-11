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
        XCTAssertEqual(names, ["MT-Token-Wap", "MT-Device-ID-Wap"])
        XCTAssertTrue(cookies.contains { $0.name == "MT-Token-Wap" && $0.value == "wap-cookie" })
        XCTAssertTrue(cookies.contains { $0.name == "MT-Device-ID-Wap" && $0.value == "DEV-1" })
        XCTAssertTrue(cookies.contains { $0.domain == "h5.moutai519.com.cn" })
        XCTAssertFalse(cookies.contains { $0.name == "idCode" })
    }

    func testEmptySessionHasDeviceCookieOnly() {
        let cookies = CookieBridge.cookies(from: Session(deviceId: "DEV-2"))
        XCTAssertTrue(cookies.allSatisfy { $0.name == "MT-Device-ID-Wap" })
        XCTAssertEqual(Set(cookies.map(\.value)), ["DEV-2"])
    }
}
