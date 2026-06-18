import SwiftUI
import FirebaseCore
import RevenueCat
import UIKit

@main
struct PinSaveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var subscriptionService = SubscriptionService()

    init() {
        FirebaseApp.configure()
        Purchases.logLevel = .error
        Purchases.configure(withAPIKey: "REVENUECAT_PUBLIC_SDK_KEY_HERE")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isLoading {
                    ZStack {
                        Color.appBackground.ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.terracotta)
                            ProgressView()
                        }
                    }
                } else {
                    ContentView()
                        .environmentObject(appState)
                        .environmentObject(subscriptionService)
                }
            }
        }
    }
}
