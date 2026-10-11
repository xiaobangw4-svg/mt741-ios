import SwiftUI

struct EnvironmentView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        NavigationStack {
            List {
                Section("真机") {
                    row("网络", "本机蜂窝/Wi-Fi，不是 GitHub 模拟器")
                    row("设备 ID", sessionStore.session.deviceId)
                    row("登录", sessionStore.session.statusText)
                }
                Section("已接入") {
                    row("短信登录", "app.moutai519.com.cn vcode/login")
                    row("H5", "WKWebView + MT-Token-Wap，走官方 BotShield wasm")
                    row("SKU", Product.sku741.sku + " / " + Product.sku741.spu)
                }
                Section("本 App 没有") {
                    Text("fk1 / Bangcle 原生 SDK。心跳和 Content-Info-Bb 只在官方「i茅台」里。Sideload 的 MT741 补不出这一层。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("env.fk1")
                }
            }
            .navigationTitle("环境")
        }
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
