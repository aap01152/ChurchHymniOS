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
                Section(NSLocalizedString("preview.window", comment: "Preview window section")) {
                    Toggle(NSLocalizedString("preview.show_preview_window", comment: "Show preview window toggle"), isOn: $previewManager.isPreviewVisible)
                        .help(NSLocalizedString("preview.show_preview_help", comment: "Show preview help text"))
                    
                    if previewManager.isPreviewVisible {
                        HStack {
                            Text(NSLocalizedString("preview.size", comment: "Size label"))
                            Spacer()
                            Picker(NSLocalizedString("preview.size", comment: "Size picker"), selection: $previewManager.previewSize) {
                                ForEach(ExternalDisplayPreviewManager.PreviewSize.allCases) { size in
                                    Text(size.rawValue).tag(size)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Text(NSLocalizedString("preview.opacity", comment: "Opacity label"))
                                Spacer()
                                Text("\(Int(previewManager.previewOpacity * 100))%")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            
                            Slider(value: $previewManager.previewOpacity, in: 0.3...1.0, step: 0.1)
                                .help(NSLocalizedString("preview.adjust_transparency_help", comment: "Adjust transparency help text"))
                        }
                    }
                }
                
                Section(NSLocalizedString("preview.behavior", comment: "Behavior section")) {
                    Toggle(NSLocalizedString("preview.auto_show_presenting", comment: "Auto-show toggle"), isOn: $previewManager.autoShowOnPresentation)
                        .help(NSLocalizedString("preview.auto_show_help", comment: "Auto-show help text"))
                    
                    Toggle(NSLocalizedString("preview.auto_hide_disconnected", comment: "Auto-hide toggle"), isOn: $previewManager.autoHideOnDisconnect)
                        .help(NSLocalizedString("preview.auto_hide_help", comment: "Auto-hide help text"))
                    
                    Toggle(NSLocalizedString("preview.snap_corners", comment: "Snap to corners toggle"), isOn: $previewManager.snapToCorners)
                        .help(NSLocalizedString("preview.snap_help", comment: "Snap to corners help text"))
                }
                
                Section(NSLocalizedString("preview.position", comment: "Preview position section")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("preview.current_position", comment: "Current position label"))
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
                            previewPositionButton(NSLocalizedString("preview.top_left", comment: "Top left position"), position: .topLeft)
                            previewPositionButton(NSLocalizedString("preview.top_right", comment: "Top right position"), position: .topRight)
                            previewPositionButton(NSLocalizedString("preview.bottom_left", comment: "Bottom left position"), position: .bottomLeft)
                            previewPositionButton(NSLocalizedString("preview.bottom_right", comment: "Bottom right position"), position: .bottomRight)
                        }
                    }
                }
                
                if previewManager.isPreviewVisible {
                    Section(NSLocalizedString("preview.test_preview", comment: "Test preview section")) {
                        Button(NSLocalizedString("preview.reset_default", comment: "Reset to default position")) {
                            previewManager.updatePosition(defaultPosition)
                        }
                        .foregroundColor(.blue)
                        
                        Button(NSLocalizedString("preview.show_now", comment: "Show preview now")) {
                            previewManager.showPreview()
                        }
                        .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("preview.settings", comment: "Preview settings title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("preview.done", comment: "Done button")) {
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
                Text(NSLocalizedString("display.preview", comment: "Preview text"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .help(NSLocalizedString("preview.configure_help", comment: "Configure preview help text"))
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
                Text(previewManager.isPreviewVisible ? NSLocalizedString("btn.hide", comment: "Hide button") : NSLocalizedString("btn.show", comment: "Show button"))
                    .font(.caption)
            }
            .foregroundColor(previewManager.isPreviewVisible ? .blue : .gray)
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
    }
}