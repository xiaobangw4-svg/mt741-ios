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
        let sku100 = app.staticTexts["product.sku.10193"]
        XCTAssertTrue(sku100.waitForExistence(timeout: 5), "100ml 商品卡 SKU 未出现")
        XCTAssertTrue(sku100.label.contains("10193"), "SKU 文案应含 10193，实际：\(sku100.label)")
        let title100 = app.staticTexts["product.title.10193"]
        XCTAssertTrue(title100.waitForExistence(timeout: 5))
        XCTAssertTrue(title100.label.contains("100ml"))
        let sku1l = app.staticTexts["product.sku.483"]
        XCTAssertTrue(sku1l.waitForExistence(timeout: 5), "1L 商品卡 SKU 未出现")
        XCTAssertTrue(sku1l.label.contains("483"), "SKU 文案应含 483，实际：\(sku1l.label)")
        let title1l = app.staticTexts["product.title.483"]
        XCTAssertTrue(title1l.waitForExistence(timeout: 5))
        XCTAssertTrue(title1l.label.contains("1L"))
    }

    func testOnScreenOfficialH5Stage() {
        let app = XCUIApplication()
        app.launch()
        let status = app.staticTexts["h5.stageStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 10), "屏幕上应有官网商品页状态条")
        XCTAssertTrue(status.label.contains("CWB"), "状态条应含 CWB，实际：\(status.label)")
        XCTAssertTrue(app.tabBars.buttons["商品"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["异步"].exists)
        XCTAssertTrue(app.tabBars.buttons["登录"].exists)
        XCTAssertTrue(app.tabBars.buttons["环境"].exists)
        XCTAssertFalse(app.tabBars.buttons["H5"].exists, "H5 已接到屏幕上，不再单独占一个 Tab")
        XCTAssertTrue(
            app.otherElements["h5.container"].waitForExistence(timeout: 8)
                || app.otherElements["h5.stageBox"].waitForExistence(timeout: 2),
            "官网 WK 应在屏幕上"
        )
    }

    func testBurstMockStartExists() {
        let app = XCUIApplication()
        app.launch()
        tapTab(app, "异步")
        XCTAssertTrue(app.staticTexts["burst.log"].waitForExistence(timeout: 8), "日志应在异步页最上面")
        XCTAssertTrue(app.buttons["burst.auto"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["burst.fetchAct"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["burst.fetchHint"].waitForExistence(timeout: 5))
        let start = app.buttons["burst.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        start.tap()
        reveal(app, app.staticTexts["burst.log"])
        let log = app.staticTexts["burst.log"]
        XCTAssertTrue(log.waitForExistence(timeout: 8))
        let finished = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "完成"),
            object: log
        )
        wait(for: [finished], timeout: 8)
        XCTAssertTrue(log.label.contains("ok="), "日志应有异步结果，实际：\(log.label)")
    }

    func testEnvironmentTabShowsDevice() {
        let app = XCUIApplication()
        app.launch()
        tapTab(app, "环境")
        XCTAssertTrue(app.staticTexts["env.network"].waitForExistence(timeout: 8), "环境页应有真机说明")
        reveal(app, app.staticTexts["env.address"])
        XCTAssertTrue(app.staticTexts["env.address"].waitForExistence(timeout: 5) || app.otherElements["env.address"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["env.cache"].exists || app.otherElements["env.cache"].exists)
    }

    private func tapTab(_ app: XCUIApplication, _ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "找不到 Tab \(name)")
        tab.tap()
    }

    private func reveal(_ app: XCUIApplication, _ element: XCUIElement) {
        for _ in 0..<8 where !element.exists {
            app.swipeUp()
        }
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
        XCTAssertTrue(app.buttons["login.clearCache"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["login.status"].waitForExistence(timeout: 5))
        reveal(app, app.buttons["login.realNameSubmit"])
        XCTAssertTrue(app.buttons["login.realNameQuery"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["login.realNameSubmit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["login.findQuery"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["login.findSubmit"].waitForExistence(timeout: 5))
        reveal(app, app.buttons["login.addressSave"])
        XCTAssertTrue(app.textFields["login.addrName"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["login.addressQuery"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["login.addressSave"].waitForExistence(timeout: 5))
        reveal(app, app.buttons["login.cancelAccount"])
        XCTAssertTrue(app.buttons["login.cancelAccount"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["login.idName"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.secureTextFields["login.idNo"].waitForExistence(timeout: 5))
    }
}
