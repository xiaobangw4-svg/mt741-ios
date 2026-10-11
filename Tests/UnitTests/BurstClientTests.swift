import XCTest
@testable import MT741

final class BurstClientTests: XCTestCase {
    func testMockBurstAll2000ForSKU741() async {
        let session = Session(deviceId: "DEV-1", userId: "9", token: "t")
        let stats = await BurstClient.burst(
            request: BurstRequest(actId: "103783", n: 8, concurrency: 4, target: .mock),
            session: session
        )
        XCTAssertEqual(stats.n, 8)
        XCTAssertEqual(stats.concurrency, 4)
        XCTAssertEqual(stats.sku, "741")
        XCTAssertEqual(stats.ok, 8)
        XCTAssertEqual(stats.fail, 0)
        XCTAssertEqual(stats.status["200"], 8)
        XCTAssertTrue(stats.summary.contains("2000"))
        let hit = RushHit.best(from: stats.shots)
        XCTAssertEqual(hit?.priorityRecordId, "99")
        XCTAssertTrue(hit?.canCompose == true)
        XCTAssertTrue(hit?.orderId.isEmpty == true)
    }

    func testMockBurstSKU10193() async {
        let session = Session(deviceId: "DEV-1", userId: "9", token: "t")
        let stats = await BurstClient.burst(
            request: BurstRequest(
                actId: "1",
                amount: "2",
                n: 2,
                concurrency: 2,
                target: .mock,
                product: .sku10193
            ),
            session: session
        )
        XCTAssertEqual(stats.sku, "10193")
        XCTAssertEqual(stats.ok, 2)
        XCTAssertEqual(stats.fail, 0)
        XCTAssertTrue(stats.summary.contains("10193"))
        XCTAssertTrue(stats.summary.contains("2000"))
    }

    func testMockRejectsOtherSKU() {
        let plain = RushPlain(amount: "1", itemCode: "1739", itemPriorityActId: "1", deviceId: "D")
        let body = RushCrypto.rushBody(plain: plain)
        let (status, text) = BurstClient.mockHandle(body: body)
        XCTAssertEqual(status, 200)
        XCTAssertTrue(text.contains("4031"))
    }

    func testClamp() {
        XCTAssertEqual(BurstClient.clampN(0), 1)
        XCTAssertEqual(BurstClient.clampN(99), 64)
        XCTAssertEqual(BurstClient.clampC(0), 1)
        XCTAssertEqual(BurstClient.clampC(32), 16)
        XCTAssertEqual(BurstClient.clampInterval(-1), 0)
        XCTAssertEqual(BurstClient.clampInterval(5000), 2000)
    }

    func testIntervalStaggersStarts() async {
        let session = Session(deviceId: "DEV-1", userId: "9", token: "t")
        let stats = await BurstClient.burst(
            request: BurstRequest(actId: "103783", n: 3, concurrency: 16, intervalMs: 80, target: .mock),
            session: session
        )
        XCTAssertEqual(stats.ok, 3)
        XCTAssertEqual(stats.intervalMs, 80)
        XCTAssertGreaterThanOrEqual(stats.elapsedMs, 140)
    }
}
