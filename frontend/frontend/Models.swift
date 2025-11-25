import Foundation
import SwiftData

enum SortOption: String, CaseIterable {
    case dateAdded = "Date Added"
    case title = "Title"
    case artist = "Artist"
    case duration = "Duration"
}

enum RepeatMode {
    case none, one, all
}

// 1. Database Models
@Model
class Song {
    var id: UUID
    var title: String
    var artist: String
    var localFileName: String
    var localArtworkName: String?
    var dateAdded: Date
    var duration: TimeInterval
    var isFavorite: Bool
    
    @Relationship(inverse: \Playlist.songs) var playlists: [Playlist]?
    
    init(title: String, artist: String, localFileName: String, localArtworkName: String?, duration: TimeInterval) {
        self.id = UUID()
        self.title = title
        self.artist = artist
        self.localFileName = localFileName
        self.localArtworkName = localArtworkName
        self.dateAdded = Date()
        self.duration = duration
        self.isFavorite = false
        self.playlists = []
    }
}

@Model
class Playlist {
    var id: UUID
    var name: String
    var dateCreated: Date
    var songs: [Song] = []
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.dateCreated = Date()
    }
}

// 2. Network Helper (DTO)
struct SongDTO: Decodable {
    let download_url: String
    let title: String
    let artist: String
    let artwork_url: String?
}
