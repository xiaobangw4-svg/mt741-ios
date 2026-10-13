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
        XCTAssertTrue(headers.contains { $0.0 == "User-Agent" && !$0.1.contains("BS-DVID") })
        let token = String(repeating: "E", count: 86)
        let withTok = AccountOps.findIdentityHeaders(session: Session(
            deviceId: "DEV", userId: "1", token: "tok", cookie: "ck", bsDvid: token
        ))
        XCTAssertTrue(withTok.contains { $0.0 == "User-Agent" && $0.1.contains("BS-DVID/\(token)") })
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

    func testDefaultAddressDraftIsBijieBihai() {
        let draft = AddressDraft()
        XCTAssertEqual(draft.provinceId, "520000000")
        XCTAssertEqual(draft.provinceName, "贵州省")
        XCTAssertEqual(draft.cityId, "520500000")
        XCTAssertEqual(draft.cityName, "毕节市")
        XCTAssertEqual(draft.districtId, "520502000")
        XCTAssertEqual(draft.districtName, "七星关区")
        XCTAssertEqual(draft.townId, "520502011")
        XCTAssertEqual(draft.townName, "碧海街道")
        XCTAssertTrue(draft.dft)
        XCTAssertEqual(draft.shipAddressId, 0)
        XCTAssertTrue(draft.summary.contains("新地址"))
        XCTAssertEqual(AccountOps.addressUpsertURL.path, "/xhr/front/user/address/ship/upsert")
        XCTAssertEqual(AccountOps.addressUpsertURL.host, "app.moutai519.com.cn")
    }

    func testValidateAddressRejectsShortNameAndEmptyRegion() {
        var draft = AddressDraft()
        draft.name = "张"
        draft.mobile = "19000811875"
        draft.address = "1号"
        XCTAssertEqual(AccountOps.validateAddress(draft), "收货人姓名过短")
        draft.name = "张三"
        draft.mobile = "123"
        XCTAssertEqual(AccountOps.validateAddress(draft), "收货手机号须为 11 位数字")
        draft.mobile = "19000811875"
        draft.address = ""
        XCTAssertEqual(AccountOps.validateAddress(draft), "省市区街道和详细地址都要填")
        draft.address = "碧海社区1号"
        XCTAssertNil(AccountOps.validateAddress(draft))
    }

    func testAddressDraftFromRowKeepsDefaultRegionWhenMissing() {
        let draft = AccountOps.addressDraft(
            from: [
                "shipAddressId": 37664847,
                "name": "李四",
                "mobile": "13800138000",
                "address": "测试路1号",
                "dft": 1,
            ],
            fallbackMobile: "19000811875"
        )
        XCTAssertEqual(draft.shipAddressId, 37664847)
        XCTAssertEqual(draft.name, "李四")
        XCTAssertEqual(draft.mobile, "13800138000")
        XCTAssertEqual(draft.address, "测试路1号")
        XCTAssertEqual(draft.provinceId, "520000000")
        XCTAssertEqual(draft.townName, "碧海街道")
        XCTAssertTrue(draft.dft)
        let fallback = AccountOps.addressDraft(from: ["name": "王五"], fallbackMobile: "19000811875")
        XCTAssertEqual(fallback.mobile, "19000811875")
    }

    func testAddressUpsertBodyMatchesOfficialFields() {
        var draft = AddressDraft()
        draft.shipAddressId = 9
        draft.name = " 张三 "
        draft.mobile = "+86 190 0081 1875"
        draft.address = " 碧海社区1号 "
        let body = AccountOps.addressUpsertBody(
            draft: draft,
            session: Session(userId: "1210358433", token: "t")
        )
        XCTAssertEqual(JSONText.int(body["shipAddressId"]), 9)
        XCTAssertEqual(JSONText.string(body["provinceId"]), "520000000")
        XCTAssertEqual(JSONText.string(body["cityId"]), "520500000")
        XCTAssertEqual(JSONText.string(body["districtId"]), "520502000")
        XCTAssertEqual(JSONText.string(body["townId"]), "520502011")
        XCTAssertEqual(JSONText.string(body["name"]), "张三")
        XCTAssertEqual(JSONText.string(body["mobile"]), "19000811875")
        XCTAssertEqual(JSONText.string(body["address"]), "碧海社区1号")
        XCTAssertEqual(body["dft"] as? Bool, true)
        XCTAssertEqual(JSONText.int(body["userId"]), 1210358433)
        XCTAssertNil(AccountOps.requireLogin(Session(userId: "1", token: "t")))
        XCTAssertEqual(AccountOps.requireLogin(Session()), "请先登录")
    }

    func testQueryAndSaveAddressStayLocalWhenInvalid() async {
        let missing = await AccountOps.queryAddress(session: Session())
        XCTAssertNil(missing.draft)
        XCTAssertEqual(missing.message, "请先登录")
        let noLogin = await AccountOps.saveAddress(session: Session(), draft: AddressDraft())
        XCTAssertFalse(noLogin.ok)
        XCTAssertEqual(noLogin.message, "请先登录")
        let short = await AccountOps.saveAddress(
            session: Session(userId: "1", token: "t"),
            draft: AddressDraft()
        )
        XCTAssertFalse(short.ok)
        XCTAssertEqual(short.message, "收货人姓名过短")
    }
}
