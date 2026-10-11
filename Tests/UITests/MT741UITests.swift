import XCTest

final class MT741UITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// CI 快线入口：启动后必须看到 SKU 741 商品卡。
    func testLaunchShowsSKU741() {
        let app = XCUIApplication()
        app.launch()
        let sku = app.staticTexts["product.sku"]
        XCTAssertTrue(sku.waitForExistence(timeout: 10), "商品卡 SKU 未出现")
        XCTAssertTrue(sku.label.contains("741"), "SKU 文案应含 741，实际：\(sku.label)")
        let title = app.staticTexts["product.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(title.label.contains("500ml"))
    }

    func testEnvironmentTabShowsDevice() {
        let app = XCUIApplication()
        app.launch()
        let envTab = app.tabBars.buttons["环境"]
        XCTAssertTrue(envTab.waitForExistence(timeout: 10))
        envTab.tap()
        XCTAssertTrue(app.staticTexts["env.fk1"].waitForExistence(timeout: 8))
    }

    func testLoginFormExists() {
        let app = XCUIApplication()
        app.launch()
        let loginTab = app.tabBars.buttons["登录"]
        XCTAssertTrue(loginTab.waitForExistence(timeout: 10))
        loginTab.tap()
        XCTAssertTrue(app.textFields["login.mobile"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["login.sendCode"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["login.submit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["login.status"].waitForExistence(timeout: 5))
    }
}
