import XCTest
@testable import MT741

final class ProductTests: XCTestCase {
    func testSKU741Identity() {
        let p = Product.sku741
        XCTAssertEqual(p.sku, "741")
        XCTAssertEqual(p.spu, "IMTP1000313")
        XCTAssertEqual(p.volume, "500ml")
        XCTAssertEqual(p.limitCount, 6)
        XCTAssertEqual(p.catalogOutPrice, 1639)
        XCTAssertTrue(p.name.contains("500ml"))
        XCTAssertTrue(p.name.contains("飞天"))
        XCTAssertEqual(p.searchKeyword, "飞天茅台1499")
        XCTAssertEqual(p.defaultAmount, "1")
        XCTAssertEqual(p.h5URL.host, "h5.moutai519.com.cn")
        XCTAssertTrue(p.h5URL.absoluteString.contains("smsp-detail"))
        XCTAssertEqual(p.rushURL.lastPathComponent, "one")
        XCTAssertEqual(p.captchaId, YidunClient.captchaId741)
    }

    func testSKU483Identity() {
        let p = Product.sku483
        XCTAssertEqual(p.sku, "483")
        XCTAssertEqual(p.spu, "IMTP1000229")
        XCTAssertEqual(p.volume, "1L")
        XCTAssertEqual(p.limitCount, 6)
        XCTAssertEqual(p.catalogOutPrice, 3799)
        XCTAssertEqual(p.defaultAmount, "1")
        XCTAssertTrue(p.name.contains("1L"))
        XCTAssertTrue(p.name.contains("飞天"))
        XCTAssertEqual(p.searchKeyword, "飞天茅台3799")
        XCTAssertTrue(p.h5URL.absoluteString.contains("1000ml-detail"))
        XCTAssertTrue(p.h5URL.absoluteString.contains("IMTP1000229"))
        XCTAssertEqual(p.rushURL.lastPathComponent, "rushPurchase")
        XCTAssertEqual(p.captchaId, YidunClient.captchaId483)
        XCTAssertNotEqual(p.captchaId, YidunClient.captchaId741)
    }

    func testSKU10193Identity() {
        let p = Product.sku10193
        XCTAssertEqual(p.sku, "10193")
        XCTAssertEqual(p.spu, "IMTP1000006")
        XCTAssertEqual(p.volume, "100ml")
        XCTAssertEqual(p.limitCount, 40)
        XCTAssertEqual(p.catalogOutPrice, 249)
        XCTAssertEqual(p.defaultAmount, "2")
        XCTAssertTrue(p.name.contains("100ml"))
        XCTAssertTrue(p.name.contains("飞天"))
        XCTAssertEqual(p.searchKeyword, "飞天茅台249")
        XCTAssertTrue(p.h5URL.absoluteString.contains("xft-detail"))
        XCTAssertTrue(p.h5URL.absoluteString.contains("IMTP1000006"))
        XCTAssertEqual(p.rushURL.lastPathComponent, "five")
    }

    func testNamedAndCatalog() {
        XCTAssertEqual(Product.all.count, 3)
        XCTAssertEqual(Product.named("10193").sku, "10193")
        XCTAssertEqual(Product.named("483").sku, "483")
        XCTAssertEqual(Product.named("nope").sku, "741")
        let store = ProductStore(selected: .sku10193)
        XCTAssertEqual(store.selected.sku, "10193")
        XCTAssertEqual(store.selected.defaultAmount, "2")
    }

    func testClampAmountAndPersistPerSKU() {
        XCTAssertEqual(Product.sku741.clampAmount(""), "1")
        XCTAssertEqual(Product.sku741.clampAmount("0"), "1")
        XCTAssertEqual(Product.sku741.clampAmount("6"), "6")
        XCTAssertEqual(Product.sku741.clampAmount("9"), "6")
        XCTAssertEqual(Product.sku10193.clampAmount(""), "2")
        XCTAssertEqual(Product.sku10193.clampAmount("40"), "40")
        XCTAssertEqual(Product.sku10193.clampAmount("41"), "40")
        XCTAssertEqual(Product.sku483.clampAmount("3"), "3")
        let key741 = ProductStore.amountDefaultsKey("741")
        let key100 = ProductStore.amountDefaultsKey("10193")
        let prev741 = UserDefaults.standard.string(forKey: key741)
        let prev100 = UserDefaults.standard.string(forKey: key100)
        defer {
            if let prev741 {
                UserDefaults.standard.set(prev741, forKey: key741)
            } else {
                UserDefaults.standard.removeObject(forKey: key741)
            }
            if let prev100 {
                UserDefaults.standard.set(prev100, forKey: key100)
            } else {
                UserDefaults.standard.removeObject(forKey: key100)
            }
        }
        let store = ProductStore(selected: .sku741)
        store.setAmount("4", for: .sku741)
        store.setAmount("8", for: .sku10193)
        XCTAssertEqual(store.amount(for: .sku741), "4")
        XCTAssertEqual(store.amount(for: .sku10193), "8")
        store.setAmount("99", for: .sku741)
        XCTAssertEqual(store.amount(for: .sku741), "6")
        store.bumpAmount(-1, for: .sku741)
        XCTAssertEqual(store.amount(for: .sku741), "5")
        store.bumpAmount(10, for: .sku741)
        XCTAssertEqual(store.amount(for: .sku741), "6")
        store.bumpAmount(-10, for: .sku741)
        XCTAssertEqual(store.amount(for: .sku741), "1")
    }
}
