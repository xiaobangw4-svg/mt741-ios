import XCTest
@testable import MT741

final class AccountOpsTests: XCTestCase {
    func testParseRealNameAuthStatus1() {
        let json: [String: Any] = [
            "code": 2000,
            "data": [
                "authStatus": 1,
                "idCardNo": "522401*********038",
                "idCardName": "王**",
                "did": "did:mt:1:0xabc",
            ],
        ]
        let info = AccountOps.parseRealName(json)
        XCTAssertTrue(info.ok)
        XCTAssertEqual(info.authStatus, 1)
        XCTAssertEqual(info.stateText, "已实名")
        XCTAssertEqual(info.idCardNo, "522401*********038")
        XCTAssertTrue(info.message.contains("已实名"))
        XCTAssertTrue(info.message.contains("王**"))
    }

    func testParseRealNameMissingAuthStatusIsNotUnverified() {
        let json: [String: Any] = ["code": 2000, "data": [:]]
        let info = AccountOps.parseRealName(json)
        XCTAssertTrue(info.ok)
        XCTAssertEqual(info.authStatus, -1)
        XCTAssertEqual(info.stateText, "响应无authStatus字段")
        XCTAssertFalse(info.message.contains("未实名"))
    }

    func testParseRealNameZeroIsUnverified() {
        let info = AccountOps.parseRealName(["code": 2000, "data": ["authStatus": 0]])
        XCTAssertEqual(info.stateText, "未实名")
    }

    func testParseRealNameRejectsNon2000() {
        let info = AccountOps.parseRealName(["code": 4011, "message": "未登录"])
        XCTAssertFalse(info.ok)
        XCTAssertEqual(info.message, "未登录")
        XCTAssertEqual(info.authStatus, -1)
    }

    func testParseFindIdentityStatus1() {
        let json: [String: Any] = [
            "code": 2000,
            "data": [
                "status": 1,
                "name": "王**",
                "idCardNo": "522401*********038",
                "mobile": "181****8484",
                "haveSubmitNum": 1,
            ],
        ]
        let info = AccountOps.parseFindIdentity(json)
        XCTAssertTrue(info.ok)
        XCTAssertEqual(info.status, 1)
        XCTAssertEqual(info.stateText, "已找回")
        XCTAssertEqual(info.haveSubmitNum, 1)
        XCTAssertTrue(info.message.contains("原绑定 181****8484"))
    }

    func testRealNameBodyUsesIdCardNameAndCardType0() {
        let body = AccountOps.realNameBody(idCardNo: " 110101199001011234 ", idCardName: " 张三 ")
        XCTAssertEqual(JSONText.string(body["idCardNo"]), "110101199001011234")
        XCTAssertEqual(JSONText.string(body["idCardName"]), "张三")
        XCTAssertEqual(JSONText.int(body["cardType"]), 0)
        XCTAssertNil(body["name"])
    }

    func testFindIdentityBodyUsesNameNotIdCardName() {
        let body = AccountOps.findIdentityBody(idCardNo: "110101199001011234", name: "张三")
        XCTAssertEqual(JSONText.string(body["idCardNo"]), "110101199001011234")
        XCTAssertEqual(JSONText.string(body["name"]), "张三")
        XCTAssertNil(body["idCardName"])
        XCTAssertNil(body["cardType"])
    }

    func testValidateIdCardLength() {
        XCTAssertNotNil(AccountOps.validateIdCard(""))
        XCTAssertNotNil(AccountOps.validateIdCard("123"))
        XCTAssertNil(AccountOps.validateIdCard("110101199001011234"))
        XCTAssertNil(AccountOps.validateIdCard("110101199001011"))
        XCTAssertNil(AccountOps.validateIdCard("11010119900101123X"))
    }

    func testMaskIdCardDoesNotLeakFullNumber() {
        let full = "110101199001011234"
        let masked = AccountOps.maskIdCard(full)
        XCTAssertEqual(masked, "1101***********234")
        XCTAssertFalse(masked.contains("19900101"))
        XCTAssertEqual(AccountOps.maskIdCard(""), "")
    }

    func testCancelRequiresExactMobile() {
        let session = Session(mobile: "13800138000", userId: "1", token: "t")
        XCTAssertNil(AccountOps.requireCancelConfirm(typed: "13800138000", session: session))
        XCTAssertEqual(
            AccountOps.requireCancelConfirm(typed: "13800138001", session: session),
            "注销确认失败: 需传入与账号完全一致的手机号"
        )
        XCTAssertEqual(
            AccountOps.requireCancelConfirm(typed: "13800138000", session: Session()),
            "请先登录"
        )
    }

    func testFindIdentityHeadersSkipMTKAndCWB() {
        let session = Session(deviceId: "DEV", userId: "1", token: "tok", cookie: "ck")
        let headers = AccountOps.findIdentityHeaders(session: session)
        XCTAssertFalse(headers.contains { $0.0 == "MT-K" })
        XCTAssertFalse(headers.contains { $0.0 == "MT-V" })
        XCTAssertFalse(headers.contains { $0.0 == "Content-Web-Bb" })
        XCTAssertTrue(headers.contains { $0.0 == "Referer" && $0.1 == AccountOps.findReferer })
        XCTAssertTrue(headers.contains { $0.0 == "Cookie" && $0.1.contains("MT-Token-Wap=ck") })
        XCTAssertTrue(headers.contains { $0.0 == "Cookie" && $0.1.contains("YX_SUPPORT_WEBP=1") })
        XCTAssertEqual(AccountOps.findInfoURL.host, "h5.moutai519.com.cn")
        XCTAssertEqual(AccountOps.findSubmitURL.lastPathComponent, "findIdentity")
        XCTAssertEqual(AccountOps.realNameAuthURL.host, "app.moutai519.com.cn")
        XCTAssertTrue(AccountOps.cancelURL.path.contains("register/cancel"))
        XCTAssertTrue(AccountOps.realNameInfoURL.path.contains("getRealNameAuthInfo"))
    }

    func testSessionStillHasNoIdCode() {
        let keys = Session.CodingKeys.allCases.map(\.rawValue)
        XCTAssertFalse(keys.contains("idCode"))
        XCTAssertFalse(keys.contains("idCardNo"))
        XCTAssertFalse(keys.contains("id_card_no"))
    }
}
