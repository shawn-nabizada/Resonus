import SwiftUI
import Combine
import AVFoundation

@MainActor
class LibraryViewModel: ObservableObject {
    // Data
    @Published var songs: [Song] = []
    @Published var currentSong: Song?
    
    // UI State
    @Published var isDownloading = false
    @Published var errorMessage: String?
    
    // Audio Manager Dependency
    @Published var audioManager = AudioManager()
    
    // Dependencies
    private let backendBaseURL = "http://172.17.29.152:8000" // Update IP if needed
    private let libraryFileName = "library.json"
    
    init() {
        loadLibrary()
        
        // Handle Auto-Play Next
        audioManager.onTrackFinished = { [weak self] in
            self?.playNext()
        }
    }
    
    // MARK: - Audio Control
    func play(song: Song) {
        currentSong = song
        let fileURL = getDocumentsDirectory().appendingPathComponent(song.localFileName)
        
        // Start audio
        audioManager.startAudio(url: fileURL)
        
        // Update Lock Screen Text
        audioManager.updateNowPlayingInfo(title: song.title, artist: song.artist)
    }
    
    func playNext() {
        guard let current = currentSong, let index = songs.firstIndex(of: current) else { return }
        let nextIndex = index + 1
        if nextIndex < songs.count {
            play(song: songs[nextIndex])
        }
    }
    
    func playPrevious() {
        guard let current = currentSong, let index = songs.firstIndex(of: current) else { return }
        let prevIndex = index - 1
        if prevIndex >= 0 {
            play(song: songs[prevIndex])
        }
    }
    
    // MARK: - Networking
    func addSong(from urlString: String) async {
        isDownloading = true
        defer { isDownloading = false } // Ensures this runs even if error occurs
        
        do {
            // 1. Request Conversion
            guard let url = URL(string: "\(backendBaseURL)/convert") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["url": urlString])
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw NSError(domain: "Server", code: 500) }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let downloadPath = json?["download_url"] as? String ?? ""
            let title = json?["title"] as? String ?? "Unknown"
            let artist = json?["artist"] as? String ?? "Unknown"
            
            // 2. Download File
            guard let mp3URL = URL(string: "\(backendBaseURL)\(downloadPath)") else { return }
            let (mp3Data, _) = try await URLSession.shared.data(from: mp3URL)
            
            // 3. Save File
            let fileName = "\(UUID().uuidString).mp3"
            let saveLocation = getDocumentsDirectory().appendingPathComponent(fileName)
            try mp3Data.write(to: saveLocation)
            
            // 4. Calculate Duration (Client Side)
            let asset = AVURLAsset(url: saveLocation)
            let duration = try await asset.load(.duration).seconds
            
            // 5. Save Metadata
            let newSong = Song(title: title, artist: artist, localFileName: fileName, dateAdded: Date(), duration: duration)
            songs.append(newSong)
            saveLibrary()
            
        } catch {
            errorMessage = "Download failed. Check server connection."
        }
    }
    
    func deleteSong(at offsets: IndexSet) {
        offsets.forEach { index in
            let song = songs[index]
            let url = getDocumentsDirectory().appendingPathComponent(song.localFileName)
            try? FileManager.default.removeItem(at: url)
        }
        songs.remove(atOffsets: offsets)
        saveLibrary()
    }
    
    // MARK: - Persistence (JSON File)
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func saveLibrary() {
        let url = getDocumentsDirectory().appendingPathComponent(libraryFileName)
        if let encoded = try? JSONEncoder().encode(songs) {
            try? encoded.write(to: url)
        }
    }
    
    private func loadLibrary() {
        let url = getDocumentsDirectory().appendingPathComponent(libraryFileName)
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Song].self, from: data) {
            songs = decoded
        }
    }
}
