import XCTest
@testable import MT741

final class JSBridgeTests: XCTestCase {
    private let session = Session(
        mobile: "13800138000",
        deviceId: "DEV-1",
        userId: "1210358433",
        token: "app-token",
        cookie: "wap-cookie"
    )

    func testHandlerNamesMatchOfficialApp() {
        XCTAssertEqual(JSBridge.wvjbHandlerName, "kYXScriptHandlerName")
        XCTAssertEqual(JSBridge.jxbHandlerName, "WKNativeMethodMessage")
        XCTAssertTrue(JSBridge.isHandler("kYXScriptHandlerName"))
        XCTAssertTrue(JSBridge.isHandler("WKNativeMethodMessage"))
        XCTAssertFalse(JSBridge.isHandler("mt741js"))
        XCTAssertEqual(JSBridge.handlerNames.count, 2)
    }

    func testGetUserInfoHasBothUserIdCasingsAndToken() {
        let body: [String: Any] = [
            "handlerName": "getUserInfo",
            "callbackId": "cb_1_1",
            "data": NSNull(),
        ]
        let d = JSBridge.decide(name: JSBridge.wvjbHandlerName, body: body, session: session)
        XCTAssertEqual(d?.handler, "getUserInfo")
        XCTAssertEqual(d?.callbackId, "cb_1_1")
        XCTAssertEqual(d?.pinUserId, "1210358433")
        let info = d?.payload as? [String: Any]
        XCTAssertEqual(JSONText.int(info?["mt_code"]), 200)
        XCTAssertEqual(JSONText.string(info?["userId"]), "1210358433")
        XCTAssertEqual(JSONText.string(info?["userid"]), "1210358433")
        XCTAssertEqual(JSONText.string(info?["token"]), "wap-cookie")
        XCTAssertEqual(JSONText.string(info?["deviceId"]), "DEV-1")
        XCTAssertEqual(JSONText.string(info?["mobile"]), "13800138000")
        let js = JSBridge.callbackJavaScript(d!)
        XCTAssertTrue(js.contains("_handleMessageFromObjC"))
        XCTAssertTrue(js.contains("cb_1_1"))
        XCTAssertTrue(js.contains("1210358433"))
    }

    func testObjCSelectorNameNormalizesToGetUserInfo() {
        let body: [String: Any] = [
            "actionName": "getUserInfo:nativeBidgeResponseCallback:",
            "identifier": "42",
            "data": [:],
        ]
        let d = JSBridge.decide(name: JSBridge.jxbHandlerName, body: body, session: session)
        XCTAssertEqual(d?.handler, "getUserInfo")
        XCTAssertEqual(d?.jxbIdentifier, "42")
        XCTAssertEqual(d?.isJXB, true)
        let js = JSBridge.callbackJavaScript(d!)
        XCTAssertTrue(js.contains("window.Callback"))
        XCTAssertTrue(js.contains("success"))
        XCTAssertTrue(js.contains("42"))
    }

    func testCheckRequestHeaderRepliesJSONNull() {
        let body: [String: Any] = [
            "handlerName": "checkRequestHeader",
            "callbackId": "cb_hdr",
        ]
        let d = JSBridge.decide(name: JSBridge.wvjbHandlerName, body: body, session: session)
        XCTAssertTrue(d?.payload is NSNull)
        XCTAssertEqual(d?.pinUserId, "")
        let encoded = JSBridge.encodeJSON([
            "responseId": d!.callbackId,
            "responseData": d!.payload,
        ])
        XCTAssertTrue(encoded.contains("\"responseData\":null"))
        XCTAssertTrue(encoded.contains("cb_hdr"))
    }

    func testGetLocationIsBijie() {
        let body: [String: Any] = ["handlerName": "getLocation", "callbackId": "cb_loc"]
        let d = JSBridge.decide(name: JSBridge.wvjbHandlerName, body: body, session: session)
        let loc = d?.payload as? [String: Any]
        let lat = (loc?["latitude"] as? Double) ?? (loc?["latitude"] as? NSNumber)?.doubleValue
        let lng = (loc?["longitude"] as? Double) ?? (loc?["longitude"] as? NSNumber)?.doubleValue
        XCTAssertEqual(lat, JSBridge.bijieLatitude)
        XCTAssertEqual(lng, JSBridge.bijieLongitude)
        XCTAssertEqual(JSONText.string(loc?["city"]), "毕节市")
        XCTAssertEqual(JSONText.string(loc?["province"]), "贵州省")
    }

    func testDetectAppEnvLooksLikeOfficialIOS() {
        let body: [String: Any] = ["handlerName": "detectAppEnv", "callbackId": "cb_env"]
        let d = JSBridge.decide(name: JSBridge.wvjbHandlerName, body: body, session: session)
        let env = d?.payload as? [String: Any]
        let isApp = (env?["isApp"] as? Bool) ?? (env?["isApp"] as? NSNumber)?.boolValue
        XCTAssertEqual(isApp, true)
        XCTAssertEqual(JSONText.string(env?["appVersion"]), AuthDigest.appVersion)
        XCTAssertEqual(JSONText.string(env?["appName"]), "com.moutai.mall")
        XCTAssertEqual(JSONText.string(env?["platform"]), "ios")
    }

    func testNetworkStatusIsCellular() {
        let body: [String: Any] = ["handlerName": "getNetworkStatus", "callbackId": "cb_net"]
        let d = JSBridge.decide(name: JSBridge.wvjbHandlerName, body: body, session: session)
        let net = d?.payload as? [String: Any]
        XCTAssertEqual(JSONText.string(net?["type"]), "CELLULAR")
    }

    func testStringJSONBodyParses() {
        let raw = #"{"handlerName":"getUserInfo","callbackId":"cb_s"}"#
        let d = JSBridge.decide(name: JSBridge.wvjbHandlerName, body: raw, session: session)
        XCTAssertEqual(d?.handler, "getUserInfo")
        XCTAssertEqual(d?.callbackId, "cb_s")
        XCTAssertEqual(d?.pinUserId, "1210358433")
    }

    func testUnknownHandlerStillReplies() {
        let body: [String: Any] = ["handlerName": "showToast", "callbackId": "cb_ui"]
        let d = JSBridge.decide(name: JSBridge.wvjbHandlerName, body: body, session: session)
        let row = d?.payload as? [String: Any]
        XCTAssertEqual(JSONText.int(row?["mt_code"]), 200)
        XCTAssertFalse(JSBridge.callbackJavaScript(d!).isEmpty)
    }

    func testIgnoresNonBridgeHandler() {
        XCTAssertNil(JSBridge.decide(name: "cwb", body: ["handlerName": "getUserInfo"], session: session))
    }

    func testInjectScriptMatchesOfficialWVJB() {
        let js = JSBridge.javaScript
        XCTAssertTrue(js.contains("kYXScriptHandlerName"))
        XCTAssertTrue(js.contains("WKNativeMethodMessage"))
        XCTAssertTrue(js.contains("_handleMessageFromObjC"))
        XCTAssertTrue(js.contains("WebViewJavascriptBridge"))
        XCTAssertTrue(js.contains("NEJsbridge"))
        XCTAssertTrue(js.contains("WVJBCallbacks"))
        XCTAssertTrue(js.contains("JXBJSBridge"))
        XCTAssertTrue(js.contains("WebViewJavascriptBridgeReady"))
        XCTAssertTrue(js.contains("window.__mt741bridge"))
        XCTAssertTrue(js.contains("callHandler"))
    }

    func testIdentityAndPushWriteOfficialStorageKeys() {
        let identity = JSBridge.identityJavaScript(session: session)
        XCTAssertTrue(identity.contains("_u_id_"))
        XCTAssertTrue(identity.contains("mt-game-user-id"))
        XCTAssertTrue(identity.contains("1210358433"))
        XCTAssertTrue(identity.contains("MT-Device-ID-Wap"))
        XCTAssertTrue(identity.contains("MT-Token-Wap"))
        let push = JSBridge.pushUserIdJavaScript(userId: "1210358433")
        XCTAssertTrue(push.contains("getUserId_callback"))
        XCTAssertTrue(push.contains("_u_id_"))
        XCTAssertTrue(push.contains("1210358433"))
    }

    func testGetUserBaseContextUAIncludesBsDvid() {
        let token = String(repeating: "D", count: 86)
        let body: [String: Any] = ["handlerName": "getUserBaseContext", "callbackId": "cb_ua"]
        let withTok = Session(
            mobile: "13800138000",
            deviceId: "DEV-1",
            userId: "1210358433",
            token: "app-token",
            cookie: "wap-cookie",
            bsDvid: token
        )
        let d = JSBridge.decide(name: JSBridge.wvjbHandlerName, body: body, session: withTok)
        let info = d?.payload as? [String: Any]
        XCTAssertEqual(JSONText.string(info?["deviceId"]), "DEV-1")
        XCTAssertTrue(JSONText.string(info?["appUserAgent"]).contains("BS-DVID/\(token)"))
        let empty = JSBridge.decide(name: JSBridge.wvjbHandlerName, body: body, session: session)
        let bare = empty?.payload as? [String: Any]
        XCTAssertFalse(JSONText.string(bare?["appUserAgent"]).contains("BS-DVID"))
    }

    func testBangcleReportFailsSoH5CanSendFk1() {
        let wvjb: [String: Any] = ["handlerName": "bangcleReport", "callbackId": "cb_fk1"]
        let d = JSBridge.decide(name: JSBridge.wvjbHandlerName, body: wvjb, session: session)
        XCTAssertEqual(d?.jxbStatus, "fail")
        let info = d?.payload as? [String: Any]
        XCTAssertEqual(JSONText.int(info?["mt_code"]), 404)
        XCTAssertEqual(info?["success"] as? Bool, false)
        let jxb: [String: Any] = [
            "actionName": "bangcleReport",
            "identifier": "fk1",
            "data": [:],
        ]
        let j = JSBridge.decide(name: JSBridge.jxbHandlerName, body: jxb, session: session)
        let js = JSBridge.callbackJavaScript(j!)
        XCTAssertTrue(js.contains("window.Callback"))
        XCTAssertTrue(js.contains("'fail'"))
        XCTAssertFalse(js.contains("'success'"))
    }

    func testEmptyUserIdDoesNotPin() {
        let body: [String: Any] = ["handlerName": "getUserInfo", "callbackId": "cb_empty"]
        let d = JSBridge.decide(name: JSBridge.wvjbHandlerName, body: body, session: Session())
        XCTAssertEqual(d?.pinUserId, "")
        let info = d?.payload as? [String: Any]
        XCTAssertEqual(JSONText.string(info?["userId"]), "")
    }
}
