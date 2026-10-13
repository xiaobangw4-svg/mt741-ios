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
            #"{"amount":"1","itemCode":"741","itemPriorityActId":"103783","userInfoBaseContext":{"addressLat":"27.414705","addressLng":"105.380223","appUserAgent":"iOS;26.2.1;Apple;iPhone 13","deviceId":"ABCDEF-DEVICE-ID","mtr":"clips_OlU6TmFRag5rCXwbNAQ/Tz1SKlN8THcecBp/HGhHdg=="},"ydLogId":"","ydToken":"","userId":"9"}"#
        )
        let body = RushCrypto.rushBody(plain: plain)
        XCTAssertEqual(
            body,
            #"{"actParam":"5H3uMgV9PvEUwjTyYpUkSY65VylSG7gxqRKuAGMMtEMT6vsFsuspvfsWxnYNM7Y802k4eEaxjbX6mja5whZn4TiXY+zr8Zcqkjk7wjntcLAj3mNR+WVJ60e5pfaHsHclZzbz9ZlfHZF80S6KFuXA5EwvRIsiG8W0WVehe82BEo0JCaIzbRXnJR5sgHjN37Cr5PX1C/Q5srr8K2BroucQn7iR3Cf563fOi8kxv7G1IokGsT6Ua9oBq5QjLF6qbrx/A50ER6MbD+9fFkGHR5SMm4JIFcMHo4EUMwI1F9jp9PdlBIaxFXf/weQ4enbXGPSqk3JViLkvsPi2st+gf7ZCAyRQuKSuiLyVl9nNJoNQlflxn/F4610Mk7SohD+HrynnSQ+QLYprAJaXFwWzsS9MU9qZNaEOs0z5iJxBuj3eENQ=","v":"0003"}"#
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
