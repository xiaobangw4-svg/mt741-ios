import XCTest
@testable import MT741

final class RushHitTests: XCTestCase {
    func testParse2000And4025() {
        let hit = RushHit.parse(#"{"code":2000,"data":{"hasGain":true,"priorityRecordId":"99","orderId":"637"}}"#)
        XCTAssertEqual(hit.code, 2000)
        XCTAssertTrue(hit.isHit)
        XCTAssertEqual(hit.priorityRecordId, "99")
        XCTAssertEqual(hit.orderId, "637")
        XCTAssertTrue(hit.canCompose)
        XCTAssertFalse(hit.needsYidun)
        let yidun = RushHit.parse(#"{"code":4025,"message":"需要验证"}"#)
        XCTAssertEqual(yidun.code, 4025)
        XCTAssertTrue(yidun.needsYidun)
        XCTAssertFalse(yidun.isHit)
    }

    func testCaptchaIdFor741() {
        XCTAssertEqual(YidunClient.captchaId741, "1e1ea52963a94c21b0babc42b2b5b910")
        XCTAssertEqual(YidunClient.verifyURL.host, "h5.moutai519.com.cn")
    }

    func testPaySecurityIDAndExtractAlipays() {
        let sec = PayClient.securityID(tn: "TN1", ts: "1000")
        XCTAssertEqual(sec, AuthDigest.md5Hex("TN1" + "1000" + PayClient.appKey))
        XCTAssertEqual(sec.count, 32)
        let url = PayClient.extractPayURL([
            "AUTH_CODE": "alipays://platformapi/startapp?appId=20000067&foo=1",
        ])
        XCTAssertEqual(url?.scheme, "alipays")
        XCTAssertNil(PayClient.extractPayURL([
            "url": "https://mclient.alipay.com/cashierRoutePay.htm?x=1",
        ]))
        XCTAssertEqual(
            PayClient.extractBankPageURL(["AUTH_CODE": ["PageURL": "https://bank.example/pay"]])?.host,
            "bank.example"
        )
        let sm4 = SM4.encryptECBBase64("1000", key: PayClient.sm4Key)
        XCTAssertFalse(sm4.isEmpty)
        XCTAssertEqual(Data(base64Encoded: sm4)?.count, 16)
    }
}
