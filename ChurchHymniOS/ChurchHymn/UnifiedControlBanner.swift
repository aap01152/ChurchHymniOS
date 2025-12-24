//
//  UnifiedControlBanner.swift
//  ChurchHymn
//
//  Created by Claude on 24/12/2025.
//

import SwiftUI

/// Unified banner that combines worship session controls and external display status
/// Replaces both WorshipSessionControls and ExternalDisplayStatusBar for cleaner UI
struct UnifiedControlBanner: View {
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    @EnvironmentObject private var worshipSessionManager: WorshipSessionManager
    @ObservedObject var serviceService: ServiceService
    let selectedHymn: Hymn?
    
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Main banner content with optimized layout
            HStack(spacing: 8) {
                // Status section (compact)
                compactStatusSection
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Controls section (uniform buttons)
                uniformControlsSection
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(bannerBackgroundColor)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(bannerBorderColor)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            )
        }
        .alert("Control Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Compact Status Section
    
    @ViewBuilder
    private var compactStatusSection: some View {
        HStack(spacing: 8) {
            // External Display Icon
            Image(systemName: externalDisplayIcon)
                .font(.title3)
                .foregroundColor(statusIconColor)
                .symbolEffect(.pulse, isActive: externalDisplayManager.state.isActive)
            
            // Compact Status Information
            VStack(alignment: .leading, spacing: 0) {
                Text(primaryStatusText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(statusTextColor)
                    .lineLimit(1)
                
                Text(secondaryStatusText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // Verse information (when presenting) - compact
            if externalDisplayManager.state.isCurrentlyPresenting {
                Text("\(externalDisplayManager.currentVerseIndex + 1)/\(externalDisplayManager.totalVerses)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(6)
            }
        }
    }
    
    // MARK: - Original Status Section (deprecated)
    
    @ViewBuilder
    private var statusSection: some View {
        HStack(spacing: 12) {
            // External Display Icon
            Image(systemName: externalDisplayIcon)
                .font(.title2)
                .foregroundColor(statusIconColor)
                .symbolEffect(.pulse, isActive: externalDisplayManager.state.isActive)
            
            // Status Information
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryStatusText)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(statusTextColor)
                
                Text(secondaryStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Verse information (when presenting)
            if externalDisplayManager.state.isCurrentlyPresenting {
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
            }
        }
    }
    
    // MARK: - Uniform Controls Section
    
    @ViewBuilder
    private var uniformControlsSection: some View {
        switch externalDisplayManager.state {
        case .disconnected:
            EmptyView()
            
        case .connected:
            HStack(spacing: 4) {
                if worshipSessionManager.canStartWorshipSession {
                    // Start Worship button
                    UniformControlButton(
                        icon: "play.circle.fill",
                        text: "Start\nWorship",
                        action: startWorshipSession,
                        style: .primary
                    )
                } else {
                    // Present button
                    UniformControlButton(
                        icon: "play.circle.fill",
                        text: "Present",
                        action: startExternalPresentation,
                        style: .secondary,
                        isEnabled: selectedHymn != nil
                    )
                }
            }
            
        case .presenting:
            uniformPresentationControls
            
        case .worshipMode:
            uniformWorshipModeControls
            
        case .worshipPresenting:
            uniformWorshipPresentationControls
        }
    }
    
    // MARK: - Original Controls Section (deprecated)
    
    @ViewBuilder
    private var controlsSection: some View {
        switch externalDisplayManager.state {
        case .disconnected:
            // No controls when disconnected
            EmptyView()
            
        case .connected:
            // Show worship session or presentation controls
            if worshipSessionManager.canStartWorshipSession {
                // Start Worship button
                Button(action: startWorshipSession) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                        Text("Start Worship")
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else {
                // Present selected hymn button
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
            }
            
        case .presenting:
            // Presentation controls
            presentationControls
            
        case .worshipMode:
            // Worship session controls
            worshipModeControls
            
        case .worshipPresenting:
            // Worship presentation controls
            worshipPresentationControls
        }
    }
    
    // MARK: - Presentation Controls
    
    @ViewBuilder
    private var presentationControls: some View {
        HStack(spacing: 8) {
            // Previous button
            Button(action: externalDisplayManager.previousVerse) {
                CompactControlButton(icon: "chevron.left.circle.fill", text: "Previous")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!externalDisplayManager.canGoToPreviousVerse)
            
            // Next button
            Button(action: externalDisplayManager.nextVerse) {
                CompactControlButton(icon: "chevron.right.circle.fill", text: "Next")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!externalDisplayManager.canGoToNextVerse)
            
            // Stop button
            Button(action: externalDisplayManager.stopPresentation) {
                CompactControlButton(icon: "stop.circle.fill", text: "Stop")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
    
    // MARK: - Worship Mode Controls
    
    @ViewBuilder
    private var worshipModeControls: some View {
        HStack(spacing: 8) {
            // Present selected hymn in worship
            if selectedHymn != nil {
                Button(action: presentSelectedHymnInWorship) {
                    CompactControlButton(
                        icon: "play.circle.fill",
                        text: selectedHymn?.title ?? "Present"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Stop worship session
            Button(action: stopWorshipSession) {
                HStack(spacing: 6) {
                    Image(systemName: "stop.circle.fill")
                    Text("Stop Worship")
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
        }
    }
    
    // MARK: - Worship Presentation Controls
    
    @ViewBuilder
    private var worshipPresentationControls: some View {
        HStack(spacing: 8) {
            // Previous button
            Button(action: externalDisplayManager.previousVerse) {
                CompactControlButton(icon: "chevron.left.circle.fill", text: "Previous")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!externalDisplayManager.canGoToPreviousVerse)
            
            // Next button
            Button(action: externalDisplayManager.nextVerse) {
                CompactControlButton(icon: "chevron.right.circle.fill", text: "Next")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!externalDisplayManager.canGoToNextVerse)
            
            // Stop worship presentation (return to worship mode)
            Button(action: stopHymnInWorshipMode) {
                CompactControlButton(icon: "stop.circle.fill", text: "Stop")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
    
    // MARK: - Computed Properties
    
    private var externalDisplayIcon: String {
        switch externalDisplayManager.state {
        case .disconnected: return "tv.slash"
        case .connected: return "tv"
        case .presenting: return "tv.fill"
        case .worshipMode: return "tv.fill"
        case .worshipPresenting: return "tv.fill"
        }
    }
    
    private var statusIconColor: Color {
        switch externalDisplayManager.state {
        case .disconnected: return .gray
        case .connected: return .blue
        case .presenting: return .green
        case .worshipMode: return .purple
        case .worshipPresenting: return .green
        }
    }
    
    private var primaryStatusText: String {
        if worshipSessionManager.isWorshipSessionActive {
            switch externalDisplayManager.state {
            case .worshipMode:
                return "Worship Active"
            case .worshipPresenting:
                if let hymn = externalDisplayManager.currentHymn {
                    return "Worship: \(hymn.title)"
                }
                return "Worship Presenting"
            default:
                return "Worship Session"
            }
        } else {
            switch externalDisplayManager.state {
            case .disconnected: return "No External Display"
            case .connected: return "External Display Ready"
            case .presenting:
                if let hymn = externalDisplayManager.currentHymn {
                    return "Presenting: \(hymn.title)"
                }
                return "Presenting"
            default: return "External Display"
            }
        }
    }
    
    private var secondaryStatusText: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return "Connect a projector or external monitor"
        case .connected:
            if worshipSessionManager.canStartWorshipSession {
                return "Ready for worship session"
            } else if let displayInfo = externalDisplayManager.externalDisplayInfo {
                return displayInfo.description
            } else {
                return "Ready to present"
            }
        case .presenting, .worshipPresenting:
            return externalDisplayManager.currentVerseInfo
        case .worshipMode:
            return "Showing background - Select hymn to present"
        }
    }
    
    private var statusTextColor: Color {
        switch externalDisplayManager.state {
        case .disconnected: return .gray
        case .connected: return .blue
        case .presenting: return .green
        case .worshipMode: return .purple
        case .worshipPresenting: return .green
        }
    }
    
    private var bannerBackgroundColor: Color {
        switch externalDisplayManager.state {
        case .disconnected: return Color(.systemGray6)
        case .connected: return Color.blue.opacity(0.05)
        case .presenting: return Color.green.opacity(0.05)
        case .worshipMode: return Color.purple.opacity(0.05)
        case .worshipPresenting: return Color.green.opacity(0.05)
        }
    }
    
    private var bannerBorderColor: Color {
        switch externalDisplayManager.state {
        case .disconnected: return Color.gray.opacity(0.2)
        case .connected: return Color.blue.opacity(0.2)
        case .presenting: return Color.green.opacity(0.2)
        case .worshipMode: return Color.purple.opacity(0.2)
        case .worshipPresenting: return Color.green.opacity(0.2)
        }
    }
    
    // MARK: - Action Methods
    
    private func startWorshipSession() {
        Task {
            do {
                try await worshipSessionManager.startWorshipSession()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func stopWorshipSession() {
        Task {
            await worshipSessionManager.stopWorshipSession()
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
                try await externalDisplayManager.presentHymnInWorshipMode(hymn)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func stopHymnInWorshipMode() {
        Task {
            await externalDisplayManager.stopHymnInWorshipMode()
        }
    }
    
    // MARK: - Uniform Presentation Controls
    
    @ViewBuilder
    private var uniformPresentationControls: some View {
        HStack(spacing: 4) {
            UniformControlButton(
                icon: "chevron.left.circle.fill",
                text: "Previous",
                action: externalDisplayManager.previousVerse,
                style: .secondary,
                isEnabled: externalDisplayManager.canGoToPreviousVerse
            )
            
            UniformControlButton(
                icon: "chevron.right.circle.fill",
                text: "Next",
                action: externalDisplayManager.nextVerse,
                style: .secondary,
                isEnabled: externalDisplayManager.canGoToNextVerse
            )
            
            UniformControlButton(
                icon: "stop.circle.fill",
                text: "Stop",
                action: externalDisplayManager.stopPresentation,
                style: .destructive
            )
        }
    }
    
    // MARK: - Uniform Worship Mode Controls
    
    @ViewBuilder
    private var uniformWorshipModeControls: some View {
        HStack(spacing: 4) {
            if selectedHymn != nil {
                UniformControlButton(
                    icon: "play.circle.fill",
                    text: selectedHymn?.title ?? "Present",
                    action: presentSelectedHymnInWorship,
                    style: .secondary
                )
            }
            
            UniformControlButton(
                icon: "stop.circle.fill",
                text: "Stop\nWorship",
                action: stopWorshipSession,
                style: .destructive
            )
        }
    }
    
    // MARK: - Uniform Worship Presentation Controls
    
    @ViewBuilder
    private var uniformWorshipPresentationControls: some View {
        HStack(spacing: 4) {
            UniformControlButton(
                icon: "chevron.left.circle.fill",
                text: "Previous",
                action: externalDisplayManager.previousVerse,
                style: .secondary,
                isEnabled: externalDisplayManager.canGoToPreviousVerse
            )
            
            UniformControlButton(
                icon: "chevron.right.circle.fill",
                text: "Next",
                action: externalDisplayManager.nextVerse,
                style: .secondary,
                isEnabled: externalDisplayManager.canGoToNextVerse
            )
            
            UniformControlButton(
                icon: "stop.circle.fill",
                text: "Stop",
                action: stopHymnInWorshipMode,
                style: .destructive
            )
        }
    }
}

// MARK: - Uniform Control Button

struct UniformControlButton: View {
    let icon: String
    let text: String
    let action: () -> Void
    let style: ButtonStyle
    let isEnabled: Bool
    
    enum ButtonStyle {
        case primary, secondary, destructive
    }
    
    init(icon: String, text: String, action: @escaping () -> Void, style: ButtonStyle = .secondary, isEnabled: Bool = true) {
        self.icon = icon
        self.text = text
        self.action = action
        self.style = style
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundColor(iconColor)
                
                Text(text)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .frame(minWidth: 50, minHeight: 32)
            .frame(maxWidth: 70)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return .green
        case .secondary:
            return Color(.systemGray6)
        case .destructive:
            return .red.opacity(0.1)
        }
    }
    
    private var iconColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return .accentColor
        case .destructive:
            return .red
        }
    }
    
    private var textColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return .primary
        case .destructive:
            return .red
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary:
            return .green.opacity(0.3)
        case .secondary:
            return Color(.systemGray4)
        case .destructive:
            return .red.opacity(0.3)
        }
    }
}

// MARK: - Extensions

private extension ExternalDisplayState {
    var isActive: Bool {
        switch self {
        case .presenting, .worshipMode, .worshipPresenting:
            return true
        case .disconnected, .connected:
            return false
        }
    }
    
    var isCurrentlyPresenting: Bool {
        switch self {
        case .presenting, .worshipPresenting:
            return true
        case .disconnected, .connected, .worshipMode:
            return false
        }
    }
}

#Preview {
    VStack {
        Text("Unified Control Banner Preview")
            .padding()
    }
}