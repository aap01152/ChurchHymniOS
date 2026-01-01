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
    case sessionNotActive
    case externalDisplayNotReady(state: ExternalDisplayState)
    case noActiveService
    case serviceHasNoHymns
    case failedToStart(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            return "Worship session is already active"
        case .sessionNotActive:
            return "No worship session is currently active"
        case .externalDisplayNotReady(let state):
            return "External display not ready for worship session. Current state: \(state.rawValue)"
        case .noActiveService:
            return "No active service found"
        case .serviceHasNoHymns:
            return "Cannot start worship session with empty service"
        case .failedToStart(let underlying):
            return "Failed to start worship session: \(underlying.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .sessionAlreadyActive:
            return "Stop the current worship session before starting a new one"
        case .sessionNotActive:
            return "Start a worship session first"
        case .externalDisplayNotReady:
            return "Ensure external display is connected and in ready state"
        case .noActiveService:
            return "Create and activate a service before starting worship session"
        case .serviceHasNoHymns:
            return "Add at least one hymn to your active service before starting worship session"
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
    
    /// List of hymns presented during current worship session
    @Published private(set) var presentedHymns: [String] = []
    
    // MARK: - Dependencies
    
    private let externalDisplayManager: ExternalDisplayManager
    private var serviceService: ServiceService?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(externalDisplayManager: ExternalDisplayManager, serviceService: ServiceService? = nil) {
        self.externalDisplayManager = externalDisplayManager
        self.serviceService = serviceService
        setupStateObservation()
    }
    
    /// Update the service service reference after initialization
    func setServiceService(_ serviceService: ServiceService) {
        self.serviceService = serviceService
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
        
        // Validate active service has hymns
        if let serviceService = serviceService {
            guard let activeService = serviceService.activeService else {
                throw WorshipSessionError.noActiveService
            }
            
            let hymnCount = serviceService.serviceHymns.filter { $0.serviceId == activeService.id }.count
            guard hymnCount > 0 else {
                throw WorshipSessionError.serviceHasNoHymns
            }
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
            
            // Reset worship hymns history for new session
            presentedHymns.removeAll()
            
            // Save state
            saveCurrentState()
            
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
        
        // Clear saved state when stopping worship session
        externalDisplayManager.clearSavedState()
        
        print("Worship session stopped")
    }
    
    // MARK: - Hymn Presentation in Worship Session
    
    /// Present a hymn within the active worship session
    /// After presentation ends, returns to worship background
    /// Now supports seamless switching if already presenting
    func presentHymnInWorshipSession(_ hymn: Hymn, startingAtVerse: Int = 0) async {
        guard isWorshipSessionActive else {
            print("Cannot present hymn - no active worship session")
            return
        }
        
        // Check if we should switch hymns during active worship presentation
        if externalDisplayManager.state == .worshipPresenting {
            do {
                // Seamlessly switch to new hymn during worship session
                try await externalDisplayManager.presentOrSwitchToHymn(hymn, startingAtVerse: startingAtVerse)
                
                // Update current hymn
                currentWorshipHymn = hymn
                
                // Track hymn in worship history (avoid duplicates)
                if !presentedHymns.contains(hymn.title) {
                    presentedHymns.append(hymn.title)
                }
                
                // Save updated state
                saveCurrentState()
                
                print("Switched to hymn '\(hymn.title)' in worship session (total presented: \(presentedHymns.count))")
            } catch {
                print("Failed to switch hymn in worship session: \(error.localizedDescription)")
            }
            return
        }
        
        // Original logic for starting new presentation
        guard externalDisplayManager.state == .worshipMode else {
            print("Cannot present hymn - worship session not in correct state")
            return
        }
        
        do {
            // Present hymn in worship mode
            try await externalDisplayManager.presentHymnInWorshipMode(hymn, startingAtVerse: startingAtVerse)
            
            // Update current hymn
            currentWorshipHymn = hymn
            
            // Track hymn in worship history (avoid duplicates)
            if !presentedHymns.contains(hymn.title) {
                presentedHymns.append(hymn.title)
            }
            
            // Save updated state
            saveCurrentState()
            
            print("Hymn '\(hymn.title)' presented in worship session (total presented: \(presentedHymns.count))")
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
        
        // Save updated state (back to worship background)
        saveCurrentState()
        
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
    
    // MARK: - Seamless Hymn Switching
    
    /// Present the currently viewed hymn on external display without stopping current presentation
    /// This method enables seamless switching during worship sessions
    func presentCurrentlyViewedHymn(_ hymn: Hymn, startingAtVerse: Int = 0) async throws {
        // Validate worship session state
        guard isWorshipSessionActive else {
            throw WorshipSessionError.sessionNotActive
        }
        
        // Validate external display capabilities
        guard externalDisplayManager.state.supportsHymnSwitching || 
              externalDisplayManager.state == .worshipMode else {
            throw WorshipSessionError.externalDisplayNotReady(state: externalDisplayManager.state)
        }
        
        print("🎵 Seamlessly switching to hymn: \(hymn.title)")
        
        do {
            // Use existing seamless switching capability
            try await externalDisplayManager.presentOrSwitchToHymn(hymn, startingAtVerse: startingAtVerse)
            
            // Update worship session state
            currentWorshipHymn = hymn
            
            // Track hymn in worship history (avoid duplicates)
            if !presentedHymns.contains(hymn.title) {
                presentedHymns.append(hymn.title)
            }
            
            // Save persistent state
            saveCurrentState()
            
            print("✅ Successfully switched to hymn: \(hymn.title) in worship session")
            
        } catch {
            print("❌ Failed to switch to hymn: \(hymn.title) - \(error.localizedDescription)")
            throw WorshipSessionError.failedToStart(underlying: error)
        }
    }
    
    /// Check if a hymn can be seamlessly presented
    func canPresentHymn(_ hymn: Hymn) -> Bool {
        return isWorshipSessionActive && 
               (externalDisplayManager.state.supportsHymnSwitching || 
                externalDisplayManager.state == .worshipMode) &&
               currentWorshipHymn?.id != hymn.id
    }
    
    // MARK: - State Recovery
    
    /// Restore worship session state after app becomes active
    /// This ensures the worship session manager stays in sync with external display manager
    func restoreStateAfterAppBecomesActive() async {
        print("Restoring worship session state...")
        
        // First, try to restore from saved persistent state
        if let savedState = ExternalDisplayStateManager.loadState() {
            await restoreFromSavedState(savedState)
            return
        }
        
        // Fallback to current in-memory state sync
        await restoreFromCurrentState()
    }
    
    /// Restore from saved persistent state
    private func restoreFromSavedState(_ savedState: ExternalDisplayStateManager.PersistentState) async {
        guard let savedExternalState = savedState.externalDisplayStateEnum else {
            print("❌ Invalid saved external display state")
            return
        }
        
        print("📱 Restoring worship session from saved state: \(savedExternalState.rawValue)")
        
        // Restore worship session properties
        isWorshipSessionActive = savedState.isWorshipSessionActive
        presentedHymns = savedState.presentedHymns
        
        if savedExternalState == .worshipMode {
            // Clear current hymn - we're back to background
            currentWorshipHymn = nil
            print("📱 Restored to worship background mode")
            
        } else if savedExternalState == .worshipPresenting, 
                  let hymnId = savedState.currentHymnId,
                  let hymnTitle = savedState.currentHymnTitle {
            
            // For now, we'll restore worship background and log the hymn that should be restored
            // The actual hymn restoration will need to be handled by the UI layer when it has access to hymns
            print("📱 Need to restore hymn presentation: \(hymnTitle) (ID: \(hymnId))")
            print("📱 Falling back to worship background - UI will need to handle hymn restoration")
            
            // Set state to worship mode for now
            externalDisplayManager.state = .worshipMode
            currentWorshipHymn = nil
        }
        
        print("📱 Worship session state restored: active=\(isWorshipSessionActive), hymn=\(currentWorshipHymn?.title ?? "none")")
    }
    
    /// Fallback restoration from current in-memory state
    private func restoreFromCurrentState() async {
        let externalState = externalDisplayManager.state
        let wasInWorshipMode = externalState.isWorshipSession
        
        print("📱 Restoring worship session from current state: external=\(externalState), current=\(isWorshipSessionActive)")
        
        // If external display indicates worship mode but we think we're not active, sync the state
        if wasInWorshipMode && !isWorshipSessionActive {
            print("Syncing worship session state - was active before app went to background")
            isWorshipSessionActive = true
        }
        
        // If external display is in worship mode but no hymn presenting, clear current hymn
        if externalState == .worshipMode && currentWorshipHymn != nil {
            print("Clearing current worship hymn - back to background")
            currentWorshipHymn = nil
        }
        
        // If external display is presenting a hymn in worship session, sync the current hymn
        if externalState == .worshipPresenting, let externalHymn = externalDisplayManager.currentHymn {
            if currentWorshipHymn?.id != externalHymn.id {
                print("Syncing current worship hymn: \(externalHymn.title)")
                currentWorshipHymn = externalHymn
                
                // Add to history if not already there
                if !presentedHymns.contains(externalHymn.title) {
                    presentedHymns.append(externalHymn.title)
                }
            }
        }
        
        print("Worship session state restored: active=\(isWorshipSessionActive), external state=\(externalState), current hymn=\(currentWorshipHymn?.title ?? "none")")
    }
    
    /// Save current worship session state
    func saveCurrentState() {
        // CRITICAL FIX: Don't auto-clear state during startup - only save when session is active
        guard isWorshipSessionActive else {
            // Don't clear state automatically - only when explicitly stopping session
            return
        }
        
        externalDisplayManager.saveCurrentState(
            worshipSessionActive: isWorshipSessionActive,
            presentedHymns: presentedHymns
        )
    }
    
    // MARK: - Worship History
    
    /// Get the current worship session hymns history as JSON string
    func getWorshipHymnsHistoryJSON() -> String? {
        guard !presentedHymns.isEmpty else { return nil }
        
        do {
            let jsonData = try JSONEncoder().encode(presentedHymns)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Failed to encode worship hymns history: \(error)")
            return nil
        }
    }
}
