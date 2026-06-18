import Foundation
import FirebaseAuth
import RevenueCat

@MainActor
class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = true
    @Published var selectedTab: Int = 0
    @Published var pendingTryOnPin: PinDownload?

    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                if let user = user {
                    self?.currentUser = user
                    self?.isLoading = false
                    try? await Purchases.shared.logIn(user.uid)
                } else {
                    await self?.signInAnonymously()
                }
            }
        }
    }

    deinit {
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    private func signInAnonymously() async {
        do {
            let result = try await Auth.auth().signInAnonymously()
            currentUser = result.user
        } catch {
            print("Anonymous auth failed: \(error)")
        }
        isLoading = false
    }

    var uid: String? { currentUser?.uid }
}
