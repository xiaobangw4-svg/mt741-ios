import SwiftUI

struct BurstView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var actId = "103783"
    @State private var amount = "1"
    @State private var n = "8"
    @State private var concurrency = "8"
    @State private var target = "mock"
    @State private var customURL = ""
    @State private var cwb = ""
    @State private var log = "默认本机回放。官方地址要显式选「官方 H5」。"
    @State private var busy = false
    @State private var confirmOfficial = false

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
                    TextField("并发 c（1-16）", text: $concurrency)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("burst.c")
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
                }
                Section {
                    Button(busy ? "请求中…" : "开始异步请求") { start() }
                        .disabled(busy || actId.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("burst.start")
                    Button("只生成 body") { dryRun() }
                        .disabled(busy)
                        .accessibilityIdentifier("burst.dry")
                }
                Section("日志") {
                    Text(log)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .accessibilityIdentifier("burst.log")
                }
            }
            .navigationTitle("异步")
            .alert("打官方地址", isPresented: $confirmOfficial) {
                Button("取消", role: .cancel) {}
                Button("继续") { Task { await runBurst(BurstTarget.official) } }
            } message: {
                Text("会从这台 iPhone 并发 POST 官方抢购接口。没 CWB 多半 429。")
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

    private func runBurst(_ dest: BurstTarget) async {
        busy = true
        defer { busy = false }
        let req = BurstRequest(
            actId: actId.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            n: Int(n) ?? 8,
            concurrency: Int(concurrency) ?? 8,
            cwb: cwb,
            target: dest
        )
        log = "开始 \(dest.urlString) n=\(BurstClient.clampN(req.n)) c=\(BurstClient.clampC(req.concurrency)) sku=741"
        let stats = await BurstClient.burst(request: req, session: sessionStore.session)
        log = "完成 ok=\(stats.ok)/\(stats.n) fail=\(stats.fail) \(stats.elapsedMs)ms status=\(stats.status)\n\(stats.summary)"
    }
}
