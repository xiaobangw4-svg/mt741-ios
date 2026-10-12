import XCTest
@testable import MT741

final class CWBHookTests: XCTestCase {
    func testScriptHooksXHRAndPostsToNative() {
        XCTAssertTrue(CWBHook.javaScript.contains("XMLHttpRequest.prototype"))
        XCTAssertTrue(CWBHook.javaScript.contains("setRequestHeader"))
        XCTAssertTrue(CWBHook.javaScript.contains("content-web-bb"))
        XCTAssertTrue(CWBHook.javaScript.contains("messageHandlers.cwb"))
        XCTAssertTrue(CWBHook.javaScript.contains("window.fetch"))
        XCTAssertTrue(CWBHook.javaScript.contains("Hs.prototype.set"))
        XCTAssertTrue(CWBHook.javaScript.contains("__mt741hookCWB"))
        XCTAssertTrue(CWBHook.javaScript.contains("purchaseInfoV2"))
        XCTAssertTrue(CWBHook.javaScript.contains("__mt741purchaseInfo"))
        XCTAssertEqual(CWBHook.handlerName, "cwb")
    }

    func testParseMessageDictAndString() {
        let parsed = CWBHook.parse(["cwb": "SIG", "hh": "HH", "url": "https://h5.moutai519.com.cn/xhr/x"])
        XCTAssertEqual(parsed.cwb, "SIG")
        XCTAssertEqual(parsed.hh, "HH")
        XCTAssertTrue(parsed.url.contains("moutai519"))
        XCTAssertEqual(CWBHook.parse("raw-cwb").cwb, "raw-cwb")
        XCTAssertEqual(CWBHook.parse(1).cwb, "")
    }

    func testStoreIngestIgnoresEmpty() {
        let store = CWBStore()
        store.ingest(["cwb": ""])
        XCTAssertEqual(store.cwb, "")
        store.ingest(["cwb": "ABC", "hh": "H1"])
        XCTAssertEqual(store.cwb, "ABC")
        XCTAssertEqual(store.contentHh, "H1")
        store.ingest(["cwb": "DEF"])
        XCTAssertEqual(store.cwb, "DEF")
        store.reset()
        XCTAssertEqual(store.cwb, "")
        XCTAssertEqual(store.contentHh, "")
        XCTAssertEqual(store.sourceURL, "")
    }
}
