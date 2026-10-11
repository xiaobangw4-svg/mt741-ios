# MT741

Windows 上写的 iOS App：SKU **741** 飞天 500ml、SKU **10193** 飞天 100ml + 短信登录 + 官方 H5。

编译和真机环境都走 GitHub Actions，本机不需要 Xcode。

仓库流程来自 [`wenjinliuu/ios-ci-workflows`](https://github.com/wenjinliuu/ios-ci-workflows)（两个 `u`）。GitHub 上搜 `wenjinlivu` 是 404。

当前钉死 **v1.1.0**：`df71d6096d6d39ea799179cb2635703548b07ae0`。

## 两种「手机上看」

| 工作流 | 你在手机上看到的 | 要不要 Apple 证书 |
| --- | --- | --- |
| **Live Preview** | CI 里的 **模拟器** 画面（MJPEG），用手机浏览器打开 | 不要。只要一个 ≥12 位预览密码 |
| **Build IPA** | 未签名 IPA，用 Sideloadly + 免费 Apple ID 装到真机 | 不要付费账号。7 天要重签 |
| **TestFlight** | 装到 **真机** 上的 App | 要。Apple Team + App Store Connect API Key |

Live Preview 不是真机运行；真机安装走 TestFlight。

## 本机（Windows）怎么用

1. 改 `App/`、`Tests/`、`.ios-ci.yml`
2. `git push`
3. 打开 GitHub Actions 读 **Build & Test** 报告
4. 要在手机浏览器里看模拟器：Actions → **Live Preview** → Run workflow
5. 免费装到自己的 iPhone：Actions → **Build IPA** → 下载产物 `MT741-unsigned`，用 Sideloadly 安装
6. 要装到自己的 iPhone（TestFlight）：先配 Secrets，再跑 **TestFlight**，或打 `v*` 标签

工程由 CI 执行 `xcodegen generate`，不要提交 `MT741.xcodeproj`。

## 第一次推到 GitHub

```powershell
cd C:\Users\Administrator\work\mt741-ios
git init
git add .
git commit -m "Add MT741 iOS app with ios-ci-workflows v1.1.0"
gh repo create mt741-ios --private --source . --remote origin --push
```

没有 `gh` 就在 GitHub 网页新建空仓库，再：

```powershell
git remote add origin https://github.com/<你的用户名>/mt741-ios.git
git branch -M main
git push -u origin main
```

推上去之后会自动跑 **Build & Test**（这一级不需要任何 Secret）。

## Secrets（仓库 Settings → Secrets and variables → Actions）

### Live Preview（模拟器推到手机浏览器）

- `AGENT_PREVIEW_PASSWORD`：至少 12 位
- `AGENT_PREVIEW_TUNNEL_TOKEN`：可选。有 Cloudflare named tunnel 再填

跑完在 job summary 里拿 URL，手机浏览器打开，输入密码。

### TestFlight（真机）

- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY`（.p8 全文）

Bundle ID 现在是 `com.local.mt741`。要上 TestFlight，先在 Apple Developer 注册这个 ID（或改 `.ios-ci.yml` / `project.yml` 成你已经有的 ID），再跑 TestFlight 工作流。

## 免费 Sideloadly 装真机

细节和排障见 [笔记7](笔记7.md)。2026-10-11 已在 iPhone 26.2.1 装通，约 7 天要重签。

1. 跑 **Build IPA**，从产物下载 `MT741.ipa`（也可直接用桌面 `MT741-unsigned\MT741.ipa`）
2. Windows 安装 [Sideloadly](https://sideloadly.io/) 0.70.1
3. Clash Verge 必须把 `gsa.apple.com` / `developerservices2.apple.com` / `sideloadly.exe` 走代理，不要走 `apple.com` DIRECT（否则 GSA 503）
4. iPhone 用数据线连电脑，点信任。iOS 16+：设置 → 隐私与安全性 → **开发者模式**
5. Sideloadly 填免费 Apple ID，拖入 `MT741.ipa`，bundle `com.local.mt741`，点 **一次** Start
6. 设置 → 通用 → VPN 与设备管理 → 信任这个开发者
7. 主屏幕打开 **MT741**。免费签名大约 7 天过期，过期按笔记7再签一次

## App 做什么

- 商品页：点选 741 / `IMTP1000313` / 飞天 500ml（默认 1 瓶，`hot/branch/one`）或 10193 / `IMTP1000006` / 飞天 100ml（默认 2 瓶，`hot/branch/five`）
- 登录页：短信验证码，打 `app.moutai519.com.cn` 的 vcode / login；实名、找回身份证、注销账号。会话不保存 `idCode`，身份证不落盘
- H5 页：WKWebView 打开官方 `h5.moutai519.com.cn`，拦截 XHR/fetch 的 `Content-Web-Bb`
- 出单：真机登录后在异步页点 **自动出单**。App 加载官方商品页，由页内 wasm 现签 CWB、拉当日 actId、开火，2000 后 `compose`/`submit` 出 `orderId`，再 `order/pay` + `requestPay` channel=71 拉起支付宝

验证码 MD5 与 Windows 工具同一套盐：`md5(VCODE_SALT + mobile + timestamp)`。

## 测试

- 逻辑：SKU 741 / 10193、vcode MD5 夹具、MT-V 夹具、会话不含 idCode、实名/找回身份证/注销解析、CWB 拦截脚本、H5 页内开火脚本、purchaseInfoV2 解析、compose 明文
- UI：启动看到 741 和 10193 商品卡；切到登录页看到输入框、实名和注销按钮（`waitForExistence`，不用 sleep）

改完代码只 push，以 CI 报告为准。
