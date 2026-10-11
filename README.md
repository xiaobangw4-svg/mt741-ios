# MT741

Windows 上写的 iOS App：SKU **741** 飞天 500ml 商品卡 + 短信登录 + 官方 H5。

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

1. 跑 **Build IPA**，从产物下载 `MT741.ipa`
2. Windows 安装 [Sideloadly](https://sideloadly.io/)
3. iPhone 用数据线连电脑，点信任
4. iOS 16+：设置 → 隐私与安全性 → **开发者模式** 打开并重启
5. Sideloadly 填免费 Apple ID，拖入 `MT741.ipa`，点 Start
6. 设置 → 通用 → VPN 与设备管理 → 信任这个开发者
7. 主屏幕打开 **MT741**。免费签名大约 7 天过期，过期再签一次

## App 做什么

- 商品页：741 / `IMTP1000313` / 飞天 500ml
- 登录页：短信验证码，打 `app.moutai519.com.cn` 的 vcode / login；会话不保存 `idCode`
- H5 页：WKWebView 打开官方 `h5.moutai519.com.cn`

验证码 MD5 与 Windows 工具同一套盐：`md5(VCODE_SALT + mobile + timestamp)`。

## 测试

- 逻辑：SKU 741、vcode MD5 夹具、MT-V 夹具、会话不含 idCode
- UI：启动看到 741 商品卡；切到登录页看到输入框（`waitForExistence`，不用 sleep）

改完代码只 push，以 CI 报告为准。
