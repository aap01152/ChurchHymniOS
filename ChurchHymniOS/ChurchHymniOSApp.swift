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
    @StateObject private var serviceFactory = ServiceFactoryManager()
    
    var body: some Scene {
        WindowGroup {
            if serviceFactory.isInitialized, let factory = serviceFactory.factory {
                ContentView()
                    .environmentObject(externalDisplayManager)
                    .environmentObject(factory)
            } else {
                LoadingView()
                    .task {
                        await serviceFactory.initialize()
                    }
            }
        }
        .modelContainer(ServiceMigrationManager.createModelContainer())
    }
}

/// Manager for the service factory initialization
@MainActor
class ServiceFactoryManager: ObservableObject {
    @Published var isInitialized = false
    @Published var initializationError: Error?
    private(set) var factory: ServiceFactory?
    
    func initialize() async {
        do {
            let container = ServiceMigrationManager.createModelContainer()
            
            // Create SwiftDataManager with the container
            let dataManager = await SwiftDataManager(modelContainer: container)
            
            // Create and initialize the service factory
            let serviceFactory = try await ServiceFactory.createForSwiftUI(dataManager: dataManager)
            
            self.factory = serviceFactory
            self.isInitialized = true
        } catch {
            self.initializationError = error
            print("Failed to initialize service factory: \(error)")
        }
    }
}

/// Loading view shown during app initialization
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Initializing ChurchHymn...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
