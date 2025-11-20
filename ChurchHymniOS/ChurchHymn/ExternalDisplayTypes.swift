//
//  ExternalDisplayTypes.swift
//  ChurchHymn
//
//  Created by paulo on 08/11/2025.
//

import Foundation
import SwiftUI

enum ExternalDisplayState {
    case disconnected
    case connected
    case presenting
}

enum ExternalDisplayError: Error, LocalizedError {
    case noExternalDisplayFound
    case sceneConfigurationFailed
    case windowCreationFailed
    case presentationFailed(String)
    
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