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
        XCTAssertEqual(p.h5URL.host, "h5.moutai519.com.cn")
    }
}
