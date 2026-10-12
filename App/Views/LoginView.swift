import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var h5Runtime: H5Runtime
    @EnvironmentObject private var cwbStore: CWBStore
    @State private var mobile = ""
    @State private var vcode = ""
    @State private var idName = ""
    @State private var idNo = ""
    @State private var cancelMobile = ""
    @State private var banner = ""
    @State private var realNameStatus = "未查"
    @State private var findStatus = "未查"
    @State private var addressStatus = "未查"
    @State private var addrName = ""
    @State private var addrMobile = ""
    @State private var addrDetail = ""
    @State private var addrProvinceId = AddressDraft().provinceId
    @State private var addrProvinceName = AddressDraft().provinceName
    @State private var addrCityId = AddressDraft().cityId
    @State private var addrCityName = AddressDraft().cityName
    @State private var addrDistrictId = AddressDraft().districtId
    @State private var addrDistrictName = AddressDraft().districtName
    @State private var addrTownId = AddressDraft().townId
    @State private var addrTownName = AddressDraft().townName
    @State private var addrShipId = 0
    @State private var busy = false
    @State private var confirmCancel = false

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
                        .disabled(sessionStore.session.isLoggedIn)
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
                        .disabled(busy || sessionStore.session.isLoggedIn)
                        .accessibilityIdentifier("login.newDevice")
                    Button("退出登录", role: .destructive) { logout() }
                        .disabled(busy)
                        .accessibilityIdentifier("login.logout")
                    Button("一键清除缓存", role: .destructive) { Task { await clearCache() } }
                        .disabled(busy)
                        .accessibilityIdentifier("login.clearCache")
                    Text("换号前要清。WK 里的 Cookie、_u_id_、Bangcle 指纹会留给下一个号，容易 4011 或 CWB 串身份。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("login.clearNote")
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

                Section("实名 / 找回身份证") {
                    TextField("身份证姓名", text: $idName)
                        .textContentType(.none)
                        .accessibilityIdentifier("login.idName")
                    SecureField("身份证号", text: $idNo)
                        .textContentType(.none)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.characters)
                        .accessibilityIdentifier("login.idNo")
                    Text(realNameStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("login.realNameStatus")
                    Button("查询实名") { Task { await queryRealName() } }
                        .disabled(busy)
                        .accessibilityIdentifier("login.realNameQuery")
                    Button("提交实名") { Task { await submitRealName() } }
                        .disabled(busy)
                        .accessibilityIdentifier("login.realNameSubmit")
                    Text(findStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("login.findStatus")
                    Button("查询找回身份证") { Task { await queryFindIdentity() } }
                        .disabled(busy)
                        .accessibilityIdentifier("login.findQuery")
                    Button("提交找回身份证") { Task { await submitFindIdentity() } }
                        .disabled(busy)
                        .accessibilityIdentifier("login.findSubmit")
                    Text("换号或注销后再上号：先找回身份证，再提交实名。姓名和身份证号只用于当次请求，不写入本地。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("login.idNote")
                }

                Section("收货地址") {
                    TextField("收货人", text: $addrName)
                        .accessibilityIdentifier("login.addrName")
                    TextField("收货手机", text: $addrMobile)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("login.addrMobile")
                    TextField("详细地址", text: $addrDetail)
                        .accessibilityIdentifier("login.addrDetail")
                    TextField("省", text: $addrProvinceName)
                        .accessibilityIdentifier("login.addrProvince")
                    TextField("市", text: $addrCityName)
                        .accessibilityIdentifier("login.addrCity")
                    TextField("区", text: $addrDistrictName)
                        .accessibilityIdentifier("login.addrDistrict")
                    TextField("街道", text: $addrTownName)
                        .accessibilityIdentifier("login.addrTown")
                    Text(addressStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("login.addressStatus")
                    Button("查询地址") { Task { await queryAddress() } }
                        .disabled(busy)
                        .accessibilityIdentifier("login.addressQuery")
                    Button("保存地址") { Task { await saveAddress() } }
                        .disabled(busy)
                        .accessibilityIdentifier("login.addressSave")
                    Text("默认贵州毕节七星关碧海街道，可改名称。组单要用默认地址。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("login.addressNote")
                }

                Section("注销账号") {
                    TextField("再输入登录手机号确认", text: $cancelMobile)
                        .keyboardType(.numberPad)
                        .textContentType(.telephoneNumber)
                        .accessibilityIdentifier("login.cancelMobile")
                    Button("注销账号", role: .destructive) { requestCancel() }
                        .disabled(busy)
                        .accessibilityIdentifier("login.cancelAccount")
                    Text("不可逆。服务端只认当前登录 token，传错号会注销错号。同一手机号约 7 天后才能重新注册。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("login.cancelNote")
                }
            }
            .navigationTitle("登录")
            .onAppear {
                if mobile.isEmpty {
                    mobile = sessionStore.session.mobile
                }
                if addrMobile.isEmpty {
                    addrMobile = sessionStore.session.mobile
                }
            }
            .alert("注销账号不可逆", isPresented: $confirmCancel) {
                Button("取消", role: .cancel) {}
                Button("确认注销", role: .destructive) { Task { await cancelAccount() } }
            } message: {
                Text("该号 token 立即失效，抢购记录一并消失。同一手机号约 7 天后才能重新注册。")
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

    private func logout() {
        sessionStore.logout()
        resetSensitiveFields()
        banner = "已退出"
    }

    private func clearCache() async {
        busy = true
        defer { busy = false }
        sessionStore.resetForNextAccount()
        cwbStore.reset()
        await CookieBridge.wipeWebsiteData()
        h5Runtime.resetSite()
        await CookieBridge.applyAsync(sessionStore.session)
        vcode = ""
        resetSensitiveFields()
        banner = "缓存已清，可登录下一个号"
    }

    private func currentDraft() -> AddressDraft {
        var draft = AddressDraft()
        draft.shipAddressId = addrShipId
        draft.name = addrName
        draft.mobile = addrMobile.isEmpty ? sessionStore.session.mobile : addrMobile
        draft.address = addrDetail
        draft.provinceId = addrProvinceId
        draft.provinceName = addrProvinceName
        draft.cityId = addrCityId
        draft.cityName = addrCityName
        draft.districtId = addrDistrictId
        draft.districtName = addrDistrictName
        draft.townId = addrTownId
        draft.townName = addrTownName
        return draft
    }

    private func applyDraft(_ draft: AddressDraft) {
        addrShipId = draft.shipAddressId
        addrName = draft.name
        addrMobile = draft.mobile
        addrDetail = draft.address
        addrProvinceId = draft.provinceId
        addrProvinceName = draft.provinceName
        addrCityId = draft.cityId
        addrCityName = draft.cityName
        addrDistrictId = draft.districtId
        addrDistrictName = draft.districtName
        addrTownId = draft.townId
        addrTownName = draft.townName
    }

    private func resetSensitiveFields() {
        idName = ""
        idNo = ""
        cancelMobile = ""
        realNameStatus = "未查"
        findStatus = "未查"
        addressStatus = "未查"
        applyDraft(AddressDraft())
        addrName = ""
        addrMobile = ""
        addrDetail = ""
        addrShipId = 0
    }

    private func queryAddress() async {
        busy = true
        defer { busy = false }
        let result = await AccountOps.queryAddress(session: sessionStore.session)
        if let draft = result.draft {
            applyDraft(draft)
        }
        addressStatus = result.message
        banner = result.message
    }

    private func saveAddress() async {
        busy = true
        defer { busy = false }
        let result = await AccountOps.saveAddress(session: sessionStore.session, draft: currentDraft())
        addressStatus = result.message
        banner = result.message
        if result.ok {
            let again = await AccountOps.queryAddress(session: sessionStore.session)
            if let draft = again.draft {
                applyDraft(draft)
            }
        }
    }

    private func queryRealName() async {
        busy = true
        defer { busy = false }
        let info = await AccountOps.fetchRealName(session: sessionStore.session)
        realNameStatus = info.message
        banner = info.message
    }

    private func submitRealName() async {
        busy = true
        defer { busy = false }
        let result = await AccountOps.submitRealName(
            session: sessionStore.session,
            idCardNo: idNo,
            idCardName: idName
        )
        banner = result.message
        if result.ok {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            let info = await AccountOps.fetchRealName(session: sessionStore.session)
            realNameStatus = info.message
            banner = result.message + " → " + info.message
        }
    }

    private func queryFindIdentity() async {
        busy = true
        defer { busy = false }
        let info = await AccountOps.fetchFindIdentity(session: sessionStore.session)
        findStatus = info.message
        banner = info.message
    }

    private func submitFindIdentity() async {
        busy = true
        defer { busy = false }
        let info = await AccountOps.submitFindIdentity(
            session: sessionStore.session,
            idCardNo: idNo,
            name: idName
        )
        findStatus = info.message
        banner = info.message
    }

    private func requestCancel() {
        if let err = AccountOps.requireCancelConfirm(typed: cancelMobile, session: sessionStore.session) {
            banner = err
            return
        }
        confirmCancel = true
    }

    private func cancelAccount() async {
        busy = true
        defer { busy = false }
        let result = await AccountOps.cancelAccount(
            session: sessionStore.session,
            confirmMobile: cancelMobile
        )
        banner = result.message
        if result.ok {
            logout()
            banner = result.message
        }
    }

    private func mask(_ token: String) -> String {
        guard token.count > 8 else { return token.isEmpty ? "—" : "••••" }
        return String(token.prefix(4)) + "…" + String(token.suffix(4))
    }
}
