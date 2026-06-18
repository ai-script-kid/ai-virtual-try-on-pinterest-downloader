import Foundation
import RevenueCat
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

@MainActor
class SubscriptionService: ObservableObject {
    @Published var isPremium = false
    @Published var tryOnCredits: Int = 0
    @Published var offerings: Offerings?

    private let functions = Functions.functions()
    private var creditsListener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        Task { await refresh() }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                if let uid = user?.uid {
                    self?.startCreditsListener(uid: uid)
                } else {
                    self?.creditsListener?.remove()
                    self?.creditsListener = nil
                    self?.tryOnCredits = 0
                }
            }
        }
    }

    func refresh() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            isPremium = info.entitlements["premium"]?.isActive == true
            offerings = try await Purchases.shared.offerings()
            // No Firebase sync here — webhook handles server state,
            // sync only happens after explicit purchase/restore.
        } catch {
            print("RevenueCat error: \(error)")
        }
    }

    func purchase(package: Package) async throws {
        let result = try await Purchases.shared.purchase(package: package)
        let premium = result.customerInfo.entitlements["premium"]?.isActive == true
        isPremium = premium
        await syncStatusToFirebase(isPremium: premium)
    }

    func restore() async throws {
        let info = try await Purchases.shared.restorePurchases()
        let premium = info.entitlements["premium"]?.isActive == true
        isPremium = premium
        await syncStatusToFirebase(isPremium: premium)
    }

    private func startCreditsListener(uid: String) {
        creditsListener?.remove()
        creditsListener = Firestore.firestore()
            .collection("users").document(uid)
            .addSnapshotListener { [weak self] snap, _ in
                let credits = snap?.data()?["tryOnCredits"] as? Int ?? 0
                Task { @MainActor [weak self] in
                    self?.tryOnCredits = credits
                }
            }
    }

    private func syncStatusToFirebase(isPremium: Bool) async {
        guard Auth.auth().currentUser != nil else { return }
        do {
            let callable = functions.httpsCallable("updateSubscriptionStatus")
            _ = try await callable.call(["isPremium": isPremium])
        } catch {
            print("Sync subscription status failed: \(error)")
        }
    }
}
