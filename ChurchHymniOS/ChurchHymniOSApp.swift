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
    
    // Worship session manager depends on external display manager
    @StateObject private var worshipSessionManager: WorshipSessionManager
    
    init() {
        let externalDisplayManager = ExternalDisplayManager()
        let worshipSessionManager = WorshipSessionManager(externalDisplayManager: externalDisplayManager)
        
        self._externalDisplayManager = StateObject(wrappedValue: externalDisplayManager)
        self._worshipSessionManager = StateObject(wrappedValue: worshipSessionManager)
        self._serviceFactory = StateObject(wrappedValue: ServiceFactoryManager())
    }
    
    var body: some Scene {
        WindowGroup {
            if serviceFactory.isInitialized, let factory = serviceFactory.factory {
                ContentView()
                    .environmentObject(externalDisplayManager)
                    .environmentObject(worshipSessionManager)
                    .environmentObject(factory)
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        // Refresh external display state when app becomes active
                        externalDisplayManager.refreshExternalDisplayState()
                        
                        // Restore worship session state to keep managers in sync
                        Task {
                            await worshipSessionManager.restoreStateAfterAppBecomesActive()
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                        // Save state when app goes to background/screen locks
                        worshipSessionManager.saveCurrentState()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                        // Save state when app enters background
                        worshipSessionManager.saveCurrentState()
                    }
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
            // CRITICAL FIX: Use proper production container instead of migration fallback
            let container = ModelContainerFactory.createProductionContainer()
            print("✅ Using production ModelContainer for persistent storage")
            
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
