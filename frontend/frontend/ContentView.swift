import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = LibraryViewModel()
    @State private var showAddSheet = false
    @State private var showFullPlayer = false // Controls the modal
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                List {
                    ForEach(viewModel.songs) { song in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(song.title).font(.headline)
                                Text(song.artist).font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            // Playing Indicator
                            if viewModel.currentSong?.id == song.id {
                                Image(systemName: "waveform")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.play(song: song)
                        }
                    }
                    .onDelete(perform: viewModel.deleteSong)
                }
                .listStyle(.insetGrouped)
                
                // Mini Player Overlay
                if viewModel.currentSong != nil {
                    MiniPlayerView(viewModel: viewModel)
                        .onTapGesture {
                            showFullPlayer = true
                        }
                        .transition(.move(edge: .bottom))
                }
            }
            .navigationTitle("Library")
            .toolbar {
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showAddSheet) {
                AddSongView(viewModel: viewModel)
            }
            .sheet(isPresented: $showFullPlayer) {
                FullPlayerView(viewModel: viewModel, audioManager: viewModel.audioManager)
            }
        }
    }
}

// Refactored MiniPlayer
struct MiniPlayerView: View {
    @ObservedObject var viewModel: LibraryViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                // Artwork Thumbnail
                Rectangle().fill(Color.gray.opacity(0.2))
                    .frame(width: 45, height: 45)
                    .cornerRadius(5)
                    .overlay(Image(systemName: "music.note").foregroundColor(.gray))
                
                Text(viewModel.currentSong?.title ?? "Unknown")
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Button {
                    viewModel.audioManager.togglePlayPause()
                } label: {
                    Image(systemName: viewModel.audioManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
        }
    }
}
