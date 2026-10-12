import Foundation
import Combine

struct Session: Equatable, Codable {
    var mobile: String = ""
    var deviceId: String = ""
    var userId: String = ""
    var userName: String = ""
    var token: String = ""
    var cookie: String = ""

    var isLoggedIn: Bool {
        !userId.isEmpty && (!token.isEmpty || !cookie.isEmpty)
    }

    /// H5 `MT-Token-Wap` is the cookie JWT; APP `token` is a different ianus key.
    var wapToken: String {
        cookie.isEmpty ? token : cookie
    }

    /// ianus 4011 compares this UUID with `MT-Device-ID` / `MT-Device-ID-Wap`.
    var authDeviceId: String {
        let fromWap = AuthDigest.jwtDeviceId(wapToken)
        if !fromWap.isEmpty { return fromWap }
        let fromApp = AuthDigest.jwtDeviceId(token)
        if !fromApp.isEmpty { return fromApp }
        return deviceId
    }

    var statusText: String {
        if isLoggedIn {
            return "已登录  userId=\(userId)"
        }
        return "未登录"
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case mobile, deviceId, userId, userName, token, cookie
    }
}

final class SessionStore: ObservableObject {
    static let defaultsKey = "mt741.session"

    @Published var session: Session {
        didSet { persist() }
    }

    init(session: Session = SessionStore.load()) {
        self.session = session
        if self.session.deviceId.isEmpty {
            self.session.deviceId = SessionStore.newDeviceId()
        }
    }

    func applyLogin(_ result: LoginResult) {
        session.mobile = result.mobile
        session.deviceId = result.deviceId
        session.userId = result.userId
        session.userName = result.userName
        session.token = result.token
        session.cookie = result.cookie
        alignDeviceFromToken()
        CookieBridge.apply(session)
    }

    func logout() {
        let device = session.authDeviceId.isEmpty ? session.deviceId : session.authDeviceId
        session = Session(deviceId: device)
        CookieBridge.apply(session)
    }

    /// Logged-in JWT already binds a UUID. Rotating here is 4011 on the next rush.
    func rotateDevice() {
        guard !session.isLoggedIn else { return }
        session.deviceId = SessionStore.newDeviceId()
        CookieBridge.apply(session)
    }

    func alignDeviceFromToken() {
        let id = session.authDeviceId
        if !id.isEmpty, id != session.deviceId {
            session.deviceId = id
        }
    }

    static func newDeviceId() -> String {
        UUID().uuidString.uppercased()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    static func load() -> Session {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return Session(deviceId: newDeviceId())
        }
        guard var decoded = try? JSONDecoder().decode(Session.self, from: data) else {
            return Session(deviceId: newDeviceId())
        }
        if decoded.deviceId.isEmpty {
            decoded.deviceId = newDeviceId()
        }
        return decoded
    }
}
