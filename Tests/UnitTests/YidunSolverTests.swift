import XCTest
@testable import MT741

final class YidunSolverTests: XCTestCase {
    func testNormalizeFillsSchemeAndPath() {
        XCTAssertEqual(
            YidunSolver.normalize("192.168.1.8:8889")?.absoluteString,
            "http://192.168.1.8:8889/api/verify"
        )
        XCTAssertEqual(
            YidunSolver.normalize("http://192.168.1.8:8889/")?.absoluteString,
            "http://192.168.1.8:8889/api/verify"
        )
        XCTAssertEqual(
            YidunSolver.normalize("http://192.168.1.8:8889/api/verify")?.absoluteString,
            "http://192.168.1.8:8889/api/verify"
        )
        XCTAssertEqual(
            YidunSolver.normalize("https://example.ngrok-free.dev/add")?.absoluteString,
            "https://example.ngrok-free.dev/api/verify"
        )
        XCTAssertEqual(
            YidunSolver.normalize("https://example.ngrok-free.dev")?.absoluteString,
            "https://example.ngrok-free.dev/api/verify"
        )
        XCTAssertTrue(YidunSolver.isConfigured("https://example.ngrok-free.dev/add"))
        XCTAssertNil(YidunSolver.normalize("  "))
        XCTAssertNil(YidunSolver.normalize(""))
        XCTAssertFalse(YidunSolver.isConfigured(""))
    }

    func testRequestJSONMatchesDesktop8889() {
        let body = YidunSolver.requestJSON(
            captchaId: YidunClient.captchaId741,
            pageUrl: Product.sku741.h5URL.absoluteString,
            priorityRecordId: "99",
            deviceId: "DEV-1",
            userAgent: "ua",
            gdxid: "fp1"
        )
        XCTAssertEqual(body["captchaId"], YidunClient.captchaId741)
        XCTAssertEqual(body["pageUrl"], Product.sku741.h5URL.absoluteString)
        XCTAssertEqual(body["priorityRecordId"], "99")
        XCTAssertEqual(body["deviceId"], "DEV-1")
        XCTAssertEqual(body["userAgent"], "ua")
        XCTAssertEqual(body["gdxid"], "fp1")
        let slim = YidunSolver.requestJSON(
            captchaId: "x",
            pageUrl: "https://h5.moutai519.com.cn/",
            priorityRecordId: "",
            deviceId: "d",
            userAgent: "u",
            gdxid: ""
        )
        XCTAssertNil(slim["priorityRecordId"])
        XCTAssertNil(slim["gdxid"])
    }

    func testParsePrefersFinalValidate() {
        let raw = #"{"success":true,"data":{"result":true,"validate":"RAW","finalValidate":"CN31_FP_v_i_1","fp":"abc"}}"#
        let got = YidunSolver.parse(raw)
        XCTAssertTrue(got.ok)
        XCTAssertEqual(got.token, "CN31_FP_v_i_1")
        XCTAssertEqual(got.fp, "abc")
        XCTAssertTrue(got.message.contains("8889"))
    }

    func testParseFallsBackToValidateAndEmpty() {
        let raw = #"{"success":true,"data":{"result":true,"validate":"RAW"}}"#
        let got = YidunSolver.parse(raw)
        XCTAssertTrue(got.ok)
        XCTAssertEqual(got.token, "RAW")
        let miss = YidunSolver.parse(#"{"success":false,"error":"unsupported type"}"#)
        XCTAssertFalse(miss.ok)
        XCTAssertEqual(miss.message, "unsupported type")
        XCTAssertFalse(YidunSolver.parse("nope").ok)
    }

    func testEmptyEndpointDoesNotHitNetwork() async {
        let got = await YidunSolver.solve(
            endpoint: "",
            captchaId: YidunClient.captchaId741,
            pageUrl: Product.sku741.h5URL.absoluteString,
            priorityRecordId: "",
            deviceId: "DEV",
            userAgent: "ua",
            gdxid: ""
        )
        XCTAssertFalse(got.ok)
        XCTAssertEqual(got.message, "没填远程上号地址")
        XCTAssertTrue(got.token.isEmpty)
    }

    func testOfficialPopupHtml() {
        let html = YidunWidget.html()
        XCTAssertTrue(html.contains(YidunClient.captchaId741))
        let html1l = YidunWidget.html(captchaId: YidunClient.captchaId483)
        XCTAssertTrue(html1l.contains(YidunClient.captchaId483))
        XCTAssertTrue(html.contains("mode: \"popup\""))
        XCTAssertTrue(html.contains("popUp()"))
        XCTAssertTrue(html.contains("安全验证"))
    }

    func testIOSCookieOmitsGdxidAndShortBsDevice() {
        let withGdx = HeaderBuilder.cookie(deviceId: "DEV", token: "tok", gdxid: "fp%2F1")
        XCTAssertFalse(withGdx.contains("gdxidpyhxdE"))
        XCTAssertFalse(withGdx.contains("_bs_device_id"))
        XCTAssertTrue(withGdx.contains("YX_SUPPORT_WEBP=0"))
        XCTAssertTrue(withGdx.contains("MT-Device-ID-Wap=DEV"))
        let plain = HeaderBuilder.cookie(deviceId: "DEV", token: "tok")
        XCTAssertFalse(plain.contains("gdxidpyhxdE"))
        let app = HeaderBuilder.cookie(deviceId: "DEV", token: "tok", webp: "1")
        XCTAssertTrue(app.contains("YX_SUPPORT_WEBP=1"))
        XCTAssertFalse(app.contains("YX_SUPPORT_WEBP=0"))
    }
}
