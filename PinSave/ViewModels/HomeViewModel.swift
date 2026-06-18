import Foundation
import FirebaseFunctions
import FirebaseFirestore
import UIKit

@MainActor
class HomeViewModel: ObservableObject {
    @Published var urlText = ""
    @Published var isLoading = false
    @Published var downloadedPin: PinDownload?
    @Published var errorMessage: String?
    @Published var showPaywall = false
    @Published var isPhotoSaving = false
    @Published var showSavedToPhotos = false

    private let functions = Functions.functions()
    private let db = Firestore.firestore()

    func pasteFromClipboard() {
        if let string = UIPasteboard.general.string {
            urlText = string
        }
    }

    func download(uid: String, isPremium: Bool) async {
        let url = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        guard url.contains("pinterest.com") else {
            errorMessage = "Please enter a valid Pinterest URL"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let callable = functions.httpsCallable("downloadPin")
            let result = try await callable.call(["pinUrl": url])

            guard let data = result.data as? [String: Any] else {
                throw NSError(domain: "PinSave", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }

            if let errorCode = data["errorCode"] as? String, errorCode == "subscription_required" {
                showPaywall = true
                isLoading = false
                return
            }

            var pin = PinDownload(
                pinUrl: url,
                imageUrl: data["imageUrl"] as? String,
                videoUrl: data["videoUrl"] as? String,
                thumbnailUrl: data["thumbnailUrl"] as? String ?? "",
                isVideo: data["isVideo"] as? Bool ?? false,
                title: data["title"] as? String,
                createdAt: Date()
            )
            pin.id = data["id"] as? String

            downloadedPin = pin
            urlText = ""

        } catch let error as NSError {
            if error.domain == FunctionsErrorDomain {
                let message = error.localizedDescription
                if message.contains("subscription_required") {
                    showPaywall = true
                } else {
                    errorMessage = message
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func saveToPhotos(pin: PinDownload) async {
        guard let urlString = pin.imageUrl, let url = URL(string: urlString) else { return }
        isPhotoSaving = true
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { isPhotoSaving = false; return }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            isPhotoSaving = false
            showSavedToPhotos = true
        } catch {
            isPhotoSaving = false
        }
    }
}
