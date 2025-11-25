import SwiftUI
import Combine
import AVFoundation
import SwiftData

@MainActor
class LibraryViewModel: ObservableObject {
    // MARK: - State
    
    @Published var audioManager = AudioManager()
    @Published var currentSong: Song?
    @Published var isPlaying = false
    
    // Queue
    private var originalQueue: [Song] = []
    private var playbackQueue: [Song] = []
    @Published var shuffleMode = false
    @Published var repeatMode: RepeatMode = .none
    
    // UI State
    @Published var isDownloading = false
    @Published var errorMessage: String?
    
    // Backend Config
    private let backendBaseURL = "https://resonus-backend.onrender.com" // CHANGE THIS IP
    
    // Database Context (Injected from View)
    var modelContext: ModelContext?

    init() {
        setupAudioBindings()
    }
    
    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - SwiftData Actions (CRUD)
    // Meets Requirement: Meaningful CRUD
    
    func deleteSong(_ song: Song) {
        // 1. Delete file from disk
        let url = getDocumentsDirectory().appendingPathComponent(song.localFileName)
        try? FileManager.default.removeItem(at: url)
        if let art = song.localArtworkName {
            let artUrl = getDocumentsDirectory().appendingPathComponent(art)
            try? FileManager.default.removeItem(at: artUrl)
        }
        
        // 2. Delete from Database
        modelContext?.delete(song)
    }
    
    func deletePlaylist(_ playlist: Playlist) {
        modelContext?.delete(playlist)
    }
    
    func toggleFavorite(song: Song) {
        song.isFavorite.toggle()
    }
    
    func createPlaylist(name: String) {
        let newPlaylist = Playlist(name: name)
        modelContext?.insert(newPlaylist)
    }
    
    func renamePlaylist(_ playlist: Playlist, newName: String) {
            playlist.name = newName
        }
    
    func addToPlaylist(playlist: Playlist, song: Song) {
        if !playlist.songs.contains(song) {
            playlist.songs.append(song)
        }
    }
    
    func removeFromPlaylist(playlist: Playlist, song: Song) {
        if let index = playlist.songs.firstIndex(of: song) {
            playlist.songs.remove(at: index)
        }
    }
    
    func updateSongMetadata(song: Song, newTitle: String, newArtist: String) {
        song.title = newTitle
        song.artist = newArtist
        
        // If this song is currently playing, update the Lock Screen info immediately
        if currentSong?.id == song.id {
            audioManager.updateNowPlayingInfo(title: newTitle, artist: newArtist)
        }
    }
    
    // MARK: - Networking (Download & Create)
    func addSong(from urlString: String) async {
        guard let context = modelContext else { return }
            isDownloading = true
            errorMessage = nil
            
            do {
                // 1. Networking
                guard let url = URL(string: "\(backendBaseURL)/convert") else { return }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: ["url": urlString])
                
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw NSError(domain: "Err", code: 1) }
                
                // 2. Parse DTO
                let dto = try JSONDecoder().decode(SongDTO.self, from: data)
                
                // 3. Download MP3
                guard let mp3URL = URL(string: "\(backendBaseURL)\(dto.download_url)") else { return }
                let (mp3Data, _) = try await URLSession.shared.data(from: mp3URL)
                let fileName = "\(UUID().uuidString).mp3"
                let saveLocation = getDocumentsDirectory().appendingPathComponent(fileName)
                try mp3Data.write(to: saveLocation)
                
                // 4. Download Art (Refactored to fix compiler error)
                var localArtName: String? = nil
                if let artPath = dto.artwork_url, let artURL = URL(string: "\(backendBaseURL)\(artPath)") {
                    do {
                        let (artData, _) = try await URLSession.shared.data(from: artURL)
                        let ext = (artPath as NSString).pathExtension
                        let artFileName = "\(UUID().uuidString).\(ext)"
                        try artData.write(to: getDocumentsDirectory().appendingPathComponent(artFileName))
                        localArtName = artFileName
                    } catch {
                        print("Artwork download failed (non-fatal)")
                    }
                }
                
                // 5. Get Duration
                let duration = try await AVURLAsset(url: saveLocation).load(.duration).seconds
                
                // 6. Insert into SwiftData
                let newSong = Song(
                    title: dto.title,
                    artist: dto.artist,
                    localFileName: fileName,
                    localArtworkName: localArtName,
                    duration: duration
                )
                
                await MainActor.run {
                    context.insert(newSong)
                }
                
            } catch {
                await MainActor.run { errorMessage = "Error: \(error.localizedDescription)" }
            }
            
            await MainActor.run { isDownloading = false }
    }

    // MARK: - Playback Logic
    func play(song: Song, context: [Song]) {
        originalQueue = context
        if shuffleMode {
            playbackQueue = originalQueue.shuffled()
            if let idx = playbackQueue.firstIndex(of: song) {
                playbackQueue.swapAt(0, idx)
            }
        } else {
            playbackQueue = originalQueue
        }
        
        if let index = playbackQueue.firstIndex(of: song) {
            startPlayback(at: index)
        }
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
        guard let current = currentSong else { return }
        
        guard let index = playbackQueue.firstIndex(where: { $0.id == current.id }) else { return }
        
        // FIX: Repeat One Logic
        if repeatMode == .one {
            audioManager.seek(to: 0)
            audioManager.player?.play()
            isPlaying = true
            return
        }
        
        let nextIndex = index + 1
        
        if nextIndex < playbackQueue.count {
            startPlayback(at: nextIndex)
        } else if repeatMode == .all {
            startPlayback(at: 0)
        } else {
            isPlaying = false
        }
    }
    
    func playPrevious() {
        if audioManager.currentTime > 3 {
            audioManager.seek(to: 0)
            audioManager.player?.play()
            return
        }
        
        guard let current = currentSong else { return }
        guard let index = playbackQueue.firstIndex(where: { $0.id == current.id }) else { return }
        
        let prevIndex = index - 1
        if prevIndex >= 0 {
            startPlayback(at: prevIndex)
        } else {
            audioManager.seek(to: 0)
            audioManager.player?.play()
        }
    }
    
    func toggleShuffle() {
        shuffleMode.toggle()
        guard let current = currentSong else { return }
        
        if shuffleMode {
            var newQueue = originalQueue.shuffled()
            
            newQueue.removeAll(where: { $0.id == current.id })
            
            newQueue.insert(current, at: 0)
            
            playbackQueue = newQueue
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
        audioManager.onTrackFinished = { [weak self] in self?.playNext() }
        audioManager.$isPlaying.receive(on: RunLoop.main).assign(to: &$isPlaying)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
