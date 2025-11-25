//
//  frontendApp.swift
//  frontend
//
//  Created by macuser on 2025-11-18.
//

import SwiftUI
import SwiftData

@main
struct frontendApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Song.self, Playlist.self])
    }
}
