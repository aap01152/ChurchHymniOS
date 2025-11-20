//
//  ExternalDisplayPreview.swift
//  ChurchHymn
//
//  Created by paulo on 08/11/2025.
//
//  PHASE 4: Visual Feedback System - Preview Window Option
//  - Small preview window showing scaled-down external display content
//  - Real-time updates as verses change
//  - Positioned in bottom-right corner of iPad interface
//  - Toggleable visibility with smooth animations
//

import SwiftUI

struct ExternalDisplayPreview: View {
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    @State private var isVisible: Bool = true
    @State private var dragOffset: CGSize = .zero
    @State private var position: CGPoint = .zero
    @State private var hasInitializedPosition = false
    
    // Preview window dimensions
    private let previewWidth: CGFloat = 240
    private let previewHeight: CGFloat = 135
    private let aspectRatio: CGFloat = 16.0 / 9.0 // Standard projector aspect ratio
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if shouldShowPreview {
                    previewWindow
                        .position(x: position.x, y: position.y)
                        .offset(dragOffset)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
                        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: dragOffset)
                        .gesture(dragGesture(in: geometry))
                        .onAppear {
                            if !hasInitializedPosition {
                                initializePosition(in: geometry)
                            }
                        }
                        .onChange(of: geometry.size) { _, newSize in
                            updatePositionForNewSize(newSize)
                        }
                }
            }
        }
        .allowsHitTesting(shouldShowPreview)
    }
    
    private var shouldShowPreview: Bool {
        return externalDisplayManager.state == .presenting &&
               externalDisplayManager.currentHymn != nil &&
               isVisible
    }
    
    private var previewWindow: some View {
        VStack(spacing: 0) {
            // Preview header with controls
            previewHeader
            
            // Scaled-down external display content
            previewContent
                .frame(width: previewWidth, height: previewHeight)
                .background(Color.black)
                .cornerRadius(6, corners: [.bottomLeft, .bottomRight])
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(.systemGray4), lineWidth: 0.5)
        )
    }
    
    private var previewHeader: some View {
        HStack(spacing: 6) {
            // Preview indicator
            HStack(spacing: 3) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                    .symbolEffect(.pulse)
                
                Text("LIVE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            // Preview title
            Text("External Display")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            // Controls
            HStack(spacing: 3) {
                // Minimize/Restore button
                Button(action: toggleMinimized) {
                    Image(systemName: isMinimized ? "arrow.up.left.and.arrow.down.right" : "minus")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                // Close button
                Button(action: closePreview) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(6, corners: [.topLeft, .topRight])
    }
    
    @State private var isMinimized: Bool = false
    
    private var previewContent: some View {
        Group {
            if isMinimized {
                // Minimized state - just show a compact indicator
                VStack {
                    Image(systemName: "tv.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("Minimized")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let hymn = externalDisplayManager.currentHymn {
                // Full preview - scaled down version of ExternalPresenterView
                ExternalDisplayMiniPreview(
                    hymn: hymn,
                    verseIndex: externalDisplayManager.currentVerseIndex
                )
            } else {
                // Fallback content
                VStack {
                    Text("No Content")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                // Update position and reset offset with adaptive bounds
                let safeArea = geometry.safeAreaInsets
                let minX = previewWidth/2 + safeArea.leading
                let maxX = geometry.size.width - previewWidth/2 - safeArea.trailing
                let minY = previewHeight/2 + safeArea.top + 50
                let maxY = geometry.size.height - previewHeight/2 - safeArea.bottom - 50
                
                let newPosition = CGPoint(
                    x: max(minX, min(maxX, position.x + value.translation.width)),
                    y: max(minY, min(maxY, position.y + value.translation.height))
                )
                position = newPosition
                dragOffset = .zero
            }
    }
    
    private func toggleMinimized() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isMinimized.toggle()
        }
    }
    
    private func closePreview() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible = false
        }
    }
    
    func showPreview() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible = true
            isMinimized = false
        }
    }
    
    private func initializePosition(in geometry: GeometryProxy) {
        let safeArea = geometry.safeAreaInsets
        let defaultX = geometry.size.width - previewWidth/2 - safeArea.trailing - 20
        let defaultY = geometry.size.height - previewHeight/2 - safeArea.bottom - 100
        
        position = CGPoint(x: defaultX, y: defaultY)
        hasInitializedPosition = true
    }
    
    private func updatePositionForNewSize(_ size: CGSize) {
        guard hasInitializedPosition else { return }
        
        // Keep the preview visible when orientation changes
        let margin: CGFloat = 20
        let minX = previewWidth/2 + margin
        let maxX = size.width - previewWidth/2 - margin
        let minY = previewHeight/2 + 70
        let maxY = size.height - previewHeight/2 - 70
        
        let adjustedPosition = CGPoint(
            x: max(minX, min(maxX, position.x)),
            y: max(minY, min(maxY, position.y))
        )
        
        withAnimation(.easeInOut(duration: 0.3)) {
            position = adjustedPosition
        }
    }
}

// Scaled-down version of the external presenter for preview
struct ExternalDisplayMiniPreview: View {
    let hymn: Hymn
    let verseIndex: Int
    
    private var presentationParts: [(label: String?, lines: [String])] {
        let allBlocks = hymn.parts
        
        let choruses = allBlocks.filter { $0.label != nil }
        let verses = allBlocks.filter { $0.label == nil }
        
        if let chorusPart = choruses.first {
            var result: [(label: String?, lines: [String])] = []
            for verse in verses {
                result.append(verse)
                result.append(chorusPart)
            }
            return result
        } else {
            return verses
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Mini header
                VStack(spacing: 2) {
                    Text(hymn.title)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    if let key = hymn.musicalKey, !key.isEmpty {
                        Text("(\(key))")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundColor(.yellow)
                    }
                }
                .frame(height: geometry.size.height * 0.12)
                .padding(.horizontal, 3)
                
                Spacer()
                
                // Mini lyrics
                Group {
                    if !presentationParts.isEmpty && verseIndex < presentationParts.count {
                        let currentPart = presentationParts[verseIndex]
                        Text(currentPart.lines.joined(separator: "\n"))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .minimumScaleFactor(0.5)
                            .lineLimit(6)
                    } else {
                        Text("No lyrics")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxHeight: geometry.size.height * 0.73)
                .padding(.horizontal, 4)
                
                Spacer()
                
                // Mini footer
                HStack {
                    // Verse indicator
                    if !presentationParts.isEmpty && verseIndex < presentationParts.count {
                        let currentPart = presentationParts[verseIndex]
                        if let label = currentPart.label {
                            Text(label)
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.yellow)
                        } else {
                            let verseNumber = presentationParts[0...verseIndex].filter { $0.label == nil }.count
                            Text("V\(verseNumber)")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Spacer()
                    
                    // Progress
                    Text("\(verseIndex + 1)/\(presentationParts.count)")
                        .font(.system(size: 6, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(height: geometry.size.height * 0.15)
                .padding(.horizontal, 3)
            }
        }
        .background(Color.black)
    }
}

// Preview window settings and manager
class ExternalDisplayPreviewSettings: ObservableObject {
    @Published var isPreviewEnabled: Bool = true
    @Published var previewOpacity: Double = 0.9
    @Published var previewSize: PreviewSize = .medium
    @Published var autoHideWhenNotPresenting: Bool = true
    
    enum PreviewSize: String, CaseIterable, Identifiable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"
        
        var id: String { rawValue }
        
        var dimensions: CGSize {
            switch self {
            case .small:
                return CGSize(width: 180, height: 100)
            case .medium:
                return CGSize(width: 240, height: 135)
            case .large:
                return CGSize(width: 320, height: 180)
            }
        }
    }
}

// Corner radius extension for specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// Preview toggle button for toolbar integration
struct ExternalDisplayPreviewToggle: View {
    @StateObject private var previewSettings = ExternalDisplayPreviewSettings()
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    
    var body: some View {
        Button(action: togglePreview) {
            VStack(spacing: 4) {
                Image(systemName: previewSettings.isPreviewEnabled ? "rectangle.inset.filled" : "rectangle")
                    .font(.title3)
                    .foregroundColor(previewSettings.isPreviewEnabled ? .blue : .gray)
                Text("Preview")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .help(previewSettings.isPreviewEnabled ? "Hide external display preview" : "Show external display preview")
    }
    
    private func togglePreview() {
        withAnimation(.easeInOut(duration: 0.3)) {
            previewSettings.isPreviewEnabled.toggle()
        }
    }
}