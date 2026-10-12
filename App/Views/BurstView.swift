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
    @State private var solverURL = YidunSolver.storedURL
    @State private var log = "真机出单：登录后点「自动出单」。本机试跑用「开始异步请求」。"
    @State private var busy = false
    @State private var confirmOfficial = false
    @State private var confirmH5 = false
    @State private var showYidun = false
    @State private var showPay = false
    @State private var lastHit = RushHit()
    @State private var lastSku = Product.sku741.sku
    @State private var fetchHint = ""
    @State private var pendingRetryDest: BurstTarget?
    @State private var yidunEpoch = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("日志") {
                    Text(log)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .frame(minHeight: 88, alignment: .topLeading)
                        .accessibilityIdentifier("burst.log")
                }
                Section {
                    Text(pipelineStatus)
                        .font(.footnote.monospaced())
                        .accessibilityIdentifier("burst.pipeline")
                    Button(busy ? "自动出单中…" : "自动出单") {
                        Task { await autoRun() }
                    }
                    .disabled(busy)
                    .accessibilityIdentifier("burst.auto")
                    Text("上面就是官网商品页。登录后点「自动出单」：页内 wasm 现签 CWB → 拉当日 actId → 开火 → 组单支付。")
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
                    Button(busy ? "拉取中…" : "拉取当日 actId") { Task { await fetchActId() } }
                        .disabled(busy)
                        .accessibilityIdentifier("burst.fetchAct")
                    Text(fetchHint.isEmpty ? "一点就拉当前商品的当日 actId，结果写在上面这一行和日志里。" : fetchHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("burst.fetchHint")
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
                    TextField("远程上号 ngrok，如 https://xxxx.ngrok-free.dev", text: $solverURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .accessibilityIdentifier("burst.solver")
                        .onChange(of: solverURL) { _, value in
                            YidunSolver.storedURL = value
                        }
                    Text("抢购走本机流量。4025 用远程上号同一条 ngrok 打电脑 8889 自动过点图；连不上立刻弹官网点选，手点即可。不用开 Wi-Fi。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("ydToken / validate", text: $ydToken)
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("burst.ydToken")
                    TextField("ydLogId", text: $ydLogId)
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("burst.ydLogId")
                    Button("打开易盾点图") { showYidun = true }
                        .accessibilityIdentifier("burst.yidun")
                    Button("打开支付") { showPay = true }
                        .accessibilityIdentifier("burst.pay")
                }
            }
            .navigationTitle("异步")
            .task(id: productStore.selected.sku) {
                let product = productStore.selected
                amount = product.defaultAmount
                if lastSku != product.sku {
                    actId = ""
                    lastSku = product.sku
                }
            }
            .alert("H5 页内出单", isPresented: $confirmH5) {
                Button("取消", role: .cancel) {}
                Button("开火") { Task { await runBurst(.h5Page) } }
            } message: {
                Text("在屏幕上的官方商品页里用 XHR 抢 SKU \(productStore.selected.sku)（\(productStore.selected.volume)），页内 wasm 现签 CWB。命中后自动组单、order/pay、拉起支付宝。")
            }
            .alert("直连官方地址", isPresented: $confirmOfficial) {
                Button("取消", role: .cancel) {}
                Button("继续") { Task { await runBurst(.official) } }
            } message: {
                Text("URLSession 直连，没有页内 wasm 现签。真机出单请用「H5出单」。")
            }
            .fullScreenCover(isPresented: $showYidun) {
                YidunSheet(
                    priorityRecordId: lastHit.priorityRecordId,
                    captchaId: productStore.selected.captchaId
                ) { value, fp in
                    ydToken = value
                    Task { await finishManualYidun(validate: value, fp: fp) }
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
            deviceId: sessionStore.session.authDeviceId,
            userId: sessionStore.session.userId
        )
        let body = RushCrypto.rushBody(plain: plain)
        log = "sku=\(plain.itemCode) act=\(plain.itemPriorityActId) v=0003\nkeys=actParam,v\n\(body.prefix(240))"
    }

    private var pipelineStatus: String {
        let login = sessionStore.session.isLoggedIn ? "已登录" : "未登录"
        let h5 = h5Runtime.ready ? "H5就绪" : "H5未就绪"
        let cwbText = cwbStore.lengthText
        let sku = productStore.selected.sku
        let style = h5Runtime.styleStatus
        return "\(login) · \(h5) · \(cwbText) · \(style) · sku \(sku) actId \(actId.isEmpty ? "无" : actId)"
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
        busy = true
        defer { busy = false }
        fetchHint = "正在拉 \(product.volume)（SKU \(product.sku)）当日 actId…"
        log = fetchHint
        h5Runtime.bindIfNeeded(
            session: sessionStore.session,
            cwbStore: cwbStore,
            product: product,
            forceLoad: !h5Runtime.isLive
        )
        if sessionStore.session.isLoggedIn {
            _ = await h5Runtime.waitUntilLive(seconds: 8)
            _ = await h5Runtime.waitForCWB(seconds: 8)
        }
        let pulled = await pullActId(product: product)
        applyActId(pulled.0, product: product, via: pulled.1)
    }

    private func pullActId(product: Product) async -> (PurchaseInfo, String) {
        var via = "URLSession"
        var info: PurchaseInfo
        if sessionStore.session.isLoggedIn, h5Runtime.isLive {
            via = "H5"
            info = await h5Runtime.fetchActId(product: product, session: sessionStore.session)
            if info.ok {
                return (info, via)
            }
            via = "URLSession"
            log = "H5 未拿到（\(info.message)），改走 URLSession"
        }
        info = await CatalogClient.fetch(session: sessionStore.session, product: product)
        return (info, via)
    }

    private func applyActId(_ info: PurchaseInfo, product: Product, via: String) {
        if info.ok {
            actId = info.actId
            if !info.shopId.isEmpty {
                shopId = info.shopId
            }
            fetchHint = "\(product.volume) actId=\(info.actId) sku=\(info.skuId) shop=\(info.shopId) via \(via)"
        } else {
            fetchHint = "\(product.volume) 拉不到：\(info.message) via \(via)"
        }
        log = fetchHint + "\nCWB \(cwbStore.cwb.count)/\(CWBStore.officialLength) H5=\(h5Runtime.pageURL)"
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
        sessionStore.alignDeviceFromToken()
        h5Runtime.bindIfNeeded(
            session: sessionStore.session,
            cwbStore: cwbStore,
            product: product,
            forceLoad: !h5Runtime.isLive
        )
        if !h5Runtime.ready {
            if let err = await h5Runtime.waitUntilLive(seconds: 8) {
                log = "H5 未就绪：\(err)，改走 URLSession 拉 actId"
            }
        }
        _ = await h5Runtime.waitForCWB(seconds: 8)
        log = "2/4 拉取当日 \(product.volume) actId… \(cwbStore.lengthText)"
        var (info, via) = await pullActId(product: product)
        if !info.ok {
            let existing = actId.trimmingCharacters(in: .whitespacesAndNewlines)
            if !existing.isEmpty {
                info = PurchaseInfo(
                    ok: true,
                    actId: existing,
                    skuId: product.sku,
                    shopId: shopId,
                    message: "使用已填 actId"
                )
                via = "已填"
            }
        }
        applyActId(info, product: product, via: via)
        if !info.ok {
            return
        }
        log = "3/4 actId=\(actId) sku=\(product.sku) via \(via) 页内开火 n=\(n)…"
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

    private func executeBurst(_ dest: BurstTarget, allowYidunRetry: Bool = true) async {
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
        sessionStore.alignDeviceFromToken()
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
            var yidunPassed = false
            if dest != .mock, hit.needsYidun {
                lastHit = hit
                pendingRetryDest = dest
                yidunEpoch += 1
                let epoch = yidunEpoch
                showYidun = true
                extra += "\n4025 已弹官网点图；远程上号隧道后台过点图"
                if YidunSolver.isConfigured(solverURL) {
                    Task { await raceRemoteYidun(hit: hit, product: product, dest: dest, epoch: epoch) }
                }
                log = "完成 ok=\(stats.ok)/\(stats.n) fail=\(stats.fail) \(stats.elapsedMs)ms c=\(stats.concurrency) interval=\(stats.intervalMs)ms status=\(stats.status)\n\(stats.summary)\(extra)\n请在弹层完成点选（本机流量）"
                return
            }
            if hit.canCompose, hit.orderId.isEmpty, (!hit.needsYidun || yidunPassed) {
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
            if dest != .mock, (!hit.needsYidun || yidunPassed), hit.isHit || !hit.orderId.isEmpty {
                showPay = true
            }
        }
        log = "完成 ok=\(stats.ok)/\(stats.n) fail=\(stats.fail) \(stats.elapsedMs)ms c=\(stats.concurrency) interval=\(stats.intervalMs)ms status=\(stats.status)\n\(stats.summary)\(extra)"
    }

    private func raceRemoteYidun(hit: RushHit, product: Product, dest: BurstTarget, epoch: Int) async {
        let passed = await passYidun(hit: hit, product: product)
        guard epoch == yidunEpoch, passed.ok else { return }
        showYidun = false
        pendingRetryDest = nil
        ydToken = passed.token
        log = "易盾已过（远程 8889），带 ydToken 再打一枪…\n\(passed.message)"
        busy = true
        defer { busy = false }
        await executeBurst(dest, allowYidunRetry: false)
    }

    private func passYidun(hit: RushHit, product: Product) async -> YidunSolver.Result {
        let gdx = await h5Runtime.cookieValue("gdxidpyhxdE")
        let solved = await YidunSolver.solve(
            endpoint: solverURL,
            captchaId: product.captchaId,
            pageUrl: product.h5URL.absoluteString,
            priorityRecordId: hit.priorityRecordId,
            deviceId: sessionStore.session.authDeviceId,
            userAgent: CookieBridge.userAgent(deviceId: sessionStore.session.authDeviceId),
            gdxid: gdx
        )
        if !solved.ok {
            return solved
        }
        return await submitYidun(token: solved.token, fp: solved.fp.isEmpty ? gdx : solved.fp, recordId: hit.priorityRecordId, product: product, prefix: solved.message)
    }

    private func submitYidun(token: String, fp: String, recordId: String, product: Product, prefix: String) async -> YidunSolver.Result {
        if recordId.isEmpty {
            return YidunSolver.Result(ok: true, token: token, fp: fp, message: prefix)
        }
        let submitted: String
        if h5Runtime.ready {
            submitted = await h5Runtime.verifyCode(
                validate: token,
                priorityRecordId: recordId,
                session: sessionStore.session,
                product: product
            )
        } else {
            submitted = await YidunClient.verify(
                validate: token,
                priorityRecordId: recordId,
                session: sessionStore.session,
                captchaId: product.captchaId,
                gdxid: fp
            )
        }
        return YidunSolver.Result(
            ok: true,
            token: token,
            fp: fp,
            message: prefix + "；" + submitted
        )
    }

    private func finishManualYidun(validate: String, fp: String) async {
        yidunEpoch += 1
        busy = true
        defer { busy = false }
        let product = productStore.selected
        let gdx = fp.isEmpty ? await h5Runtime.cookieValue("gdxidpyhxdE") : fp
        let submitted = await submitYidun(
            token: validate,
            fp: gdx,
            recordId: lastHit.priorityRecordId,
            product: product,
            prefix: "官网点选已完成"
        )
        log = submitted.message
        let dest = pendingRetryDest ?? .h5Page
        pendingRetryDest = nil
        await executeBurst(dest, allowYidunRetry: false)
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
