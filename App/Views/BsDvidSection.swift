import SwiftUI

struct BsDvidSection: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var draft = ""
    @State private var status = "未写入"

    var body: some View {
        Section("浩天 BS-DVID") {
            Text("同机官网 i茅台长令牌，发码/出单会读剪贴板并写进 H5 UA。换号保留。可贴纯令牌、整行 UA，或 hook 的 H BS-DVID =。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("env.bsdvid.help")
            TextField("粘贴令牌、UA 或 H BS-DVID =", text: $draft, axis: .vertical)
                .font(.footnote.monospaced())
                .lineLimit(3...6)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("env.bsdvid.field")
            Button("写入") { save(draft) }
                .accessibilityIdentifier("env.bsdvid.save")
            Button("从剪贴板读") { save(CookieBridge.ingestPasteboard()) }
                .accessibilityIdentifier("env.bsdvid.pasteboard")
            Text(status)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("env.bsdvid.status")
        }
        .onAppear { refreshFromSession() }
    }

    private func refreshFromSession() {
        _ = sessionStore.ingestPasteboardIfEmpty()
        let current = sessionStore.session.bsDvid
        if current.isEmpty {
            status = "未写入，发码和出单会尝试剪贴板"
            return
        }
        draft = current
        status = "本机已有 \(current.count) 字符"
    }

    private func save(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = sessionStore.applyBsDvid(raw)
        if trimmed.isEmpty {
            status = "已清空，UA 省略 BS-DVID"
            draft = ""
            return
        }
        if token.isEmpty {
            status = "未写入：短 bid- 或格式不对"
            return
        }
        draft = token
        status = "已写入 \(token.count) 字符，换号保留"
    }
}
