import XCTest
@testable import MT741

final class PayClientTests: XCTestCase {
    func testRequestPaySalesIdPrefersOrderId() {
        XCTAssertEqual(PayClient.requestPaySalesId(orderId: "637", tn: "tn-1"), "637")
        XCTAssertEqual(PayClient.requestPaySalesId(orderId: " 637 ", tn: "tn-1"), "637")
        XCTAssertEqual(PayClient.requestPaySalesId(orderId: "", tn: "tn-1"), "tn-1")
        XCTAssertEqual(PayClient.channel71, "71")
    }
}
