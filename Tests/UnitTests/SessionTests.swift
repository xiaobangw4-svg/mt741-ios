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

    func testAuthDeviceIdPrefersJWTOverSessionField() {
        let jwt = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJtdCIsImV4cCI6MTc5MzQ1MTE5NCwidXNlcklkIjoxMDY1NTAzNTAzLCJkZXZpY2VJZCI6IjAzRjMxQzdBLUVFNDctNDI4Ny1CNzFGLUE3ODdDNjlBMkExQiIsImlhdCI6MTc5MDg1OTE5NH0.h6_StStFuJ8V-0F5aqXeCSG8AYG5emqpa0sTqHo3uU0"
        let session = Session(
            deviceId: "WRONG-UUID",
            userId: "1",
            token: "app-token",
            cookie: jwt
        )
        XCTAssertEqual(session.wapToken, jwt)
        XCTAssertEqual(session.authDeviceId, "03F31C7A-EE47-4287-B71F-A787C69A2A1B")
    }

    func testRotateDeviceNoOpWhenLoggedIn() {
        let key = SessionStore.defaultsKey
        let prev = UserDefaults.standard.data(forKey: key)
        defer {
            if let prev {
                UserDefaults.standard.set(prev, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        let store = SessionStore(session: Session(
            deviceId: "DEV-A",
            userId: "1",
            token: "t",
            cookie: "c"
        ))
        store.rotateDevice()
        XCTAssertEqual(store.session.deviceId, "DEV-A")
        store.logout()
        let afterLogout = store.session.deviceId
        store.rotateDevice()
        XCTAssertNotEqual(store.session.deviceId, afterLogout)
    }

    func testAlignDeviceFromTokenRewritesStaleSessionField() {
        let key = SessionStore.defaultsKey
        let prev = UserDefaults.standard.data(forKey: key)
        defer {
            if let prev {
                UserDefaults.standard.set(prev, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        let jwt = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJtdCIsImV4cCI6MTc5MzQ1MTE5NCwidXNlcklkIjoxMDY1NTAzNTAzLCJkZXZpY2VJZCI6IjAzRjMxQzdBLUVFNDctNDI4Ny1CNzFGLUE3ODdDNjlBMkExQiIsImlhdCI6MTc5MDg1OTE5NH0.h6_StStFuJ8V-0F5aqXeCSG8AYG5emqpa0sTqHo3uU0"
        let store = SessionStore(session: Session(
            deviceId: "STALE",
            userId: "1",
            token: "t",
            cookie: jwt
        ))
        store.alignDeviceFromToken()
        XCTAssertEqual(store.session.deviceId, "03F31C7A-EE47-4287-B71F-A787C69A2A1B")
    }

    func testResetForNextAccountWipesLoginAndRotatesDevice() {
        let key = SessionStore.defaultsKey
        let prev = UserDefaults.standard.data(forKey: key)
        defer {
            if let prev {
                UserDefaults.standard.set(prev, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        let store = SessionStore(session: Session(
            mobile: "19000811875",
            deviceId: "DEV-OLD",
            userId: "1210358433",
            userName: "u",
            token: "tok",
            cookie: "wap"
        ))
        store.resetForNextAccount()
        XCTAssertFalse(store.session.isLoggedIn)
        XCTAssertEqual(store.session.userId, "")
        XCTAssertEqual(store.session.token, "")
        XCTAssertEqual(store.session.cookie, "")
        XCTAssertEqual(store.session.mobile, "")
        XCTAssertNotEqual(store.session.deviceId, "DEV-OLD")
        XCTAssertFalse(store.session.deviceId.isEmpty)
    }
}

