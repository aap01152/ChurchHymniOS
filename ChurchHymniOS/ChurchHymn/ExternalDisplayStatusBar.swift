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
            Image(systemName: externalDisplayManager.state.systemIcon)
                .font(.title2)
                .foregroundColor(externalDisplayManager.state.stateColor)
                .symbolEffect(.pulse, isActive: externalDisplayManager.state.isPresenting)
        }
        .frame(width: 32, height: 32)
        .help("External Display Status: \(externalDisplayManager.state.displayName)")
    }
    
    private var statusTitle: String {
        let baseTitle = externalDisplayManager.state.displayName
        
        if let hymn = externalDisplayManager.currentHymn,
           externalDisplayManager.state.isPresenting {
            return "\(baseTitle): \(hymn.title)"
        } else {
            return baseTitle
        }
    }
    
    private var statusSubtitle: String {
        // Use suggested actions for disconnected state, otherwise existing logic
        if externalDisplayManager.state == .disconnected {
            return externalDisplayManager.state.suggestedActions.first ?? "No external display"
        }
        
        if let displayInfo = externalDisplayManager.externalDisplayInfo,
           externalDisplayManager.state == .connected {
            return displayInfo.description
        }
        
        if externalDisplayManager.state.supportsVerseNavigation {
            return externalDisplayManager.currentVerseInfo
        }
        
        // Use suggested action for other states
        return externalDisplayManager.state.suggestedActions.first ?? "External display active"
    }
    
    private var statusTextColor: Color {
        return externalDisplayManager.state.stateColor
    }
    
    private var statusBackgroundColor: Color {
        return externalDisplayManager.state.stateColor.opacity(0.1)
    }
    
    private var statusBorderColor: Color {
        return externalDisplayManager.state.stateColor.opacity(0.3)
    }
    
    private var statusShadowColor: Color {
        return externalDisplayManager.state == .disconnected ? 
            Color.clear : 
            externalDisplayManager.state.stateColor.opacity(0.2)
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
                    Text(NSLocalizedString("btn.present", comment: "Present"))
                }
                .font(.subheadline)
                .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(selectedHymn == nil)
        case .presenting:
            // Show presentation controls with prominent navigation
            HStack(spacing: 8) {
                // Previous verse button
                Button(action: externalDisplayManager.previousVerse) {
                    CompactControlButton(
                        icon: "chevron.left.circle.fill",
                        text: "Previous"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!externalDisplayManager.canGoToPreviousVerse)
                
                // Current verse indicator
                VStack(spacing: 2) {
                    Text("\(externalDisplayManager.currentVerseIndex + 1)/\(externalDisplayManager.totalVerses)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                    
                    Text(externalDisplayManager.currentVerseInfo)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 70)
                
                // Next verse button
                Button(action: externalDisplayManager.nextVerse) {
                    CompactControlButton(
                        icon: "chevron.right.circle.fill",
                        text: "Next"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!externalDisplayManager.canGoToNextVerse)
                
                Spacer()
                
                // COMMENTED OUT: Preview toggle for iPad - preview window disabled
                // if UIDevice.current.userInterfaceIdiom == .pad {
                //     ExternalDisplayPreviewQuickToggle()
                // }
                
                // Stop presentation button
                Button(action: externalDisplayManager.stopPresentation) {
                    CompactControlButton(
                        icon: "stop.circle.fill",
                        text: "Stop"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        case .worshipMode:
            // Show worship session active indicator and present hymn button
            HStack(spacing: 12) {
                // Worship session status
                HStack(spacing: 4) {
                    Image(systemName: "infinity.circle.fill")
                        .font(.title3)
                        .foregroundColor(.purple)
                        .symbolEffect(.pulse)
                    Text("Worship Active")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                }
                
                Spacer()
                
                // Present hymn button
                Button(action: presentSelectedHymnInWorship) {
                    CompactControlButton(
                        icon: "play.circle.fill",
                        text: selectedHymn?.title ?? "No Hymn"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(selectedHymn == nil)
                .help(selectedHymn != nil ? "Present \(selectedHymn!.title) in worship session" : "Select a hymn to present in worship session")
            }
        case .worshipPresenting:
            // Show worship presentation controls with prominent navigation
            HStack(spacing: 8) {
                // Previous verse button
                Button(action: externalDisplayManager.previousVerse) {
                    CompactControlButton(
                        icon: "chevron.left.circle.fill",
                        text: "Previous"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!externalDisplayManager.canGoToPreviousVerse)
                
                // Current verse indicator
                VStack(spacing: 2) {
                    Text("\(externalDisplayManager.currentVerseIndex + 1)/\(externalDisplayManager.totalVerses)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                    
                    Text(externalDisplayManager.currentVerseInfo)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 70)
                
                // Next verse button
                Button(action: externalDisplayManager.nextVerse) {
                    CompactControlButton(
                        icon: "chevron.right.circle.fill",
                        text: "Next"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!externalDisplayManager.canGoToNextVerse)
                
                Spacer()
                
                // COMMENTED OUT: Preview toggle for iPad - preview window disabled
                // if UIDevice.current.userInterfaceIdiom == .pad {
                //     ExternalDisplayPreviewQuickToggle()
                // }
                
                // Stop presentation button
                Button(action: { 
                    Task { 
                        await externalDisplayManager.stopHymnInWorshipMode() 
                    }
                }) {
                    CompactControlButton(
                        icon: "stop.circle.fill",
                        text: "Stop"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
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
    
    private func presentSelectedHymnInWorship() {
        guard let hymn = selectedHymn else { return }
        
        Task {
            do {
                try await externalDisplayManager.presentOrSwitchToHymn(hymn)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
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
                HStack(spacing: 8) {
                    Button(action: externalDisplayManager.previousVerse) {
                        CompactControlButton(
                            icon: "chevron.left.circle.fill",
                            text: "Previous"
                        )
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
                    .frame(minWidth: 70)
                    
                    Button(action: externalDisplayManager.nextVerse) {
                        CompactControlButton(
                            icon: "chevron.right.circle.fill",
                            text: "Next"
                        )
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
