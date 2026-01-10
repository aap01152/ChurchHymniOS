//
//  UniformWorshipSessionControl.swift
//  ChurchHymniOS
//
//  Created by paulo on 10/01/2026.
//

import SwiftUI

struct UniformWorshipSessionControl: View {
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    @EnvironmentObject private var worshipSessionManager: WorshipSessionManager
    @ObservedObject var serviceService: ServiceService
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        Button(action: toggleWorshipSession) {
            UniformToolbarButtonContent(
                icon: worshipIcon,
                text: worshipText,
                color: worshipIconColor
            )
        }
        .disabled(!canToggleWorshipSession)
        .help(worshipHelpText)
        .frame(maxWidth: .infinity)
        .alert(NSLocalizedString("alert.worship_session_error", comment: "Worship session error"), isPresented: $showingErrorAlert) {
            Button(NSLocalizedString("btn.ok", comment: "OK")) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var worshipIcon: String {
        switch externalDisplayManager.state {
        case .disconnected, .connected:
            return "play.circle.fill"
        case .presenting, .worshipMode, .worshipPresenting:
            return "stop.circle.fill"
        }
    }
    
    private var worshipIconColor: Color {
        switch externalDisplayManager.state {
        case .disconnected:
            return .gray
        case .connected:
            return .green
        case .presenting, .worshipMode, .worshipPresenting:
            return .red
        }
    }
    
    private var worshipText: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return NSLocalizedString("btn.worship", comment: "Worship button")
        case .connected:
            return canToggleWorshipSession
                ? NSLocalizedString("btn.start_worship_multiline", comment: "Start Worship button")
                : NSLocalizedString("btn.worship", comment: "Worship button")
        case .presenting, .worshipMode, .worshipPresenting:
            return NSLocalizedString("btn.stop_worship_multiline", comment: "Stop Worship button")
        }
    }
    
    private var canToggleWorshipSession: Bool {
        switch externalDisplayManager.state {
        case .disconnected:
            return false
        case .connected:
            return worshipSessionManager.canStartWorshipSession
        case .presenting, .worshipMode, .worshipPresenting:
            return true
        }
    }
    
    private var worshipHelpText: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return NSLocalizedString("status.no_external_display", comment: "No external display available")
        case .connected:
            return canToggleWorshipSession
                ? NSLocalizedString("help.start_worship_session", comment: "Start worship session help")
                : NSLocalizedString("status.external_display_ready", comment: "External display ready")
        case .presenting, .worshipMode, .worshipPresenting:
            return NSLocalizedString("help.stop_worship_session", comment: "Stop worship session help")
        }
    }
    
    private func toggleWorshipSession() {
        Task {
            do {
                switch externalDisplayManager.state {
                case .disconnected, .connected:
                    if worshipSessionManager.canStartWorshipSession {
                        try await worshipSessionManager.startWorshipSession()
                    }
                case .presenting, .worshipMode, .worshipPresenting:
                    await worshipSessionManager.stopWorshipSession()
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

struct UniformToolbarButtonContent: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
}

struct UniformToolbarButton: View {
    let icon: String
    let text: String
    let color: Color
    let action: () -> Void
    let isEnabled: Bool
    
    init(icon: String, text: String, color: Color, action: @escaping () -> Void, isEnabled: Bool = true) {
        self.icon = icon
        self.text = text
        self.color = color
        self.action = action
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        Button(action: action) {
            UniformToolbarButtonContent(
                icon: icon,
                text: text,
                color: isEnabled ? color : .gray
            )
        }
        .disabled(!isEnabled)
        .frame(maxWidth: .infinity)
    }
}
