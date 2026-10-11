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
    @State private var log = "真机出单：登录后点「自动出单」。本机试跑用「开始异步请求」。"
    @State private var busy = false
    @State private var confirmOfficial = false
    @State private var confirmH5 = false
    @State private var showYidun = false
    @State private var showPay = false
    @State private var lastHit = RushHit()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(pipelineStatus)
                        .font(.footnote.monospaced())
                        .accessibilityIdentifier("burst.pipeline")
                    Button(busy ? "自动出单中…" : "自动出单") {
                        Task { await autoRun() }
                    }
                    .disabled(busy)
                    .accessibilityIdentifier("burst.auto")
                    Text("一点：加载官方商品页 → wasm 现签 CWB → 拉当日 actId → 页内开火 → 组单支付。先登录。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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
            Task { await runBurst(.h5Page) }
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

    private var pipelineStatus: String {
        let login = sessionStore.session.isLoggedIn ? "已登录" : "未登录"
        let h5 = h5Runtime.ready ? "H5就绪" : "H5未就绪"
        let cwbText = cwbStore.cwb.isEmpty ? "CWB空" : "CWB \(cwbStore.cwb.count)字"
        return "\(login) · \(h5) · \(cwbText) · actId \(actId.isEmpty ? "无" : actId)"
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
            return "H5 商品页还没好。点「自动出单」会先加载官方页并现签。"
        }
        if !cwb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "使用粘贴的 CWB \(cwb.count) 字"
        }
        if !cwbStore.cwb.isEmpty {
            return "使用 H5 捕获的 CWB \(cwbStore.cwb.count) 字"
        }
        return "还没有 CWB。点「自动出单」由页内 wasm 现签，不用粘贴。"
    }

    private func fetchActId() async {
        let product = productStore.selected
        h5Runtime.bindIfNeeded(
            session: sessionStore.session,
            cwbStore: cwbStore,
            product: product
        )
        var info: PurchaseInfo
        if sessionStore.session.isLoggedIn {
            if let err = await h5Runtime.waitUntilReady(seconds: 20, product: product, session: sessionStore.session) {
                log = "H5 未就绪：\(err)，改走 URLSession"
                info = await CatalogClient.fetch(session: sessionStore.session, product: product)
            } else {
                info = await h5Runtime.fetchActId(product: product, session: sessionStore.session)
            }
        } else {
            info = await CatalogClient.fetch(session: sessionStore.session, product: product)
        }
        if info.ok {
            actId = info.actId
            if !info.shopId.isEmpty {
                shopId = info.shopId
            }
        }
        if !busy {
            log = info.ok
                ? "purchaseInfoV2 actId=\(info.actId) sku=\(info.skuId) CWB=\(cwbStore.cwb.count)"
                : "purchaseInfoV2 \(info.message)"
        }
    }

    private func autoRun() async {
        let product = productStore.selected
        if !sessionStore.session.isLoggedIn {
            log = "先登录，再点「自动出单」。"
            return
        }
        busy = true
        defer { busy = false }
        log = "1/4 加载官方 \(product.volume) 商品页…"
        h5Runtime.bindIfNeeded(
            session: sessionStore.session,
            cwbStore: cwbStore,
            product: product,
            forceLoad: !h5Runtime.isLive
        )
        if let err = await h5Runtime.waitUntilReady(seconds: 28, product: product, session: sessionStore.session) {
            log = "商品页未就绪：\(err)"
            return
        }
        log = "2/4 拉取当日 actId… CWB=\(cwbStore.cwb.isEmpty ? "页内现签" : "\(cwbStore.cwb.count)字")"
        let info = await h5Runtime.fetchActId(product: product, session: sessionStore.session)
        if info.ok {
            actId = info.actId
            if !info.shopId.isEmpty {
                shopId = info.shopId
            }
        } else {
            log = "actId 拉不到：\(info.message)\nCWB=\(cwbStore.cwb.count) H5=\(h5Runtime.pageURL)"
            return
        }
        log = "3/4 actId=\(actId) 页内开火 sku=\(product.sku) n=\(n)…"
        await executeBurst(.h5Page)
    }

    private func runBurst(_ dest: BurstTarget) async {
        let product = productStore.selected
        if dest == .h5Page, !sessionStore.session.isLoggedIn {
            log = "先登录再选「H5出单」。登录后点「自动出单」会加载官方 \(product.volume) 商品页。"
            return
        }
        busy = true
        defer { busy = false }
        await executeBurst(dest)
    }

    private func executeBurst(_ dest: BurstTarget) async {
        let product = productStore.selected
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
