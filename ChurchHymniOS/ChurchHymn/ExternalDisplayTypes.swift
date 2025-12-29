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
}

enum ExternalDisplayError: Error, LocalizedError {
    case noExternalDisplayFound
    case sceneConfigurationFailed
    case windowCreationFailed
    case presentationFailed(String)
    case notCurrentlyPresenting
    
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