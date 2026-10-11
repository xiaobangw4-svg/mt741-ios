import SwiftUI
import UIKit

@main
struct MT741App: App {
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var cwbStore = CWBStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionStore)
                .environmentObject(cwbStore)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                    CookieBridge.apply(sessionStore.session)
                }
        }
    }
}
