import SwiftUI
import UIKit

@main
struct MT741App: App {
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var cwbStore = CWBStore()
    @StateObject private var h5Runtime = H5Runtime()
    @StateObject private var productStore = ProductStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionStore)
                .environmentObject(cwbStore)
                .environmentObject(h5Runtime)
                .environmentObject(productStore)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                    CookieBridge.apply(sessionStore.session)
                    h5Runtime.keepInWindow()
                    h5Runtime.bindIfNeeded(
                        session: sessionStore.session,
                        cwbStore: cwbStore,
                        product: productStore.selected
                    )
                }
                .onChange(of: sessionStore.session) { _, session in
                    h5Runtime.bindIfNeeded(
                        session: session,
                        cwbStore: cwbStore,
                        product: productStore.selected
                    )
                }
                .onChange(of: productStore.selected) { _, product in
                    h5Runtime.bindIfNeeded(
                        session: sessionStore.session,
                        cwbStore: cwbStore,
                        product: product,
                        forceLoad: true
                    )
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        h5Runtime.keepInWindow()
                    }
                }
        }
    }
}
