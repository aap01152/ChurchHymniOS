//
//  ExternalDisplayTypes.swift
//  ChurchHymn
//
//  Created by paulo on 08/11/2025.
//

import Foundation
import SwiftUI

enum ExternalDisplayState: String, CaseIterable {
    case disconnected       // No external display connected
    case connected         // Display connected, not in use
    case presenting        // Individual hymn presentation (existing behavior)
    
    // WORSHIP SESSION STATES
    case worshipMode       // Worship session active, showing background
    case worshipPresenting // Worship session active, presenting hymn
    
    // Computed properties for state checking
    var isWorshipSession: Bool {
        switch self {
        case .worshipMode, .worshipPresenting:
            return true
        case .disconnected, .connected, .presenting:
            return false
        }
    }
    
    var isConnected: Bool {
        switch self {
        case .disconnected:
            return false
        case .connected, .presenting, .worshipMode, .worshipPresenting:
            return true
        }
    }
    
    var isPresenting: Bool {
        switch self {
        case .presenting, .worshipPresenting:
            return true
        case .disconnected, .connected, .worshipMode:
            return false
        }
    }
    
    var canStartWorshipSession: Bool {
        return self == .connected
    }
    
    var canPresentHymn: Bool {
        switch self {
        case .connected, .worshipMode:
            return true
        case .disconnected, .presenting, .worshipPresenting:
            return false
        }
    }
    
    /// Whether this state supports seamless hymn switching
    var supportsHymnSwitching: Bool {
        switch self {
        case .presenting, .worshipPresenting:
            return true
        default:
            return false
        }
    }
    
    /// Whether the state allows starting a new presentation
    var canStartPresentation: Bool {
        switch self {
        case .connected:
            return true
        case .disconnected, .presenting, .worshipMode, .worshipPresenting:
            return false
        }
    }
    
    /// Whether the state allows stopping the current presentation
    var canStopPresentation: Bool {
        switch self {
        case .presenting, .worshipPresenting:
            return true
        case .disconnected, .connected, .worshipMode:
            return false
        }
    }
    
    /// Whether the state supports verse navigation
    var supportsVerseNavigation: Bool {
        switch self {
        case .presenting, .worshipPresenting:
            return true
        default:
            return false
        }
    }
    
    /// Whether the state allows entering worship mode
    var canEnterWorshipMode: Bool {
        switch self {
        case .connected:
            return true
        case .disconnected, .presenting, .worshipMode, .worshipPresenting:
            return false
        }
    }
    
    /// Whether the state allows exiting worship mode
    var canExitWorshipMode: Bool {
        switch self {
        case .worshipMode, .worshipPresenting:
            return true
        case .disconnected, .connected, .presenting:
            return false
        }
    }
    
    /// Get the priority level for state transitions
    var transitionPriority: Int {
        switch self {
        case .disconnected: return 0
        case .connected: return 1
        case .worshipMode: return 2
        case .presenting: return 3
        case .worshipPresenting: return 4
        }
    }
    
    /// Get user-friendly display name for the state
    var displayName: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connected: return "Connected"
        case .presenting: return "Presenting"
        case .worshipMode: return "Worship Mode"
        case .worshipPresenting: return "Worship Presenting"
        }
    }
    
    /// Get appropriate icon for the state
    var systemIcon: String {
        switch self {
        case .disconnected: return "display.slash"
        case .connected: return "display"
        case .presenting: return "play.tv"
        case .worshipMode: return "cross.case"
        case .worshipPresenting: return "cross.case.fill"
        }
    }
    
    /// Get state color for UI indicators
    var stateColor: Color {
        switch self {
        case .disconnected: return .gray
        case .connected: return .blue
        case .presenting: return .green
        case .worshipMode: return .purple
        case .worshipPresenting: return .purple
        }
    }
    
    /// Validate if transition to target state is allowed
    func canTransitionTo(_ targetState: ExternalDisplayState) -> Bool {
        switch (self, targetState) {
        // From disconnected
        case (.disconnected, .connected):
            return true
        case (.disconnected, _):
            return false
            
        // From connected
        case (.connected, .disconnected):
            return true
        case (.connected, .presenting):
            return true
        case (.connected, .worshipMode):
            return true
        case (.connected, .connected):
            return true // Allow same state
        case (.connected, .worshipPresenting):
            return false // Must go through worship mode first
            
        // From presenting
        case (.presenting, .connected):
            return true // Stop presentation
        case (.presenting, .disconnected):
            return true // Display disconnected
        case (.presenting, .presenting):
            return true // Switch hymn
        case (.presenting, _):
            return false
            
        // From worship mode
        case (.worshipMode, .connected):
            return true // Exit worship
        case (.worshipMode, .disconnected):
            return true // Display disconnected
        case (.worshipMode, .worshipPresenting):
            return true // Start presenting in worship
        case (.worshipMode, .worshipMode):
            return true // Allow same state
        case (.worshipMode, _):
            return false
            
        // From worship presenting
        case (.worshipPresenting, .worshipMode):
            return true // Stop hymn, stay in worship
        case (.worshipPresenting, .connected):
            return true // Exit worship completely
        case (.worshipPresenting, .disconnected):
            return true // Display disconnected
        case (.worshipPresenting, .worshipPresenting):
            return true // Switch hymn
        case (.worshipPresenting, _):
            return false
        }
    }
    
    /// Get suggested next actions for current state
    var suggestedActions: [String] {
        switch self {
        case .disconnected:
            return ["Connect external display", "Check display cable"]
        case .connected:
            return ["Present hymn", "Start worship session", "Check display setup"]
        case .presenting:
            return ["Switch hymn", "Stop presentation", "Navigate verses"]
        case .worshipMode:
            return ["Present hymn", "Exit worship mode", "Add hymns to service"]
        case .worshipPresenting:
            return ["Switch hymn", "Stop hymn", "Navigate verses", "Exit worship"]
        }
    }
    
    /// Get transition error message if transition is not allowed
    func transitionErrorMessage(to targetState: ExternalDisplayState) -> String? {
        guard !canTransitionTo(targetState) else { return nil }
        
        switch (self, targetState) {
        case (.disconnected, .presenting):
            return "Cannot start presentation without an external display connection."
        case (.disconnected, .worshipMode):
            return "Cannot start worship session without an external display connection."
        case (.connected, .worshipPresenting):
            return "Must enter worship mode before presenting hymns in worship session."
        case (.presenting, .worshipMode):
            return "Stop current presentation before starting worship session."
        case (.presenting, .worshipPresenting):
            return "Exit current presentation mode to use worship session."
        case (.worshipMode, .presenting):
            return "Cannot use standard presentation mode during worship session."
        default:
            return "State transition from \(self.displayName) to \(targetState.displayName) is not allowed."
        }
    }
}

enum ExternalDisplayError: Error, LocalizedError {
    case noExternalDisplayFound
    case sceneConfigurationFailed
    case windowCreationFailed
    case presentationFailed(String)
    case notCurrentlyPresenting
    case invalidStateTransition(from: ExternalDisplayState, to: ExternalDisplayState)
    case stateValidationFailed(String)
    case hymnSwitchingNotSupported
    case worshipSessionRequired
    case displayDisconnectedDuringOperation
    
    var errorDescription: String? {
        switch self {
        case .noExternalDisplayFound:
            return "No external display found. Please connect a projector or external monitor."
        case .sceneConfigurationFailed:
            return "Failed to configure external display scene."
        case .windowCreationFailed:
            return "Failed to create external display window."
        case .presentationFailed(let details):
            return "Failed to present to external display: \(details)"
        case .notCurrentlyPresenting:
            return "Cannot switch hymn: not currently presenting to external display."
        case .invalidStateTransition(let from, let to):
            return "Invalid state transition from \(from.displayName) to \(to.displayName)."
        case .stateValidationFailed(let details):
            return "State validation failed: \(details)"
        case .hymnSwitchingNotSupported:
            return "Hymn switching is not supported in the current state. Start a presentation first."
        case .worshipSessionRequired:
            return "This operation requires an active worship session."
        case .displayDisconnectedDuringOperation:
            return "External display was disconnected during the operation."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noExternalDisplayFound:
            return "Connect an external display via HDMI, USB-C, or AirPlay and try again."
        case .sceneConfigurationFailed:
            return "Restart the app and reconnect the external display."
        case .windowCreationFailed:
            return "Try disconnecting and reconnecting the external display."
        case .presentationFailed:
            return "Check the external display connection and try presenting again."
        case .notCurrentlyPresenting:
            return "Start a hymn presentation first, then try switching hymns."
        case .invalidStateTransition(let from, let to):
            return from.transitionErrorMessage(to: to)
        case .stateValidationFailed:
            return "Check the external display connection and app state."
        case .hymnSwitchingNotSupported:
            return "Start presenting a hymn to enable seamless switching."
        case .worshipSessionRequired:
            return "Start a worship session from the toolbar to use this feature."
        case .displayDisconnectedDuringOperation:
            return "Reconnect the external display and try again."
        }
    }
}

struct ExternalDisplayInfo {
    let scene: UIWindowScene
    let bounds: CGRect
    let scale: CGFloat
    let maximumFramesPerSecond: Int
    
    var description: String {
        return "External Display: \(Int(bounds.width))×\(Int(bounds.height)) @\(scale)x, \(maximumFramesPerSecond)fps"
    }
}

/// State transition information for logging and debugging
struct StateTransition {
    let from: ExternalDisplayState
    let to: ExternalDisplayState
    let timestamp: Date
    let reason: String?
    let success: Bool
    let error: ExternalDisplayError?
    
    init(from: ExternalDisplayState, to: ExternalDisplayState, reason: String? = nil, success: Bool = true, error: ExternalDisplayError? = nil) {
        self.from = from
        self.to = to
        self.timestamp = Date()
        self.reason = reason
        self.success = success
        self.error = error
    }
    
    var description: String {
        let status = success ? "✅" : "❌"
        let errorInfo = error?.localizedDescription ?? ""
        let reasonInfo = reason.map { " (\($0))" } ?? ""
        return "\(status) \(from.displayName) → \(to.displayName)\(reasonInfo)\(errorInfo.isEmpty ? "" : " - \(errorInfo)")"
    }
}

/// State validation result
struct StateValidationResult {
    let isValid: Bool
    let warnings: [String]
    let errors: [String]
    let suggestions: [String]
    
    static let valid = StateValidationResult(isValid: true, warnings: [], errors: [], suggestions: [])
    
    static func invalid(errors: [String], warnings: [String] = [], suggestions: [String] = []) -> StateValidationResult {
        return StateValidationResult(isValid: false, warnings: warnings, errors: errors, suggestions: suggestions)
    }
    
    var hasIssues: Bool {
        return !warnings.isEmpty || !errors.isEmpty
    }
}

/// External display capabilities and configuration
struct ExternalDisplayCapabilities {
    let supportsMultipleWindows: Bool
    let supportsTouchInput: Bool
    let supportsHDR: Bool
    let preferredRefreshRate: Int
    let recommendedResolution: CGSize
    let colorSpace: String
    
    static let `default` = ExternalDisplayCapabilities(
        supportsMultipleWindows: false,
        supportsTouchInput: false,
        supportsHDR: false,
        preferredRefreshRate: 60,
        recommendedResolution: CGSize(width: 1920, height: 1080),
        colorSpace: "sRGB"
    )
}

/// Configuration for state management behavior
struct StateManagerConfiguration {
    let enableAutomaticStateRecovery: Bool
    let enableStateTransitionLogging: Bool
    let enableStateValidation: Bool
    let maxTransitionHistory: Int
    let defaultTransitionTimeout: TimeInterval
    
    static let `default` = StateManagerConfiguration(
        enableAutomaticStateRecovery: true,
        enableStateTransitionLogging: true,
        enableStateValidation: true,
        maxTransitionHistory: 50,
        defaultTransitionTimeout: 5.0
    )
}