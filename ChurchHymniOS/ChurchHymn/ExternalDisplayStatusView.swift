//
//  ExternalDisplayStatusView.swift
//  ChurchHymn
//
//  Created by paulo on 08/11/2025.
//

import SwiftUI

struct ExternalDisplayStatusView: View {
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    let selectedHymn: Hymn?
    
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            statusText
            
            // Add Present button when display is ready
            if externalDisplayManager.state == .connected {
                presentButton
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusBackgroundColor)
        .cornerRadius(6)
        .alert("External Display Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var statusIcon: some View {
        Group {
            switch externalDisplayManager.state {
            case .disconnected:
                Image(systemName: "tv.slash")
                    .foregroundColor(.gray)
            case .connected:
                Image(systemName: "tv")
                    .foregroundColor(.blue)
            case .presenting:
                Image(systemName: "tv.fill")
                    .foregroundColor(.green)
            case .worshipMode:
                Image(systemName: "tv.fill")
                    .foregroundColor(.purple)
            case .worshipPresenting:
                Image(systemName: "tv.fill")
                    .foregroundColor(.green)
            }
        }
        .font(.system(size: 16))
    }
    
    private var statusText: some View {
        Group {
            switch externalDisplayManager.state {
            case .disconnected:
                Text("No External Display")
                    .foregroundColor(.gray)
            case .connected:
                Text("External Display Ready")
                    .foregroundColor(.blue)
            case .presenting:
                Text(externalDisplayManager.currentVerseInfo)
                    .foregroundColor(.green)
            case .worshipMode:
                Text("Worship Session Active")
                    .foregroundColor(.purple)
            case .worshipPresenting:
                Text(externalDisplayManager.currentVerseInfo)
                    .foregroundColor(.green)
            }
        }
        .font(.caption)
        .fontWeight(.medium)
    }
    
    private var statusBackgroundColor: Color {
        switch externalDisplayManager.state {
        case .disconnected:
            return Color.gray.opacity(0.1)
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
    
    private var presentButton: some View {
        Button(action: startExternalPresentation) {
            HStack(spacing: 4) {
                Image(systemName: "tv")
                Text("Present")
            }
            .font(.caption)
            .fontWeight(.medium)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(selectedHymn == nil)
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

struct ExternalDisplayControlsView: View {
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    let selectedHymn: Hymn?
    
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        HStack(spacing: 12) {
            if externalDisplayManager.state == .connected {
                startPresentationButton
            } else if externalDisplayManager.state == .presenting {
                presentationControls
            }
        }
        .alert("External Display Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var startPresentationButton: some View {
        Button(action: startExternalPresentation) {
            HStack(spacing: 4) {
                Image(systemName: "tv")
                Text("Present Externally")
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(selectedHymn == nil)
    }
    
    private var presentationControls: some View {
        HStack(spacing: 8) {
            Button(action: externalDisplayManager.previousVerse) {
                Image(systemName: "chevron.left")
            }
            .disabled(!externalDisplayManager.canGoToPreviousVerse)
            
            VStack(spacing: 2) {
                Text("\(externalDisplayManager.currentVerseIndex + 1)")
                    .font(.headline)
                Text("of \(externalDisplayManager.totalVerses)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 40)
            
            Button(action: externalDisplayManager.nextVerse) {
                Image(systemName: "chevron.right")
            }
            .disabled(!externalDisplayManager.canGoToNextVerse)
            
            Button(action: externalDisplayManager.stopPresentation) {
                HStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                    Text("Stop")
                }
            }
            .buttonStyle(.bordered)
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