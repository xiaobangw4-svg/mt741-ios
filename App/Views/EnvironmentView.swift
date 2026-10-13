import SwiftUI

struct EnvironmentView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var productStore: ProductStore
    @State private var bsDvidDraft = ""
    @State private var bsDvidStatus = "未写入"

    var body: some View {
        NavigationStack {
            List {
                Section("真机") {
                    row("网络", "本机蜂窝/Wi-Fi，不是 GitHub 模拟器")
                        .accessibilityIdentifier("env.network")
                    row("设备 ID", sessionStore.session.authDeviceId.isEmpty ? sessionStore.session.deviceId : sessionStore.session.authDeviceId)
                    row("登录", sessionStore.session.statusText)
                }
                Section("浩天 BS-DVID") {
                    Text("同机官网 i茅台抓到的长令牌，写入 H5 UA。换号保留，清缓存不删。短 bid- 无效。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("env.bsdvid.help")
                    TextField("粘贴令牌或整行 UA", text: $bsDvidDraft, axis: .vertical)
                        .font(.footnote.monospaced())
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("env.bsdvid.field")
                    Button("写入") { saveBsDvid() }
                        .accessibilityIdentifier("env.bsdvid.save")
                    Text(bsDvidStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("env.bsdvid.status")
                }
                Section("已接入") {
                    row("短信登录", "app.moutai519.com.cn vcode/login")
                    row("实名", "APP getRealNameAuthInfo / realNameAuth，身份证不落盘")
                    row("找回身份证", "H5 getFindIdentityInfo / findIdentity")
                    row("注销", "APP register/cancel，需重复手机号确认，不可逆")
                    row("收货地址", "APP upsert / H5 query，默认贵州毕节七星关碧海街道")
                        .accessibilityIdentifier("env.address")
                    row("清缓存", "换号前一键清 WK Cookie/_u_id_/Bangcle，避免 4011 和 CWB 串号")
                        .accessibilityIdentifier("env.cache")
                    row("H5", "WKWebView + MT-Token-Wap，走官方 BotShield wasm")
                    row("异步请求", "n≤64，并发 1-16，间隔 0-2000ms")
                    row("易盾", "4025 走远程上号 ngrok 打电脑 8889；连不上弹官网点图")
                    row("支付", "order/pay + requestPay channel=71 拉起支付宝")
                    row("BS-DVID", "同机官网长令牌贴进 UA；不进 CWB 哈希，换号共用")
                    row("CWB", "H5 WKWebView 拦截 Content-Web-Bb，异步请求自动带上")
                    row("actId", "purchaseInfoV2 POST hot+spuId=\(productStore.selected.spu)")
                    row("组单", "2000 后 v1 compose/submit 出 orderId")
                    row("出单", "真机登录后点「自动出单」：加载官方页 → 现签 CWB → 拉 actId → 开火 → 组单支付")
                    row("SKU", "\(productStore.selected.sku) / \(productStore.selected.spu) / \(productStore.selected.volume)")
                }
                Section("本 App 没有") {
                    Text("fk1 / Bangcle 原生 SDK。心跳和 Content-Info-Bb 只在官方「i茅台」里。Sideload 的 MT741 补不出这一层。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("env.fk1")
                }
            }
            .navigationTitle("环境")
            .onAppear { loadBsDvidDraft() }
        }
    }

    private func loadBsDvidDraft() {
        let current = sessionStore.session.bsDvid
        if !current.isEmpty {
            bsDvidDraft = current
            bsDvidStatus = "本机已有 \(current.count) 字符"
        }
    }

    private func saveBsDvid() {
        let raw = bsDvidDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = sessionStore.applyBsDvid(bsDvidDraft)
        if raw.isEmpty {
            bsDvidStatus = "已清空，UA 省略 BS-DVID"
            return
        }
        if token.isEmpty {
            bsDvidStatus = "未写入：短 bid- 或长度不够"
            return
        }
        bsDvidDraft = token
        bsDvidStatus = "已写入 \(token.count) 字符，换号保留"
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
        }
        .accessibilityIdentifier("env.\(title)")
    }
}
