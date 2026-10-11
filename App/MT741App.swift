import SwiftUI
import UIKit

@main
struct MT741App: App {
    @StateObject private var sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionStore)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                    CookieBridge.apply(sessionStore.session)
                }
        }
    }
}
