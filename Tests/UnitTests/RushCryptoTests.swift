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
            #"{"amount":"1","itemCode":"741","itemPriorityActId":"103783","userInfoBaseContext":{"addressLat":"","addressLng":"","appUserAgent":"iOS;18.7;Apple;iPhone","deviceId":"ABCDEF-DEVICE-ID","mtr":""},"ydLogId":"","ydToken":"","userId":"9"}"#
        )
        let body = RushCrypto.rushBody(plain: plain)
        XCTAssertEqual(
            body,
            #"{"actParam":"5H3uMgV9PvEUwjTyYpUkSY65VylSG7gxqRKuAGMMtEMT6vsFsuspvfsWxnYNM7Y802k4eEaxjbX6mja5whZn4TiXY+zr8Zcqkjk7wjntcLAj3mNR+WVJ60e5pfaHsHclJDNrxIWmyZM9rlVmhzZPsWJ2Cky3kgBH/qRD4rbmdvlNtM8AXR5+fOkPyyJ3iYsN9/k2szGv5yZtZhi7Vx3jf1OPOB9Mu/w2qqs0pOPPMTkUSiS97D6CHvIHby8HfoDeJqbAVojb9Pg746PfEwANQg8cKQZGVRQqlMoypw1/6vRY+bbVCaGkY5XDg2yI5SMC","v":"0003"}"#
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
        let withCWB = HeaderBuilder.headers(deviceId: "DEV", token: "tok", mtK: "1", mtV: "2", cwb: "abc")
        XCTAssertEqual(withCWB.first?.0, "Content-Web-Bb")
    }
}
