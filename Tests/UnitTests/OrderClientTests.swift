import XCTest
@testable import MT741

final class OrderClientTests: XCTestCase {
    func testComposeActParamUsesSKU741AndNegativeDeliverMethod() throws {
        let obj = OrderClient.composeActParam(
            amount: "2",
            shipAddressId: 37664847,
            priorityRecordId: 99,
            shopId: ""
        )
        XCTAssertEqual(JSONText.int(obj["deliverMethod"]), -1)
        let items = JSONText.array(obj["itemList"])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(JSONText.string(items[0]["spuId"]), "741")
        XCTAssertEqual(JSONText.string(items[0]["storeId"]), "0")
        XCTAssertEqual(JSONText.int(items[0]["count"]), 2)
        let addr = JSONText.object(obj["addressInfo"])
        XCTAssertEqual(JSONText.int(addr["shipAddressId"]), 37664847)
        let pri = JSONText.object(obj["userPriorityInfo"])
        XCTAssertEqual(JSONText.int(pri["priorityRecordId"]), 99)
        XCTAssertEqual(JSONText.int(pri["inventorySource"]), 0)
    }

    func testEncryptActParamRoundTripWithAesKey() {
        let inner = OrderClient.composeActParam(amount: "1", shipAddressId: 1, priorityRecordId: 99)
        let enc = OrderClient.encryptActParam(inner)
        XCTAssertFalse(enc.isEmpty)
        XCTAssertFalse(enc.contains("\n"))
        let pt = RushCrypto.decrypt(enc)
        XCTAssertTrue(pt.contains("\"deliverMethod\":-1"))
        XCTAssertTrue(pt.contains("\"spuId\":\"741\""))
        XCTAssertTrue(pt.contains("\"priorityRecordId\":99"))
    }

    func testOrderMIMEWrapAndRoundTrip() {
        XCTAssertEqual(RushCrypto.mimeWrap("YWJj"), "YWJj\n")
        let long = String(repeating: "A", count: 80)
        let wrapped = RushCrypto.mimeWrap(long)
        XCTAssertTrue(wrapped.contains("\n"))
        XCTAssertTrue(wrapped.hasSuffix("\n"))
        XCTAssertEqual(wrapped.split(separator: "\n", omittingEmptySubsequences: false).first?.count, 76)
        let mime = RushCrypto.encryptOrderMIME("{\"x\":1}")
        XCTAssertTrue(mime.contains("\n"))
        XCTAssertEqual(RushCrypto.decrypt(mime, key: RushCrypto.orderKey, iv: RushCrypto.orderIV), "{\"x\":1}")
    }

    func testPayChannelAndShopIdAndOrderId() {
        let data: [String: Any] = [
            "payChannels": [["type": 71, "name": "支付宝"]],
            "userPriorityComposeResult": ["priorityStoreInfo": ["id": 2333]],
        ]
        XCTAssertEqual(OrderClient.payChannel(from: data), 71)
        XCTAssertEqual(OrderClient.shopId(from: data, fallback: "x"), "2333")
        XCTAssertEqual(OrderClient.parseOrderId(["code": 2000, "data": ["orderId": 637]]), "637")
        XCTAssertEqual(OrderClient.composeURL.lastPathComponent, "compose")
        XCTAssertEqual(OrderClient.submitURL.lastPathComponent, "submit")
        XCTAssertFalse(OrderClient.composeURL.path.contains("/v2"))
    }

    func testMockPlaceAfter2000() {
        let hit = RushHit(code: 2000, priorityRecordId: "99")
        XCTAssertTrue(hit.canCompose)
        let placed = OrderClient.mockPlace(hit: hit, amount: "1")
        XCTAssertTrue(placed.ok)
        XCTAssertEqual(placed.orderId, "637")
        XCTAssertEqual(placed.payChannel, 71)
        XCTAssertTrue(placed.message.contains("compose/submit"))
    }
}
