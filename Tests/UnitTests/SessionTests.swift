import XCTest
@testable import MT741

final class SessionTests: XCTestCase {
    func testSessionHasNoIdCodeKey() {
        let keys = Session.CodingKeys.allCases.map(\.rawValue)
        XCTAssertFalse(keys.contains("idCode"))
        XCTAssertFalse(keys.contains("id_code"))
        XCTAssertEqual(Set(keys), Set(["mobile", "deviceId", "userId", "userName", "token", "cookie"]))
    }

    func testDecodeDropsUnknownIdCode() throws {
        let json = """
        {"mobile":"19000811875","deviceId":"DEV","userId":"1","userName":"u","token":"t","cookie":"c","idCode":"should-not-persist"}
        """.data(using: .utf8)!
        let session = try JSONDecoder().decode(Session.self, from: json)
        XCTAssertEqual(session.userId, "1")
        let encoded = try JSONEncoder().encode(session)
        let object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        XCTAssertNil(object["idCode"])
        XCTAssertEqual(object["token"] as? String, "t")
    }

    func testLoggedInRequiresUserAndToken() {
        var session = Session(userId: "1", token: "abc")
        XCTAssertTrue(session.isLoggedIn)
        session.token = ""
        session.cookie = ""
        XCTAssertFalse(session.isLoggedIn)
        XCTAssertEqual(Session().statusText, "未登录")
    }
}

