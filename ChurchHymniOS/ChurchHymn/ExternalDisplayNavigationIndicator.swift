//
//  ExternalDisplayNavigationIndicator.swift
//  ChurchHymn
//
//  Created by paulo on 08/11/2025.
//
//  PHASE 3: Navigation bar indicator for external display status
//  - Compact indicator for toolbar integration
//  - Quick visual feedback of connection status
//

import SwiftUI

struct ExternalDisplayNavigationIndicator: View {
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        HStack(spacing: 4) {
            // Connection status icon
            Image(systemName: statusIcon)
                .font(.caption)
                .foregroundColor(statusColor)
                .symbolEffect(.pulse, isActive: externalDisplayManager.state == .presenting)
            
            // Optional status text for iPad
            if UIDevice.current.userInterfaceIdiom == .pad {
                Text(statusText)
                    .font(.caption2)
                    .foregroundColor(statusColor)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusBackgroundColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(statusBorderColor, lineWidth: 0.5)
        )
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // Force refresh external display state when app becomes active
                print("ExternalDisplayNavigationIndicator: App became active, current state: \(externalDisplayManager.state)")
                externalDisplayManager.refreshExternalDisplayState()
            }
        }
    }
    
    private var statusIcon: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return "tv.slash"
        case .connected:
            return "tv"
        case .presenting:
            return "tv.fill"
        case .worshipMode:
            return "tv.fill"
        case .worshipPresenting:
            return "tv.fill"
        }
    }
    
    private var statusColor: Color {
        switch externalDisplayManager.state {
        case .disconnected:
            return .gray
        case .connected:
            return .blue
        case .presenting:
            return .green
        case .worshipMode:
            return .purple
        case .worshipPresenting:
            return .green
        }
    }
    
    private var statusText: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return "No Display"
        case .connected:
            return "Ready"
        case .presenting:
            return "Live"
        case .worshipMode:
            return "Worship"
        case .worshipPresenting:
            return "Live"
        }
    }
    
    private var statusBackgroundColor: Color {
        switch externalDisplayManager.state {
        case .disconnected:
            return Color.clear
        case .connected:
            return Color.blue.opacity(0.1)
        case .presenting:
            return Color.green.opacity(0.1)
        case .worshipMode:
            return Color.purple.opacity(0.1)
        case .worshipPresenting:
            return Color.green.opacity(0.1)
        }
    }
    
    private var statusBorderColor: Color {
        switch externalDisplayManager.state {
        case .disconnected:
            return Color.gray.opacity(0.2)
        case .connected:
            return Color.blue.opacity(0.3)
        case .presenting:
            return Color.green.opacity(0.3)
        case .worshipMode:
            return Color.purple.opacity(0.3)
        case .worshipPresenting:
            return Color.green.opacity(0.3)
        }
    }
}