import Foundation

struct Song: Identifiable, Codable, Hashable {
    var id = UUID()
    let title: String
    let artist: String
    let localFileName: String
    let dateAdded: Date
    var duration: TimeInterval = 0.0
}
