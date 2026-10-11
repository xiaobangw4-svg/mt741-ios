import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var mobile = ""
    @State private var vcode = ""
    @State private var banner = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section("账号") {
                    TextField("手机号", text: $mobile)
                        .keyboardType(.numberPad)
                        .textContentType(.telephoneNumber)
                        .accessibilityIdentifier("login.mobile")
                    SecureField("短信验证码", text: $vcode)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("login.vcode")
                    TextField("设备 ID", text: $sessionStore.session.deviceId)
                        .font(.footnote.monospaced())
                        .accessibilityIdentifier("login.device")
                }

                Section {
                    Button(busy ? "发送中…" : "发送验证码") { Task { await sendCode() } }
                        .disabled(busy)
                        .accessibilityIdentifier("login.sendCode")
                    Button("登录") { Task { await submitLogin() } }
                        .disabled(busy)
                        .accessibilityIdentifier("login.submit")
                    Button("新设备") { sessionStore.rotateDevice() }
                        .disabled(busy)
                        .accessibilityIdentifier("login.newDevice")
                    Button("退出登录", role: .destructive) { sessionStore.logout() }
                        .disabled(busy)
                        .accessibilityIdentifier("login.logout")
                }

                Section("状态") {
                    Text(sessionStore.session.statusText)
                        .accessibilityIdentifier("login.status")
                    if sessionStore.session.isLoggedIn {
                        Text("userName \(sessionStore.session.userName)")
                            .accessibilityIdentifier("login.userName")
                        Text("token \(mask(sessionStore.session.token))")
                            .font(.footnote.monospaced())
                            .accessibilityIdentifier("login.token")
                    }
                    Text(banner.isEmpty ? "就绪" : banner)
                        .foregroundStyle(busy ? AppTheme.gold : .secondary)
                        .accessibilityIdentifier("login.banner")
                }
            }
            .navigationTitle("登录")
            .onAppear {
                if mobile.isEmpty {
                    mobile = sessionStore.session.mobile
                }
            }
        }
    }

    private func sendCode() async {
        busy = true
        banner = "正在发送验证码…"
        defer { busy = false }
        let result = await AuthClient().sendVCode(mobile: mobile, deviceId: sessionStore.session.deviceId)
        banner = result.message
    }

    private func submitLogin() async {
        busy = true
        defer { busy = false }
        let result = await AuthClient().login(
            mobile: mobile,
            vcode: vcode,
            deviceId: sessionStore.session.deviceId
        )
        banner = result.message
        if result.ok {
            sessionStore.applyLogin(result)
        }
    }

    private func mask(_ token: String) -> String {
        guard token.count > 8 else { return token.isEmpty ? "—" : "••••" }
        return String(token.prefix(4)) + "…" + String(token.suffix(4))
    }
}
