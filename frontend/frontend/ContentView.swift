import SwiftUI
import SwiftData
import AVKit

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @StateObject var viewModel = LibraryViewModel()
    
    @Query(sort: \Song.dateAdded, order: .reverse) var songs: [Song]
    @Query(sort: \Playlist.dateCreated) var playlists: [Playlist]
    
    @State private var showAddSheet = false
    @State private var showFullPlayer = false
    
    // Editing States
    @State private var songToEdit: Song?
    
    // Playlist States
    @State private var showCreatePlaylistAlert = false
    @State private var newPlaylistName = ""
    
    @State private var showRenamePlaylistAlert = false
    @State private var playlistToRename: Playlist?
    @State private var renamePlaylistName = ""
    
    @State private var showToast = false
    @State private var toastMessage = ""
    
    func showToast(message: String) {
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }
    
    var body: some View {
        TabView {
            // MARK: - TAB 1: Library
            NavigationStack {
                if songs.isEmpty {
                    ContentUnavailableView(
                        "No Music Yet",
                        systemImage: "music.quarternote.3",
                        description: Text("Tap the + button to download your first song.")
                    )
                } else {
                    List {
                        ForEach(songs) { song in
                            SongRow(
                                viewModel: viewModel,
                                song: song,
                                context: songs,
                                playlists: playlists,
                                onEdit: { songToEdit = song },
                                onToast: showToast,
                                parentPlaylist: nil
                            )
                            .swipeActions(edge: .leading) {
                                Button { viewModel.toggleFavorite(song: song) } label: {
                                    Label("Fav", systemImage: song.isFavorite ? "heart.slash" : "heart")
                                }
                                .tint(.pink)
                            }
                        }
                    }
                    .navigationTitle("Library")
                    .toolbar {
                        Button { showAddSheet = true } label: { Image(systemName: "plus") }
                    }
                    .sheet(item: $songToEdit) { song in
                        EditSongView(viewModel: viewModel, song: song)
                    }
                }
            }
            .tabItem { Label("Library", systemImage: "music.note.list") }
            
            // MARK: - TAB 2: Playlists
            NavigationStack {
                List {
                    ForEach(playlists) { playlist in
                        NavigationLink(destination: PlaylistDetailView(viewModel: viewModel, playlist: playlist)) {
                            Text(playlist.name)
                        }
                        .contextMenu {
                            Button {
                                playlistToRename = playlist
                                renamePlaylistName = playlist.name
                                showRenamePlaylistAlert = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                playlistToRename = playlist
                                renamePlaylistName = playlist.name
                                showRenamePlaylistAlert = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { viewModel.deletePlaylist(playlists[$0]) }
                    }
                }
                .navigationTitle("Playlists")
                .toolbar {
                    Button {
                        newPlaylistName = ""
                        showCreatePlaylistAlert = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
                .alert("New Playlist", isPresented: $showCreatePlaylistAlert) {
                    TextField("Playlist Name", text: $newPlaylistName)
                    Button("Cancel", role: .cancel) { }
                    Button("Create") {
                        if !newPlaylistName.isEmpty {
                            viewModel.createPlaylist(name: newPlaylistName)
                        }
                    }
                }
                .alert("Rename Playlist", isPresented: $showRenamePlaylistAlert) {
                    TextField("New Name", text: $renamePlaylistName)
                    Button("Cancel", role: .cancel) { }
                    Button("Save") {
                        if let pl = playlistToRename, !renamePlaylistName.isEmpty {
                            viewModel.renamePlaylist(pl, newName: renamePlaylistName)
                        }
                    }
                }
            }
            .tabItem { Label("Playlists", systemImage: "music.note.list") }
        }
        .onAppear {
            viewModel.setContext(modelContext)
        }
        .sheet(isPresented: $showAddSheet) {
            AddSongView(viewModel: viewModel)
        }
        .sheet(isPresented: $showFullPlayer) {
            FullPlayerView(viewModel: viewModel, audioManager: viewModel.audioManager)
        }
        .overlay(alignment: .bottom) {
            if viewModel.currentSong != nil {
                MiniPlayerView(viewModel: viewModel)
                    .onTapGesture { showFullPlayer = true }
                    .padding(.bottom, 49)
            }
        }
        .overlay(alignment: .top) {
            if showToast {
                Text(toastMessage)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding(.top, 50)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(), value: showToast)
            }
        }
    }
}

// MARK: - Subviews

struct PlaylistDetailView: View {
    @ObservedObject var viewModel: LibraryViewModel
    let playlist: Playlist
    @Query var allPlaylists: [Playlist]
    @State private var songToEdit: Song?
    
    var body: some View {
        List {
            if playlist.songs.isEmpty {
                Text("No songs in playlist").foregroundColor(.gray)
            }
            ForEach(playlist.songs) { song in
                SongRow(
                    viewModel: viewModel,
                    song: song,
                    context: playlist.songs,
                    playlists: allPlaylists,
                    onEdit: { songToEdit = song },
                    onToast: nil,
                    parentPlaylist: playlist
                )
            }
            .onDelete { indexSet in
                indexSet.forEach { index in
                    viewModel.removeFromPlaylist(playlist: playlist, song: playlist.songs[index])
                }
            }
        }
        .navigationTitle(playlist.name)
        .sheet(item: $songToEdit) { song in
            EditSongView(viewModel: viewModel, song: song)
        }
    }
}

struct SongRow: View {
    @ObservedObject var viewModel: LibraryViewModel
    let song: Song
    let context: [Song]
    let playlists: [Playlist]
    var onEdit: () -> Void
    
    var onToast: ((String) -> Void)? = nil
    
    var parentPlaylist: Playlist? = nil
    
    var body: some View {
        HStack {
            // 1. Info & Playback
            HStack {
                VStack(alignment: .leading) {
                    Text(song.title).font(.headline)
                        .foregroundColor(viewModel.currentSong?.id == song.id ? .blue : .primary)
                    Text(song.artist).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                
                if viewModel.currentSong?.id == song.id {
                    Image(systemName: "waveform").foregroundColor(.blue)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.play(song: song, context: context)
            }
            
            // 2. Context-Aware Menu
            Menu {
                // --- SHARED ACTIONS (Always available) ---
                Button {
                    viewModel.toggleFavorite(song: song)
                } label: {
                    Label(song.isFavorite ? "Unfavorite" : "Favorite", systemImage: song.isFavorite ? "heart.slash" : "heart")
                }
                
                Button {
                    onEdit()
                } label: {
                    Label("Edit Metadata", systemImage: "pencil")
                }
                
                Divider()
                
                // --- CONTEXT SPECIFIC ACTIONS ---
                if let playlist = parentPlaylist {
                    // CASE A: Inside a Playlist -> Remove ONLY from playlist
                    Button(role: .destructive) {
                        viewModel.removeFromPlaylist(playlist: playlist, song: song)
                    } label: {
                        Label("Remove from Playlist", systemImage: "minus.circle")
                    }
                } else {
                    // CASE B: In Library -> Full Delete & Add to Playlist
                    Menu {
                        ForEach(playlists) { playlist in
                            Button(playlist.name) {
                                viewModel.addToPlaylist(playlist: playlist, song: song)
                                onToast?("Added to \(playlist.name)")
                            }
                        }
                    } label: {
                        Label("Add to Playlist", systemImage: "text.badge.plus")
                    }
                    
                    Button(role: .destructive) {
                        viewModel.deleteSong(song)
                    } label: {
                        Label("Delete from Library", systemImage: "trash")
                    }
                }
                
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 40, height: 40)
                    .foregroundColor(.gray)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }
}

struct MiniPlayerView: View {
    @ObservedObject var viewModel: LibraryViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                if let artName = viewModel.currentSong?.localArtworkName,
                   let artURL = getDocumentsDirectory().appendingPathComponent(artName).path as String?,
                   let image = UIImage(contentsOfFile: artURL) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 45, height: 45)
                        .cornerRadius(5)
                } else {
                    Rectangle().fill(Color.gray.opacity(0.2))
                        .frame(width: 45, height: 45)
                        .cornerRadius(5)
                        .overlay(Image(systemName: "music.note").foregroundColor(.gray))
                }
                
                VStack(alignment: .leading) {
                    Text(viewModel.currentSong?.title ?? "Unknown").font(.headline).lineLimit(1)
                    Text(viewModel.currentSong?.artist ?? "Unknown").font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
                Button { viewModel.audioManager.togglePlayPause() } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill").font(.title2)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
        }
    }
    
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.activeTintColor = .systemBlue
        picker.tintColor = .white
        return picker
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
