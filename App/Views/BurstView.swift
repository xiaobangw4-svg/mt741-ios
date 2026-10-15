import SwiftUI

struct BurstView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var cwbStore: CWBStore
    @EnvironmentObject private var h5Runtime: H5Runtime
    @EnvironmentObject private var productStore: ProductStore
    @State private var actId = ""
    @State private var amount = Product.sku741.defaultAmount
    @State private var n = "8"
    @State private var concurrency = "8"
    @State private var interval = "40"
    @State private var speed = "fast"
    @State private var target = ProcessInfo.processInfo.arguments.contains("-ui-testing") ? "mock" : "h5page"
    @State private var customURL = ""
    @State private var cwb = ""
    @State private var shopId = ""
    @State private var ydToken = ""
    @State private var ydLogId = ""
    @State private var solverURL = YidunSolver.storedURL
    @State private var logBook = BurstLog(hint: "真机：登录后点「开始」或「自动出单」，页内 wasm 现签 CWB 打 rushPurchase。本机试跑把目标切到「本机」。")
    @State private var busy = false
    @State private var running = false
    @State private var continuous = false
    @State private var runTask: Task<Void, Never>?
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
            VStack(spacing: 0) {
                logPanel
                controlBar
                Form {
                    Section {
                        Text(pipelineStatus)
                            .font(.footnote.monospaced())
                            .accessibilityIdentifier("burst.pipeline")
                        Button(busy ? "自动出单中…" : "自动出单") {
                            kickoff { await autoRun() }
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
                        HStack(spacing: 10) {
                            Text("瓶数")
                            Spacer()
                            Button {
                                bumpAmount(-1)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .disabled(busy || (Int(amount) ?? 1) <= 1)
                            .accessibilityIdentifier("burst.amount.minus")
                            TextField("瓶数", text: $amount)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 56)
                                .accessibilityIdentifier("burst.amount")
                            Button {
                                bumpAmount(1)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            .disabled(busy || (Int(amount) ?? 1) >= productStore.selected.limitCount)
                            .accessibilityIdentifier("burst.amount.plus")
                        }
                        .onChange(of: amount) { _, value in
                            persistAmount(value)
                        }
                        Text("1–\(productStore.selected.limitCount) 瓶，写进抢购 body。当前 \(productStore.selected.volume)。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        TextField("请求数 n（1-64）", text: $n)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("burst.n")
                        TextField("门店 shopId（可空）", text: $shopId)
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier("burst.shopId")
                        Button(busy ? "拉取中…" : "拉取当日 actId") { Task { await fetchActId() } }
                            .disabled(busy)
                            .accessibilityIdentifier("burst.fetchAct")
                        Text(fetchHint.isEmpty ? "活动 ID 每天换。空着会在开火前 POST purchaseInfoV2 现拉；不要填昨天的。" : fetchHint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("burst.fetchHint")
                    }
                    Section {
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
                        Text("间隔是相邻请求的启动间隔。默认 40ms。0=拉满，只受并发限制。")
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
            }
            .navigationTitle("异步")
            .task(id: productStore.selected.sku) {
                let product = productStore.selected
                amount = productStore.amount(for: product)
                if lastSku != product.sku {
                    actId = ""
                    shopId = ""
                    lastSku = product.sku
                }
                if sessionStore.session.isLoggedIn, !Self.uiTesting {
                    await fetchActId()
                }
            }
            .alert("H5 页内出单", isPresented: $confirmH5) {
                Button("取消", role: .cancel) {}
                Button("开火") { kickoff { await runBurst(.h5Page) } }
            } message: {
                Text("在屏幕上的官方商品页里用 XHR 抢 SKU \(productStore.selected.sku)（\(productStore.selected.volume)），页内 wasm 现签 CWB。命中后自动组单、order/pay、拉起支付宝。")
            }
            .alert("直连官方地址", isPresented: $confirmOfficial) {
                Button("取消", role: .cancel) {}
                Button("继续") { kickoff { await runBurst(.official) } }
            } message: {
                Text("URLSession 直连，没有页内 wasm 现签。真机出单请用「H5出单」。")
            }
            .fullScreenCover(isPresented: $showYidun) {
                YidunSheet(
                    priorityRecordId: lastHit.priorityRecordId,
                    captchaId: productStore.selected.captchaId,
                    userAgent: CookieBridge.userAgent(from: sessionStore.session)
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

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("日志")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Button("清空") {
                    logBook.reset("日志已清空。")
                }
                .font(.caption)
                .foregroundStyle(AppTheme.gold)
                .accessibilityIdentifier("burst.clear")
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
            ScrollViewReader { proxy in
                ScrollView {
                    Text(logBook.text)
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color(red: 0.62, green: 0.96, blue: 0.70))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .textSelection(.enabled)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .id("burst-log-tail")
                        .accessibilityIdentifier("burst.log")
                }
                .onChange(of: logBook.text) { _, _ in
                    proxy.scrollTo("burst-log-tail", anchor: .bottom)
                }
            }
        }
        .frame(height: 168)
        .background(Color.black.opacity(0.92))
    }

    private var controlBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    start()
                } label: {
                    Label(busy ? "请求中…" : "开始", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(startDisabled)
                .accessibilityIdentifier("burst.start")

                Button {
                    pause()
                } label: {
                    Label("暂停", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(!busy && !running)
                .accessibilityIdentifier("burst.pause")
            }
            Toggle("持续请求", isOn: $continuous)
                .accessibilityIdentifier("burst.loop")
            Text(continuous
                 ? "打完一轮接着打，直到点暂停、命中出单或弹出易盾。"
                 : "只打一轮 n 次。打开持续请求会一直打。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    private static var uiTesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing")
    }

    private var startDisabled: Bool {
        if busy { return true }
        if target == "h5page" || target == "mock" { return false }
        if target == "custom" {
            return customURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }

    private func kickoff(_ work: @escaping () async -> Void) {
        guard !busy else { return }
        running = true
        runTask?.cancel()
        runTask = Task { await work() }
    }

    private func start() {
        switch target {
        case "h5page":
            kickoff { await autoRun() }
        case "official":
            confirmOfficial = true
        case "custom":
            kickoff { await runBurst(.custom(customURL.trimmingCharacters(in: .whitespaces))) }
        default:
            kickoff { await runBurst(.mock) }
        }
    }

    private func pause() {
        running = false
        runTask?.cancel()
        runTask = nil
        appendLog("暂停")
    }

    private func dryRun() {
        let product = productStore.selected
        if actId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendLog("没有 actId。先点「拉取当日 actId」，不要手填昨天的。")
            return
        }
        let plain = RushPlain(
            amount: product.clampAmount(amount),
            itemCode: product.sku,
            itemPriorityActId: actId,
            deviceId: sessionStore.session.authDeviceId,
            userId: sessionStore.session.userId
        )
        let body = RushCrypto.rushBody(plain: plain)
        appendLog("sku=\(plain.itemCode) act=\(plain.itemPriorityActId) v=0003\nkeys=actParam,v\n\(body.prefix(240))")
    }

    private var pipelineStatus: String {
        let login = sessionStore.session.isLoggedIn ? "已登录" : "未登录"
        let h5 = h5Runtime.ready ? "H5就绪" : "H5未就绪"
        let cwbText = cwbStore.lengthText
        let sku = productStore.selected.sku
        let style = h5Runtime.styleStatus
        let loop = continuous ? "持续" : "单轮"
        let state = busy ? "请求中" : "空闲"
        return "\(login) · \(h5) · \(cwbText) · \(style) · \(loop)/\(state) · sku \(sku) actId \(actId.isEmpty ? "无" : actId)"
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

    private func appendLog(_ line: String) {
        logBook.append(line)
    }

    private func stopped() -> Bool {
        !running || Task.isCancelled
    }

    private func fetchActId() async {
        let product = productStore.selected
        busy = true
        defer { busy = false }
        fetchHint = "正在拉 \(product.volume)（SKU \(product.sku)）当日 actId…"
        appendLog(fetchHint)
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
            appendLog("H5 未拿到（\(info.message)），改走 URLSession")
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
        appendLog(fetchHint + "\nCWB \(cwbStore.cwb.count)/\(CWBStore.officialLength) H5=\(h5Runtime.pageURL)")
    }

    private func autoRun() async {
        let product = productStore.selected
        if !sessionStore.session.isLoggedIn {
            appendLog("先登录，再点「自动出单」。")
            running = false
            return
        }
        _ = sessionStore.ingestPasteboardIfEmpty()
        busy = true
        defer {
            busy = false
            running = false
        }
        let dvidHint = sessionStore.session.bsDvid.isEmpty
            ? "UA 无 BS-DVID，先复制官网长令牌"
            : "BS-DVID \(sessionStore.session.bsDvid.count) 字符"
        appendLog("1/4 加载官方 \(product.volume) 商品页… \(dvidHint)")
        sessionStore.alignDeviceFromToken()
        h5Runtime.bindIfNeeded(
            session: sessionStore.session,
            cwbStore: cwbStore,
            product: product,
            forceLoad: !h5Runtime.isLive
        )
        if !h5Runtime.ready {
            if let err = await h5Runtime.waitUntilLive(seconds: 8) {
                appendLog("H5 未就绪：\(err)，改走 URLSession 拉 actId")
            }
        }
        if stopped() {
            appendLog("已暂停")
            return
        }
        _ = await h5Runtime.waitForCWB(seconds: 8)
        if stopped() {
            appendLog("已暂停")
            return
        }
        appendLog("2/4 等待 fk1 心跳…")
        let beat = await h5Runtime.waitForFk1(seconds: 12)
        if stopped() {
            appendLog("已暂停")
            return
        }
        appendLog(beat
            ? "2/4 fk1 心跳已到，拉当日 actId… \(cwbStore.lengthText)"
            : "2/4 未等到 fk1，仍拉 actId… \(cwbStore.lengthText)")
        let (info, via) = await pullActId(product: product)
        applyActId(info, product: product, via: via)
        if !info.ok {
            appendLog("没有当日 actId，不开火。点「拉取当日 actId」或等放货窗口。")
            return
        }
        if stopped() {
            appendLog("已暂停")
            return
        }
        appendLog("3/4 actId=\(actId) sku=\(product.sku) 瓶数=\(product.clampAmount(amount)) via \(via) 页内开火 n=\(n)…")
        await loopBurst(.h5Page)
    }

    private func runBurst(_ dest: BurstTarget) async {
        let product = productStore.selected
        if dest == .h5Page, !sessionStore.session.isLoggedIn {
            appendLog("先登录再选「H5出单」。登录后点「自动出单」会加载官方 \(product.volume) 商品页。")
            running = false
            return
        }
        busy = true
        defer {
            busy = false
            running = false
        }
        if dest != .mock {
            let (info, via) = await pullActId(product: product)
            applyActId(info, product: product, via: via)
            if !info.ok {
                appendLog("没有当日 actId，不开火。点「拉取当日 actId」或等放货窗口。")
                return
            }
        }
        await loopBurst(dest)
    }

    private func loopBurst(_ dest: BurstTarget) async {
        var round = 0
        while running && !Task.isCancelled {
            round += 1
            if continuous {
                appendLog("第 \(round) 轮 sku=\(productStore.selected.sku) n=\(n) c=\(concurrency) interval=\(interval)ms")
            }
            let result = await executeBurst(dest)
            if result == .yidun {
                if continuous {
                    appendLog("等易盾点图，先停轮询")
                }
                running = false
                return
            }
            if result == .hit {
                if continuous {
                    appendLog("已命中，停止请求")
                }
                running = false
                return
            }
            if !continuous || stopped() {
                break
            }
            let gapMs = max(BurstClient.clampInterval(Int(interval) ?? 40), 40)
            try? await Task.sleep(nanoseconds: UInt64(gapMs) * 1_000_000)
        }
        if stopped() {
            appendLog("已暂停")
        }
    }

    private func executeBurst(_ dest: BurstTarget, allowYidunRetry: Bool = true) async -> BurstRoundResult {
        let product = productStore.selected
        if dest != .mock {
            var live = actId.trimmingCharacters(in: .whitespacesAndNewlines)
            if live.isEmpty {
                let pulled = await pullActId(product: product)
                applyActId(pulled.0, product: product, via: pulled.1)
                live = actId.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if live.isEmpty {
                appendLog("没有当日 actId，先拉 purchaseInfoV2。")
                return .ran
            }
        }
        let req = BurstRequest(
            actId: actId.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: product.clampAmount(amount),
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
        _ = sessionStore.ingestPasteboardIfEmpty()
        if dest == .h5Page, h5Runtime.fk1Beats == 0 {
            appendLog("开火前等待 fk1 心跳…")
            let beat = await h5Runtime.waitForFk1(seconds: 12)
            appendLog(beat ? "fk1 心跳已到，开始开火…" : "未等到 fk1 心跳，仍开火…")
            if stopped() {
                return .ran
            }
        }
        appendLog("开始 \(dest == .official ? product.rushURL.absoluteString : dest.urlString) n=\(BurstClient.clampN(req.n)) c=\(BurstClient.clampC(req.concurrency)) interval=\(BurstClient.clampInterval(req.intervalMs))ms sku=\(product.sku) 瓶数=\(req.amount) \(cwbStore.lengthText)")
        sessionStore.alignDeviceFromToken()
        let stats: BurstStats
        if dest == .h5Page {
            stats = await h5Runtime.fire(request: req, session: sessionStore.session)
            _ = sessionStore.applyH5Did(h5Runtime.lastH5Did)
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
                appendLog("完成 \(cwbStore.lengthText) ok=\(stats.ok)/\(stats.n) fail=\(stats.fail) \(stats.elapsedMs)ms c=\(stats.concurrency) interval=\(stats.intervalMs)ms status=\(stats.status)\n\(stats.summary)\(extra)\n请在弹层完成点选（本机流量）")
                return .yidun
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
                    amount: product.clampAmount(amount),
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
            appendLog("完成 \(cwbStore.lengthText) ok=\(stats.ok)/\(stats.n) fail=\(stats.fail) \(stats.elapsedMs)ms c=\(stats.concurrency) interval=\(stats.intervalMs)ms status=\(stats.status)\n\(stats.summary)\(extra)")
            if hit.isHit || !hit.orderId.isEmpty {
                return .hit
            }
            return .ran
        }
        appendLog("完成 \(cwbStore.lengthText) ok=\(stats.ok)/\(stats.n) fail=\(stats.fail) \(stats.elapsedMs)ms c=\(stats.concurrency) interval=\(stats.intervalMs)ms status=\(stats.status)\n\(stats.summary)\(extra)")
        return .ran
    }

    private func raceRemoteYidun(hit: RushHit, product: Product, dest: BurstTarget, epoch: Int) async {
        let passed = await passYidun(hit: hit, product: product)
        guard epoch == yidunEpoch, passed.ok else { return }
        showYidun = false
        pendingRetryDest = nil
        ydToken = passed.token
        appendLog("易盾已过（远程 8889），带 ydToken 再打一枪…\n\(passed.message)")
        running = true
        busy = true
        defer {
            busy = false
            running = false
        }
        let result = await executeBurst(dest, allowYidunRetry: false)
        if result == .hit || result == .yidun || !continuous {
            return
        }
        running = true
        await loopBurst(dest)
    }

    private func passYidun(hit: RushHit, product: Product) async -> YidunSolver.Result {
        let gdx = await h5Runtime.cookieValue("gdxidpyhxdE")
        let solved = await YidunSolver.solve(
            endpoint: solverURL,
            captchaId: product.captchaId,
            pageUrl: product.h5URL.absoluteString,
            priorityRecordId: hit.priorityRecordId,
            deviceId: sessionStore.session.authDeviceId,
            userAgent: CookieBridge.userAgent(from: sessionStore.session),
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
        running = true
        busy = true
        defer {
            busy = false
            running = false
        }
        let product = productStore.selected
        let gdx = fp.isEmpty ? await h5Runtime.cookieValue("gdxidpyhxdE") : fp
        let submitted = await submitYidun(
            token: validate,
            fp: gdx,
            recordId: lastHit.priorityRecordId,
            product: product,
            prefix: "官网点选已完成"
        )
        appendLog(submitted.message)
        let dest = pendingRetryDest ?? .h5Page
        pendingRetryDest = nil
        let result = await executeBurst(dest, allowYidunRetry: false)
        if result == .hit || result == .yidun || !continuous {
            return
        }
        running = true
        await loopBurst(dest)
    }

    private func persistAmount(_ raw: String) {
        let product = productStore.selected
        let digits = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Int(digits) != nil else { return }
        let clamped = product.clampAmount(digits)
        if clamped != raw {
            amount = clamped
        }
        productStore.setAmount(clamped, for: product)
    }

    private func bumpAmount(_ delta: Int) {
        let product = productStore.selected
        let cur = Int(product.clampAmount(amount)) ?? 1
        let next = product.clampAmount(String(cur + delta))
        amount = next
        productStore.setAmount(next, for: product)
    }

    private func applySpeed(_ value: String) {
        switch value {
        case "max":
            concurrency = "16"
            interval = "40"
        case "fast":
            concurrency = "8"
            interval = "40"
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

private enum BurstRoundResult {
    case ran
    case yidun
    case hit
}
