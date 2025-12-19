//
//  WorshipSessionManager.swift
//  ChurchHymn
//
//  Created by Claude on 13/12/2025.
//

import SwiftUI
import UIKit
import Combine

// MARK: - Worship Session Errors

enum WorshipSessionError: LocalizedError {
    case sessionAlreadyActive
    case externalDisplayNotReady(state: ExternalDisplayState)
    case failedToStart(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            return "Worship session is already active"
        case .externalDisplayNotReady(let state):
            return "External display not ready for worship session. Current state: \(state.rawValue)"
        case .failedToStart(let underlying):
            return "Failed to start worship session: \(underlying.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .sessionAlreadyActive:
            return "Stop the current worship session before starting a new one"
        case .externalDisplayNotReady:
            return "Ensure external display is connected and in ready state"
        case .failedToStart:
            return "Check external display connection and try again"
        }
    }
}

/// Manages worship sessions with persistent external display and background image
/// Coordinates with ExternalDisplayManager to provide seamless worship experience
@MainActor
final class WorshipSessionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether a worship session is currently active
    @Published var isWorshipSessionActive: Bool = false
    
    /// The background image to show during worship session
    @Published var worshipBackgroundImage: String = "serene"
    
    /// Current hymn being presented in worship session (if any)
    @Published var currentWorshipHymn: Hymn?
    
    // MARK: - Dependencies
    
    private let externalDisplayManager: ExternalDisplayManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(externalDisplayManager: ExternalDisplayManager) {
        self.externalDisplayManager = externalDisplayManager
        setupStateObservation()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Private Setup
    
    private func setupStateObservation() {
        // Monitor external display manager state changes
        externalDisplayManager.$state
            .sink { [weak self] newState in
                self?.handleExternalDisplayStateChange(newState)
            }
            .store(in: &cancellables)
    }
    
    private func handleExternalDisplayStateChange(_ newState: ExternalDisplayState) {
        // If external display gets disconnected, end worship session
        if newState == .disconnected && isWorshipSessionActive {
            Task {
                await stopWorshipSession()
            }
        }
    }
    
    // MARK: - Worship Session Lifecycle
    
    /// Start a worship session with persistent external display
    /// This will show the background image on the external display
    func startWorshipSession() async throws {
        // Validate current state
        guard !isWorshipSessionActive else {
            throw WorshipSessionError.sessionAlreadyActive
        }
        
        guard externalDisplayManager.state.canStartWorshipSession else {
            throw WorshipSessionError.externalDisplayNotReady(state: externalDisplayManager.state)
        }
        
        // Validate background image exists
        guard UIImage(named: worshipBackgroundImage) != nil else {
            print("Warning: Background image '\(worshipBackgroundImage)' not found, will use fallback")
            return
        }
        
        do {
            print("Starting worship session with background: \(worshipBackgroundImage)")
            
            // Transition external display to worship mode
            try await externalDisplayManager.startWorshipMode()
            
            // Update our state
            isWorshipSessionActive = true
            currentWorshipHymn = nil
            
            print("✅ Worship session started successfully")
        } catch {
            print("❌ Failed to start worship session: \(error.localizedDescription)")
            throw WorshipSessionError.failedToStart(underlying: error)
        }
    }
    
    /// Stop the current worship session
    /// This will return to normal connected state
    func stopWorshipSession() async {
        guard isWorshipSessionActive else { return }
        
        // Stop any current hymn presentation in worship session
        if externalDisplayManager.state == .worshipPresenting {
            await stopHymnPresentationInWorshipSession()
        }
        
        // Stop worship mode
        await externalDisplayManager.stopWorshipMode()
        
        // Update our state
        isWorshipSessionActive = false
        currentWorshipHymn = nil
        
        print("Worship session stopped")
    }
    
    // MARK: - Hymn Presentation in Worship Session
    
    /// Present a hymn within the active worship session
    /// After presentation ends, returns to worship background
    func presentHymnInWorshipSession(_ hymn: Hymn, startingAtVerse: Int = 0) async {
        guard isWorshipSessionActive else {
            print("Cannot present hymn - no active worship session")
            return
        }
        
        guard externalDisplayManager.state == .worshipMode else {
            print("Cannot present hymn - worship session not in correct state")
            return
        }
        
        do {
            // Present hymn in worship mode
            try await externalDisplayManager.presentHymnInWorshipMode(hymn, startingAtVerse: startingAtVerse)
            
            // Update current hymn
            currentWorshipHymn = hymn
            
            print("Hymn '\(hymn.title)' presented in worship session")
        } catch {
            print("Failed to present hymn in worship session: \(error.localizedDescription)")
        }
    }
    
    /// Stop hymn presentation within worship session
    /// Returns to worship background image
    func stopHymnPresentationInWorshipSession() async {
        guard isWorshipSessionActive && externalDisplayManager.state == .worshipPresenting else {
            return
        }
        
        // Stop hymn presentation and return to worship background
        await externalDisplayManager.stopHymnInWorshipMode()
        
        // Clear current hymn
        currentWorshipHymn = nil
        
        print("Hymn presentation stopped - returned to worship background")
    }
    
    // MARK: - Computed Properties
    
    /// Whether we can start a worship session
    var canStartWorshipSession: Bool {
        return !isWorshipSessionActive && externalDisplayManager.state.canStartWorshipSession
    }
    
    /// Whether we can stop the worship session
    var canStopWorshipSession: Bool {
        return isWorshipSessionActive
    }
    
    /// Whether we can present a hymn in the current worship session
    var canPresentHymnInWorshipSession: Bool {
        return isWorshipSessionActive && externalDisplayManager.state == .worshipMode
    }
    
    /// Whether we can stop hymn presentation in the current worship session
    var canStopHymnInWorshipSession: Bool {
        return isWorshipSessionActive && externalDisplayManager.state == .worshipPresenting
    }
    
    /// Text description of current worship session state
    var worshipSessionStatusText: String {
        if !isWorshipSessionActive {
            return "No worship session"
        }
        
        switch externalDisplayManager.state {
        case .worshipMode:
            return "Showing background"
        case .worshipPresenting:
            if let hymn = currentWorshipHymn {
                return "Presenting: \(hymn.title)"
            }
            return "Presenting hymn"
        default:
            return "Worship session active"
        }
    }
    
    // MARK: - Navigation Helpers
    
    /// Navigate to next verse in current worship hymn
    func nextVerse() {
        guard isWorshipSessionActive && externalDisplayManager.state == .worshipPresenting else { return }
        externalDisplayManager.nextVerse()
    }
    
    /// Navigate to previous verse in current worship hymn
    func previousVerse() {
        guard isWorshipSessionActive && externalDisplayManager.state == .worshipPresenting else { return }
        externalDisplayManager.previousVerse()
    }
    
    /// Navigate to specific verse in current worship hymn
    func goToVerse(_ index: Int) {
        guard isWorshipSessionActive && externalDisplayManager.state == .worshipPresenting else { return }
        externalDisplayManager.goToVerse(index)
    }
}
