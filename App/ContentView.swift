import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var tab = AppTab.product

    var body: some View {
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

            H5WebView()
                .tabItem { Label("H5", systemImage: "safari") }
                .tag(AppTab.h5)
                .accessibilityIdentifier("tab.h5")

            EnvironmentView()
                .tabItem { Label("环境", systemImage: "iphone") }
                .tag(AppTab.env)
                .accessibilityIdentifier("tab.env")
        }
        .tint(AppTheme.gold)
    }
}

enum AppTab: Hashable {
    case product, burst, login, h5, env
}

enum AppTheme {
    static let gold = Color(red: 0.90, green: 0.76, blue: 0.42)
    static let ink = Color(red: 0.11, green: 0.11, blue: 0.11)
}

#Preview {
    ContentView()
        .environmentObject(SessionStore())
}
