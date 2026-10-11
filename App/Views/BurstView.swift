import SwiftUI

struct BurstView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var cwbStore: CWBStore
    @EnvironmentObject private var h5Runtime: H5Runtime
    @EnvironmentObject private var productStore: ProductStore
    @State private var actId = "103783"
    @State private var amount = Product.sku741.defaultAmount
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
    @State private var log = "默认本机回放。真机出单：登录 → 等 H5 商品页起来 → 选「H5出单」。"
    @State private var busy = false
    @State private var confirmOfficial = false
    @State private var confirmH5 = false
    @State private var showYidun = false
    @State private var showPay = false
    @State private var lastHit = RushHit()

    var body: some View {
        NavigationStack {
            Form {
                Section("\(productStore.selected.volume) 异步请求") {
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
                        Text("本机").tag("mock")
                        Text("H5出单").tag("h5page")
                        Text("直连").tag("official")
                        Text("自定义").tag("custom")
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
            .task(id: productStore.selected.sku) {
                amount = productStore.selected.defaultAmount
                if sessionStore.session.isLoggedIn {
                    await fetchActId()
                }
            }
            .alert("H5 页内出单", isPresented: $confirmH5) {
                Button("取消", role: .cancel) {}
                Button("开火") { Task { await runBurst(.h5Page) } }
            } message: {
                Text("在后台挂着的官方商品页里用 XHR 抢 SKU \(productStore.selected.sku)（\(productStore.selected.volume)），页内 wasm 现签 CWB。命中后自动组单、order/pay、拉起支付宝。")
            }
            .alert("直连官方地址", isPresented: $confirmOfficial) {
                Button("取消", role: .cancel) {}
                Button("继续") { Task { await runBurst(.official) } }
            } message: {
                Text("URLSession 直连，没有页内 wasm 现签。真机出单请用「H5出单」。")
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
                    autoStart: !lastHit.orderId.isEmpty,
                    orderId: lastHit.orderId,
                    tn: ""
                )
            }
        }
    }

    private func start() {
        switch target {
        case "h5page":
            confirmH5 = true
        case "official":
            confirmOfficial = true
        case "custom":
            Task { await runBurst(.custom(customURL.trimmingCharacters(in: .whitespaces))) }
        default:
            Task { await runBurst(.mock) }
        }
    }

    private func dryRun() {
        let product = productStore.selected
        let plain = RushPlain(
            amount: amount.isEmpty ? product.defaultAmount : amount,
            itemCode: product.sku,
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
        if target == "h5page" {
            if h5Runtime.ready {
                return cwbStore.cwb.isEmpty
                    ? "H5 页已加载。开火时由页内 wasm 现签，不用粘贴。"
                    : "H5 已捕获 CWB \(cwbStore.cwb.count) 字，页内开火会再签一次。"
            }
            return "H5 商品页还没好。先登录，必要时打开「H5」等到有 CWB。"
        }
        if !cwb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "使用粘贴的 CWB \(cwb.count) 字"
        }
        if !cwbStore.cwb.isEmpty {
            return "使用 H5 捕获的 CWB \(cwbStore.cwb.count) 字"
        }
        return "还没有 CWB。出单请选「H5出单」并先打开 H5。"
    }

    private func fetchActId() async {
        let info: PurchaseInfo
        if h5Runtime.ready {
            info = await h5Runtime.fetchActId(product: productStore.selected)
        } else {
            info = await CatalogClient.fetch(session: sessionStore.session, product: productStore.selected)
        }
        if info.ok {
            actId = info.actId
            if !info.shopId.isEmpty {
                shopId = info.shopId
            }
        }
        if !busy {
            log = info.ok
                ? "purchaseInfoV2 actId=\(info.actId) sku=\(info.skuId) via=\(h5Runtime.ready ? "H5" : "URLSession")"
                : "purchaseInfoV2 \(info.message)"
        }
    }

    private func runBurst(_ dest: BurstTarget) async {
        let product = productStore.selected
        if dest == .h5Page, !sessionStore.session.isLoggedIn {
            log = "先登录再选「H5出单」。登录后 App 会在后台加载官方 \(product.volume) 商品页。"
            return
        }
        busy = true
        defer { busy = false }
        let req = BurstRequest(
            actId: actId.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount.isEmpty ? product.defaultAmount : amount,
            n: Int(n) ?? 8,
            concurrency: Int(concurrency) ?? 8,
            intervalMs: Int(interval) ?? 0,
            cwb: usedCWB,
            shopId: shopId,
            ydToken: ydToken,
            ydLogId: ydLogId,
            target: dest,
            product: product
        )
        log = "开始 \(dest == .official ? product.rushURL.absoluteString : dest.urlString) n=\(BurstClient.clampN(req.n)) c=\(BurstClient.clampC(req.concurrency)) interval=\(BurstClient.clampInterval(req.intervalMs))ms sku=\(product.sku)"
        let stats: BurstStats
        if dest == .h5Page {
            stats = await h5Runtime.fire(request: req, session: sessionStore.session)
        } else {
            stats = await BurstClient.burst(request: req, session: sessionStore.session)
        }
        var extra = ""
        if var hit = RushHit.best(from: stats.shots) {
            extra = "\n业务 code=\(hit.code.map(String.init) ?? "-") \(hit.message) record=\(hit.priorityRecordId) order=\(hit.orderId)"
            if hit.shopId.isEmpty {
                hit.shopId = shopId
            } else if shopId.isEmpty {
                shopId = hit.shopId
            }
            if hit.canCompose, hit.orderId.isEmpty {
                var addr: [String: Any]?
                var dU = ""
                if dest == .h5Page || h5Runtime.ready {
                    let pack = await h5Runtime.fetchAddress()
                    addr = pack.address
                    extra += "\n\(pack.message)"
                    dU = await h5Runtime.cookieValue("_d_u")
                }
                let placed = await OrderClient.place(
                    session: sessionStore.session,
                    hit: hit,
                    amount: amount.isEmpty ? product.defaultAmount : amount,
                    shopId: hit.shopId,
                    mock: dest == .mock,
                    address: addr,
                    dU: dU,
                    product: product
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
