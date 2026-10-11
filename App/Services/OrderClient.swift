import Foundation

struct OrderResult: Equatable {
    var ok: Bool
    var orderId: String = ""
    var transactionId: String = ""
    var payChannel: Int = 0
    var message: String = ""
}

enum OrderClient {
    static let composeURL = URL(string: "https://app.moutai519.com.cn/xhr/front/trade/order/standard/compose")!
    static let submitURL = URL(string: "https://app.moutai519.com.cn/xhr/front/trade/order/standard/submit")!

    static func itemList(amount: String, storeId: String = "0", product: Product = .sku741) -> [[String: Any]] {
        let count = Int(amount) ?? Int(product.defaultAmount) ?? 1
        return [[
            "storeId": storeId,
            "spuId": product.sku,
            "count": max(1, count),
        ]]
    }

    static func composeActParam(
        amount: String,
        shipAddressId: Int,
        priorityRecordId: Int,
        shopId: String = "",
        userId: String = "",
        product: Product = .sku741
    ) -> [String: Any] {
        var info: [String: Any] = [
            "priorityRecordId": priorityRecordId,
            "shopId": shopId,
            "inventorySource": 0,
        ]
        if priorityRecordId == 0 {
            info = [:]
        }
        var body: [String: Any] = [
            "deliverMethod": -1,
            "itemList": itemList(amount: amount, product: product),
            "addressInfo": ["shipAddressId": shipAddressId],
            "selfLatitude": "",
            "selfLongitude": "",
        ]
        if !info.isEmpty {
            body["userPriorityInfo"] = info
        }
        if !userId.isEmpty {
            body["userId"] = userId
        }
        return body
    }

    static func encryptActParam(_ obj: [String: Any]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data()
        let plain = String(data: data, encoding: .utf8) ?? ""
        return RushCrypto.encrypt(plain)
    }

    static func payChannel(from data: [String: Any]) -> Int {
        let channels = JSONText.array(data["payChannels"])
        if let first = channels.first, let type = JSONText.int(first["type"]) {
            return type
        }
        return 0
    }

    static func shopId(from data: [String: Any], fallback: String) -> String {
        let result = JSONText.object(data["userPriorityComposeResult"])
        let store = JSONText.object(result["priorityStoreInfo"])
        let id = JSONText.string(store["id"])
        if !id.isEmpty { return id }
        let sid = JSONText.string(store["storeId"])
        if !sid.isEmpty { return sid }
        return fallback
    }

    static func parseOrderId(_ json: [String: Any]) -> String {
        let data = JSONText.object(json["data"])
        let id = JSONText.string(data["orderId"])
        return id.isEmpty ? JSONText.string(json["orderId"]) : id
    }

    static func mockPlace(hit: RushHit, amount: String) -> OrderResult {
        OrderResult(
            ok: true,
            orderId: "637",
            transactionId: "tx-mock",
            payChannel: 71,
            message: "mock compose/submit record=\(hit.priorityRecordId) amount=\(amount) order=637"
        )
    }

    static func place(
        session: Session,
        hit: RushHit,
        amount: String,
        shopId: String,
        mock: Bool,
        address: [String: Any]? = nil,
        dU: String = "",
        product: Product = .sku741
    ) async -> OrderResult {
        if mock {
            return mockPlace(hit: hit, amount: amount)
        }
        let record = JSONText.int(hit.priorityRecordId) ?? 0
        if record == 0 {
            return OrderResult(ok: false, message: "没有 priorityRecordId，无法组单")
        }
        var resolvedAddress = address
        var addrMsg = ""
        if resolvedAddress == nil {
            let addrPack = await CatalogClient.fetchAddress(session: session)
            resolvedAddress = addrPack.address
            addrMsg = addrPack.message
        }
        guard let address = resolvedAddress, let shipId = JSONText.int(address["shipAddressId"]) else {
            return OrderResult(ok: false, message: "组单失败：\(addrMsg.isEmpty ? "无收货地址" : addrMsg)")
        }
        let compose = await compose(
            session: session,
            amount: amount,
            shipAddressId: shipId,
            priorityRecordId: record,
            shopId: shopId,
            dU: dU,
            product: product
        )
        var transactionId = compose.transactionId
        var composeData = compose.data
        var log = compose.message
        if transactionId.isEmpty {
            transactionId = fallbackTransactionId(userId: session.userId)
            log += "；无 transactionId，用兜底 \(transactionId)"
        }
        let submit = await submit(
            session: session,
            amount: amount,
            shipAddressId: shipId,
            priorityRecordId: record,
            transactionId: transactionId,
            composeData: composeData,
            address: address,
            shopId: shopId,
            dU: dU,
            product: product
        )
        return OrderResult(
            ok: submit.ok,
            orderId: submit.orderId,
            transactionId: transactionId,
            payChannel: submit.payChannel,
            message: log + " → " + submit.message
        )
    }

    private struct ComposeReply {
        var ok: Bool
        var transactionId: String
        var data: [String: Any]
        var message: String
    }

    private static func compose(
        session: Session,
        amount: String,
        shipAddressId: Int,
        priorityRecordId: Int,
        shopId: String,
        dU: String,
        product: Product
    ) async -> ComposeReply {
        let inner = composeActParam(
            amount: amount,
            shipAddressId: shipAddressId,
            priorityRecordId: priorityRecordId,
            shopId: shopId,
            userId: session.userId,
            product: product
        )
        let body: [String: Any] = [
            "deliverMethod": -1,
            "addressInfo": ["shipAddressId": shipAddressId],
            "itemList": itemList(amount: amount, product: product),
            "actParam": encryptActParam(inner),
        ]
        do {
            let json = try await appPost(url: composeURL, body: body, session: session, dU: dU)
            let code = AuthClient.jsonCode(json)
            let data = JSONText.object(json["data"])
            let tx = JSONText.string(data["transactionId"])
            if code == 2000 {
                return ComposeReply(ok: true, transactionId: tx, data: data, message: "compose 2000 tx=\(tx)")
            }
            return ComposeReply(
                ok: false,
                transactionId: tx,
                data: data,
                message: (json["message"] as? String) ?? "compose code=\(code.map(String.init) ?? "nil")"
            )
        } catch {
            return ComposeReply(ok: false, transactionId: "", data: [:], message: AuthClient.describe(error))
        }
    }

    private static func submit(
        session: Session,
        amount: String,
        shipAddressId: Int,
        priorityRecordId: Int,
        transactionId: String,
        composeData: [String: Any],
        address: [String: Any],
        shopId: String,
        dU: String,
        product: Product
    ) async -> OrderResult {
        let resolvedShop = shopId.isEmpty ? self.shopId(from: composeData, fallback: "") : shopId
        let pay = payChannel(from: composeData)
        var addressInfo = JSONText.object(composeData["userAddress"])
        if addressInfo.isEmpty {
            addressInfo = address
        }
        if addressInfo["shipAddressId"] == nil {
            addressInfo["shipAddressId"] = shipAddressId
        }
        if JSONText.string(addressInfo["userId"]).isEmpty, let uid = JSONText.int(session.userId) {
            addressInfo["userId"] = uid
        }
        let deliverMethodList: Any = composeData["deliverMethodList"] ?? [[
            "type": 1, "desc": "快递配送", "notes": "", "checked": false,
        ]]
        var inner: [String: Any] = [
            "transactionId": transactionId,
            "deliverMethod": 1,
            "itemList": itemList(amount: amount, product: product),
            "addressInfo": addressInfo,
            "invoiceSubmitDTO": composeData["invoiceInitVO"] ?? NSNull(),
            "payChannel": pay,
            "selectedCoupon": NSNull(),
            "userPriorityInfo": [
                "priorityRecordId": priorityRecordId,
                "shopId": resolvedShop,
                "inventorySource": 0,
            ],
            "deliverMethodList": deliverMethodList,
            "promIdList": composeData["promIdList"] ?? [],
            "source": JSONText.string(composeData["source"]),
            "sourceId": JSONText.string(composeData["sourceId"]),
            "ignorePromInconsistent": false,
        ]
        if !session.userId.isEmpty {
            inner["userId"] = session.userId
        }
        let body: [String: Any] = [
            "transactionId": transactionId,
            "deliverMethod": 1,
            "itemList": itemList(amount: amount, product: product),
            "actParam": encryptActParam(inner),
            "addressInfo": addressInfo,
            "payChannel": pay,
            "invoiceSubmitDTO": composeData["invoiceInitVO"] ?? NSNull(),
            "source": JSONText.string(composeData["source"]),
            "sourceId": JSONText.string(composeData["sourceId"]),
        ]
        do {
            let json = try await appPost(url: submitURL, body: body, session: session, dU: dU)
            let code = AuthClient.jsonCode(json)
            let orderId = parseOrderId(json)
            if code == 2000, !orderId.isEmpty {
                return OrderResult(ok: true, orderId: orderId, transactionId: transactionId, payChannel: pay, message: "submit 2000 order=\(orderId)")
            }
            return OrderResult(
                ok: false,
                orderId: orderId,
                transactionId: transactionId,
                payChannel: pay,
                message: (json["message"] as? String) ?? "submit code=\(code.map(String.init) ?? "nil")"
            )
        } catch {
            return OrderResult(ok: false, transactionId: transactionId, payChannel: pay, message: AuthClient.describe(error))
        }
    }

    private static func fallbackTransactionId(userId: String) -> String {
        let a = Int.random(in: 100_000_000...999_999_999)
        let b = Int.random(in: 100...999)
        let ts = Int64(Date().timeIntervalSince1970 * 1000)
        return "1_\(a)_\(ts)_\(b)_\(userId)"
    }

    private static func appPost(url: URL, body: [String: Any], session: Session, dU: String = "") async throws -> [String: Any] {
        let token = session.cookie.isEmpty ? session.token : session.cookie
        let mtK = String(Int64(Date().timeIntervalSince1970 * 1000))
        let mtV = AuthDigest.mtV(
            timestamp: mtK,
            deviceId: session.deviceId,
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
        request.setValue(session.deviceId, forHTTPHeaderField: "MT-Device-ID")
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
        let cookie = HeaderBuilder.cookie(deviceId: session.deviceId, token: token, dU: dU)
        if !cookie.isEmpty {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        let (data, resp) = try await URLSession.shared.data(for: request)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "Order", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "HTTP \(http.statusCode) \(text.prefix(120))",
            ])
        }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}
