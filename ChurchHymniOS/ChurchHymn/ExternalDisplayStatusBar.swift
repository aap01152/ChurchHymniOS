//
//  ExternalDisplayStatusBar.swift
//  ChurchHymn
//
//  Created by paulo on 08/11/2025.
//
//  PHASE 3: Main Interface Integration
//  - External display status indicator for main interface
//  - Connection status with visual feedback
//  - Quick access controls and information
//

import SwiftUI

struct ExternalDisplayStatusBar: View {
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    let selectedHymn: Hymn?
    
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // Connection status icon
            connectionStatusIcon
            
            // Status text and information
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(statusTextColor)
                
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Additional info or controls based on state
            statusTrailingContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(statusBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusBorderColor, lineWidth: 1)
        )
        .shadow(color: statusShadowColor, radius: 2, x: 0, y: 1)
        .alert("External Display Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    @ViewBuilder
    private var connectionStatusIcon: some View {
        Group {
            switch externalDisplayManager.state {
            case .disconnected:
                Image(systemName: "tv.slash")
                    .font(.title2)
                    .foregroundColor(.gray)
            case .connected:
                Image(systemName: "tv")
                    .font(.title2)
                    .foregroundColor(.blue)
            case .presenting:
                Image(systemName: "tv.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                    .symbolEffect(.pulse)
            case .worshipMode:
                Image(systemName: "tv.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                    .symbolEffect(.pulse)
            case .worshipPresenting:
                Image(systemName: "tv.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                    .symbolEffect(.pulse)
            }
        }
        .frame(width: 32, height: 32)
    }
    
    private var statusTitle: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return "No External Display"
        case .connected:
            return "External Display Ready"
        case .presenting:
            if let hymn = externalDisplayManager.currentHymn {
                return "Presenting: \(hymn.title)"
            } else {
                return "Presenting to External Display"
            }
        case .worshipMode:
            return "Worship Session Active"
        case .worshipPresenting:
            if let hymn = externalDisplayManager.currentHymn {
                return "Worship: \(hymn.title)"
            } else {
                return "Worship Session - Presenting"
            }
        }
    }
    
    private var statusSubtitle: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return "Connect a projector or external monitor"
        case .connected:
            if let displayInfo = externalDisplayManager.externalDisplayInfo {
                return displayInfo.description
            } else {
                return "Ready to present"
            }
        case .presenting:
            return externalDisplayManager.currentVerseInfo
        case .worshipMode:
            return "Showing background - Ready for hymn presentation"
        case .worshipPresenting:
            return externalDisplayManager.currentVerseInfo
        }
    }
    
    private var statusTextColor: Color {
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
    
    private var statusBackgroundColor: Color {
        switch externalDisplayManager.state {
        case .disconnected:
            return Color(.systemGray6)
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
            return Color.gray.opacity(0.3)
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
    
    private var statusShadowColor: Color {
        switch externalDisplayManager.state {
        case .disconnected:
            return Color.clear
        case .connected:
            return Color.blue.opacity(0.1)
        case .presenting:
            return Color.green.opacity(0.2)
        case .worshipMode:
            return Color.purple.opacity(0.2)
        case .worshipPresenting:
            return Color.green.opacity(0.2)
        }
    }
    
    @ViewBuilder
    private var statusTrailingContent: some View {
        switch externalDisplayManager.state {
        case .disconnected:
            // Show help icon
            Image(systemName: "questionmark.circle")
                .font(.title3)
                .foregroundColor(.gray)
        case .connected:
            // Show Present button
            Button(action: startExternalPresentation) {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                    Text("Present")
                }
                .font(.subheadline)
                .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(selectedHymn == nil)
        case .presenting:
            // Show presentation controls
            HStack(spacing: 8) {
                Text("\(externalDisplayManager.currentVerseIndex + 1)/\(externalDisplayManager.totalVerses)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
                
                // Preview toggle for iPad
                if UIDevice.current.userInterfaceIdiom == .pad {
                    ExternalDisplayPreviewQuickToggle()
                }
                
                Button(action: externalDisplayManager.stopPresentation) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title3)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        case .worshipMode:
            // Show worship session active indicator
            HStack(spacing: 4) {
                Image(systemName: "infinity.circle.fill")
                    .font(.title3)
                    .foregroundColor(.purple)
                    .symbolEffect(.pulse)
                Text("Active")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
            }
        case .worshipPresenting:
            // Show worship presentation controls
            HStack(spacing: 8) {
                Text("\(externalDisplayManager.currentVerseIndex + 1)/\(externalDisplayManager.totalVerses)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
                
                // Preview toggle for iPad
                if UIDevice.current.userInterfaceIdiom == .pad {
                    ExternalDisplayPreviewQuickToggle()
                }
                
                Button(action: { 
                    Task { 
                        await externalDisplayManager.stopHymnInWorshipMode() 
                    }
                }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title3)
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func startExternalPresentation() {
        guard let hymn = selectedHymn else { return }
        
        do {
            try externalDisplayManager.startPresentation(hymn: hymn)
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
}

struct ExternalDisplayQuickControls: View {
    let selectedHymn: Hymn?
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        HStack(spacing: 16) {
            if externalDisplayManager.state == .presenting {
                // Presentation controls
                HStack(spacing: 12) {
                    Button(action: externalDisplayManager.previousVerse) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Previous")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!externalDisplayManager.canGoToPreviousVerse)
                    
                    VStack(spacing: 2) {
                        Text(externalDisplayManager.currentVerseInfo)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("Current Verse")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 80)
                    
                    Button(action: externalDisplayManager.nextVerse) {
                        HStack(spacing: 4) {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!externalDisplayManager.canGoToNextVerse)
                }
            } else if externalDisplayManager.state == .connected {
                // Start presentation button
                Button(action: startExternalPresentation) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                        Text("Present to External Display")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedHymn == nil)
            }
        }
        .alert("External Display Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func startExternalPresentation() {
        guard let hymn = selectedHymn else { return }
        
        do {
            try externalDisplayManager.startPresentation(hymn: hymn)
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
}