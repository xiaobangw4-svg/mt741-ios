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

    func testParsePrefersRequestedSKU10193() {
        let json: [String: Any] = [
            "code": 2000,
            "data": [
                "purchaseInfoMap": [
                    "741": ["purchaseInfo": ["itemPriorityActId": 88001, "skuId": "741"]],
                    "10193": ["purchaseInfo": ["itemPriorityActId": 99002, "skuId": "10193"]],
                ],
            ],
        ]
        let info = CatalogClient.parse(json, sku: "10193")
        XCTAssertTrue(info.ok)
        XCTAssertEqual(info.actId, "99002")
        XCTAssertEqual(info.skuId, "10193")
    }

    func testParseRealShopKeyedMapDoesNotCrossSKU() {
        let json: [String: Any] = [
            "code": 2000,
            "data": [
                "purchaseInfoMap": [
                    "1001017": [
                        "defaultSkuFlag": true,
                        "purchaseInfo": [
                            "skuId": "741",
                            "itemPriorityActId": 104193,
                            "limitCount": 6,
                        ],
                    ],
                    "1000139": [
                        "defaultSkuFlag": true,
                        "purchaseInfo": [
                            "skuId": "10193",
                            "itemPriorityActId": 87183,
                            "limitCount": 40,
                        ],
                    ],
                ],
            ],
        ]
        let ft500 = CatalogClient.parse(json, sku: "741")
        XCTAssertEqual(ft500.actId, "104193")
        XCTAssertEqual(ft500.skuId, "741")
        XCTAssertEqual(ft500.shopId, "1001017")
        let ft100 = CatalogClient.parse(json, sku: "10193")
        XCTAssertEqual(ft100.actId, "87183")
        XCTAssertEqual(ft100.skuId, "10193")
        XCTAssertEqual(ft100.shopId, "1000139")
    }

    func testParseEmptyMapExplainsNoActId() {
        let json: [String: Any] = ["code": 2000, "data": ["purchaseInfoMap": [:]]]
        let info = CatalogClient.parse(json)
        XCTAssertFalse(info.ok)
        XCTAssertTrue(info.message.contains("actId") || info.message.contains("购买信息"))
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
