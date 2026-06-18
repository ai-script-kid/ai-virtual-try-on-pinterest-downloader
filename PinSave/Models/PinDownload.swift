import Foundation
import FirebaseFirestore

struct PinDownload: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var pinUrl: String
    var imageUrl: String?
    var videoUrl: String?
    var thumbnailUrl: String
    var isVideo: Bool
    var title: String?
    var createdAt: Date

    var displayId: String { id ?? UUID().uuidString }
}
