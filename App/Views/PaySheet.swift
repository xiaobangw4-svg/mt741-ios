import SwiftUI

struct PaySheet: View {
    let session: Session
    var autoStart: Bool = false
    @State var orderId: String
    @State var tn: String
    @State private var log = "channel=71。有订单号就 order/pay，有 TN 就 requestPay 拉起支付宝。"
    @State private var busy = false
    @State private var didAuto = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("订单") {
                    TextField("orderId", text: $orderId)
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("pay.orderId")
                    TextField("TN / channelTradeSn", text: $tn)
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("pay.tn")
                }
                Section {
                    Button(busy ? "处理中…" : "order/pay") { Task { _ = await doOrderPay() } }
                        .disabled(busy || orderId.isEmpty)
                        .accessibilityIdentifier("pay.order")
                    Button("requestPay 并打开支付宝") { Task { await doRequestPay(using: tn) } }
                        .disabled(busy || tn.isEmpty)
                        .accessibilityIdentifier("pay.request")
                    Button("打开官方 H5 订单页") {
                        if let url = URL(string: "https://h5.moutai519.com.cn/mt/item/smsp-detail?appConfig=2_1_2") {
                            PayClient.open(url)
                        }
                    }
                    .accessibilityIdentifier("pay.h5")
                }
                Section("日志") {
                    Text(log)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .accessibilityIdentifier("pay.log")
                }
            }
            .navigationTitle("支付")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                guard autoStart, !didAuto, !orderId.isEmpty else { return }
                didAuto = true
                let paidTn = await doOrderPay()
                if !paidTn.isEmpty {
                    await doRequestPay(using: paidTn)
                }
            }
        }
    }

    private func doOrderPay() async -> String {
        busy = true
        defer { busy = false }
        let result = await PayClient.orderPay(orderId: orderId, session: session, payChannel: 71)
        log = result.message
        if !result.tn.isEmpty {
            tn = result.tn
        }
        return result.tn
    }

    private func doRequestPay(using paidTn: String) async {
        busy = true
        defer { busy = false }
        let result = await PayClient.requestPay(tn: paidTn, orderId: orderId)
        log = result.message
        if let url = result.payURL {
            PayClient.open(url)
        }
    }
}
