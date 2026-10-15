import Foundation
import Combine

struct Session: Equatable, Codable {
    var mobile: String = ""
    var deviceId: String = ""
    var userId: String = ""
    var userName: String = ""
    var token: String = ""
    var cookie: String = ""
    /// Same-phone official HaoTian long token for H5 UA `BS-DVID/`. Empty = omit. Survives 换号.
    var bsDvid: String = ""
    /// Page wasm h5_did (`h`+hex) or a bootstrap 32-hex for UA `device-id/`. Survives 换号.
    var h5Did: String = ""
    /// CWB data[2] `start_id` from page `__36_i__` / last SDK CWB. Per Bangcle session.
    var h5StartId: String = ""
    /// Fire with local Murmur + field141 + StyleTotal + SM4. Page wasm stays for fk1 / identity.
    var pureSign: Bool = true

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
        case mobile, deviceId, userId, userName, token, cookie, bsDvid, h5Did, h5StartId, pureSign
    }

    init(
        mobile: String = "",
        deviceId: String = "",
        userId: String = "",
        userName: String = "",
        token: String = "",
        cookie: String = "",
        bsDvid: String = "",
        h5Did: String = "",
        h5StartId: String = "",
        pureSign: Bool = true
    ) {
        self.mobile = mobile
        self.deviceId = deviceId
        self.userId = userId
        self.userName = userName
        self.token = token
        self.cookie = cookie
        self.bsDvid = CookieBridge.sanitizeBsDvid(bsDvid)
        self.h5Did = CookieBridge.sanitizeH5Did(h5Did)
        self.h5StartId = h5StartId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.pureSign = pureSign
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mobile = try c.decodeIfPresent(String.self, forKey: .mobile) ?? ""
        deviceId = try c.decodeIfPresent(String.self, forKey: .deviceId) ?? ""
        userId = try c.decodeIfPresent(String.self, forKey: .userId) ?? ""
        userName = try c.decodeIfPresent(String.self, forKey: .userName) ?? ""
        token = try c.decodeIfPresent(String.self, forKey: .token) ?? ""
        cookie = try c.decodeIfPresent(String.self, forKey: .cookie) ?? ""
        bsDvid = CookieBridge.sanitizeBsDvid(try c.decodeIfPresent(String.self, forKey: .bsDvid) ?? "")
        h5Did = CookieBridge.sanitizeH5Did(try c.decodeIfPresent(String.self, forKey: .h5Did) ?? "")
        h5StartId = (try c.decodeIfPresent(String.self, forKey: .h5StartId) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        pureSign = try c.decodeIfPresent(Bool.self, forKey: .pureSign) ?? true
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
        session = Session(deviceId: device, bsDvid: session.bsDvid, h5Did: session.h5Did, h5StartId: session.h5StartId, pureSign: session.pureSign)
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

    func resetForNextAccount() {
        session = Session(deviceId: SessionStore.newDeviceId(), bsDvid: session.bsDvid, h5Did: session.h5Did, h5StartId: session.h5StartId, pureSign: session.pureSign)
    }

    /// Page wasm `__ud` / CWB did. Empty raw is ignored. Survives 换号.
    @discardableResult
    func applyH5Did(_ raw: String) -> String {
        let did = CookieBridge.sanitizeH5Did(raw)
        if !did.isEmpty, session.h5Did != did {
            session.h5Did = did
        }
        return session.h5Did
    }

    /// Drop persisted did so the next H5 load lets Bangcle mint a new `h…`. Login and BS-DVID stay.
    func clearH5Did() {
        if !session.h5Did.isEmpty {
            session.h5Did = ""
        }
        if !session.h5StartId.isEmpty {
            session.h5StartId = ""
        }
        PureWac.resetCallSeq()
    }

    func applyStartId(_ raw: String) {
        let sid = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sid.isEmpty, session.h5StartId != sid {
            session.h5StartId = sid
        }
    }

    /// Persist a pasted HaoTian token or a full official UA line. Empty raw clears. Rejects `bid-`.
    @discardableResult
    func applyBsDvid(_ raw: String) -> String {
        let token = CookieBridge.sanitizeBsDvid(raw)
        if session.bsDvid != token {
            session.bsDvid = token
        }
        return token
    }

    /// If this phone has no token yet, take one from the pasteboard (UA line or `H BS-DVID =`).
    @discardableResult
    func ingestPasteboardIfEmpty() -> String {
        if !session.bsDvid.isEmpty { return session.bsDvid }
        let token = CookieBridge.ingestPasteboard()
        if !token.isEmpty {
            session.bsDvid = token
        }
        return session.bsDvid
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
