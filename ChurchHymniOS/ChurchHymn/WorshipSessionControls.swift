//
//  WorshipSessionControls.swift
//  ChurchHymn
//
//  Created by Claude on 14/12/2025.
//

import SwiftUI

/// Controls for starting/stopping worship sessions with external display
struct WorshipSessionControls: View {
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    @EnvironmentObject private var worshipSessionManager: WorshipSessionManager
    @ObservedObject var serviceService: ServiceService
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // Worship session status indicator
            worshipSessionStatusIndicator
            
            // Main worship session control button
            worshipSessionButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(worshipSessionBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(worshipSessionBorderColor, lineWidth: 1)
        )
        .alert("Worship Session Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    @ViewBuilder
    private var worshipSessionStatusIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: worshipSessionIcon)
                .font(.title2)
                .foregroundColor(worshipSessionIconColor)
                .symbolEffect(.pulse, isActive: externalDisplayManager.isInWorshipMode)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(worshipSessionStatusTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(worshipSessionTextColor)
                
                Text(worshipSessionStatusSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var worshipSessionButton: some View {
        Button(action: toggleWorshipSession) {
            HStack(spacing: 6) {
                Image(systemName: worshipSessionButtonIcon)
                    .font(.title3)
                Text(worshipSessionButtonText)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(worshipSessionButtonBackgroundColor)
            .foregroundColor(worshipSessionButtonTextColor)
            .cornerRadius(8)
        }
        .disabled(!canToggleWorshipSession)
        .help(worshipSessionButtonHelpText)
    }
    
    // MARK: - Computed Properties for UI States
    
    private var worshipSessionIcon: String {
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
    
    private var worshipSessionIconColor: Color {
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
    
    private var worshipSessionTextColor: Color {
        return worshipSessionIconColor
    }
    
    private var worshipSessionStatusTitle: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return NSLocalizedString("worship.no_external_display", comment: "No External Display")
        case .connected:
            return NSLocalizedString("worship.ready_for_worship", comment: "Ready for Worship")
        case .presenting:
            return NSLocalizedString("worship.individual_presentation", comment: "Individual Presentation")
        case .worshipMode:
            return NSLocalizedString("worship.worship_session_active", comment: "Worship Session Active")
        case .worshipPresenting:
            return NSLocalizedString("worship.worship_presentation", comment: "Worship Presentation")
        }
    }
    
    private var worshipSessionStatusSubtitle: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return NSLocalizedString("worship.connect_projector", comment: "Connect a projector to start worship")
        case .connected:
            return NSLocalizedString("worship.start_worship_session", comment: "Start worship session to begin")
        case .presenting:
            return NSLocalizedString("worship.stop_to_enable", comment: "Stop to enable worship session")
        case .worshipMode:
            return NSLocalizedString("worship.ready_for_hymn", comment: "Ready for hymn presentation")
        case .worshipPresenting:
            if let hymn = externalDisplayManager.currentHymn {
                return String(format: NSLocalizedString("worship.presenting_hymn", comment: "Presenting: %@"), hymn.title)
            } else {
                return NSLocalizedString("worship.hymn_being_presented", comment: "Hymn being presented")
            }
        }
    }
    
    private var worshipSessionButtonIcon: String {
        switch externalDisplayManager.state {
        case .disconnected, .presenting:
            return "exclamationmark.triangle"
        case .connected:
            return "play.circle.fill"
        case .worshipMode:
            return "stop.circle.fill"
        case .worshipPresenting:
            return "stop.circle.fill"
        }
    }
    
    private var worshipSessionButtonText: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return NSLocalizedString("external.no_display", comment: "No external display available")
        case .connected:
            return NSLocalizedString("btn.start_worship", comment: "Start Worship")
        case .presenting:
            return NSLocalizedString("btn.stop_presentation", comment: "Stop Presentation")
        case .worshipMode:
            return NSLocalizedString("btn.stop_worship", comment: "Stop Worship")
        case .worshipPresenting:
            return NSLocalizedString("btn.stop_worship", comment: "Stop Worship")
        }
    }
    
    private var worshipSessionButtonBackgroundColor: Color {
        switch externalDisplayManager.state {
        case .disconnected:
            return Color.gray.opacity(0.2)
        case .connected:
            // Only green if we can actually start worship session (has hymns)
            return hasActiveServiceWithHymns ? Color.green : Color.gray.opacity(0.2)
        case .presenting:
            return Color.orange
        case .worshipMode, .worshipPresenting:
            return Color.red
        }
    }
    
    private var worshipSessionButtonTextColor: Color {
        switch externalDisplayManager.state {
        case .disconnected:
            return .gray
        case .connected:
            // Gray text if we can't start worship session (no hymns)
            return hasActiveServiceWithHymns ? .white : .gray
        case .presenting:
            return .white
        case .worshipMode, .worshipPresenting:
            return .white
        }
    }
    
    private var worshipSessionButtonHelpText: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return "Connect an external display first"
        case .connected:
            if hasActiveServiceWithHymns {
                return "Start worship session with background display"
            } else {
                return "Add hymns to your active service before starting worship session"
            }
        case .presenting:
            return "Stop current presentation to enable worship session"
        case .worshipMode:
            return "Stop worship session and return to normal mode"
        case .worshipPresenting:
            return "Stop worship session and return to normal mode"
        }
    }
    
    private var canToggleWorshipSession: Bool {
        // First check external display state
        switch externalDisplayManager.state {
        case .disconnected:
            return false
        case .connected:
            // For starting worship session, also check if service has hymns
            return hasActiveServiceWithHymns
        case .presenting, .worshipMode, .worshipPresenting:
            // Can always stop or change modes
            return true
        }
    }
    
    private var hasActiveServiceWithHymns: Bool {
        guard let activeService = serviceService.activeService else {
            return false
        }
        
        let hymnCount = serviceService.serviceHymns.filter { $0.serviceId == activeService.id }.count
        return hymnCount > 0
    }
    
    private var worshipSessionBackgroundColor: Color {
        switch externalDisplayManager.state {
        case .disconnected:
            return Color(.systemGray6)
        case .connected:
            return Color.blue.opacity(0.05)
        case .presenting:
            return Color.green.opacity(0.05)
        case .worshipMode:
            return Color.purple.opacity(0.1)
        case .worshipPresenting:
            return Color.green.opacity(0.1)
        }
    }
    
    private var worshipSessionBorderColor: Color {
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
    
    // MARK: - Actions
    
    private func toggleWorshipSession() {
        Task {
            do {
                switch externalDisplayManager.state {
                case .connected:
                    try await worshipSessionManager.startWorshipSession()
                case .presenting:
                    // Stop individual presentation
                    externalDisplayManager.stopPresentation()
                case .worshipMode, .worshipPresenting:
                    await worshipSessionManager.stopWorshipSession()
                default:
                    break
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }
}

/// Compact worship session control for toolbar integration
struct CompactWorshipSessionControl: View {
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    @EnvironmentObject private var worshipSessionManager: WorshipSessionManager
    @ObservedObject var serviceService: ServiceService
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        Button(action: toggleWorshipSession) {
            VStack(spacing: 4) {
                Image(systemName: worshipIcon)
                    .font(.title)
                    .foregroundColor(worshipIconColor)
                    .symbolEffect(.pulse, isActive: externalDisplayManager.isInWorshipMode)
                Text(worshipText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .disabled(!canToggleWorshipSession)
        .help(worshipHelpText)
        .alert("Worship Session Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var worshipIcon: String {
        switch externalDisplayManager.state {
        case .disconnected, .presenting:
            return "tv.slash"
        case .connected:
            return "tv"
        case .worshipMode, .worshipPresenting:
            return "tv.fill"
        }
    }
    
    private var worshipIconColor: Color {
        switch externalDisplayManager.state {
        case .disconnected, .presenting:
            return .gray
        case .connected:
            return .green
        case .worshipMode, .worshipPresenting:
            return .purple
        }
    }
    
    private var worshipText: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return NSLocalizedString("external.no_display", comment: "No external display available")
        case .connected:
            return "Start Worship"
        case .presenting:
            return "Stop First"
        case .worshipMode, .worshipPresenting:
            return "Stop Worship"
        }
    }
    
    private var worshipHelpText: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return "Connect an external display first"
        case .connected:
            return "Start worship session"
        case .presenting:
            return "Stop current presentation first"
        case .worshipMode, .worshipPresenting:
            return "Stop worship session"
        }
    }
    
    private var hasActiveServiceWithHymns: Bool {
        guard let activeService = serviceService.activeService else {
            return false
        }
        
        let hymnCount = serviceService.serviceHymns.filter { $0.serviceId == activeService.id }.count
        return hymnCount > 0
    }
    
    private var canToggleWorshipSession: Bool {
        switch externalDisplayManager.state {
        case .disconnected, .presenting:
            return false
        case .connected:
            // For starting worship session, also check if service has hymns
            return hasActiveServiceWithHymns
        case .worshipMode, .worshipPresenting:
            // Can always stop or change modes
            return true
        }
    }
    
    private func toggleWorshipSession() {
        Task {
            do {
                switch externalDisplayManager.state {
                case .connected:
                    try await worshipSessionManager.startWorshipSession()
                case .worshipMode, .worshipPresenting:
                    await worshipSessionManager.stopWorshipSession()
                default:
                    break
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }
}

#Preview {
    Text("WorshipSessionControls Preview")
        .foregroundColor(.secondary)
}
