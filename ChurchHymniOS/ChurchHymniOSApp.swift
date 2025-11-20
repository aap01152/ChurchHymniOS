//
//  ChurchHymniOSApp.swift
//  ChurchHymniOS
//
//  Created by Wan Mekwi on 01/09/2025.
//

import SwiftUI
import SwiftData

@main
struct ChurchHymniOSApp: App {
    @StateObject private var externalDisplayManager = ExternalDisplayManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(externalDisplayManager)
        }
        .modelContainer(for: Hymn.self)
    }
}
