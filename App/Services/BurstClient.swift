import Foundation

struct BurstShot: Equatable {
    var idx: Int
    var ok: Bool
    var status: Int
    var ms: Double
    var body: String
    var error: String = ""
}

struct BurstStats: Equatable {
    var url: String
    var n: Int
    var concurrency: Int
    var intervalMs: Int
    var sku: String
    var elapsedMs: Double
    var ok: Int
    var fail: Int
    var status: [String: Int]
    var summary: String
}

enum BurstTarget: Equatable {
    case mock
    case custom(String)
    case official

    var urlString: String {
        switch self {
        case .mock: return "mock://local/rush"
        case .custom(let s): return s
        case .official: return RushCrypto.officialURL.absoluteString
        }
    }
}

struct BurstRequest: Equatable {
    var actId: String
    var amount: String = "1"
    var n: Int = 8
    var concurrency: Int = 8
    var intervalMs: Int = 0
    var cwb: String = ""
    var shopId: String = ""
    var target: BurstTarget = .mock
}

enum BurstClient {
    static func clampN(_ n: Int) -> Int { min(64, max(1, n)) }
    static func clampC(_ c: Int) -> Int { min(16, max(1, c)) }
    static func clampInterval(_ ms: Int) -> Int { min(2000, max(0, ms)) }

    static func mockHandle(body: String) -> (Int, String) {
        guard
            let data = body.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let act = obj["actParam"] as? String
        else {
            return (400, #"{"code":400,"message":"bad body"}"#)
        }
        let pt = RushCrypto.decrypt(act)
        guard
            let pdata = pt.data(using: .utf8),
            let plain = try? JSONSerialization.jsonObject(with: pdata) as? [String: Any]
        else {
            return (400, #"{"code":400,"message":"bad actParam"}"#)
        }
        let sku = String(describing: plain["itemCode"] ?? "")
        if sku != Product.sku741.sku {
            return (200, #"{"code":4031,"message":"库存不足"}"#)
        }
        let amount = String(describing: plain["amount"] ?? "")
        let actId = String(describing: plain["itemPriorityActId"] ?? "")
        return (200, #"{"code":2000,"data":{"itemCode":"741","amount":"\#(amount)","itemPriorityActId":"\#(actId)","v":"0003"}}"#)
    }

    static func burst(request: BurstRequest, session: Session) async -> BurstStats {
        let n = clampN(request.n)
        let c = clampC(request.concurrency)
        let interval = clampInterval(request.intervalMs)
        let token = session.cookie.isEmpty ? session.token : session.cookie
        let plain = RushPlain(
            amount: request.amount.isEmpty ? "1" : request.amount,
            itemPriorityActId: request.actId,
            deviceId: session.deviceId,
            userId: session.userId,
            shopId: request.shopId
        )
        let body = RushCrypto.rushBody(plain: plain)
        let gate = AsyncSemaphore(value: c)
        let t0 = Date()
        var shots = Array(repeating: BurstShot(idx: 0, ok: false, status: 0, ms: 0, body: ""), count: n)
        await withTaskGroup(of: BurstShot.self) { group in
            for i in 0..<n {
                group.addTask {
                    if interval > 0, i > 0 {
                        let ns = UInt64(i) * UInt64(interval) * 1_000_000
                        try? await Task.sleep(nanoseconds: ns)
                    }
                    await gate.acquire()
                    let shot = await one(
                        idx: i,
                        target: request.target,
                        body: body,
                        session: session,
                        token: token,
                        cwb: request.cwb
                    )
                    await gate.release()
                    return shot
                }
            }
            for await shot in group {
                if shot.idx >= 0, shot.idx < shots.count {
                    shots[shot.idx] = shot
                }
            }
        }
        let elapsed = Date().timeIntervalSince(t0) * 1000
        var status: [String: Int] = [:]
        for s in shots {
            status["\(s.status)", default: 0] += 1
        }
        let ok = shots.filter(\.ok).count
        let fail = n - ok
        let summary = shots.prefix(4).map { s in
            s.ok ? "#\(s.idx) \(s.status) \(Int(s.ms))ms \(s.body.prefix(80))" : "#\(s.idx) err \(s.error.prefix(80))"
        }.joined(separator: "\n")
        return BurstStats(
            url: request.target.urlString,
            n: n,
            concurrency: c,
            intervalMs: interval,
            sku: plain.itemCode,
            elapsedMs: (elapsed * 100).rounded() / 100,
            ok: ok,
            fail: fail,
            status: status,
            summary: summary
        )
    }

    private static func one(
        idx: Int,
        target: BurstTarget,
        body: String,
        session: Session,
        token: String,
        cwb: String
    ) async -> BurstShot {
        let t0 = Date()
        if case .mock = target {
            let (status, text) = mockHandle(body: body)
            let ms = Date().timeIntervalSince(t0) * 1000
            return BurstShot(idx: idx, ok: true, status: status, ms: ms, body: text)
        }
        let urlString = target.urlString
        guard let url = URL(string: urlString), let scheme = url.scheme, scheme == "http" || scheme == "https" else {
            return BurstShot(idx: idx, ok: false, status: 0, ms: 0, body: "", error: "URL 无效")
        }
        let mtK = String(Int64(Date().timeIntervalSince1970 * 1000))
        let mtV = AuthDigest.mtV(
            timestamp: mtK,
            deviceId: session.deviceId,
            version: AuthDigest.appVersion,
            suffix: AuthDigest.randomSuffix()
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(body.utf8)
        request.timeoutInterval = 8
        request.httpShouldHandleCookies = false
        for (key, value) in HeaderBuilder.headers(
            deviceId: session.deviceId,
            token: token,
            mtK: mtK,
            mtV: mtV,
            cwb: cwb
        ) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        do {
            let (data, resp) = try await sharedSession.data(for: request)
            let ms = Date().timeIntervalSince(t0) * 1000
            let http = resp as? HTTPURLResponse
            let text = String(data: data, encoding: .utf8) ?? ""
            return BurstShot(
                idx: idx,
                ok: true,
                status: http?.statusCode ?? 0,
                ms: ms,
                body: String(text.prefix(300))
            )
        } catch {
            let ms = Date().timeIntervalSince(t0) * 1000
            return BurstShot(idx: idx, ok: false, status: 0, ms: ms, body: "", error: error.localizedDescription)
        }
    }

    private static let sharedSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 10
        config.httpMaximumConnectionsPerHost = 16
        config.httpShouldUsePipelining = false
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()
}

actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = value
    }

    func acquire() async {
        if value > 0 {
            value -= 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if waiters.isEmpty {
            value += 1
        } else {
            let first = waiters.removeFirst()
            first.resume()
        }
    }
}
