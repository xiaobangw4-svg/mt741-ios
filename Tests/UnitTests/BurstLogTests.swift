import XCTest
@testable import MT741

final class BurstLogTests: XCTestCase {
    func testAppendKeepsHistoryAndStamp() {
        var log = BurstLog(hint: "就绪")
        let date = Date(timeIntervalSince1970: 1_768_000_000)
        log.append("开始 n=8", at: date)
        log.append("完成 ok=8/8 fail=0", at: date.addingTimeInterval(0.2))
        XCTAssertTrue(log.text.contains("就绪"))
        XCTAssertTrue(log.text.contains("开始 n=8"))
        XCTAssertTrue(log.text.contains("完成 ok=8/8"))
        XCTAssertTrue(log.text.contains("["))
        XCTAssertEqual(log.lines.count, 3)
    }

    func testCapDropsOldest() {
        var log = BurstLog(hint: "first", cap: 3)
        log.append("a", at: Date(timeIntervalSince1970: 1))
        log.append("b", at: Date(timeIntervalSince1970: 2))
        log.append("c", at: Date(timeIntervalSince1970: 3))
        XCTAssertEqual(log.lines.count, 3)
        XCTAssertFalse(log.text.contains("first"))
        XCTAssertTrue(log.text.contains("c"))
    }

    func testMultilineKeepsCompletionMarker() {
        var log = BurstLog()
        log.append("完成 ok=8/8 fail=0 12ms\n#0 200 1ms 2000")
        XCTAssertTrue(log.text.contains("完成"))
        XCTAssertTrue(log.text.contains("ok="))
        XCTAssertTrue(log.text.contains("#0 200"))
    }

    func testResetClearsHistory() {
        var log = BurstLog(hint: "old")
        log.append("line")
        log.reset("日志已清空。")
        XCTAssertEqual(log.text, "日志已清空。")
    }
}
