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
        CookieBridge.apply(session)
    }

    func logout() {
        let device = session.deviceId
        session = Session(deviceId: device)
        CookieBridge.apply(session)
    }

    func rotateDevice() {
        session.deviceId = SessionStore.newDeviceId()
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
