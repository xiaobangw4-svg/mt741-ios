import XCTest
@testable import MT741

final class PayClientTests: XCTestCase {
    func testRequestPaySalesIdPrefersOrderId() {
        XCTAssertEqual(PayClient.requestPaySalesId(orderId: "637", tn: "tn-1"), "637")
        XCTAssertEqual(PayClient.requestPaySalesId(orderId: " 637 ", tn: "tn-1"), "637")
        XCTAssertEqual(PayClient.requestPaySalesId(orderId: "", tn: "tn-1"), "tn-1")
        XCTAssertEqual(PayClient.channel71, "71")
        XCTAssertEqual(PayClient.channel81, "81")
        XCTAssertEqual(PayClient.channel90, "90")
        XCTAssertEqual(PayClient.channelName("90"), "京东金融")
    }

    func testExtractGuizhouBankPageURL() {
        let nested = PayClient.extractBankPageURL([
            "AUTH_CODE": ["PageURL": "https://pay.example.com/gzb?a=1\\u0026b=2"],
        ])
        XCTAssertEqual(nested?.scheme, "https")
        XCTAssertEqual(nested?.host, "pay.example.com")
        XCTAssertTrue(nested?.absoluteString.contains("b=2") == true)

        let json = PayClient.extractBankPageURL([
            "AUTH_CODE": #"{"PageURL":"https://pay.example.com/cashier"}"#,
        ])
        XCTAssertEqual(json?.absoluteString, "https://pay.example.com/cashier")

        let direct = PayClient.extractBankPageURL([
            "PageURL": "https://pay.example.com/direct",
        ])
        XCTAssertEqual(direct?.absoluteString, "https://pay.example.com/direct")

        XCTAssertEqual(
            PayClient.payURL(from: ["AUTH_CODE": ["PageURL": "https://pay.example.com/ch81"]], channel: PayClient.channel81)?.host,
            "pay.example.com"
        )
        XCTAssertNil(PayClient.payURL(from: ["AUTH_CODE": ["PageURL": "https://pay.example.com/ch81"]], channel: PayClient.channel71))
    }

    func testExtractJDFinanceScheme() {
        let urls = PayClient.extractJDPayURLs([
            "AUTH_CODE": [
                "appId": "jdjr123",
                "merchantId": "m-1",
                "tradeNo": "t-9",
                "signData": "sig",
            ],
        ])
        XCTAssertEqual(urls.count, 3)
        XCTAssertEqual(urls[0].scheme, "jdpay")
        XCTAssertEqual(urls[1].scheme, "jdpayopen")
        XCTAssertEqual(urls[2].scheme, "jdmobilejdpay")
        let json = PayClient.jdPayJSON(from: [
            "appId": "jdjr123",
            "merchantId": "m-1",
            "tradeNo": "t-9",
            "signData": "sig",
        ])
        XCTAssertEqual(json, #"{"orderId":"t-9","appId":"jdjr123","merchant":"m-1","signData":"sig"}"#)
        XCTAssertTrue(urls[0].absoluteString.contains("orderId"))
        XCTAssertTrue(urls[0].absoluteString.contains("merchant"))
        XCTAssertFalse(urls[0].absoluteString.contains("merchantId"))
        XCTAssertFalse(urls[0].absoluteString.contains("tradeNo"))

        let already = PayClient.extractJDPayURLs([
            "AUTH_CODE": "jdpay://?params=%7B%22orderId%22%3A%221%22%7D",
        ])
        XCTAssertEqual(already.first?.scheme, "jdpay")
        XCTAssertEqual(
            PayClient.payURL(from: [
                "AUTH_CODE": ["appId": "a", "merchantId": "m", "tradeNo": "t", "signData": "s"],
            ], channel: PayClient.channel90)?.scheme,
            "jdpay"
        )
    }
}
