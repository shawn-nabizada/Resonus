import SwiftUI

struct AddSongView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) var dismiss
    @State private var urlInput = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add Music from YouTube")
                    .font(.headline)
                    .padding(.top)
                
                TextField("Paste Link Here...", text: $urlInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                
                if viewModel.isDownloading {
                    ProgressView("Downloading & Converting...")
                        .padding()
                } else {
                    Button {
                        Task {
                            await viewModel.addSong(from: urlInput)
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        Text("Download Song")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(urlInput.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(urlInput.isEmpty)
                    .padding()
                }
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Import Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
