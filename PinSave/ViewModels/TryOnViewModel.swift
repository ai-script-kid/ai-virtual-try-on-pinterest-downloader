import Foundation
import FirebaseAuth
import FirebaseFunctions
import UIKit

enum TryOnError: LocalizedError {
    case noClothingSelected
    case noUserPhoto
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noClothingSelected: return "Please select a Pinterest image first"
        case .noUserPhoto: return "Please add your photo"
        case .apiError(let msg): return msg
        }
    }
}

@MainActor
class TryOnViewModel: ObservableObject {
    @Published var selectedPin: PinDownload?
    @Published var userImage: UIImage?
    @Published var resultImageUrl: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showPaywall = false

    private let functions = Functions.functions()

    func runTryOn() async {
        guard let pin = selectedPin else {
            errorMessage = TryOnError.noClothingSelected.localizedDescription
            return
        }
        guard let userImage else {
            errorMessage = TryOnError.noUserPhoto.localizedDescription
            return
        }
        let clothingUrl = pin.imageUrl ?? (pin.thumbnailUrl.isEmpty ? nil : pin.thumbnailUrl)
        guard let clothingUrl else {
            errorMessage = "No image available for this pin"
            return
        }
        guard let imageData = userImage.jpegData(compressionQuality: 0.85) else { return }

        // Ensure user is authenticated before calling the function
        if Auth.auth().currentUser == nil {
            do {
                try await Auth.auth().signInAnonymously()
            } catch {
                errorMessage = "Authentication failed. Please check your connection and try again."
                return
            }
        }

        isLoading = true
        errorMessage = nil
        resultImageUrl = nil

        do {
            let callable = functions.httpsCallable("tryOn")
            let result = try await callable.call([
                "clothingImageUrl": clothingUrl,
                "userImageBase64": imageData.base64EncodedString()
            ])

            if let data = result.data as? [String: Any],
               let url = data["resultUrl"] as? String {
                resultImageUrl = url
            }
        } catch let error as NSError {
            if error.domain == FunctionsErrorDomain {
                let msg = error.localizedDescription
                if msg.contains("subscription_required") {
                    showPaywall = true
                } else if msg.contains("credits_exhausted") {
                    errorMessage = "You've used all your AI try-on credits for this period. They'll reset on your next renewal."
                } else if error.code == 16 { // unauthenticated
                    errorMessage = "Authentication error. Please restart the app and try again."
                } else {
                    errorMessage = msg
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func reset() {
        resultImageUrl = nil
        errorMessage = nil
    }
}
