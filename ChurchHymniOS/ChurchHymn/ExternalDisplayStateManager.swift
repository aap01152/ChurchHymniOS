//
//  ExternalDisplayStateManager.swift
//  ChurchHymn
//
//  Created by Claude on 28/12/2025.
//

import Foundation
import SwiftUI

/// Manages persistence of external display and worship session state
/// Ensures state survives app backgrounding and screen locks
class ExternalDisplayStateManager {
    private static let stateKey = "ExternalDisplayPersistentState"
    
    /// Persistent state structure
    struct PersistentState: Codable {
        let externalDisplayState: String  // Raw value of ExternalDisplayState
        let isWorshipSessionActive: Bool
        let currentHymnId: String?
        let currentHymnTitle: String?
        let currentVerseIndex: Int
        let presentedHymns: [String]
        let timestamp: Date
        
        init(externalState: ExternalDisplayState, 
             worshipActive: Bool, 
             hymn: Hymn?, 
             verseIndex: Int,
             presentedHymns: [String]) {
            self.externalDisplayState = externalState.rawValue
            self.isWorshipSessionActive = worshipActive
            self.currentHymnId = hymn?.id.uuidString
            self.currentHymnTitle = hymn?.title
            self.currentVerseIndex = verseIndex
            self.presentedHymns = presentedHymns
            self.timestamp = Date()
        }
        
        var externalDisplayStateEnum: ExternalDisplayState? {
            return ExternalDisplayState(rawValue: externalDisplayState)
        }
        
        /// Check if state is recent (within last 30 minutes)
        var isRecent: Bool {
            return Date().timeIntervalSince(timestamp) < 1800 // 30 minutes
        }
    }
    
    /// Save current state to UserDefaults
    static func saveState(externalDisplayState: ExternalDisplayState,
                         worshipSessionActive: Bool,
                         currentHymn: Hymn?,
                         currentVerseIndex: Int,
                         presentedHymns: [String]) {
        let state = PersistentState(
            externalState: externalDisplayState,
            worshipActive: worshipSessionActive,
            hymn: currentHymn,
            verseIndex: currentVerseIndex,
            presentedHymns: presentedHymns
        )
        
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: stateKey)
            print("💾 Saved worship session state: \(externalDisplayState.rawValue), hymn: \(currentHymn?.title ?? "none")")
        } catch {
            print("❌ Failed to save state: \(error)")
        }
    }
    
    /// Load saved state from UserDefaults
    static func loadState() -> PersistentState? {
        guard let data = UserDefaults.standard.data(forKey: stateKey) else {
            print("📱 No saved state found")
            return nil
        }
        
        do {
            let state = try JSONDecoder().decode(PersistentState.self, from: data)
            
            // Only return recent state
            if state.isRecent {
                print("📱 Loaded saved state: \(state.externalDisplayState), hymn: \(state.currentHymnTitle ?? "none")")
                return state
            } else {
                print("📱 Saved state is too old, ignoring")
                clearState()
                return nil
            }
        } catch {
            print("❌ Failed to load state: \(error)")
            clearState()
            return nil
        }
    }
    
    /// Clear saved state
    static func clearState() {
        UserDefaults.standard.removeObject(forKey: stateKey)
        print("🗑️ Cleared saved worship session state")
    }
    
    /// Check if there's any saved state
    static func hasSavedState() -> Bool {
        return UserDefaults.standard.data(forKey: stateKey) != nil
    }
}