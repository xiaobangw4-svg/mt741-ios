import Foundation

struct PurchaseInfo: Equatable {
    var ok: Bool
    var actId: String = ""
    var skuId: String = ""
    var shopId: String = ""
    var message: String = ""
}

enum CatalogClient {
    static let purchaseInfoURL = URL(string: "https://h5.moutai519.com.cn/xhr/front/mall/item/purchaseInfoV2")!
    static let addressURL = URL(string: "https://h5.moutai519.com.cn/xhr/front/user/address/ship/query")!

    static func parse(_ json: [String: Any], sku: String = Product.sku741.sku) -> PurchaseInfo {
        let code = AuthClient.jsonCode(json)
        if code != 2000 {
            return PurchaseInfo(ok: false, message: (json["message"] as? String) ?? "code=\(code.map(String.init) ?? "nil")")
        }
        let data = JSONText.object(json["data"])
        let map = JSONText.object(data["purchaseInfoMap"])
        let preferred = JSONText.object(map[sku])
        let candidates: [[String: Any]] = [preferred] + map.values.compactMap { $0 as? [String: Any] }
        for row in candidates {
            let info = JSONText.object(row["purchaseInfo"]).isEmpty ? row : JSONText.object(row["purchaseInfo"])
            let act = JSONText.string(info["itemPriorityActId"])
            if !act.isEmpty, act != "0" {
                return PurchaseInfo(
                    ok: true,
                    actId: act,
                    skuId: JSONText.string(info["skuId"]).isEmpty ? sku : JSONText.string(info["skuId"]),
                    shopId: JSONText.string(info["shopId"]),
                    message: "actId=\(act)"
                )
            }
        }
        return PurchaseInfo(ok: false, message: (json["message"] as? String) ?? "未找到购买信息")
    }

    static func fetch(session: Session, product: Product = .sku741) async -> PurchaseInfo {
        let body: [String: Any] = ["hot": true, "spuId": product.spu]
        do {
            let json = try await postJSON(url: purchaseInfoURL, body: body, session: session)
            return parse(json, sku: product.sku)
        } catch {
            return PurchaseInfo(ok: false, message: AuthClient.describe(error))
        }
    }

    static func parseAddress(_ json: [String: Any]) -> [String: Any]? {
        let code = AuthClient.jsonCode(json)
        guard code == 2000 else { return nil }
        let data = json["data"]
        var rows: [[String: Any]] = []
        if let obj = data as? [String: Any] {
            rows = JSONText.array(obj["list"])
            if rows.isEmpty, obj["shipAddressId"] != nil {
                rows = [obj]
            }
        } else if let arr = data as? [[String: Any]] {
            rows = arr
        }
        if let dft = rows.first(where: { ($0["dft"] as? Bool) == true || JSONText.int($0["dft"]) == 1 }) {
            return dft
        }
        return rows.first
    }

    static func fetchAddress(session: Session) async -> (message: String, address: [String: Any]?) {
        var comps = URLComponents(url: addressURL, resolvingAgainstBaseURL: false)!
        let ts = String(Int64(Date().timeIntervalSince1970 * 1000))
        comps.queryItems = [URLQueryItem(name: "__timestamp", value: ts)]
        do {
            let json = try await getJSON(url: comps.url ?? addressURL, session: session)
            if let addr = parseAddress(json) {
                let aid = JSONText.string(addr["shipAddressId"])
                return ("地址 id=\(aid)", addr)
            }
            return ((json["message"] as? String) ?? "无收货地址", nil)
        } catch {
            return (AuthClient.describe(error), nil)
        }
    }

    private static func postJSON(url: URL, body: [String: Any], session: Session) async throws -> [String: Any] {
        try await h5JSON(url: url, method: "POST", body: try JSONSerialization.data(withJSONObject: body), session: session)
    }

    private static func getJSON(url: URL, session: Session) async throws -> [String: Any] {
        try await h5JSON(url: url, method: "GET", body: nil, session: session)
    }

    private static func h5JSON(url: URL, method: String, body: Data?, session: Session) async throws -> [String: Any] {
        let token = session.cookie.isEmpty ? session.token : session.cookie
        let mtK = String(Int64(Date().timeIntervalSince1970 * 1000))
        let mtV = AuthDigest.mtV(
            timestamp: mtK,
            deviceId: session.deviceId,
            version: AuthDigest.appVersion,
            suffix: AuthDigest.randomSuffix()
        )
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 12
        request.httpShouldHandleCookies = false
        request.httpBody = body
        for (key, value) in HeaderBuilder.headers(
            deviceId: session.deviceId,
            token: token,
            mtK: mtK,
            mtV: mtV,
            cwb: ""
        ) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, resp) = try await URLSession.shared.data(for: request)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "Catalog", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "HTTP \(http.statusCode) \(text.prefix(120))",
            ])
        }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}
