//
//  ExternalDisplayPreviewManager.swift
//  ChurchHymn
//
//  Created by paulo on 08/11/2025.
//
//  PHASE 4: Preview Window Manager
//  - Manages preview window state and settings
//  - Handles positioning and visibility
//  - Coordinates with external display manager
//

import SwiftUI
import Combine

@MainActor
class ExternalDisplayPreviewManager: ObservableObject {
    @Published var isPreviewVisible: Bool = true
    @Published var isMinimized: Bool = false
    @Published var previewSize: PreviewSize = .medium
    @Published var previewOpacity: Double = 0.95
    @Published var position: CGPoint
    
    // Auto-behavior settings
    @Published var autoShowOnPresentation: Bool = true
    @Published var autoHideOnDisconnect: Bool = true
    @Published var snapToCorners: Bool = true
    
    private var cancellables = Set<AnyCancellable>()
    
    enum PreviewSize: String, CaseIterable, Identifiable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"
        
        var id: String { rawValue }
        
        var dimensions: CGSize {
            switch self {
            case .small:
                return CGSize(width: 180, height: 101) // 16:9 ratio
            case .medium:
                return CGSize(width: 240, height: 135) // 16:9 ratio
            case .large:
                return CGSize(width: 320, height: 180) // 16:9 ratio
            }
        }
    }
    
    init() {
        // Default position in bottom-right corner
        let screenBounds = UIScreen.main.bounds
        let defaultDimensions = PreviewSize.medium.dimensions
        self.position = CGPoint(
            x: screenBounds.width - defaultDimensions.width/2 - 40,
            y: screenBounds.height - defaultDimensions.height/2 - 120
        )
        
        // Load saved preferences
        loadPreferences()
        
        // Save preferences when they change
        setupPreferenceSaving()
    }
    
    private func loadPreferences() {
        isPreviewVisible = UserDefaults.standard.object(forKey: "ExternalPreview_Visible") as? Bool ?? true
        autoShowOnPresentation = UserDefaults.standard.object(forKey: "ExternalPreview_AutoShow") as? Bool ?? true
        autoHideOnDisconnect = UserDefaults.standard.object(forKey: "ExternalPreview_AutoHide") as? Bool ?? true
        snapToCorners = UserDefaults.standard.object(forKey: "ExternalPreview_SnapCorners") as? Bool ?? true
        previewOpacity = UserDefaults.standard.object(forKey: "ExternalPreview_Opacity") as? Double ?? 0.95
        
        if let sizeString = UserDefaults.standard.string(forKey: "ExternalPreview_Size"),
           let size = PreviewSize(rawValue: sizeString) {
            previewSize = size
        }
        
        // Load saved position
        let savedX = UserDefaults.standard.double(forKey: "ExternalPreview_PositionX")
        let savedY = UserDefaults.standard.double(forKey: "ExternalPreview_PositionY")
        if savedX > 0 && savedY > 0 {
            position = CGPoint(x: savedX, y: savedY)
        }
    }
    
    private func setupPreferenceSaving() {
        // Save preferences when they change
        $isPreviewVisible
            .sink { UserDefaults.standard.set($0, forKey: "ExternalPreview_Visible") }
            .store(in: &cancellables)
        
        $autoShowOnPresentation
            .sink { UserDefaults.standard.set($0, forKey: "ExternalPreview_AutoShow") }
            .store(in: &cancellables)
        
        $autoHideOnDisconnect
            .sink { UserDefaults.standard.set($0, forKey: "ExternalPreview_AutoHide") }
            .store(in: &cancellables)
        
        $snapToCorners
            .sink { UserDefaults.standard.set($0, forKey: "ExternalPreview_SnapCorners") }
            .store(in: &cancellables)
        
        $previewOpacity
            .sink { UserDefaults.standard.set($0, forKey: "ExternalPreview_Opacity") }
            .store(in: &cancellables)
        
        $previewSize
            .sink { UserDefaults.standard.set($0.rawValue, forKey: "ExternalPreview_Size") }
            .store(in: &cancellables)
        
        $position
            .sink { position in
                UserDefaults.standard.set(position.x, forKey: "ExternalPreview_PositionX")
                UserDefaults.standard.set(position.y, forKey: "ExternalPreview_PositionY")
            }
            .store(in: &cancellables)
    }
    
    func showPreview() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPreviewVisible = true
            isMinimized = false
        }
    }
    
    func hidePreview() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPreviewVisible = false
        }
    }
    
    func togglePreview() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPreviewVisible.toggle()
            if isPreviewVisible {
                isMinimized = false
            }
        }
    }
    
    func minimizePreview() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isMinimized = true
        }
    }
    
    func restorePreview() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isMinimized = false
        }
    }
    
    func updatePosition(_ newPosition: CGPoint, screenSize: CGSize? = nil) {
        let screenBounds = screenSize.map { CGRect(origin: .zero, size: $0) } ?? UIScreen.main.bounds
        let dimensions = previewSize.dimensions
        let margin: CGFloat = 20
        
        // Constrain to screen bounds with proper margins
        let constrainedPosition = CGPoint(
            x: max(dimensions.width/2 + margin, min(screenBounds.width - dimensions.width/2 - margin, newPosition.x)),
            y: max(dimensions.height/2 + 70, min(screenBounds.height - dimensions.height/2 - 70, newPosition.y))
        )
        
        // Snap to corners if enabled
        let finalPosition = snapToCorners ? snapToNearestCorner(constrainedPosition, screenBounds: screenBounds) : constrainedPosition
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            position = finalPosition
        }
    }
    
    private func snapToNearestCorner(_ point: CGPoint, screenBounds: CGRect) -> CGPoint {
        let dimensions = previewSize.dimensions
        let margin: CGFloat = 20
        
        let corners = [
            CGPoint(x: dimensions.width/2 + margin, y: dimensions.height/2 + margin + 70), // Top-left
            CGPoint(x: screenBounds.width - dimensions.width/2 - margin, y: dimensions.height/2 + margin + 70), // Top-right
            CGPoint(x: dimensions.width/2 + margin, y: screenBounds.height - dimensions.height/2 - margin - 70), // Bottom-left
            CGPoint(x: screenBounds.width - dimensions.width/2 - margin, y: screenBounds.height - dimensions.height/2 - margin - 70) // Bottom-right
        ]
        
        let snapDistance: CGFloat = 80
        
        for corner in corners {
            let distance = sqrt(pow(point.x - corner.x, 2) + pow(point.y - corner.y, 2))
            if distance < snapDistance {
                return corner
            }
        }
        
        return point
    }
    
    func handleExternalDisplayStateChange(_ state: ExternalDisplayState) {
        switch state {
        case .presenting:
            if autoShowOnPresentation && !isPreviewVisible {
                showPreview()
            }
        case .disconnected:
            if autoHideOnDisconnect {
                hidePreview()
            }
        case .connected:
            break
        case .worshipMode:
            // Show preview when worship session starts
            if autoShowOnPresentation && !isPreviewVisible {
                showPreview()
            }
        case .worshipPresenting:
            // Keep preview visible during worship hymn presentation
            if autoShowOnPresentation && !isPreviewVisible {
                showPreview()
            }
        }
    }
}

// Enhanced preview window with manager integration
struct ManagedExternalDisplayPreview: View {
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    @StateObject private var previewManager = ExternalDisplayPreviewManager()
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.clear
                .background {
                    GeometryReader { geometry in
                        Color.clear
                            .onChange(of: geometry.size) { _, newSize in
                                // Adjust position when screen size changes (orientation)
                                previewManager.updatePosition(previewManager.position, screenSize: newSize)
                            }
                            .onAppear {
                                // Initialize position if needed
                                if previewManager.position.x == 0 && previewManager.position.y == 0 {
                                    let dimensions = previewManager.previewSize.dimensions
                                    let defaultPosition = CGPoint(
                                        x: geometry.size.width - dimensions.width/2 - 20,
                                        y: geometry.size.height - dimensions.height/2 - 100
                                    )
                                    previewManager.updatePosition(defaultPosition, screenSize: geometry.size)
                                }
                            }
                    }
                }
            
            if shouldShowPreview {
                previewWindow
                    .position(previewManager.position)
                    .offset(dragOffset)
                    .opacity(previewManager.previewOpacity)
                    .scaleEffect(previewManager.isMinimized ? 0.7 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: previewManager.isPreviewVisible)
                    .animation(.spring(response: 0.3, dampingFraction: 0.9), value: previewManager.isMinimized)
                    .gesture(simpleDragGesture)
                    .allowsHitTesting(true)
            }
        }
        .allowsHitTesting(shouldShowPreview)
        .onChange(of: externalDisplayManager.state) { _, newState in
            previewManager.handleExternalDisplayStateChange(newState)
        }
    }
    
    private var shouldShowPreview: Bool {
        return externalDisplayManager.state == .presenting &&
               externalDisplayManager.currentHymn != nil &&
               previewManager.isPreviewVisible
    }
    
    private var previewWindow: some View {
        let dimensions = previewManager.previewSize.dimensions
        
        return VStack(spacing: 0) {
            // Enhanced header with drag handle
            previewHeader
            
            // Content area
            if !previewManager.isMinimized {
                previewContent
                    .frame(width: dimensions.width, height: dimensions.height)
                    .background(Color.black)
                    .cornerRadius(6, corners: [.bottomLeft, .bottomRight])
            }
        }
        .frame(width: dimensions.width)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(.systemGray3), lineWidth: 0.5)
        )
    }
    
    private var previewHeader: some View {
        HStack(spacing: 6) {
            // Live indicator
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
            
            // Title with current hymn
            if let hymn = externalDisplayManager.currentHymn {
                Text(hymn.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Control buttons
            HStack(spacing: 3) {
                Button(action: { previewManager.isMinimized.toggle() }) {
                    Image(systemName: previewManager.isMinimized ? "arrow.up.left.and.arrow.down.right" : "minus")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Button(action: previewManager.hidePreview) {
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
    
    private var previewContent: some View {
        Group {
            if let hymn = externalDisplayManager.currentHymn {
                ExternalDisplayMiniPreview(
                    hymn: hymn,
                    verseIndex: externalDisplayManager.currentVerseIndex
                )
            } else {
                VStack {
                    Image(systemName: "tv.slash")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))
                    Text("No Content")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private var simpleDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let newPosition = CGPoint(
                    x: previewManager.position.x + value.translation.width,
                    y: previewManager.position.y + value.translation.height
                )
                // Get current screen size (handles orientation changes)
                let currentSize = UIScreen.main.bounds.size
                previewManager.updatePosition(newPosition, screenSize: currentSize)
                dragOffset = .zero
            }
    }
    
    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let newPosition = CGPoint(
                    x: previewManager.position.x + value.translation.width,
                    y: previewManager.position.y + value.translation.height
                )
                previewManager.updatePosition(newPosition, screenSize: geometry.size)
                dragOffset = .zero
            }
    }
}

// Floating preview that adapts to content size
struct FloatingExternalDisplayPreview: View {
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    @StateObject private var previewManager = ExternalDisplayPreviewManager()
    @State private var dragOffset: CGSize = .zero
    @State private var screenSize: CGSize = UIScreen.main.bounds.size
    
    var body: some View {
        GeometryReader { geometry in
            if shouldShowPreview {
                previewWindow
                    .position(
                        x: geometry.size.width + previewManager.position.x,
                        y: geometry.size.height + previewManager.position.y
                    )
                    .offset(dragOffset)
                    .opacity(previewManager.previewOpacity)
                    .scaleEffect(previewManager.isMinimized ? 0.7 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: previewManager.isPreviewVisible)
                    .animation(.spring(response: 0.3, dampingFraction: 0.9), value: previewManager.isMinimized)
                    .gesture(dragGesture(in: geometry))
                    .onAppear {
                        initializePosition(in: geometry)
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        screenSize = newSize
                        constrainPosition(in: geometry)
                    }
            }
        }
        .allowsHitTesting(shouldShowPreview)
        .onChange(of: externalDisplayManager.state) { _, newState in
            previewManager.handleExternalDisplayStateChange(newState)
        }
    }
    
    private var shouldShowPreview: Bool {
        return externalDisplayManager.state == .presenting &&
               externalDisplayManager.currentHymn != nil &&
               previewManager.isPreviewVisible
    }
    
    private var previewWindow: some View {
        let dimensions = previewManager.previewSize.dimensions
        
        return VStack(spacing: 0) {
            // Enhanced header with drag handle
            previewHeader
            
            // Content area
            if !previewManager.isMinimized {
                previewContent
                    .frame(width: dimensions.width, height: dimensions.height)
                    .background(Color.black)
                    .cornerRadius(6, corners: [.bottomLeft, .bottomRight])
            }
        }
        .frame(width: dimensions.width)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(.systemGray3), lineWidth: 0.5)
        )
    }
    
    private var previewHeader: some View {
        HStack(spacing: 6) {
            // Live indicator
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
            
            // Title with current hymn
            if let hymn = externalDisplayManager.currentHymn {
                Text(hymn.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Control buttons
            HStack(spacing: 3) {
                Button(action: { previewManager.isMinimized.toggle() }) {
                    Image(systemName: previewManager.isMinimized ? "arrow.up.left.and.arrow.down.right" : "minus")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Button(action: previewManager.hidePreview) {
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
    
    private var previewContent: some View {
        Group {
            if let hymn = externalDisplayManager.currentHymn {
                ExternalDisplayMiniPreview(
                    hymn: hymn,
                    verseIndex: externalDisplayManager.currentVerseIndex
                )
            } else {
                VStack {
                    Image(systemName: "tv.slash")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))
                    Text("No Content")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    
    private func initializePosition(in geometry: GeometryProxy) {
        let dimensions = previewManager.previewSize.dimensions
        let margin: CGFloat = 20
        
        // Position relative to bottom-right of geometry (outside the content area)
        let defaultPosition = CGPoint(
            x: -dimensions.width/2 - margin, // Offset to the left from right edge
            y: -dimensions.height/2 - margin // Offset up from bottom edge
        )
        previewManager.position = defaultPosition
    }
    
    private func updatePosition(_ newPosition: CGPoint, in geometry: GeometryProxy) {
        let dimensions = previewManager.previewSize.dimensions
        let margin: CGFloat = 20
        
        // Constrain position (coordinates are relative to bottom-right of geometry)
        let constrainedPosition = CGPoint(
            x: max(-(geometry.size.width - dimensions.width/2 - margin), min(-dimensions.width/2 - margin, newPosition.x)),
            y: max(-(geometry.size.height - dimensions.height/2 - 100), min(-dimensions.height/2 - margin, newPosition.y))
        )
        
        previewManager.position = constrainedPosition
    }
    
    private func constrainPosition(in geometry: GeometryProxy) {
        updatePosition(previewManager.position, in: geometry)
    }
    
    
    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let newPosition = CGPoint(
                    x: previewManager.position.x + value.translation.width,
                    y: previewManager.position.y + value.translation.height
                )
                updatePosition(newPosition, in: geometry)
                dragOffset = .zero
            }
    }
}
