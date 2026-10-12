import Foundation

struct RealNameInfo: Equatable {
    var ok: Bool
    var authStatus: Int = -1
    var idCardNo: String = ""
    var idCardName: String = ""
    var did: String = ""
    var message: String = ""

    var stateText: String {
        switch authStatus {
        case 1: return "已实名"
        case 0: return "未实名"
        case -1: return "响应无authStatus字段"
        default: return "状态\(authStatus)(未知)"
        }
    }
}

struct FindIdentityInfo: Equatable {
    var ok: Bool
    var status: Int = -1
    var name: String = ""
    var idCardNo: String = ""
    var mobile: String = ""
    var haveSubmitNum: Int = 0
    var message: String = ""

    var stateText: String {
        switch status {
        case 1: return "已找回"
        case 0: return "未找回"
        case -1: return "响应无status字段"
        default: return "状态\(status)(未知)"
        }
    }
}

struct AccountOpResult: Equatable {
    var ok: Bool
    var message: String
}

struct AddressDraft: Equatable {
    var shipAddressId: Int = 0
    var name: String = ""
    var mobile: String = ""
    var address: String = ""
    var provinceId: String = "520000000"
    var provinceName: String = "贵州省"
    var cityId: String = "520500000"
    var cityName: String = "毕节市"
    var districtId: String = "520502000"
    var districtName: String = "七星关区"
    var townId: String = "520502011"
    var townName: String = "碧海街道"
    var dft: Bool = true

    var summary: String {
        let id = shipAddressId == 0 ? "新地址" : "id=\(shipAddressId)"
        let who = name.isEmpty ? "未填收货人" : name
        return "\(id) \(who) \(provinceName)\(cityName)\(districtName)\(townName)\(address)"
    }
}

enum AccountOps {
    static let realNameInfoURL = URL(string: "https://app.moutai519.com.cn/xhr/front/user/getRealNameAuthInfo")!
    static let realNameAuthURL = URL(string: "https://app.moutai519.com.cn/xhr/front/user/realNameAuth")!
    static let cancelURL = URL(string: "https://app.moutai519.com.cn/xhr/front/user/register/cancel")!
    static let findInfoURL = URL(string: "https://h5.moutai519.com.cn/xhr/front/user/getFindIdentityInfo")!
    static let findSubmitURL = URL(string: "https://h5.moutai519.com.cn/xhr/front/user/findIdentity")!
    static let findReferer = "https://h5.moutai519.com.cn/mt/findIdentity"
    static let addressUpsertURL = URL(string: "https://app.moutai519.com.cn/xhr/front/user/address/ship/upsert")!

    static func validateIdCard(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty {
            return "身份证号/姓名不能为空"
        }
        if s.count != 18 && s.count != 15 {
            return "身份证号长度应为 18(或老式15)位, 当前 \(s.count) 位"
        }
        return nil
    }

    static func validateName(_ raw: String) -> String? {
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "身份证号/姓名不能为空"
        }
        return nil
    }

    static func requireLogin(_ session: Session) -> String? {
        session.isLoggedIn ? nil : "请先登录"
    }

    static func validateAddress(_ draft: AddressDraft) -> String? {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.count < 2 {
            return "收货人姓名过短"
        }
        if let err = AuthDigest.validateMobile(draft.mobile) {
            return "收货" + err
        }
        let pairs = [
            draft.provinceId, draft.provinceName,
            draft.cityId, draft.cityName,
            draft.districtId, draft.districtName,
            draft.townId, draft.townName,
            draft.address,
        ]
        if pairs.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return "省市区街道和详细地址都要填"
        }
        return nil
    }

    static func addressDraft(from row: [String: Any], fallbackMobile: String = "") -> AddressDraft {
        var draft = AddressDraft()
        draft.shipAddressId = JSONText.int(row["shipAddressId"]) ?? 0
        draft.name = JSONText.string(row["name"])
        let mobile = JSONText.string(row["mobile"])
        draft.mobile = mobile.isEmpty ? AuthDigest.normalizeMobile(fallbackMobile) : mobile
        draft.address = JSONText.string(row["address"])
        let provinceId = JSONText.string(row["provinceId"])
        if !provinceId.isEmpty { draft.provinceId = provinceId }
        let provinceName = JSONText.string(row["provinceName"])
        if !provinceName.isEmpty { draft.provinceName = provinceName }
        let cityId = JSONText.string(row["cityId"])
        if !cityId.isEmpty { draft.cityId = cityId }
        let cityName = JSONText.string(row["cityName"])
        if !cityName.isEmpty { draft.cityName = cityName }
        let districtId = JSONText.string(row["districtId"])
        if !districtId.isEmpty { draft.districtId = districtId }
        let districtName = JSONText.string(row["districtName"])
        if !districtName.isEmpty { draft.districtName = districtName }
        let townId = JSONText.string(row["townId"])
        if !townId.isEmpty { draft.townId = townId }
        let townName = JSONText.string(row["townName"])
        if !townName.isEmpty { draft.townName = townName }
        if let dft = row["dft"] as? Bool {
            draft.dft = dft
        } else if let n = JSONText.int(row["dft"]) {
            draft.dft = n == 1
        }
        return draft
    }

    static func addressUpsertBody(draft: AddressDraft, session: Session) -> [String: Any] {
        let userId: Any
        if let n = Int(session.userId) {
            userId = n
        } else {
            userId = session.userId
        }
        return [
            "shipAddressId": draft.shipAddressId,
            "provinceId": draft.provinceId.trimmingCharacters(in: .whitespacesAndNewlines),
            "provinceName": draft.provinceName.trimmingCharacters(in: .whitespacesAndNewlines),
            "cityId": draft.cityId.trimmingCharacters(in: .whitespacesAndNewlines),
            "cityName": draft.cityName.trimmingCharacters(in: .whitespacesAndNewlines),
            "districtId": draft.districtId.trimmingCharacters(in: .whitespacesAndNewlines),
            "districtName": draft.districtName.trimmingCharacters(in: .whitespacesAndNewlines),
            "townId": draft.townId.trimmingCharacters(in: .whitespacesAndNewlines),
            "townName": draft.townName.trimmingCharacters(in: .whitespacesAndNewlines),
            "address": draft.address.trimmingCharacters(in: .whitespacesAndNewlines),
            "name": draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            "mobile": AuthDigest.normalizeMobile(draft.mobile),
            "dft": draft.dft,
            "userId": userId,
        ]
    }

    static func requireCancelConfirm(typed: String, session: Session) -> String? {
        if let err = requireLogin(session) { return err }
        if session.mobile.isEmpty {
            return "会话没有手机号，无法确认注销"
        }
        if AuthDigest.normalizeMobile(typed) != AuthDigest.normalizeMobile(session.mobile) {
            return "注销确认失败: 需传入与账号完全一致的手机号"
        }
        return nil
    }

    static func maskIdCard(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "" }
        if s.count < 8 { return "****" }
        return String(s.prefix(4)) + String(repeating: "*", count: s.count - 7) + String(s.suffix(3))
    }

    static func realNameBody(idCardNo: String, idCardName: String) -> [String: Any] {
        [
            "idCardNo": idCardNo.trimmingCharacters(in: .whitespacesAndNewlines),
            "idCardName": idCardName.trimmingCharacters(in: .whitespacesAndNewlines),
            "cardType": 0,
        ]
    }

    static func findIdentityBody(idCardNo: String, name: String) -> [String: Any] {
        [
            "idCardNo": idCardNo.trimmingCharacters(in: .whitespacesAndNewlines),
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
    }

    static func findIdentityHeaders(session: Session) -> [(String, String)] {
        let token = session.wapToken
        var cookie = HeaderBuilder.cookie(deviceId: session.authDeviceId, token: token, webp: "1")
        if cookie.isEmpty {
            cookie = "YX_SUPPORT_WEBP=1"
        }
        return [
            ("Accept", "application/json, text/javascript, */*; q=0.01"),
            ("X-Requested-With", "XMLHttpRequest"),
            ("User-Agent", CookieBridge.h5UA),
            ("Referer", findReferer),
            ("Origin", HeaderBuilder.origin),
            ("MT-APP-Version", AuthDigest.appVersion),
            ("Content-Type", "application/json"),
            ("Accept-Language", "zh-CN,zh-Hans;q=0.9"),
            ("Cookie", cookie),
        ]
    }

    static func parseRealName(_ json: [String: Any]) -> RealNameInfo {
        let code = AuthClient.jsonCode(json)
        if code != 2000 {
            return RealNameInfo(
                ok: false,
                message: (json["message"] as? String) ?? "code=\(code.map(String.init) ?? "nil")"
            )
        }
        let data = JSONText.object(json["data"])
        var info = RealNameInfo(ok: true, authStatus: -1, message: "")
        if let status = JSONText.int(data["authStatus"]) {
            info.authStatus = status
        }
        info.idCardNo = JSONText.string(data["idCardNo"])
        info.idCardName = JSONText.string(data["idCardName"])
        info.did = JSONText.string(data["did"])
        var msg = info.stateText
        if !info.idCardName.isEmpty || !info.idCardNo.isEmpty {
            msg += " \(info.idCardName) \(info.idCardNo)"
        }
        info.message = msg.trimmingCharacters(in: .whitespaces)
        return info
    }

    static func parseFindIdentity(_ json: [String: Any]) -> FindIdentityInfo {
        let code = AuthClient.jsonCode(json)
        if code != 2000 {
            return FindIdentityInfo(
                ok: false,
                message: (json["message"] as? String) ?? "code=\(code.map(String.init) ?? "nil")"
            )
        }
        let data = JSONText.object(json["data"])
        var info = FindIdentityInfo(ok: true, status: -1, message: "")
        if let status = JSONText.int(data["status"]) {
            info.status = status
        }
        info.name = JSONText.string(data["name"])
        info.idCardNo = JSONText.string(data["idCardNo"])
        info.mobile = JSONText.string(data["mobile"])
        info.haveSubmitNum = JSONText.int(data["haveSubmitNum"]) ?? 0
        var msg = info.stateText
        if !info.name.isEmpty || !info.idCardNo.isEmpty {
            msg += ": \(info.name) \(info.idCardNo)"
        }
        if !info.mobile.isEmpty {
            msg += "（原绑定 \(info.mobile)）"
        }
        info.message = msg
        return info
    }

    static func fetchRealName(session: Session) async -> RealNameInfo {
        if let err = requireLogin(session) {
            return RealNameInfo(ok: false, message: err)
        }
        do {
            let json = try await appPost(url: realNameInfoURL, body: [:], session: session)
            return parseRealName(json)
        } catch {
            return RealNameInfo(ok: false, message: AuthClient.describe(error))
        }
    }

    static func submitRealName(session: Session, idCardNo: String, idCardName: String) async -> AccountOpResult {
        if let err = requireLogin(session) {
            return AccountOpResult(ok: false, message: err)
        }
        if let err = validateName(idCardName) ?? validateIdCard(idCardNo) {
            return AccountOpResult(ok: false, message: err)
        }
        do {
            let json = try await appPost(
                url: realNameAuthURL,
                body: realNameBody(idCardNo: idCardNo, idCardName: idCardName),
                session: session
            )
            let code = AuthClient.jsonCode(json)
            if code == 2000 {
                return AccountOpResult(ok: true, message: "实名已受理，结果异步，请查询实名状态")
            }
            return AccountOpResult(
                ok: false,
                message: (json["message"] as? String) ?? "realNameAuth code=\(code.map(String.init) ?? "nil")"
            )
        } catch {
            return AccountOpResult(ok: false, message: AuthClient.describe(error))
        }
    }

    static func fetchFindIdentity(session: Session) async -> FindIdentityInfo {
        if let err = requireLogin(session) {
            return FindIdentityInfo(ok: false, message: err)
        }
        do {
            let json = try await h5Post(url: findInfoURL, body: [:], session: session)
            return parseFindIdentity(json)
        } catch {
            return FindIdentityInfo(ok: false, message: AuthClient.describe(error))
        }
    }

    static func submitFindIdentity(session: Session, idCardNo: String, name: String) async -> FindIdentityInfo {
        if let err = requireLogin(session) {
            return FindIdentityInfo(ok: false, message: err)
        }
        if let err = validateName(name) ?? validateIdCard(idCardNo) {
            return FindIdentityInfo(ok: false, message: err)
        }
        do {
            let json = try await h5Post(
                url: findSubmitURL,
                body: findIdentityBody(idCardNo: idCardNo, name: name),
                session: session
            )
            var info = parseFindIdentity(json)
            if info.ok, info.status == 1, !info.message.contains("请继续提交实名") {
                info.message += "，请继续提交实名"
            }
            return info
        } catch {
            return FindIdentityInfo(ok: false, message: AuthClient.describe(error))
        }
    }

    static func queryAddress(session: Session) async -> (draft: AddressDraft?, message: String) {
        if let err = requireLogin(session) {
            return (nil, err)
        }
        let pack = await CatalogClient.fetchAddress(session: session)
        if let row = pack.address {
            let draft = addressDraft(from: row, fallbackMobile: session.mobile)
            return (draft, draft.summary)
        }
        return (nil, pack.message)
    }

    static func saveAddress(session: Session, draft: AddressDraft) async -> AccountOpResult {
        if let err = requireLogin(session) {
            return AccountOpResult(ok: false, message: err)
        }
        if let err = validateAddress(draft) {
            return AccountOpResult(ok: false, message: err)
        }
        do {
            let json = try await appPost(
                url: addressUpsertURL,
                body: addressUpsertBody(draft: draft, session: session),
                session: session
            )
            let code = AuthClient.jsonCode(json)
            if code == 2000 || code == 200 {
                let row = JSONText.object(json["data"])
                let aid = JSONText.string(row["shipAddressId"])
                let suffix = aid.isEmpty ? "" : " id=\(aid)"
                return AccountOpResult(ok: true, message: "收货地址已保存\(suffix)")
            }
            return AccountOpResult(
                ok: false,
                message: (json["message"] as? String) ?? "地址保存被拒 code=\(code.map(String.init) ?? "nil")"
            )
        } catch {
            return AccountOpResult(ok: false, message: AuthClient.describe(error))
        }
    }

    static func cancelAccount(session: Session, confirmMobile: String) async -> AccountOpResult {
        if let err = requireCancelConfirm(typed: confirmMobile, session: session) {
            return AccountOpResult(ok: false, message: err)
        }
        do {
            let json = try await appPost(url: cancelURL, body: [:], session: session)
            let code = AuthClient.jsonCode(json)
            if code == 2000 {
                return AccountOpResult(ok: true, message: "账号已注销，token 即刻失效。同一手机号约 7 天后才能重新注册")
            }
            return AccountOpResult(
                ok: false,
                message: (json["message"] as? String) ?? "注销被拒 code=\(code.map(String.init) ?? "nil")"
            )
        } catch {
            return AccountOpResult(ok: false, message: AuthClient.describe(error))
        }
    }

    private static func appPost(url: URL, body: [String: Any], session: Session) async throws -> [String: Any] {
        let token = session.wapToken
        let deviceId = session.authDeviceId
        let mtK = String(Int64(Date().timeIntervalSince1970 * 1000))
        let mtV = AuthDigest.mtV(
            timestamp: mtK,
            deviceId: deviceId,
            version: AuthDigest.appVersion,
            suffix: AuthDigest.randomSuffix()
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.httpShouldHandleCookies = false
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue(AuthDigest.nativeUA, forHTTPHeaderField: "User-Agent")
        request.setValue(deviceId, forHTTPHeaderField: "MT-Device-ID")
        request.setValue(AuthDigest.appVersion, forHTTPHeaderField: "MT-APP-Version")
        request.setValue(AuthDigest.bundleId, forHTTPHeaderField: "MT-Bundle-ID")
        request.setValue("WIFI", forHTTPHeaderField: "MT-Network-Type")
        request.setValue("0", forHTTPHeaderField: "MT-User-Tag")
        request.setValue(HeaderBuilder.mtInfo, forHTTPHeaderField: "MT-Info")
        request.setValue(mtK, forHTTPHeaderField: "MT-K")
        request.setValue(mtV, forHTTPHeaderField: "MT-V")
        if !session.token.isEmpty {
            request.setValue(session.token, forHTTPHeaderField: "MT-Token")
        }
        let cookie = HeaderBuilder.cookie(deviceId: deviceId, token: token, webp: nil)
        if !cookie.isEmpty {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        return try await sendJSON(request)
    }

    private static func h5Post(url: URL, body: [String: Any], session: Session) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.httpShouldHandleCookies = false
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        for (key, value) in findIdentityHeaders(session: session) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return try await sendJSON(request)
    }

    private static func sendJSON(_ request: URLRequest) async throws -> [String: Any] {
        let (data, resp) = try await URLSession.shared.data(for: request)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "AccountOps", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "HTTP \(http.statusCode) \(text.prefix(120))",
            ])
        }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}
