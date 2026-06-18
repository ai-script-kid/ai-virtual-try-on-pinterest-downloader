import Foundation
import FirebaseFirestore

@MainActor
class DownloadsViewModel: ObservableObject {
    @Published var downloads: [PinDownload] = []
    @Published var isLoading = false
    @Published var selectedPin: PinDownload?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening(uid: String) {
        listener?.remove()
        isLoading = true

        listener = db.collection("users").document(uid)
            .collection("downloads")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    self?.isLoading = false
                    guard let docs = snapshot?.documents else { return }
                    self?.downloads = docs.compactMap { try? $0.data(as: PinDownload.self) }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func delete(pin: PinDownload, uid: String) async {
        guard let id = pin.id else { return }
        try? await db.collection("users").document(uid)
            .collection("downloads").document(id).delete()
    }
}
