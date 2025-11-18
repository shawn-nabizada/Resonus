import SwiftUI

struct FullPlayerView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject var audioManager: AudioManager
    
    // Helpers for formatting time (e.g. 3:45)
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // 1. Artwork Placeholder
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 250, height: 250)
                .overlay(
                    Image(systemName: "music.note")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100)
                        .foregroundColor(.gray)
                )
                .shadow(radius: 10)
                .padding(.top, 40)
            
            // 2. Song Info
            VStack(spacing: 8) {
                Text(viewModel.currentSong?.title ?? "Not Playing")
                    .font(.title2).bold()
                    .multilineTextAlignment(.center)
                
                Text(viewModel.currentSong?.artist ?? "Unknown Artist")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 3. Scrubber / Slider
            VStack(spacing: 5) {
                Slider(value: Binding(
                    get: { audioManager.currentTime },
                    set: { newValue in audioManager.seek(to: newValue) }
                ), in: 0...audioManager.duration)
                
                HStack {
                    Text(formatTime(audioManager.currentTime))
                    Spacer()
                    Text(formatTime(audioManager.duration))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 30)
            
            // 4. Controls
            HStack(spacing: 40) {
                Button {
                    viewModel.playPrevious()
                } label: {
                    Image(systemName: "backward.fill").font(.system(size: 30))
                }
                
                Button {
                    audioManager.togglePlayPause()
                } label: {
                    Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.blue)
                }
                
                Button {
                    viewModel.playNext()
                } label: {
                    Image(systemName: "forward.fill").font(.system(size: 30))
                }
            }
            .foregroundColor(.primary)
            .padding(.bottom, 50)
        }
        .padding()
    }
}
