import SwiftUI

struct EditSongView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: LibraryViewModel
    let song: Song
    
    @State private var title: String
    @State private var artist: String
    
    init(viewModel: LibraryViewModel, song: Song) {
        self.viewModel = viewModel
        self.song = song
        _title = State(initialValue: song.title)
        _artist = State(initialValue: song.artist)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Metadata")) {
                    TextField("Title", text: $title)
                    TextField("Artist", text: $artist)
                }
            }
            .navigationTitle("Edit Song")
            .toolbar {
                Button("Save") {
                    viewModel.updateSongMetadata(song: song, newTitle: title, newArtist: artist)
                    dismiss()
                }
            }
        }
    }
}
