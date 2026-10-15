import XCTest
@testable import MT741

final class H5FireTests: XCTestCase {
    func testScriptInstallsPageFire() {
        XCTAssertTrue(H5Fire.javaScript.contains("window.__mt741fire"))
        XCTAssertTrue(H5Fire.javaScript.contains("window.__mt741request"))
        XCTAssertTrue(H5Fire.javaScript.contains("XMLHttpRequest"))
        XCTAssertTrue(H5Fire.javaScript.contains("withCredentials"))
        XCTAssertTrue(H5Fire.javaScript.contains("MT-K"))
        XCTAssertTrue(H5Fire.javaScript.contains("content-web-bb"))
        XCTAssertTrue(H5Fire.javaScript.contains("sdk-ver-bb"))
        XCTAssertTrue(H5Fire.javaScript.contains("rushPurchase") || H5Fire.javaScript.contains("xhrOnce"))
        XCTAssertTrue(H5Fire.javaScript.contains("MT-Device-ID-Wap"))
        XCTAssertTrue(H5Fire.javaScript.contains("payload.deviceId"))
        XCTAssertTrue(H5Fire.javaScript.contains("wapToken"))
        XCTAssertTrue(H5Fire.javaScript.contains("lockDevice"))
        XCTAssertTrue(H5Fire.javaScript.contains("_u_id_"))
        XCTAssertTrue(H5Fire.javaScript.contains("__mt741signReady"))
        XCTAssertFalse(H5Fire.javaScript.contains("origSend"))
        XCTAssertTrue(H5Fire.javaScript.contains("skipPin"))
        XCTAssertTrue(H5Fire.javaScript.contains("cookieVal(name) === want"))
        XCTAssertTrue(H5Fire.javaScript.contains("Function.prototype.toString.call(orig)"))
        XCTAssertTrue(H5Fire.javaScript.contains("payload.userId"))
        XCTAssertTrue(H5Fire.javaScript.contains("pinRushCookies"))
        XCTAssertTrue(H5Fire.javaScript.contains("gdxidpyhxdE"))
        XCTAssertTrue(H5Fire.javaScript.contains("__snaker__id"))
        XCTAssertFalse(H5Fire.javaScript.contains("expireCookie('_bs_device_id')"))
        XCTAssertTrue(H5Fire.javaScript.contains("_bs_device_id"))
        XCTAssertTrue(H5Fire.javaScript.contains("pinCookie('_bs_device_id'"))
        XCTAssertTrue(H5Fire.javaScript.contains("payload.bsDeviceId"))
        XCTAssertTrue(H5Fire.javaScript.contains("__mt741pinIdentity"))
        XCTAssertTrue(H5Fire.javaScript.contains("YX_SUPPORT_WEBP=1") || H5Fire.javaScript.contains("pinCookie('YX_SUPPORT_WEBP', '1')"))
        XCTAssertTrue(H5Fire.javaScript.contains("pinCookie('YX_SUPPORT_WEBP'"))
        XCTAssertTrue(H5Fire.javaScript.contains("domain=h5.moutai519.com.cn"))
        XCTAssertTrue(H5Fire.javaScript.contains("domain=.moutai519.com.cn"))
        XCTAssertTrue(H5Fire.javaScript.contains("expireTails"))
        XCTAssertFalse(H5Fire.javaScript.contains("String(value) + tails"))
        XCTAssertFalse(H5Fire.javaScript.contains("YX_SUPPORT_WEBP=0"))
        XCTAssertTrue(H5Fire.javaScript.contains("lk === 'mt-device-id'"))
        XCTAssertTrue(H5Fire.javaScript.contains("__mt741didSet"))
        XCTAssertTrue(H5Fire.javaScript.contains("__mt741didOnce"))
        XCTAssertTrue(H5Fire.javaScript.contains("__mt741h5Did"))
        XCTAssertTrue(H5Fire.javaScript.contains("localStorage.getItem('__ud')"))
        XCTAssertEqual(
            H5Fire.javaScript.components(separatedBy: "setRequestHeader('MT-Device-ID'").count - 1,
            1,
            "WKWebView concatenates repeated MT-Device-ID; lockDevice is the only literal setter"
        )
        XCTAssertTrue(H5Fire.javaScript.contains("x-csrf-token"))
        XCTAssertTrue(H5Fire.javaScript.contains("expires=Thu, 01 Jan 1970"))
    }

    func testPageHeadersSkipCWBAndIncludeDevice() {
        let headers = H5Fire.pageHeaders(deviceId: "DEV-1")
        XCTAssertNil(headers["MT-Device-ID"])
        XCTAssertEqual(headers["MT-APP-Version"], AuthDigest.appVersion)
        XCTAssertNil(headers["Content-Web-Bb"])
        XCTAssertNil(headers["Cookie"])
        XCTAssertTrue(headers["Referer"]?.contains("smsp-detail") == true)
        XCTAssertEqual(headers["x-csrf-token"], "")
        let h100 = H5Fire.pageHeaders(deviceId: "DEV-1", product: .sku10193)
        XCTAssertTrue(h100["Referer"]?.contains("xft-detail") == true)
        let h1l = H5Fire.pageHeaders(deviceId: "DEV-1", product: .sku483)
        XCTAssertTrue(h1l["Referer"]?.contains("1000ml-detail") == true)
        let kv = H5Fire.kvPairs(count: 3, deviceId: "DEV-1")
        XCTAssertEqual(kv.count, 3)
        XCTAssertFalse(kv[0]["k", default: ""].isEmpty)
        XCTAssertEqual(kv[0]["v"]?.count, 27)
        XCTAssertNotEqual(kv[0]["k"], kv[2]["k"])
    }

    func testParseShotsAndStats() {
        let result: [String: Any] = [
            "n": 2,
            "shots": [
                ["idx": 0, "ok": true, "status": 200, "ms": 12, "body": #"{"code":2000,"data":{"priorityRecordId":"99"}}"#, "error": ""],
                ["idx": 1, "ok": false, "status": 0, "ms": 8, "body": "", "error": "timeout"],
            ],
        ]
        let shots = H5Fire.parseShots(result)
        XCTAssertEqual(shots.count, 2)
        XCTAssertEqual(shots[0].status, 200)
        XCTAssertTrue(shots[0].body.contains("2000"))
        XCTAssertEqual(shots[1].error, "timeout")
        let stats = H5Fire.stats(
            from: result,
            request: BurstRequest(actId: "1", n: 2, concurrency: 2, target: .h5Page),
            elapsedMs: 20
        )
        XCTAssertEqual(stats.ok, 1)
        XCTAssertEqual(stats.fail, 1)
        XCTAssertEqual(stats.url, "h5://webview/rushPurchase")
        let hit = RushHit.best(from: shots)
        XCTAssertEqual(hit?.priorityRecordId, "99")
        XCTAssertTrue(hit?.canCompose == true)
    }

    func testH5PageTargetIsNotURLSessionOfficial() {
        XCTAssertEqual(BurstTarget.h5Page.urlString, "h5://webview/rushPurchase")
        XCTAssertNotEqual(BurstTarget.h5Page.urlString, BurstTarget.official.urlString)
    }
}
