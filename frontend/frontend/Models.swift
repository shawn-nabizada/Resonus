import Foundation

enum SortOption: String, CaseIterable {
    case dateAdded = "Date Added"
    case title = "Title"
    case artist = "Artist"
    case duration = "Duration"
}

enum RepeatMode {
    case none, one, all
}

struct Song: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var artist: String
    let localFileName: String
    let localArtworkName: String?
    let dateAdded: Date
    var duration: TimeInterval = 0.0
    var isFavorite: Bool = false
}

struct Playlist: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var songIDs: [UUID] // References to the master library
    var dateCreated = Date()
}
