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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Hymn.self)
    }
}
