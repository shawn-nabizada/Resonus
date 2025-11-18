import SwiftUI
import Combine
import AVFoundation

@MainActor
class LibraryViewModel: ObservableObject {
    // MARK: - Library State
    @Published var songs: [Song] = []
    @Published var playlists: [Playlist] = []
    @Published var searchText = ""
    @Published var sortOption: SortOption = .dateAdded
    
    // MARK: - Playback State
    @Published var audioManager = AudioManager()
    @Published var currentSong: Song?
    @Published var isPlaying = false
    
    // Queue System
    private var originalQueue: [Song] = []   // The list user tapped on (Library or Playlist)
    private var playbackQueue: [Song] = []   // The actual list being played (affected by shuffle)
    @Published var shuffleMode = false
    @Published var repeatMode: RepeatMode = .none
    
    // UI State
    @Published var isDownloading = false
    @Published var errorMessage: String?
    
    // Dependencies
    private let backendBaseURL = "http://172.17.29.152:8000" // UPDATE THIS IP
    private let libraryFile = "library.json"
    private let playlistFile = "playlists.json"
    
    init() {
        loadData()
        setupAudioBindings()
    }
    
    // MARK: - 1. Search & Sort
    var filteredSongs: [Song] {
        var result = songs
        
        // Filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort
        switch sortOption {
        case .dateAdded: result.sort { $0.dateAdded > $1.dateAdded }
        case .title: result.sort { $0.title < $1.title }
        case .artist: result.sort { $0.artist < $1.artist }
        case .duration: result.sort { $0.duration < $1.duration }
        }
        
        return result
    }
    
    // MARK: - 2. Playback Logic (Queue, Shuffle, Repeat)
    func play(song: Song, context: [Song]) {
        // 1. Set the context (Library, Playlist, or Filtered Search results)
        originalQueue = context
        
        // 2. Build the Playback Queue
        if shuffleMode {
            playbackQueue = originalQueue.shuffled()
            // Ensure the tapped song plays first
            if let idx = playbackQueue.firstIndex(where: { $0.id == song.id }) {
                playbackQueue.swapAt(0, idx)
            }
        } else {
            playbackQueue = originalQueue
        }
        
        // 3. Find index and play
        guard let index = playbackQueue.firstIndex(where: { $0.id == song.id }) else { return }
        startPlayback(at: index)
    }
    
    private func startPlayback(at index: Int) {
        guard playbackQueue.indices.contains(index) else { return }
        let song = playbackQueue[index]
        
        currentSong = song
        isPlaying = true
        
        let url = getDocumentsDirectory().appendingPathComponent(song.localFileName)
        audioManager.startAudio(url: url)
        audioManager.updateNowPlayingInfo(title: song.title, artist: song.artist)
    }
    
    func playNext() {
        guard let current = currentSong, let index = playbackQueue.firstIndex(where: { $0.id == current.id }) else { return }
        
        // Handle Repeat One
        if repeatMode == .one {
            audioManager.seek(to: 0)
            return
        }
        
        let nextIndex = index + 1
        if nextIndex < playbackQueue.count {
            startPlayback(at: nextIndex)
        } else if repeatMode == .all {
            // Loop back to start
            startPlayback(at: 0)
        } else {
            // End of queue
            isPlaying = false
        }
    }
    
    func playPrevious() {
        // If within first 3 seconds, restart song. Otherwise go to prev.
        if audioManager.currentTime > 3 {
            audioManager.seek(to: 0)
            return
        }
        
        guard let current = currentSong, let index = playbackQueue.firstIndex(where: { $0.id == current.id }) else { return }
        let prevIndex = index - 1
        if prevIndex >= 0 {
            startPlayback(at: prevIndex)
        } else {
            startPlayback(at: 0)
        }
    }
    
    func toggleShuffle() {
        shuffleMode.toggle()
        guard let current = currentSong else { return }
        
        if shuffleMode {
            playbackQueue = originalQueue.shuffled()
            if let idx = playbackQueue.firstIndex(where: { $0.id == current.id }) {
                playbackQueue.swapAt(0, idx)
            }
        } else {
            playbackQueue = originalQueue
        }
    }
    
    func toggleRepeat() {
        switch repeatMode {
        case .none: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .none
        }
    }
    
    private func setupAudioBindings() {
        // Auto-play next when audio finishes
        audioManager.onTrackFinished = { [weak self] in
            self?.playNext()
        }
        
        // Sync play/pause state from AudioManager (Lock Screen) back to ViewModel
        audioManager.$isPlaying
            .receive(on: RunLoop.main)
            .assign(to: &$isPlaying)
    }
    
    // MARK: - 3. Data Management
    func toggleFavorite(song: Song) {
        if let index = songs.firstIndex(where: { $0.id == song.id }) {
            songs[index].isFavorite.toggle()
            saveData()
        }
    }
    
    func updateSongMetadata(song: Song, newTitle: String, newArtist: String) {
        if let index = songs.firstIndex(where: { $0.id == song.id }) {
            songs[index].title = newTitle
            songs[index].artist = newArtist
            saveData()
            // Update current song if it's the one playing
            if currentSong?.id == song.id {
                currentSong = songs[index]
                audioManager.updateNowPlayingInfo(title: newTitle, artist: newArtist)
            }
        }
    }
    
    func createPlaylist(name: String) {
        let newDetails = Playlist(name: name, songIDs: [])
        playlists.append(newDetails)
        saveData()
    }
    
    func addToPlaylist(playlistID: UUID, song: Song) {
        if let index = playlists.firstIndex(where: { $0.id == playlistID }) {
            if !playlists[index].songIDs.contains(song.id) {
                playlists[index].songIDs.append(song.id)
                saveData()
            }
        }
    }
    
    func deletePlaylist(at offsets: IndexSet) {
        playlists.remove(atOffsets: offsets)
        saveData()
    }
    
    func removeFromPlaylist(playlistID: UUID, at offsets: IndexSet) {
        if let index = playlists.firstIndex(where: { $0.id == playlistID }) {
            playlists[index].songIDs.remove(atOffsets: offsets)
            saveData()
        }
    }
    
    // MARK: - 4. Networking (Download)
    func addSong(from urlString: String) async {
        isDownloading = true
                errorMessage = nil
                
                do {
                    // 1. Request Conversion
                    guard let url = URL(string: "\(backendBaseURL)/convert") else { return }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    let body = ["url": urlString]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                        throw NSError(domain: "Resonus", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server Error"])
                    }
                    
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let downloadPath = json?["download_url"] as? String ?? ""
                    let title = json?["title"] as? String ?? "Unknown"
                    let artist = json?["artist"] as? String ?? "Unknown"
                    let artworkPath = json?["artwork_url"] as? String
                    
                    // 2. Download MP3
                    guard let mp3URL = URL(string: "\(backendBaseURL)\(downloadPath)") else { return }
                    let (mp3Data, _) = try await URLSession.shared.data(from: mp3URL)
                    
                    // 3. Save MP3
                    let fileName = "\(UUID().uuidString).mp3"
                    let saveLocation = getDocumentsDirectory().appendingPathComponent(fileName)
                    try mp3Data.write(to: saveLocation)
                    
                    // 4. Download Artwork (Optional)
                    var localArtName: String? = nil
                    if let artPath = artworkPath, let artURL = URL(string: "\(backendBaseURL)\(artPath)") {
                        do {
                            let (artData, _) = try await URLSession.shared.data(from: artURL)
                            let ext = (artPath as NSString).pathExtension
                            let artFileName = "\(UUID().uuidString).\(ext)"
                            let artSaveURL = getDocumentsDirectory().appendingPathComponent(artFileName)
                            try artData.write(to: artSaveURL)
                            localArtName = artFileName
                        } catch {
                            print("Artwork download failed: \(error)")
                        }
                    }
                    
                    // 5. Calculate Duration
                    let asset = AVURLAsset(url: saveLocation)
                    let duration = try await asset.load(.duration).seconds
                    
                    // 6. Create & Save
                    let newSong = Song(
                        title: title,
                        artist: artist,
                        localFileName: fileName,
                        localArtworkName: localArtName,
                        dateAdded: Date(),
                        duration: duration,
                        isFavorite: false // Default for new songs
                    )
                    
                    // Update Main Thread
                    await MainActor.run {
                        songs.append(newSong)
                        saveData() // Important: This saves the new JSON structure
                    }
                    
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed: \(error.localizedDescription)"
                    }
                }
                
                await MainActor.run {
                    isDownloading = false
                }
    }
    
    func deleteSong(at offsets: IndexSet) {
        offsets.forEach { index in
            let song = filteredSongs[index]
            // Remove file
            let url = getDocumentsDirectory().appendingPathComponent(song.localFileName)
            try? FileManager.default.removeItem(at: url)
            if let art = song.localArtworkName {
                let artUrl = getDocumentsDirectory().appendingPathComponent(art)
                try? FileManager.default.removeItem(at: artUrl)
            }
            // Remove from master list
            if let masterIndex = songs.firstIndex(where: { $0.id == song.id }) {
                songs.remove(at: masterIndex)
            }
        }
        saveData()
    }

    // MARK: - Persistence
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func saveData() {
        if let encodedSongs = try? JSONEncoder().encode(songs) {
            try? encodedSongs.write(to: getDocumentsDirectory().appendingPathComponent(libraryFile))
        }
        if let encodedPlaylists = try? JSONEncoder().encode(playlists) {
            try? encodedPlaylists.write(to: getDocumentsDirectory().appendingPathComponent(playlistFile))
        }
    }
    
    private func loadData() {
        let songUrl = getDocumentsDirectory().appendingPathComponent(libraryFile)
        if let data = try? Data(contentsOf: songUrl), let decoded = try? JSONDecoder().decode([Song].self, from: data) {
            songs = decoded
        }
        
        let playlistUrl = getDocumentsDirectory().appendingPathComponent(playlistFile)
        if let data = try? Data(contentsOf: playlistUrl), let decoded = try? JSONDecoder().decode([Playlist].self, from: data) {
            playlists = decoded
        }
    }
}
