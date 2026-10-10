import XCTest
@testable import MT741

final class AuthDigestTests: XCTestCase {
    func testVCodeMD5Fixture() {
        let digest = AuthDigest.vcodeMD5(mobile: "19000811875", timestamp: "1786632305010")
        XCTAssertEqual(digest, "8cad0779458c32bd9f15dd78c6ccee11")
    }

    func testBubbleSortAndMTVFixture() {
        let combined = "iOS" + "1786632305010" + "ABCDEF-DEVICE-ID" + "1.9.14"
        XCTAssertEqual(AuthDigest.bubbleSort(combined), "--..00011112334566789ABCCDDDEEEFIIOSVi")
        let mtv = AuthDigest.mtV(
            timestamp: "1786632305010",
            deviceId: "ABCDEF-DEVICE-ID",
            version: "1.9.14",
            suffix: "a"
        )
        XCTAssertEqual(mtv, "abe622e04e7cde34661aab5e2ea")
        XCTAssertEqual(mtv.count, 27)
    }

    func testValidateMobile() {
        XCTAssertEqual(AuthDigest.validateMobile("123"), "手机号须为 11 位数字")
        XCTAssertEqual(AuthDigest.validateMobile("abcdefghijk"), "手机号须为 11 位数字")
        XCTAssertNil(AuthDigest.validateMobile("19000811875"))
    }

    func testValidateVCode() {
        XCTAssertEqual(AuthDigest.validateVCode("  "), "请填写验证码")
        XCTAssertNil(AuthDigest.validateVCode("123456"))
    }
}
