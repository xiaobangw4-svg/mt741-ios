import SwiftUI

struct BurstView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var cwbStore: CWBStore
    @State private var actId = "103783"
    @State private var amount = "1"
    @State private var n = "8"
    @State private var concurrency = "8"
    @State private var interval = "0"
    @State private var speed = "fast"
    @State private var target = "mock"
    @State private var customURL = ""
    @State private var cwb = ""
    @State private var shopId = ""
    @State private var ydToken = ""
    @State private var ydLogId = ""
    @State private var log = "默认本机回放。官方地址要显式选「官方 H5」。"
    @State private var busy = false
    @State private var confirmOfficial = false
    @State private var showYidun = false
    @State private var showPay = false
    @State private var lastHit = RushHit()

    var body: some View {
        NavigationStack {
            Form {
                Section("741 异步请求") {
                    TextField("活动 ID", text: $actId)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("burst.actId")
                    TextField("数量", text: $amount)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("burst.amount")
                    TextField("请求数 n（1-64）", text: $n)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("burst.n")
                    TextField("门店 shopId（可空）", text: $shopId)
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("burst.shopId")
                    Button("拉取当日 actId") { Task { await fetchActId() } }
                        .disabled(busy)
                        .accessibilityIdentifier("burst.fetchAct")
                }
                Section {
                    Button(busy ? "请求中…" : "开始异步请求") { start() }
                        .disabled(busy || actId.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("burst.start")
                    Button("只生成 body") { dryRun() }
                        .disabled(busy)
                        .accessibilityIdentifier("burst.dry")
                }
                Section("速度") {
                    Picker("档位", selection: $speed) {
                        Text("最快").tag("max")
                        Text("快").tag("fast")
                        Text("中").tag("mid")
                        Text("慢").tag("slow")
                        Text("自定义").tag("custom")
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("burst.speed")
                    .onChange(of: speed) { _, value in
                        applySpeed(value)
                    }
                    TextField("并发 c（1-16）", text: $concurrency)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("burst.c")
                    TextField("间隔 ms（0-2000）", text: $interval)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("burst.interval")
                    Text("间隔是相邻请求的启动间隔。0=拉满，只受并发限制。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("目标") {
                    Picker("目标", selection: $target) {
                        Text("本机回放").tag("mock")
                        Text("自定义").tag("custom")
                        Text("官方 H5").tag("official")
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("burst.target")
                    if target == "custom" {
                        TextField("https://...", text: $customURL)
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier("burst.url")
                    }
                    SecureField("Content-Web-Bb", text: $cwb)
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("burst.cwb")
                    Text(cwbStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("burst.cwbStatus")
                }
                Section("易盾 / 支付") {
                    TextField("ydToken / validate", text: $ydToken)
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("burst.ydToken")
                    TextField("ydLogId", text: $ydLogId)
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("burst.ydLogId")
                    Button("打开易盾滑块") { showYidun = true }
                        .accessibilityIdentifier("burst.yidun")
                    Button("打开支付") { showPay = true }
                        .accessibilityIdentifier("burst.pay")
                }
                Section("日志") {
                    Text(log)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .accessibilityIdentifier("burst.log")
                }
            }
            .navigationTitle("异步")
            .task {
                if sessionStore.session.isLoggedIn {
                    await fetchActId()
                }
            }
            .alert("打官方地址", isPresented: $confirmOfficial) {
                Button("取消", role: .cancel) {}
                Button("继续") { Task { await runBurst(BurstTarget.official) } }
            } message: {
                Text("会从这台 iPhone 并发 POST 官方抢购接口。没 CWB 多半 429。")
            }
            .sheet(isPresented: $showYidun) {
                YidunSheet(
                    session: sessionStore.session,
                    priorityRecordId: lastHit.priorityRecordId
                ) { value in
                    ydToken = value
                }
            }
            .sheet(isPresented: $showPay) {
                PaySheet(
                    session: sessionStore.session,
                    orderId: lastHit.orderId,
                    tn: ""
                )
            }
        }
    }

    private func start() {
        switch target {
        case "official":
            confirmOfficial = true
        case "custom":
            Task { await runBurst(.custom(customURL.trimmingCharacters(in: .whitespaces))) }
        default:
            Task { await runBurst(.mock) }
        }
    }

    private func dryRun() {
        let plain = RushPlain(
            amount: amount.isEmpty ? "1" : amount,
            itemPriorityActId: actId,
            deviceId: sessionStore.session.deviceId,
            userId: sessionStore.session.userId
        )
        let body = RushCrypto.rushBody(plain: plain)
        log = "sku=\(plain.itemCode) act=\(plain.itemPriorityActId) v=0003\nkeys=actParam,v\n\(body.prefix(240))"
    }

    private var usedCWB: String {
        let pasted = cwb.trimmingCharacters(in: .whitespacesAndNewlines)
        return pasted.isEmpty ? cwbStore.cwb : pasted
    }

    private var cwbStatus: String {
        if !cwb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "使用粘贴的 CWB \(cwb.count) 字"
        }
        if !cwbStore.cwb.isEmpty {
            return "使用 H5 捕获的 CWB \(cwbStore.cwb.count) 字"
        }
        return "还没有 CWB。先打开「H5」逛商品页，或粘贴。"
    }

    private func fetchActId() async {
        let info = await CatalogClient.fetch(session: sessionStore.session)
        if info.ok {
            actId = info.actId
            if !info.shopId.isEmpty {
                shopId = info.shopId
            }
        }
        if !busy {
            log = info.ok
                ? "purchaseInfoV2 actId=\(info.actId) sku=\(info.skuId)"
                : "purchaseInfoV2 \(info.message)"
        }
    }

    private func runBurst(_ dest: BurstTarget) async {
        busy = true
        defer { busy = false }
        let req = BurstRequest(
            actId: actId.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            n: Int(n) ?? 8,
            concurrency: Int(concurrency) ?? 8,
            intervalMs: Int(interval) ?? 0,
            cwb: usedCWB,
            shopId: shopId,
            ydToken: ydToken,
            ydLogId: ydLogId,
            target: dest
        )
        log = "开始 \(dest.urlString) n=\(BurstClient.clampN(req.n)) c=\(BurstClient.clampC(req.concurrency)) interval=\(BurstClient.clampInterval(req.intervalMs))ms sku=741"
        let stats = await BurstClient.burst(request: req, session: sessionStore.session)
        var extra = ""
        if var hit = RushHit.best(from: stats.shots) {
            extra = "\n业务 code=\(hit.code.map(String.init) ?? "-") \(hit.message) record=\(hit.priorityRecordId) order=\(hit.orderId)"
            if hit.shopId.isEmpty {
                hit.shopId = shopId
            } else if shopId.isEmpty {
                shopId = hit.shopId
            }
            if hit.canCompose, hit.orderId.isEmpty {
                let placed = await OrderClient.place(
                    session: sessionStore.session,
                    hit: hit,
                    amount: amount,
                    shopId: hit.shopId,
                    mock: dest == .mock
                )
                extra += "\n\(placed.message)"
                if !placed.orderId.isEmpty {
                    hit.orderId = placed.orderId
                    extra += " order=\(placed.orderId)"
                }
            }
            lastHit = hit
            if dest != .mock {
                if hit.needsYidun {
                    showYidun = true
                } else if !hit.orderId.isEmpty {
                    showPay = true
                } else if hit.isHit {
                    showPay = true
                }
            }
        }
        log = "完成 ok=\(stats.ok)/\(stats.n) fail=\(stats.fail) \(stats.elapsedMs)ms c=\(stats.concurrency) interval=\(stats.intervalMs)ms status=\(stats.status)\n\(stats.summary)\(extra)"
    }

    private func applySpeed(_ value: String) {
        switch value {
        case "max":
            concurrency = "16"
            interval = "0"
        case "fast":
            concurrency = "8"
            interval = "0"
        case "mid":
            concurrency = "4"
            interval = "50"
        case "slow":
            concurrency = "2"
            interval = "200"
        default:
            break
        }
    }
}
