import XCTest
@testable import MT741

final class RushCryptoTests: XCTestCase {
    func testMarshalAndAESMatchPythonFixture() {
        let plain = RushPlain(
            amount: "1",
            itemPriorityActId: "103783",
            deviceId: "ABCDEF-DEVICE-ID",
            userId: "9"
        )
        let marshaled = RushCrypto.marshal(plain)
        XCTAssertEqual(
            marshaled,
            #"{"amount":"1","itemCode":"741","itemPriorityActId":"103783","userInfoBaseContext":{"addressLat":"","addressLng":"","appUserAgent":"iOS;26.2.1;Apple;iPhone 13","deviceId":"ABCDEF-DEVICE-ID","mtr":"clips_OlU6TmFRag5rCXwbNAQ/Tz1SKlN8THcecBp/HGhHdg=="},"ydLogId":"","ydToken":"","userId":"9"}"#
        )
        let body = RushCrypto.rushBody(plain: plain)
        XCTAssertEqual(
            body,
            #"{"actParam":"5H3uMgV9PvEUwjTyYpUkSY65VylSG7gxqRKuAGMMtEMT6vsFsuspvfsWxnYNM7Y802k4eEaxjbX6mja5whZn4TiXY+zr8Zcqkjk7wjntcLAj3mNR+WVJ60e5pfaHsHclJDNrxIWmyZM9rlVmhzZPsWJ2Cky3kgBH/qRD4rbmdvlv0i3WLl/PQwcDj/H27KVzT6zXT1JdJIlUyGIH5oFk6dV5U1d9QSMQ2O0Vz2LVsSz7qgLenbl+xsDlXtF19UMoe8Puj0SxCW/bZ4+4JOhEMecdUsbwjjj64AVLfdkG7x1XP9n3A2R8sGGepFQshycdE+E2jpTbDDLhILRbLoikw3e5hdPzt10db0koKbM6qwyjiY/tPp3Ptycg2CdGuspnVD3o+OU4JoDck5Pi4ewhtA==","v":"0003"}"#
        )
        XCTAssertFalse(body.contains("cardBindingPay"))
        XCTAssertTrue(body.contains("\"v\":\"0003\""))
        XCTAssertEqual(RushCrypto.decrypt(RushCrypto.encrypt(marshaled)), marshaled)
        XCTAssertEqual(RushCrypto.orderKey.count, 32)
        XCTAssertEqual(RushCrypto.orderIV.count, 16)
    }

    func testHeaderSkipsEmptyCWB() {
        let headers = HeaderBuilder.headers(
            deviceId: "DEV",
            token: "tok",
            mtK: "1",
            mtV: "2",
            cwb: ""
        )
        XCTAssertFalse(headers.contains { $0.0 == "Content-Web-Bb" })
        XCTAssertTrue(headers.contains { $0.0 == "Cookie" && $0.1.contains("MT-Token-Wap=tok") })
        XCTAssertTrue(headers.contains { $0.0 == "Cookie" && $0.1.contains("YX_SUPPORT_WEBP=0") })
        XCTAssertFalse(headers.contains { $0.0 == "Cookie" && $0.1.contains("gdxidpyhxdE") })
        XCTAssertFalse(headers.contains { $0.0 == "Cookie" && $0.1.contains("_bs_device_id") })
        XCTAssertTrue(headers.contains { $0.0 == "x-csrf-token" && $0.1.isEmpty })
        let withCWB = HeaderBuilder.headers(deviceId: "DEV", token: "tok", mtK: "1", mtV: "2", cwb: "abc")
        XCTAssertEqual(withCWB.first?.0, "Content-Web-Bb")
        XCTAssertTrue(headers.contains { $0.0 == "User-Agent" && !$0.1.contains("BS-DVID") })
        let token = String(repeating: "F", count: 86)
        let withDvid = HeaderBuilder.headers(deviceId: "DEV", token: "tok", mtK: "1", mtV: "2", cwb: "abc", bsDvid: token)
        XCTAssertTrue(withDvid.contains { $0.0 == "User-Agent" && $0.1.contains("BS-DVID/\(token)") })
    }
}
