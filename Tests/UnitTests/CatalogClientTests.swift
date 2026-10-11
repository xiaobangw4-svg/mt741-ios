import XCTest
@testable import MT741

final class CatalogClientTests: XCTestCase {
    func testParseActIdFromPurchaseInfoMap() {
        let json: [String: Any] = [
            "code": 2000,
            "data": [
                "purchaseInfoMap": [
                    "741": [
                        "purchaseInfo": [
                            "itemPriorityActId": 103783,
                            "skuId": "741",
                            "shopId": "2333",
                        ],
                    ],
                ],
            ],
        ]
        let info = CatalogClient.parse(json)
        XCTAssertTrue(info.ok)
        XCTAssertEqual(info.actId, "103783")
        XCTAssertEqual(info.skuId, "741")
        XCTAssertEqual(info.shopId, "2333")
    }

    func testParsePrefersSKU741WhenMapHasOthers() {
        let json: [String: Any] = [
            "code": 2000,
            "data": [
                "purchaseInfoMap": [
                    "1739": ["purchaseInfo": ["itemPriorityActId": 1, "skuId": "1739"]],
                    "741": ["purchaseInfo": ["itemPriorityActId": 88001, "skuId": "741"]],
                ],
            ],
        ]
        let info = CatalogClient.parse(json)
        XCTAssertEqual(info.actId, "88001")
        XCTAssertEqual(info.skuId, "741")
    }

    func testParseRejectsNon2000() {
        let info = CatalogClient.parse(["code": 4810, "message": "缺 spuId"])
        XCTAssertFalse(info.ok)
        XCTAssertEqual(info.message, "缺 spuId")
    }

    func testParseDefaultAddress() {
        let json: [String: Any] = [
            "code": 2000,
            "data": [
                "list": [
                    ["shipAddressId": 11, "dft": false, "name": "a"],
                    ["shipAddressId": 22, "dft": true, "name": "b"],
                ],
            ],
        ]
        let addr = CatalogClient.parseAddress(json)
        XCTAssertEqual(JSONText.string(addr?["shipAddressId"]), "22")
        XCTAssertEqual(JSONText.string(addr?["name"]), "b")
    }
}
