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
        XCTAssertEqual(Product.all.count, 2)
        XCTAssertEqual(Product.named("10193").sku, "10193")
        XCTAssertEqual(Product.named("nope").sku, "741")
        let store = ProductStore(selected: .sku10193)
        XCTAssertEqual(store.selected.sku, "10193")
        XCTAssertEqual(store.selected.defaultAmount, "2")
    }
}
