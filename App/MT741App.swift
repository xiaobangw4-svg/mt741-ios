import SwiftUI
import UIKit

@main
struct MT741App: App {
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var cwbStore = CWBStore()
    @StateObject private var h5Runtime = H5Runtime()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionStore)
                .environmentObject(cwbStore)
                .environmentObject(h5Runtime)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                    CookieBridge.apply(sessionStore.session)
                    h5Runtime.keepInWindow()
                    h5Runtime.bindIfNeeded(session: sessionStore.session, cwbStore: cwbStore)
                }
                .onChange(of: sessionStore.session) { _, session in
                    h5Runtime.bindIfNeeded(session: session, cwbStore: cwbStore)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        h5Runtime.keepInWindow()
                    }
                }
        }
    }
}
