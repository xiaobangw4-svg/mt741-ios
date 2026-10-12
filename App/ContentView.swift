import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var cwbStore: CWBStore
    @EnvironmentObject private var h5Runtime: H5Runtime
    @EnvironmentObject private var productStore: ProductStore
    @State private var tab = AppTab.product

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Text(stageStatus)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.88))
                    .accessibilityIdentifier("h5.stageStatus")

                WebViewContainer(
                    runtime: h5Runtime,
                    session: sessionStore.session,
                    cwbStore: cwbStore,
                    product: productStore.selected
                )
                .frame(height: stageHeight(geo.size.height))
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("h5.container")

                TabView(selection: $tab) {
                    ProductView()
                        .tabItem { Label("商品", systemImage: "shippingbox") }
                        .tag(AppTab.product)
                        .accessibilityIdentifier("tab.product")

                    BurstView()
                        .tabItem { Label("异步", systemImage: "bolt") }
                        .tag(AppTab.burst)
                        .accessibilityIdentifier("tab.burst")

                    LoginView()
                        .tabItem { Label("登录", systemImage: "person.crop.circle") }
                        .tag(AppTab.login)
                        .accessibilityIdentifier("tab.login")

                    EnvironmentView()
                        .tabItem { Label("环境", systemImage: "iphone") }
                        .tag(AppTab.env)
                        .accessibilityIdentifier("tab.env")
                }
            }
        }
        .tint(AppTheme.gold)
    }

    private func stageHeight(_ total: CGFloat) -> CGFloat {
        max(280, min(total * 0.45, total - 360))
    }

    private var stageStatus: String {
        let cwb = cwbStore.cwb.count
        let h5 = h5Runtime.ready ? "H5就绪" : "H5加载"
        return "\(h5) · CWB \(cwb)/800 · \(h5Runtime.styleStatus)"
    }
}

enum AppTab: Hashable {
    case product, burst, login, env
}

enum AppTheme {
    static let gold = Color(red: 0.90, green: 0.76, blue: 0.42)
    static let ink = Color(red: 0.11, green: 0.11, blue: 0.11)
}

#Preview {
    ContentView()
        .environmentObject(SessionStore())
        .environmentObject(CWBStore())
        .environmentObject(H5Runtime())
        .environmentObject(ProductStore())
}
