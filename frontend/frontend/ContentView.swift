import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = LibraryViewModel()
    @State private var showAddSheet = false
    @State private var showFullPlayer = false
    
    var body: some View {
        TabView {
            // TAB 1: Library
            NavigationView {
                LibraryListView(viewModel: viewModel)
                    .navigationTitle("Library")
                    .searchable(text: $viewModel.searchText, prompt: "Search songs...")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Menu {
                                Picker("Sort By", selection: $viewModel.sortOption) {
                                    ForEach(SortOption.allCases, id: \.self) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down.circle")
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button { showAddSheet = true } label: { Image(systemName: "plus") }
                        }
                    }
            }
            .tabItem { Label("Library", systemImage: "music.note.list") }
            
            // TAB 2: Playlists
            NavigationView {
                PlaylistListView(viewModel: viewModel)
                    .navigationTitle("Playlists")
            }
            .tabItem { Label("Playlists", systemImage: "music.note.list") }
            
            // TAB 3: Favorites
            NavigationView {
                FavoritesView(viewModel: viewModel)
                    .navigationTitle("Favorites")
            }
            .tabItem { Label("Favorites", systemImage: "heart.fill") }
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
                    .padding(.bottom, 49) // Lift above TabBar
            }
        }
    }
}

// Reusable Song List
struct LibraryListView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @State private var songToEdit: Song?
    
    var body: some View {
        List {
            ForEach(viewModel.filteredSongs) { song in
                SongRow(viewModel: viewModel, song: song, context: viewModel.filteredSongs)
                    .swipeActions(edge: .leading) {
                        Button {
                            viewModel.toggleFavorite(song: song)
                        } label: {
                            Label("Favorite", systemImage: song.isFavorite ? "heart.slash" : "heart")
                        }
                        .tint(.pink)
                        
                        Button {
                            songToEdit = song
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Menu("Add to Playlist...") {
                            ForEach(viewModel.playlists) { playlist in
                                Button(playlist.name) {
                                    viewModel.addToPlaylist(playlistID: playlist.id, song: song)
                                }
                            }
                        }
                    }
            }
            .onDelete(perform: viewModel.deleteSong)
        }
        .sheet(item: $songToEdit) { song in
            EditSongView(viewModel: viewModel, song: song)
        }
    }
}

struct SongRow: View {
    @ObservedObject var viewModel: LibraryViewModel
    let song: Song
    let context: [Song]
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(song.title).font(.headline)
                    .foregroundColor(viewModel.currentSong?.id == song.id ? .blue : .primary)
                Text(song.artist).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            if song.isFavorite {
                Image(systemName: "heart.fill").foregroundColor(.pink).font(.caption)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.play(song: song, context: context)
        }
    }
}

// Favorites Tab
struct FavoritesView: View {
    @ObservedObject var viewModel: LibraryViewModel
    var favs: [Song] { viewModel.songs.filter { $0.isFavorite } }
    
    var body: some View {
        List {
            ForEach(favs) { song in
                SongRow(viewModel: viewModel, song: song, context: favs)
            }
        }
    }
}

// Playlist Tab
struct PlaylistListView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @State private var showCreateAlert = false
    @State private var newPlaylistName = ""
    
    var body: some View {
        List {
            ForEach(viewModel.playlists) { playlist in
                NavigationLink(destination: PlaylistDetailView(viewModel: viewModel, playlist: playlist)) {
                    Text(playlist.name)
                }
            }
            .onDelete(perform: viewModel.deletePlaylist)
        }
        .toolbar {
            Button { showCreateAlert = true } label: { Image(systemName: "plus.circle") }
        }
        .alert("New Playlist", isPresented: $showCreateAlert) {
            TextField("Name", text: $newPlaylistName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                viewModel.createPlaylist(name: newPlaylistName)
                newPlaylistName = ""
            }
        }
    }
}

struct PlaylistDetailView: View {
    @ObservedObject var viewModel: LibraryViewModel
    let playlist: Playlist
    
    var playlistSongs: [Song] {
        // Map IDs back to actual Song objects (handles edits/metadata changes automatically)
        playlist.songIDs.compactMap { id in
            viewModel.songs.first(where: { $0.id == id })
        }
    }
    
    var body: some View {
        List {
            ForEach(playlistSongs) { song in
                SongRow(viewModel: viewModel, song: song, context: playlistSongs)
            }
            .onDelete { indices in
                viewModel.removeFromPlaylist(playlistID: playlist.id, at: indices)
            }
        }
        .navigationTitle(playlist.name)
    }
}

struct MiniPlayerView: View {
    @ObservedObject var viewModel: LibraryViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                // Artwork Thumbnail
                if let artName = viewModel.currentSong?.localArtworkName,
                   let artURL = getDocumentsDirectory().appendingPathComponent(artName).path as String?,
                   let image = UIImage(contentsOfFile: artURL) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 45, height: 45)
                        .cornerRadius(5)
                } else {
                    // Fallback Placeholder
                    Rectangle().fill(Color.gray.opacity(0.2))
                        .frame(width: 45, height: 45)
                        .cornerRadius(5)
                        .overlay(Image(systemName: "music.note").foregroundColor(.gray))
                }
                
                VStack(alignment: .leading) {
                    Text(viewModel.currentSong?.title ?? "Unknown")
                        .font(.headline)
                        .lineLimit(1)
                    Text(viewModel.currentSong?.artist ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Play/Pause Button
                Button {
                    viewModel.audioManager.togglePlayPause()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
        }
    }
    
    // Helper to find the image path
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
