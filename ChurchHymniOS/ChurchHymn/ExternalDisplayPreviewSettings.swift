//
//  ExternalDisplayPreviewSettings.swift
//  ChurchHymn
//
//  Created by paulo on 08/11/2025.
//
//  PHASE 4: Preview Window Settings
//  - User interface for configuring preview window behavior
//  - Size, opacity, and auto-behavior settings
//  - Integration with preview manager
//

import SwiftUI

struct ExternalDisplayPreviewSettingsView: View {
    @ObservedObject var previewManager: ExternalDisplayPreviewManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Preview Window") {
                    Toggle("Show Preview Window", isOn: $previewManager.isPreviewVisible)
                        .help("Show a small preview of what's displayed on the external screen")
                    
                    if previewManager.isPreviewVisible {
                        HStack {
                            Text("Size")
                            Spacer()
                            Picker("Size", selection: $previewManager.previewSize) {
                                ForEach(ExternalDisplayPreviewManager.PreviewSize.allCases) { size in
                                    Text(size.rawValue).tag(size)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Opacity")
                                Spacer()
                                Text("\(Int(previewManager.previewOpacity * 100))%")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            
                            Slider(value: $previewManager.previewOpacity, in: 0.3...1.0, step: 0.1)
                                .help("Adjust the transparency of the preview window")
                        }
                    }
                }
                
                Section("Behavior") {
                    Toggle("Auto-show when presenting", isOn: $previewManager.autoShowOnPresentation)
                        .help("Automatically show the preview window when starting an external presentation")
                    
                    Toggle("Auto-hide when disconnected", isOn: $previewManager.autoHideOnDisconnect)
                        .help("Automatically hide the preview window when the external display is disconnected")
                    
                    Toggle("Snap to corners", isOn: $previewManager.snapToCorners)
                        .help("Snap the preview window to screen corners when dragging nearby")
                }
                
                Section("Preview Position") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Position")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack {
                            Text("X: \(Int(previewManager.position.x))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                            
                            Spacer()
                            
                            Text("Y: \(Int(previewManager.position.y))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        
                        // Quick position buttons
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            previewPositionButton("Top Left", position: .topLeft)
                            previewPositionButton("Top Right", position: .topRight)
                            previewPositionButton("Bottom Left", position: .bottomLeft)
                            previewPositionButton("Bottom Right", position: .bottomRight)
                        }
                    }
                }
                
                if previewManager.isPreviewVisible {
                    Section("Test Preview") {
                        Button("Reset to Default Position") {
                            previewManager.updatePosition(defaultPosition)
                        }
                        .foregroundColor(.blue)
                        
                        Button("Show Preview Now") {
                            previewManager.showPreview()
                        }
                        .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Preview Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var defaultPosition: CGPoint {
        let screenBounds = UIScreen.main.bounds
        return CGPoint(
            x: screenBounds.width - 140,
            y: screenBounds.height - 200
        )
    }
    
    private func previewPositionButton(_ title: String, position: CornerPosition) -> some View {
        Button(title) {
            previewManager.updatePosition(position.point(for: previewManager.previewSize))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
    
    enum CornerPosition {
        case topLeft, topRight, bottomLeft, bottomRight
        
        func point(for size: ExternalDisplayPreviewManager.PreviewSize) -> CGPoint {
            let screenBounds = UIScreen.main.bounds
            let dimensions = size.dimensions
            let margin: CGFloat = 20
            
            switch self {
            case .topLeft:
                return CGPoint(
                    x: dimensions.width/2 + margin,
                    y: dimensions.height/2 + margin + 100
                )
            case .topRight:
                return CGPoint(
                    x: screenBounds.width - dimensions.width/2 - margin,
                    y: dimensions.height/2 + margin + 100
                )
            case .bottomLeft:
                return CGPoint(
                    x: dimensions.width/2 + margin,
                    y: screenBounds.height - dimensions.height/2 - margin - 100
                )
            case .bottomRight:
                return CGPoint(
                    x: screenBounds.width - dimensions.width/2 - margin,
                    y: screenBounds.height - dimensions.height/2 - margin - 100
                )
            }
        }
    }
}

// Toolbar button for accessing preview settings
struct ExternalDisplayPreviewSettingsButton: View {
    @StateObject private var previewManager = ExternalDisplayPreviewManager()
    @State private var showingSettings = false
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    
    var body: some View {
        Button(action: { showingSettings = true }) {
            VStack(spacing: 4) {
                Image(systemName: previewManager.isPreviewVisible ? "rectangle.inset.filled" : "rectangle")
                    .font(.title3)
                    .foregroundColor(previewManager.isPreviewVisible ? .blue : .gray)
                Text("Preview")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .help("Configure external display preview")
        .sheet(isPresented: $showingSettings) {
            ExternalDisplayPreviewSettingsView(previewManager: previewManager)
        }
        .onChange(of: externalDisplayManager.state) { _, newState in
            previewManager.handleExternalDisplayStateChange(newState)
        }
    }
}

// Quick toggle for preview visibility
struct ExternalDisplayPreviewQuickToggle: View {
    @StateObject private var previewManager = ExternalDisplayPreviewManager()
    
    var body: some View {
        Button(action: previewManager.togglePreview) {
            HStack(spacing: 6) {
                Image(systemName: previewManager.isPreviewVisible ? "eye" : "eye.slash")
                    .font(.caption)
                Text(previewManager.isPreviewVisible ? "Hide" : "Show")
                    .font(.caption)
            }
            .foregroundColor(previewManager.isPreviewVisible ? .blue : .gray)
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
    }
}